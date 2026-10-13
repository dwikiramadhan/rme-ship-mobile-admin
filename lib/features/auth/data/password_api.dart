import 'package:dio/dio.dart';

import '../../../core/network/api_config.dart';
import '../../../core/network/dio_client.dart';

/// PUT /api/v1/auth/me/password: {current_password, new_password}.
class PasswordApi {
  PasswordApi({Dio? dio}) : _dio = dio ?? DioClient.instance;

  final Dio _dio;

  Future<void> changePassword({required String oldPassword, required String newPassword}) async {
    try {
      await _dio.put(
        ApiConfig.changePasswordPath,
        data: {'current_password': oldPassword, 'new_password': newPassword},
      );
    } on DioException catch (e) {
      throw DioClient.mapError(e);
    }
  }
}