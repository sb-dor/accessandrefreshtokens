import 'package:accessandrefreshtoken/src/common/util/api_client.dart';
import 'package:accessandrefreshtoken/src/common/util/interceptor/authentication_interceptor.dart';
import 'package:accessandrefreshtoken/src/features/authentication/model/user.dart';

abstract interface class IAuthenticationRepository {
  Future<User> login({required String email, required String password});

  Future<User> register({required String name, required String email, required String password});

  Future<void> logout();

  /// Validates the stored access token with the backend.
  /// Returns null if no token is stored or both tokens are invalid.
  Future<User?> restoreSession();
}

class AuthenticationRepositoryImpl implements IAuthenticationRepository {
  AuthenticationRepositoryImpl({
    required final ApiClient client,
    required final ITokenStorage tokenStorage,
  }) : _client = client,
       _tokenStorage = tokenStorage;

  final ApiClient _client;
  final ITokenStorage _tokenStorage;

  @override
  Future<User> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final response = await _client.post(
      '/auth/register',
      body: {'name': name, 'email': email, 'password': password},
    );
    final data = response.body;
    final tokens = data['tokens'] as Map<String, Object?>;
    await _tokenStorage.saveTokens(
      accessToken: tokens['accessToken'] as String,
      refreshToken: tokens['refreshToken'] as String,
    );
    _tokenStorage.restore();
    return User.fromMap(data['user'] as Map<String, Object?>);
  }

  @override
  Future<User> login({required String email, required String password}) async {
    final response = await _client.post(
      '/auth/login',
      body: {'email': email, 'password': password},
    );
    final data = response.body;
    final tokens = data['tokens'] as Map<String, Object?>;
    await _tokenStorage.saveTokens(
      accessToken: tokens['accessToken'] as String,
      refreshToken: tokens['refreshToken'] as String,
    );
    _tokenStorage.restore();
    return User.fromMap(data['user'] as Map<String, Object?>);
  }

  @override
  Future<void> logout() async {
    try {
      await _client.post(
        '/auth/logout',
        body: {'refresh_token': _tokenStorage.refreshToken},
        // Authorization header is added automatically by AuthenticationInterceptor
      );
    } finally {
      await _tokenStorage.clearTokens();
    }
  }

  @override
  Future<User?> restoreSession() async {
    // Tokens are already in memory after restore() was called during init.
    // No disk read needed here — just check if the access token is present.
    if (_tokenStorage.accessToken == null) return null;
    // The interceptor will transparently refresh the token if it's expired.
    final response = await _client.get('/auth/me');
    return User.fromMap(response.body);
  }
}

class AuthenticationFakeRepositoryImpl implements IAuthenticationRepository {
  @override
  Future<User> login({required String email, required String password}) =>
      Future.value(const User(id: '-1'));

  @override
  Future<User> register({required String name, required String email, required String password}) =>
      Future.value(const User(id: '-1'));

  @override
  Future<void> logout() => Future.value();

  @override
  Future<User?> restoreSession() => Future.value(const User(id: '-1'));
}
