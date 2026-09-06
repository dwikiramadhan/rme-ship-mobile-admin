import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../core/network/api_config.dart';
import '../../../core/network/dio_client.dart';
import '../domain/environment_item.dart';
import 'environment_storage.dart';

class EnvironmentApi {
  EnvironmentApi({Dio? dio, EnvironmentStorage? storage})
      : _dio = dio ?? DioClient.instance,
        _storage = storage ?? EnvironmentStorage();

  final Dio _dio;
  final EnvironmentStorage _storage;

  /// Fetches GET /api/v1/environments?page=1&limit=10,
  /// extracts the first environment item in the list,
  /// and saves its code and details to local storage.
  Future<EnvironmentItem?> fetchFirstEnvironment() async {
    try {
      final response = await _dio.get(
        ApiConfig.environmentsPath,
        queryParameters: {
          'page': 1,
          'limit': 10,
        },
      );

      final data = response.data;
      if (data is! Map<String, dynamic>) {
        debugPrint('EnvironmentApi response is not a Map: $data');
        return _storage.read();
      }

      final result = data['data'] ?? data['result'] ?? data['items'];
      final List rawList;
      if (result is List) {
        rawList = result;
      } else if (result is Map<String, dynamic> && result['data'] is List) {
        rawList = result['data'] as List;
      } else if (result is Map<String, dynamic> && result['items'] is List) {
        rawList = result['items'] as List;
      } else {
        rawList = [];
      }

      if (rawList.isEmpty) {
        debugPrint('EnvironmentApi: environments list is empty');
        return _storage.read();
      }

      final firstJson = rawList.first;
      if (firstJson is! Map<String, dynamic>) {
        debugPrint('EnvironmentApi: first item is not a Map: $firstJson');
        return _storage.read();
      }

      final env = EnvironmentItem.fromJson(firstJson);

      // Persist code & environment item to local storage
      await _storage.save(env);

      debugPrint('EnvironmentApi: loaded active environment: ${env.name} (${env.code})');
      return env;
    } on DioException catch (e) {
      debugPrint('EnvironmentApi fetchFirstEnvironment DioException: $e');
      // If offline or request fails, fallback to cached data in local storage
      return _storage.read();
    } catch (e) {
      debugPrint('EnvironmentApi fetchFirstEnvironment error: $e');
      return _storage.read();
    }
  }
}
