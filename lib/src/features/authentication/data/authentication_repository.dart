import 'dart:convert';

import 'package:accessandrefreshtoken/src/common/constant/config.dart';
import 'package:accessandrefreshtoken/src/common/util/interceptor/authentication_interceptor.dart';
import 'package:accessandrefreshtoken/src/features/authentication/model/user.dart';
import 'package:http/http.dart' as http;

abstract interface class IAuthenticationRepository {
  Future<User> login({required String email, required String password});

  Future<User> register({required String name, required String email, required String password});

  Future<void> logout();

  /// Attempts to refresh the access token using the stored refresh token.
  /// Returns true if successful, false if the session is expired.
  Future<String?> refreshToken();

  /// Validates the stored access token with the backend.
  /// Returns null if no token is stored or both tokens are invalid.
  Future<User?> restoreSession();
}

class AuthenticationRepositoryImpl implements IAuthenticationRepository {
  AuthenticationRepositoryImpl({
    required final http.Client client,
    required final ITokenStorage tokenStorage,
  }) : _client = client,
       _tokenStorage = tokenStorage;

  final http.Client _client;
  final ITokenStorage _tokenStorage;

  @override
  Future<User> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final response = await _client.post(
      Uri.parse('${Config.apiBaseUrl}/auth/register'),
      body: jsonEncode({'name': name, 'email': email, 'password': password}),
    );
    final data = jsonDecode(response.body) as Map<String, Object?>;
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
      Uri.parse('${Config.apiBaseUrl}/auth/login'),
      body: jsonEncode({'email': email, 'password': password}),
    );
    final data = jsonDecode(response.body) as Map<String, Object?>;
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
        Uri.parse('${Config.apiBaseUrl}/auth/logout'),
        body: {'refresh_token': _tokenStorage.refreshToken},
        // Authorization header is added automatically by AuthenticationInterceptor
      );
    } finally {
      await _tokenStorage.clearTokens();
    }
  }

  @override
  Future<String?> refreshToken() async {
    final refreshToken = _tokenStorage.refreshToken;
    if (refreshToken == null) return null;
    final response = await _client.post(
      Uri.parse('${Config.apiBaseUrl}/auth/refresh'),
      body: jsonEncode({'refreshToken': refreshToken}),
    );
    final data = jsonDecode(response.body) as Map<String, Object?>;
    await _tokenStorage.saveTokens(
      accessToken: data['access_token'] as String,
      refreshToken: data['refresh_token'] as String,
    );
    return data['access_token'] as String;
  }

  @override
  Future<User?> restoreSession() async {
    // Tokens are already in memory after restore() was called during init.
    // No disk read needed here — just check if the access token is present.
    if (_tokenStorage.accessToken == null) return null;
    // The interceptor will transparently refresh the token if it's expired.
    final response = await _client.get(Uri.parse('${Config.alpha}/auth/me'));
    return User.fromMap(jsonDecode(response.body) as Map<String, Object?>);
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
  Future<String?> refreshToken() => Future.value(null);

  @override
  Future<User?> restoreSession() => Future.value(const User(id: '-1'));
}
