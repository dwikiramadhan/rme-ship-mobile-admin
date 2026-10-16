import 'package:dio/dio.dart';

import '../../../core/network/api_config.dart';
import '../../../core/network/dio_client.dart';

/// POST /api/v1/devices: {fcm_token, platform} — tells the backend where to
/// send the signed-in user's push notifications. Upserted per user and
/// token, so registering again is harmless.
class DeviceApi {
  DeviceApi({Dio? dio}) : _dio = dio ?? DioClient.instance;

  final Dio _dio;

  Future<void> register({
    required String fcmToken,
    required String platform,
  }) async {
    try {
      await _dio.post(
        ApiConfig.devicesPath,
        data: {'fcm_token': fcmToken, 'platform': platform},
      );
    } on DioException catch (e) {
      throw DioClient.mapError(e);
    }
  }
}
