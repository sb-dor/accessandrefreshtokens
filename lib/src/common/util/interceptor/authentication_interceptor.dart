import 'dart:async';

import 'package:dio/dio.dart';
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

/// Dio interceptor that:
/// 1. Attaches the access token from memory to every outgoing request.
/// 2. On 401: attempts a token refresh, then retries the original request.
/// 3. On refresh 401 (or no refresh token): clears tokens and calls [onUnauthenticated].
///
/// Concurrent 401s are serialized — only one refresh HTTP call is ever in flight.
final class AuthenticationInterceptor extends Interceptor {
  AuthenticationInterceptor({
    required ITokenStorage tokenStorage,
    required Dio dio,
    required void Function() onUnauthenticated,
  }) : _storage = tokenStorage,
       _dio = dio,
       _onUnauthenticated = onUnauthenticated;

  final ITokenStorage _storage;
  final Dio _dio;
  final void Function() _onUnauthenticated;

  /// Serializes concurrent refresh attempts.
  /// While a refresh is in flight all other failing requests await this completer.
  Completer<bool>? _refreshCompleter;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = _storage.accessToken;
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode != 401) {
      handler.next(err);
      return;
    }

    // A 401 from the refresh endpoint itself → session is fully dead → logout.
    if (err.requestOptions.path.contains('/auth/refresh')) {
      await _storage.clearTokens();
      _onUnauthenticated();
      handler.next(err);
      return;
    }

    final refreshed = await _doRefresh();

    if (refreshed) {
      // Retry the original request with the new access token.
      try {
        final opts = err.requestOptions;
        opts.headers['Authorization'] = 'Bearer ${_storage.accessToken}';
        final retryResponse = await _dio.fetch(opts);
        handler.resolve(retryResponse);
      } on DioException catch (retryErr) {
        handler.next(retryErr);
      }
    } else {
      _onUnauthenticated();
      handler.next(err);
    }
  }

  /// Returns true if the refresh succeeded and new tokens are saved.
  /// Serialized: if already in flight, waits for the in-flight result.
  Future<bool> _doRefresh() async {
    if (_refreshCompleter != null) {
      return _refreshCompleter!.future;
    }

    _refreshCompleter = Completer<bool>();

    try {
      final refreshToken = _storage.refreshToken;
      if (refreshToken == null) {
        _refreshCompleter!.complete(false);
        return false;
      }

      final response = await _dio.post<Map<String, Object?>>(
        '/api/auth/refresh',
        data: {'refresh_token': refreshToken},
      );

      final data = response.data!;
      await _storage.saveTokens(
        accessToken: data['access_token'] as String,
        refreshToken: data['refresh_token'] as String,
      );

      _refreshCompleter!.complete(true);
      return true;
    } on DioException {
      _refreshCompleter!.complete(false);
      return false;
    } finally {
      _refreshCompleter = null;
    }
  }
}
