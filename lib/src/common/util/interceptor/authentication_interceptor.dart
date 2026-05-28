import 'dart:async';

import 'package:accessandrefreshtoken/src/common/util/api_client.dart';
import 'package:accessandrefreshtoken/src/features/authentication/data/refresh_token_repository.dart';
import 'package:l/l.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Token Storage Interface
// ─────────────────────────────────────────────────────────────────────────────

/// Contract for token storage.
///
/// After [restore] is called once at startup, all subsequent reads come from
/// memory — never from disk. This avoids I/O on every HTTP request.
abstract interface class ITokenStorage {
  String? get accessToken;
  String? get refreshToken;

  /// Load tokens from SharedPreferences into memory. Call once at app startup.
  Future<void> restore();

  /// Save both tokens to memory + SharedPreferences (e.g. after login/refresh).
  Future<void> saveTokens({required String accessToken, required String refreshToken});

  /// Clear both tokens from memory + SharedPreferences (e.g. on logout).
  Future<void> clearTokens();
}

// ─────────────────────────────────────────────────────────────────────────────
// SharedPreferences Implementation
// ─────────────────────────────────────────────────────────────────────────────

final class SharedPrefsTokenStorage implements ITokenStorage {
  SharedPrefsTokenStorage({required SharedPreferences sharedPreferences})
    : _prefs = sharedPreferences;

  final SharedPreferences _prefs;

  static const _accessKey = 'access_token';
  static const _refreshKey = 'refresh_token';

  // In-memory cache — populated by restore(), updated by saveTokens/clearTokens
  String? _accessToken;
  String? _refreshToken;

  @override
  String? get accessToken => _accessToken;

  @override
  String? get refreshToken => _refreshToken;

  @override
  Future<void> restore() async {
    _accessToken = _prefs.getString(_accessKey);
    _refreshToken = _prefs.getString(_refreshKey);
  }

  @override
  Future<void> saveTokens({required String accessToken, required String refreshToken}) async {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
    await Future.wait([
      _prefs.setString(_accessKey, accessToken),
      _prefs.setString(_refreshKey, refreshToken),
    ]);
  }

  @override
  Future<void> clearTokens() async {
    _accessToken = null;
    _refreshToken = null;
    await Future.wait([_prefs.remove(_accessKey), _prefs.remove(_refreshKey)]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Authentication Interceptor
// ─────────────────────────────────────────────────────────────────────────────

/// HTTP auth interceptor/retry policy that:
/// 1. Attaches the access token from memory to every outgoing request.
/// 2. On 401: attempts a token refresh, then lets http_interceptor retry once.
/// 3. On refresh 401 (or no refresh token): clears tokens and calls [onUnauthenticated].
///
/// Concurrent 401s are serialized — only one refresh HTTP call is ever in flight.

class AuthenticationInterceptor {
  AuthenticationInterceptor({
    required final AuthenticationHeaders authenticationHeaders,
    required final Future<TokenPair?> Function() onTokenRefreshed,
    required final void Function() onExpired,
  }) : _authenticationHeaders = authenticationHeaders,
       _onTokenRefreshed = onTokenRefreshed,
       _onExpired = onExpired;

  final AuthenticationHeaders _authenticationHeaders;
  final Future<TokenPair?> Function() _onTokenRefreshed;
  final void Function() _onExpired;

  // refresh token flow (not yet active — only access_token is used for now):
  //
  // required this.onRefreshToken — provides the refresh token string to send to the server
  //

  //
  // call() would become:
  //
  ApiClientHandler call(ApiClientHandler innerHandler) =>
      (request, context, onServerErrorMessage) async {
        final headers = _authenticationHeaders.headers();
        if (headers.isNotEmpty) request.headers.addAll(headers);

        try {
          return await innerHandler(request, context, onServerErrorMessage);
        } on APIClientException$Authorization {
          // first 401: try refresh instead of expiring immediately
          try {
            final newToken = await _onTokenRefreshed();
            if (newToken == null) {
              _onExpired();
              rethrow;
            }
            l.d('new token value: $newToken');
            final retryRequest = request.copy()
              ..headers['Authorization'] = 'Bearer ${newToken.accessToken}';
            return await innerHandler(retryRequest, context, onServerErrorMessage);
          } on APIClientException$Authorization {
            // refresh failed or retry also got 401 → session truly expired
            l.d('refresh token expired');
            _onExpired();
            rethrow;
          }
        }
      };
}

class AuthenticationHeaders {
  const AuthenticationHeaders({required final ITokenStorage tokenStorage})
    : _tokenStorage = tokenStorage;

  final ITokenStorage _tokenStorage;

  Map<String, String> headers() {
    final headers = <String, String>{};
    if (_tokenStorage.accessToken != null) {
      headers['Authorization'] = 'Bearer ${_tokenStorage.accessToken}';
    }

    return headers;
  }
}
