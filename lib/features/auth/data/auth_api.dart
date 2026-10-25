import 'package:dio/dio.dart';

import '../../../core/network/api_config.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import '../domain/app_user.dart';

/// Talks to POST /api/v1/auth/login: {email, password} -> {token, user:{...}},
/// and GET /api/v1/auth/me for the user's current data.
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
      if (e.response?.statusCode == 401) {
        throw const ApiException('Email atau password salah.', statusCode: 401);
      }
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

  /// The logged-in user as the server has them now (an admin may have
  /// changed their ship or role since the login). Null when the server
  /// can't be reached: the answer would be the copy kept on the device.
  Future<AppUser?> me() async {
    final Response response;
    try {
      response = await _dio.get(ApiConfig.mePath);
    } on DioException catch (e) {
      throw DioClient.mapError(e);
    }
    if (response.extra['fromCache'] == true) return null;
    final data = response.data;
    final user = data is Map<String, dynamic> ? data['result'] ?? data['data'] : null;
    if (user is! Map<String, dynamic>) {
      throw const ApiException('Format respons profil tidak dikenali.');
    }
    return AppUser.fromJson(user);
  }
}
