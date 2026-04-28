import 'package:accessandrefreshtoken/src/common/util/interceptor/authentication_interceptor.dart';
import 'package:accessandrefreshtoken/src/features/authentication/model/user.dart';
import 'package:dio/dio.dart';

abstract interface class IAuthenticationRepository {
  Future<User> login({required String email, required String password});

  Future<User> register({required String name, required String email, required String password});

  Future<void> logout();

  /// Attempts to refresh the access token using the stored refresh token.
  /// Returns true if successful, false if the session is expired.
  Future<bool> refreshToken();

  /// Validates the stored access token with the backend.
  /// Returns null if no token is stored or both tokens are invalid.
  Future<User?> restoreSession();
}

class AuthenticationRepositoryImpl implements IAuthenticationRepository {
  AuthenticationRepositoryImpl({required final Dio dio, required final ITokenStorage tokenStorage})
    : _dio = dio,
      _tokenStorage = tokenStorage;

  final Dio _dio;
  final ITokenStorage _tokenStorage;

  @override
  Future<User> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final response = await _dio.post<Map<String, Object?>>(
      '/api/auth/register',
      data: {'name': name, 'email': email, 'password': password},
    );
    final data = response.data!;
    await _tokenStorage.saveTokens(
      accessToken: data['access_token'] as String,
      refreshToken: data['refresh_token'] as String,
    );
    return User.fromMap(data['user'] as Map<String, Object?>);
  }

  @override
  Future<User> login({required String email, required String password}) async {
    final response = await _dio.post<Map<String, Object?>>(
      '/api/auth/login',
      data: {'email': email, 'password': password},
    );
    final data = response.data!;
    await _tokenStorage.saveTokens(
      accessToken: data['access_token'] as String,
      refreshToken: data['refresh_token'] as String,
    );
    return User.fromMap(data['user'] as Map<String, Object?>);
  }

  @override
  Future<void> logout() async {
    try {
      await _dio.post<void>(
        '/api/auth/logout',
        data: {'refresh_token': _tokenStorage.refreshToken},
        // Authorization header is added automatically by AuthenticationInterceptor
      );
    } on DioException {
      // Best-effort — always clear tokens locally regardless of network result
    } finally {
      await _tokenStorage.clearTokens();
    }
  }

  @override
  Future<bool> refreshToken() async {
    final refreshToken = _tokenStorage.refreshToken;
    if (refreshToken == null) return false;
    try {
      final response = await _dio.post<Map<String, Object?>>(
        '/api/auth/refresh',
        data: {'refresh_token': refreshToken},
      );
      final data = response.data!;
      await _tokenStorage.saveTokens(
        accessToken: data['access_token'] as String,
        refreshToken: data['refresh_token'] as String,
      );
      return true;
    } on DioException {
      return false;
    }
  }

  @override
  Future<User?> restoreSession() async {
    // Tokens are already in memory after restore() was called during init.
    // No disk read needed here — just check if the access token is present.
    if (_tokenStorage.accessToken == null) return null;
    try {
      // The interceptor will transparently refresh the token if it's expired.
      final response = await _dio.get<Map<String, Object?>>('/api/auth/me');
      return User.fromMap(response.data!);
    } on DioException catch (e) {
      // If both access + refresh tokens are invalid, the interceptor calls
      // onUnauthenticated and we get here with a 401 that wasn't retried.
      if (e.response?.statusCode == 401) {
        await _tokenStorage.clearTokens();
      }
      return null;
    }
  }
}

class AuthenticationFakeRepositoryImpl implements IAuthenticationRepository {
  @override
  Future<User> login({required String email, required String password}) =>
      Future.value(const User(id: -1));

  @override
  Future<User> register({required String name, required String email, required String password}) =>
      Future.value(const User(id: -1));

  @override
  Future<void> logout() => Future.value();

  @override
  Future<bool> refreshToken() => Future.value(true);

  @override
  Future<User?> restoreSession() => Future.value(const User(id: -1));
}
