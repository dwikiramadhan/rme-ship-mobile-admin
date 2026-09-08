import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../core/network/api_config.dart';

/// Service responsible for pinging the backend server's `/health` endpoint
/// to determine live connectivity.
class HealthApi {
  HealthApi({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: ApiConfig.baseUrl,
                connectTimeout: const Duration(seconds: 3),
                receiveTimeout: const Duration(seconds: 3),
                headers: {'Accept': 'application/json'},
              ),
            );

  final Dio _dio;

  /// Pings `/health`. Returns true if the backend returns HTTP 200,
  /// otherwise returns false.
  Future<bool> checkHealth() async {
    try {
      final response = await _dio.get(ApiConfig.healthPath);
      final isHealthy = response.statusCode == 200;
      return isHealthy;
    } catch (e) {
      debugPrint('⚠️ [HealthApi] Health check failed: $e');
      return false;
    }
  }
}
