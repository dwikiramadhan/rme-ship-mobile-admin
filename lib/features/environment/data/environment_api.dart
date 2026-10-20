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

  /// Fetches GET /api/v1/environments?page=1&limit=10 (only [shipId]'s,
  /// the logged-in user's ship, when given), extracts the first environment
  /// item in the list, and saves its code and details to local storage.
  Future<EnvironmentItem?> fetchFirstEnvironment({String? shipId}) async {
    try {
      final response = await _dio.get(
        ApiConfig.environmentsPath,
        queryParameters: {
          'page': 1,
          'limit': 10,
          if (shipId != null && shipId.isNotEmpty) 'ship_id': shipId,
        },
      );

      final data = response.data;
      if (data is! Map<String, dynamic>) {
        debugPrint('EnvironmentApi response is not a Map: $data');
        return await cached(shipId);
      }

      final List rawList = switch (data['data'] ??
          data['result'] ??
          data['items']) {
        final List list => list,
        {'data': final List list} => list,
        {'items': final List list} => list,
        _ => const [],
      };

      if (rawList.isEmpty) {
        debugPrint('EnvironmentApi: environments list is empty');
        return await cached(shipId);
      }

      final firstJson = rawList.first;
      if (firstJson is! Map<String, dynamic>) {
        debugPrint('EnvironmentApi: first item is not a Map: $firstJson');
        return await cached(shipId);
      }

      final env = EnvironmentItem.fromJson(firstJson);

      // Persist code & environment item to local storage
      await _storage.save(env);

      debugPrint(
        'EnvironmentApi: loaded active environment: ${env.name} (${env.code})',
      );
      return env;
    } on DioException catch (e) {
      debugPrint('EnvironmentApi fetchFirstEnvironment DioException: $e');
      // If offline or request fails, fallback to cached data in local storage
      return cached(shipId);
    } catch (e) {
      debugPrint('EnvironmentApi fetchFirstEnvironment error: $e');
      return cached(shipId);
    }
  }

  /// The environment saved on this device, unless it is another ship's
  /// (saved before another user logged in).
  Future<EnvironmentItem?> cached(String? shipId) async {
    final env = await _storage.read();
    if (env == null || shipId == null || shipId.isEmpty) return env;
    return env.shipId == shipId ? env : null;
  }
}
