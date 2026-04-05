import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:accessandrefreshtoken/src/features/authentication/model/user.dart';

abstract interface class IAuthenticationRepository {
  Future<User> login({required String email, required String password});

  Future<User> register({required String name, required String email, required String password});

  Future<void> logout();

  /// Reads stored token from SharedPreferences and validates it with the backend.
  /// Returns null if no token is stored or it is no longer valid.
  Future<User?> restoreSession();
}

class AuthenticationRepositoryImpl implements IAuthenticationRepository {
  AuthenticationRepositoryImpl({
    required final Dio dio,
    required final SharedPreferences sharedPreferences,
  }) : _dio = dio,
       _sharedPreferences = sharedPreferences;

  final Dio _dio;
  final SharedPreferences _sharedPreferences;
  static const _tokenKey = 'auth_token';

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
    final token = data['token'] as String;
    await _saveToken(token);
    return User.fromMap(data['user'] as Map<String, Object?>);
  }

  @override
  Future<User> login({required String email, required String password}) async {
    final response = await _dio.post<Map<String, Object?>>(
      '/api/auth/login',
      data: {'email': email, 'password': password},
    );
    final data = response.data!;
    final token = data['token'] as String;
    await _saveToken(token);
    return User.fromMap(data['user'] as Map<String, Object?>);
  }

  @override
  Future<void> logout() async {
    try {
      final token = _sharedPreferences.getString(_tokenKey);
      await _dio.post<void>(
        '/api/auth/logout',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
    } on DioException {
      // Best-effort — always clear local token regardless of network result
    } finally {
      await _clearToken();
    }
  }

  @override
  Future<User?> restoreSession() async {
    final token = await _loadToken();
    if (token == null) return null;
    try {
      final response = await _dio.get<Map<String, Object?>>(
        '/api/auth/me',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return User.fromMap(response.data!);
    } on DioException {
      await _clearToken();
      return null;
    }
  }

  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  Future<String?> _loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<void> _clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
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

  /// Reads stored token from SharedPreferences and validates it with the backend.
  /// Returns null if no token is stored or it is no longer valid.
  @override
  Future<User?> restoreSession() => Future.value(const User(id: -1));
}
