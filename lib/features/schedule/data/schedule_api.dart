import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../core/network/api_config.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import '../domain/trip_schedule.dart';

class ScheduleApi {
  ScheduleApi({Dio? dio}) : _dio = dio ?? DioClient.instance;

  final Dio _dio;

  /// Fetches schedules for a specific ship via GET /api/v1/schedules/ship/:ship_id
  Future<List<JadwalPerjalanan>> getSchedulesByShipId(String shipId) async {
    try {
      final response = await _dio.get(ApiConfig.schedulesByShipPath(shipId));
      final data = response.data;
      debugPrint('ScheduleApi [GET schedules/ship/$shipId] response: $data');

      if (data is! Map<String, dynamic>) {
        throw const ApiException('Format data jadwal kapal tidak valid.');
      }

      final result = data['result'] ?? data['data'] ?? data['schedules'] ?? data['schedule'];
      final List rawList;
      if (result is List) {
        rawList = result;
      } else if (result is Map<String, dynamic> && result['data'] is List) {
        rawList = result['data'] as List;
      } else if (result is Map<String, dynamic> && result['schedules'] is List) {
        rawList = result['schedules'] as List;
      } else if (result is Map<String, dynamic>) {
        // Single object schedule returned
        return [JadwalPerjalanan.fromApiJson(result)];
      } else {
        rawList = [];
      }

      return rawList
          .whereType<Map<String, dynamic>>()
          .map((json) => JadwalPerjalanan.fromApiJson(json))
          .toList();
    } on DioException catch (e) {
      debugPrint('ScheduleApi getSchedulesByShipId error: $e');
      throw DioClient.mapError(e);
    }
  }

  /// Fetches a specific schedule by ID via GET /api/v1/schedules/:id
  Future<JadwalPerjalanan> getScheduleById(String id) async {
    try {
      final response = await _dio.get('${ApiConfig.schedulesPath}/$id');
      final data = response.data;
      debugPrint('ScheduleApi [GET schedules/$id] response: $data');

      if (data is! Map<String, dynamic>) {
        throw const ApiException('Format data jadwal tidak valid.');
      }

      final payload = (data['result'] is Map<String, dynamic>)
          ? data['result'] as Map<String, dynamic>
          : (data['data'] is Map<String, dynamic>)
              ? data['data'] as Map<String, dynamic>
              : data;

      return JadwalPerjalanan.fromApiJson(payload);
    } on DioException catch (e) {
      debugPrint('ScheduleApi getScheduleById error: $e');
      throw DioClient.mapError(e);
    }
  }

  /// Fetches schedules list via GET /api/v1/schedules
  Future<List<JadwalPerjalanan>> getSchedules({String? shipId}) async {
    if (shipId != null && shipId.isNotEmpty) {
      return getSchedulesByShipId(shipId);
    }

    try {
      final response = await _dio.get(ApiConfig.schedulesPath);
      final data = response.data;
      debugPrint('ScheduleApi [GET schedules] response: $data');

      if (data is! Map<String, dynamic>) {
        throw const ApiException('Format data jadwal tidak valid.');
      }

      final result = data['result'] ?? data['data'] ?? data['schedules'] ?? data['schedule'];
      final List rawList;
      if (result is List) {
        rawList = result;
      } else if (result is Map<String, dynamic> && result['data'] is List) {
        rawList = result['data'] as List;
      } else if (result is Map<String, dynamic> && result['schedules'] is List) {
        rawList = result['schedules'] as List;
      } else if (result is Map<String, dynamic>) {
        return [JadwalPerjalanan.fromApiJson(result)];
      } else {
        rawList = [];
      }

      return rawList
          .whereType<Map<String, dynamic>>()
          .map((json) => JadwalPerjalanan.fromApiJson(json))
          .toList();
    } on DioException catch (e) {
      debugPrint('ScheduleApi getSchedules error: $e');
      throw DioClient.mapError(e);
    }
  }
}
