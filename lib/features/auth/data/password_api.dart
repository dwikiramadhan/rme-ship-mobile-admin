import 'package:dio/dio.dart';

import '../../../core/network/api_config.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';

/// POST /api/v1/auth/change-password: {oldPassword, newPassword}.
class PasswordApi {
  PasswordApi({Dio? dio}) : _dio = dio ?? DioClient.instance;

  final Dio _dio;

  Future<void> changePassword({required String oldPassword, required String newPassword}) async {
    try {
      await _dio.post(
        ApiConfig.changePasswordPath,
        data: {'oldPassword': oldPassword, 'newPassword': newPassword},
      );
    } on DioException catch (e) {
      throw DioClient.mapError(e);
    }
  }
}