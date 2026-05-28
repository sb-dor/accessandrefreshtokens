import 'dart:async';
import 'dart:convert';

import 'package:accessandrefreshtoken/src/common/constant/config.dart';
import 'package:http_interceptor/http_interceptor.dart';
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
final class AuthenticationInterceptor implements HttpInterceptor, RetryPolicy {
  AuthenticationInterceptor({
    required ITokenStorage tokenStorage,
    required Future<void> Function() onUnauthenticated,
  }) : _storage = tokenStorage,
       _onUnauthenticated = onUnauthenticated;

  final ITokenStorage _storage;
  final Future<void> Function() _onUnauthenticated;

  /// Serializes concurrent refresh attempts.
  /// While a refresh is in flight all other failing requests await this completer.
  Completer<bool>? _refreshCompleter;

  @override
  int get maxRetryAttempts => 1;

  @override
  BaseRequest interceptRequest({required BaseRequest request}) {
    final intercepted = _cloneRequest(request);

    intercepted.headers.putIfAbsent('Content-Type', () => 'application/json');
    intercepted.headers.putIfAbsent('Accept', () => 'application/json');

    final path = intercepted.url.path;
    final accessToken = _storage.accessToken;
    if (accessToken != null &&
        accessToken.isNotEmpty &&
        !path.contains('auth/login') &&
        !path.contains('auth/refresh')) {
      intercepted.headers['Authorization'] = 'Bearer $accessToken';
    }

    return intercepted;
  }

  @override
  BaseResponse interceptResponse({required BaseResponse response}) => response;

  @override
  bool shouldInterceptRequest({required BaseRequest request}) => true;

  @override
  bool shouldInterceptResponse({required BaseResponse response}) => false;

  @override
  bool shouldAttemptRetryOnException(Exception reason, BaseRequest request) => false;

  @override
  Future<bool> shouldAttemptRetryOnResponse(BaseResponse response) async {
    if (response.statusCode != 401) return false;

    final requestPath = response.request?.url.path;
    if (requestPath == null ||
        requestPath.contains('auth/login') ||
        requestPath.contains('auth/register') ||
        requestPath.contains('auth/refresh')) {
      return false;
    }

    return _refreshTokens();
  }

  @override
  Duration delayRetryAttemptOnException({required int retryAttempt}) => Duration.zero;

  @override
  Duration delayRetryAttemptOnResponse({required int retryAttempt}) => Duration.zero;

  BaseRequest _cloneRequest(BaseRequest request) {
    if (request is Request) {
      return Request(request.method, request.url)
        ..bodyBytes = request.bodyBytes
        ..encoding = request.encoding
        ..headers.addAll(request.headers)
        ..followRedirects = request.followRedirects
        ..maxRedirects = request.maxRedirects
        ..persistentConnection = request.persistentConnection;
    }

    return Request(request.method, request.url)
      ..headers.addAll(request.headers)
      ..followRedirects = request.followRedirects
      ..maxRedirects = request.maxRedirects
      ..persistentConnection = request.persistentConnection;
  }

  Future<bool> _refreshTokens() {
    final activeRefresh = _refreshCompleter;
    if (activeRefresh != null) return activeRefresh.future;

    final completer = Completer<bool>();
    _refreshCompleter = completer;

    () async {
      try {
        completer.complete(await _doRefreshTokens());
      } on Object {
        await _handleUnauthenticated();
        completer.complete(false);
      } finally {
        _refreshCompleter = null;
      }
    }();

    return completer.future;
  }

  Future<bool> _doRefreshTokens() async {
    final refreshToken = _storage.refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) {
      await _handleUnauthenticated();
      return false;
    }

    final request = Request('POST', Uri.parse('${Config.apiBaseUrl}/auth/refresh'))
      ..headers.addAll({'Content-Type': 'application/json', 'Accept': 'application/json'})
      ..body = jsonEncode({'refreshToken': refreshToken});

    final response = await request.send();
    final bytes = await response.stream.toBytes();

    if (response.statusCode == 401 || response.statusCode == 403) {
      await _handleUnauthenticated();
      return false;
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      return false;
    }

    final data = bytes.isEmpty ? null : jsonDecode(utf8.decode(bytes));
    if (data is! Map<String, Object?>) return false;

    final tokens = data['tokens'];
    final tokenMap = tokens is Map<String, Object?> ? tokens : data;
    final accessToken = tokenMap['accessToken'] ?? tokenMap['access_token'];
    final newRefreshToken = tokenMap['refreshToken'] ?? tokenMap['refresh_token'];

    if (accessToken is! String ||
        accessToken.isEmpty ||
        newRefreshToken is! String ||
        newRefreshToken.isEmpty) {
      return false;
    }

    await _storage.saveTokens(accessToken: accessToken, refreshToken: newRefreshToken);
    return true;
  }

  Future<void> _handleUnauthenticated() async {
    await _storage.clearTokens();
    await _onUnauthenticated();
  }
}
