import 'package:dio/dio.dart';

import '../../../core/network/api_config.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import '../domain/app_user.dart';

/// Talks to POST /api/v1/auth/login: {email, password} -> {token, user:{...}}.
class AuthApi {
  AuthApi({Dio? dio}) : _dio = dio ?? DioClient.instance;

  final Dio _dio;

  Future<AuthSession> login({required String email, required String password}) async {
    final Response response;
    try {
      response = await _dio.post(
        ApiConfig.loginPath,
        data: {'email': email, 'password': password},
      );
    } on DioException catch (e) {
      throw DioClient.mapError(e);
    }

    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw const ApiException('Format respons login tidak dikenali.');
    }
    try {
      return AuthSession.fromLoginResponse(data);
    } on FormatException catch (e) {
      throw ApiException('Respons login tidak lengkap: ${e.message}');
    }
  }
}
