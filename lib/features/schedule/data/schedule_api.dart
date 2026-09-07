import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../core/network/api_config.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import '../domain/trip_schedule.dart';

class SchedulePageResult {
  const SchedulePageResult({
    required this.items,
    this.total = 0,
    this.page = 1,
    this.limit = 10,
    this.hasMore = false,
  });

  final List<JadwalPerjalanan> items;
  final int total;
  final int page;
  final int limit;
  final bool hasMore;
}

class ScheduleApi {
  ScheduleApi({Dio? dio}) : _dio = dio ?? DioClient.instance;

  final Dio _dio;

  /// Fetches schedules for a specific ship via GET /api/v1/schedules/ship/:ship_code?page=1&limit=10
  Future<List<JadwalPerjalanan>> getSchedulesByShipId(
    String shipId, {
    int page = 1,
    int limit = 10,
    String? search,
    String? status,
  }) =>
      getSchedulesByShipCode(
        shipCode: shipId,
        page: page,
        limit: limit,
        search: search,
        status: status,
      );

  /// Fetches schedules for a specific ship via GET /api/v1/schedules/ship/:ship_code?page=1&limit=10&search=...&status=...
  Future<SchedulePageResult> getPaginatedSchedulesByShipCode({
    required String shipCode,
    int page = 1,
    int limit = 10,
    String? search,
    String? status,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'limit': limit,
      };
      if (search != null && search.trim().isNotEmpty) {
        queryParams['search'] = search.trim();
      }
      if (status != null &&
          status.trim().isNotEmpty &&
          status.trim().toLowerCase() != 'semua') {
        queryParams['status'] = status.trim();
      }

      final response = await _dio.get(
        ApiConfig.schedulesByShipPath(shipCode),
        queryParameters: queryParams,
      );
      final data = response.data;
      debugPrint('ScheduleApi [GET schedules/ship/$shipCode] query: $queryParams, response: $data');

      if (data is! Map<String, dynamic>) {
        if (data is List) {
          final items = data
              .whereType<Map<String, dynamic>>()
              .map((json) => JadwalPerjalanan.fromApiJson(json))
              .toList();
          return SchedulePageResult(
            items: items,
            total: items.length,
            page: page,
            limit: limit,
            hasMore: items.length >= limit,
          );
        }
        throw const ApiException('Format data jadwal kapal tidak valid.');
      }

      final result = data['result'] ??
          data['data'] ??
          data['items'] ??
          data['schedules'] ??
          data['schedule'];
      final List rawList;
      if (result is List) {
        rawList = result;
      } else if (result is Map<String, dynamic> && result['items'] is List) {
        rawList = result['items'] as List;
      } else if (result is Map<String, dynamic> && result['data'] is List) {
        rawList = result['data'] as List;
      } else if (result is Map<String, dynamic> && result['schedules'] is List) {
        rawList = result['schedules'] as List;
      } else if (result is Map<String, dynamic>) {
        // Single object schedule returned
        final single = JadwalPerjalanan.fromApiJson(result);
        return SchedulePageResult(
          items: [single],
          total: 1,
          page: page,
          limit: limit,
          hasMore: false,
        );
      } else {
        rawList = [];
      }

      int resTotal = 0;
      if (data['total'] is num) {
        resTotal = (data['total'] as num).toInt();
      } else if (data['pagination'] is Map && data['pagination']['total'] is num) {
        resTotal = (data['pagination']['total'] as num).toInt();
      } else if (result is Map && result['total'] is num) {
        resTotal = (result['total'] as num).toInt();
      } else if (data['meta'] is Map && data['meta']['total'] is num) {
        resTotal = (data['meta']['total'] as num).toInt();
      }

      final items = rawList
          .whereType<Map<String, dynamic>>()
          .map((json) => JadwalPerjalanan.fromApiJson(json))
          .toList();

      final bool hasMore = resTotal > 0
          ? (page * limit) < resTotal
          : items.length >= limit;

      return SchedulePageResult(
        items: items,
        total: resTotal > 0 ? resTotal : items.length,
        page: page,
        limit: limit,
        hasMore: hasMore,
      );
    } on DioException catch (e) {
      debugPrint('ScheduleApi getPaginatedSchedulesByShipCode error: $e');
      throw DioClient.mapError(e);
    }
  }

  /// Fetches schedules list for a specific ship via GET /api/v1/schedules/ship/:ship_code
  Future<List<JadwalPerjalanan>> getSchedulesByShipCode({
    required String shipCode,
    int page = 1,
    int limit = 10,
    String? search,
    String? status,
  }) async {
    final result = await getPaginatedSchedulesByShipCode(
      shipCode: shipCode,
      page: page,
      limit: limit,
      search: search,
      status: status,
    );
    return result.items;
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
