import 'dart:convert';

import 'package:accessandrefreshtoken/src/common/constant/config.dart';
import 'package:accessandrefreshtoken/src/common/util/interceptor/authentication_interceptor.dart';
import 'package:http/http.dart' as http_package;

typedef TokenPair = ({String accessToken, String refreshToken});

abstract interface class IRefreshTokenRepository {
  /// Attempts to refresh the access token using the stored refresh token.
  /// Returns true if successful, false if the session is expired.
  Future<TokenPair?> refreshToken();
}

final class RefreshTokenRepositoryImpl implements IRefreshTokenRepository {
  RefreshTokenRepositoryImpl({
    required final ITokenStorage tokenStorage,
    final http_package.Client? client,
  }) : _tokenStorage = tokenStorage,
       _client = client ?? http_package.Client();

  final ITokenStorage _tokenStorage;
  final http_package.Client _client;

  @override
  Future<TokenPair?> refreshToken() async {
    final refreshToken = _tokenStorage.refreshToken;
    if (refreshToken == null) return null;

    final response = await _client.post(
      Uri.parse('${Config.apiBaseUrl}/auth/refresh'),
      body: jsonEncode({'refreshToken': refreshToken}),
      headers: {'Accept': 'application/json', 'Content-Type': 'application/json'},
    );

    final data = jsonDecode(response.body) as Map<String, Object?>;

    await _tokenStorage.saveTokens(
      accessToken: data['accessToken'] as String,
      refreshToken: data['refreshToken'] as String,
    );

    return (
      accessToken: data['accessToken'] as String,
      refreshToken: data['refreshToken'] as String,
    );
  }
}
