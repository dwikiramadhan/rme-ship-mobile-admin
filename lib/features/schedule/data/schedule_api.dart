import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../core/network/api_config.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import '../domain/trip_schedule.dart';

class ScheduleCounter {
  const ScheduleCounter({
    this.ongoing = 0,
    this.scheduled = 0,
    this.completed = 0,
  });

  final int ongoing;
  final int scheduled;
  final int completed;

  int get total => ongoing + scheduled + completed;

  factory ScheduleCounter.fromJson(Map<String, dynamic> json) {
    return ScheduleCounter(
      ongoing: (json['ongoing'] as num?)?.toInt() ?? 0,
      scheduled: (json['scheduled'] as num?)?.toInt() ?? 0,
      completed: (json['completed'] as num?)?.toInt() ?? 0,
    );
  }
}

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

  /// Updates schedule by ID via PUT /api/v1/schedules/:id
  Future<JadwalPerjalanan> updateSchedule(
    String id,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await _dio.put(
        '${ApiConfig.schedulesPath}/$id',
        data: body,
      );
      final data = response.data;
      debugPrint('ScheduleApi [PUT schedules/$id] response: $data');

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
      debugPrint('ScheduleApi updateSchedule error: $e');
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

  /// Fetches provisions history for a schedule code via GET /api/v1/ship-provisions-history/schedule/:scheduleCode
  Future<List<ProvisionHistoryItem>> getProvisionsHistory(String scheduleCode) async {
    try {
      final response = await _dio.get(
        '${ApiConfig.shipProvisionsHistoryPath}/schedule/${Uri.encodeComponent(scheduleCode)}',
      );
      final data = response.data;
      debugPrint('ScheduleApi [GET provisions/$scheduleCode] response: $data');

      final result = data['result'] ?? data['data'];
      final List rawList = (result is List)
          ? result
          : (result is Map<String, dynamic> && result['data'] is List)
              ? result['data'] as List
              : [];

      final items = rawList
          .whereType<Map<String, dynamic>>()
          .toList();

      return items
          .asMap()
          .entries
          .map((e) => ProvisionHistoryItem.fromJson(e.value, isLatest: e.key == 0))
          .toList();
    } on DioException catch (e) {
      debugPrint('ScheduleApi getProvisionsHistory error: $e');
      return [];
    }
  }

  /// Records new provision entry via POST /api/v1/ship-provisions-history
  Future<ProvisionHistoryItem> createProvision(Map<String, dynamic> body) async {
    try {
      debugPrint('ScheduleApi [POST ${ApiConfig.shipProvisionsHistoryPath}] body: $body');
      final response = await _dio.post(ApiConfig.shipProvisionsHistoryPath, data: body);
      final data = response.data;
      final payload = (data['result'] is Map<String, dynamic>)
          ? data['result'] as Map<String, dynamic>
          : (data['data'] is Map<String, dynamic>)
              ? data['data'] as Map<String, dynamic>
              : (data is Map<String, dynamic> ? data : <String, dynamic>{});
      return ProvisionHistoryItem.fromJson(payload, isLatest: true);
    } on DioException catch (e) {
      debugPrint('ScheduleApi createProvision error: $e');
      throw DioClient.mapError(e);
    }
  }

  /// Deletes a provision entry via DELETE /api/v1/ship-provisions-history/:id
  Future<void> deleteProvision(String id) async {
    try {
      await _dio.delete('${ApiConfig.shipProvisionsHistoryPath}/$id');
    } on DioException catch (e) {
      debugPrint('ScheduleApi deleteProvision error: $e');
      throw DioClient.mapError(e);
    }
  }

  /// Fetches trip issues for a schedule via GET /api/v1/trip-issues?schedule_id=:scheduleId
  Future<List<TripIssueItem>> getTripIssues(String scheduleId) async {
    try {
      final response = await _dio.get(
        ApiConfig.tripIssuesPath,
        queryParameters: {'schedule_id': scheduleId, 'limit': 100},
      );
      final data = response.data;
      debugPrint('ScheduleApi [GET trip-issues/$scheduleId] response: $data');

      final result = data['result'] ?? data['data'];
      final List rawList = (result is List)
          ? result
          : (result is Map<String, dynamic> && result['data'] is List)
              ? result['data'] as List
              : [];

      return rawList
          .whereType<Map<String, dynamic>>()
          .map((j) => TripIssueItem.fromJson(j))
          .toList();
    } on DioException catch (e) {
      debugPrint('ScheduleApi getTripIssues error: $e');
      return [];
    }
  }

  /// Creates a new trip issue via POST /api/v1/trip-issues
  Future<TripIssueItem> createTripIssue(Map<String, dynamic> body) async {
    try {
      final response = await _dio.post(ApiConfig.tripIssuesPath, data: body);
      final data = response.data;
      final payload = (data['result'] is Map<String, dynamic>)
          ? data['result'] as Map<String, dynamic>
          : (data['data'] is Map<String, dynamic>)
              ? data['data'] as Map<String, dynamic>
              : (data is Map<String, dynamic> ? data : <String, dynamic>{});
      return TripIssueItem.fromJson(payload);
    } on DioException catch (e) {
      debugPrint('ScheduleApi createTripIssue error: $e');
      throw DioClient.mapError(e);
    }
  }

  /// Deletes a trip issue via DELETE /api/v1/trip-issues/:id
  Future<void> deleteTripIssue(String id) async {
    try {
      await _dio.delete('${ApiConfig.tripIssuesPath}/$id');
    } on DioException catch (e) {
      debugPrint('ScheduleApi deleteTripIssue error: $e');
      throw DioClient.mapError(e);
    }
  }

  /// Fetches paginated ports via GET /api/v1/ports?page=1&limit=10
  Future<PaginatedPortResult> getPorts({
    int page = 1,
    int limit = 10,
    String? search,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'limit': limit,
      };
      if (search != null && search.trim().isNotEmpty) {
        queryParams['search'] = search.trim();
      }

      final response = await _dio.get(
        ApiConfig.portsPath,
        queryParameters: queryParams,
      );
      final data = response.data;
      debugPrint(
        'ScheduleApi [GET ${ApiConfig.portsPath}] query: $queryParams, response: $data',
      );

      if (data is! Map<String, dynamic>) {
        if (data is List) {
          final items = data
              .whereType<Map<String, dynamic>>()
              .map((j) => PortItem.fromJson(j))
              .toList();
          return PaginatedPortResult(
            items: items,
            total: items.length,
            page: page,
            limit: limit,
            hasMore: items.length >= limit,
          );
        }
        return PaginatedPortResult(
          items: const [],
          total: 0,
          page: page,
          limit: limit,
          hasMore: false,
        );
      }

      final result =
          data['result'] ?? data['data'] ?? data['items'] ?? data['ports'];
      final List rawList;
      int total = 0;
      int totalPages = 1;
      int currentPage = page;
      bool hasMore = false;

      if (result is Map<String, dynamic>) {
        rawList = result['data'] is List
            ? (result['data'] as List)
            : (result['items'] is List
                ? (result['items'] as List)
                : (result['ports'] is List
                    ? (result['ports'] as List)
                    : []));
        total = (result['total'] as num?)?.toInt() ??
            (result['total_items'] as num?)?.toInt() ??
            (data['total'] as num?)?.toInt() ??
            rawList.length;
        totalPages = (result['total_pages'] as num?)?.toInt() ??
            (result['totalPages'] as num?)?.toInt() ??
            (data['total_pages'] as num?)?.toInt() ??
            1;
        currentPage = (result['page'] as num?)?.toInt() ?? page;
        hasMore = currentPage < totalPages || rawList.length >= limit;
      } else if (result is List) {
        rawList = result;
        total = (data['total'] as num?)?.toInt() ??
            (data['total_items'] as num?)?.toInt() ??
            rawList.length;
        totalPages = (data['total_pages'] as num?)?.toInt() ??
            (data['totalPages'] as num?)?.toInt() ??
            1;
        currentPage = (data['page'] as num?)?.toInt() ?? page;
        hasMore = currentPage < totalPages || rawList.length >= limit;
      } else {
        rawList = [];
      }

      final items = rawList
          .whereType<Map<String, dynamic>>()
          .map((j) => PortItem.fromJson(j))
          .toList();

      return PaginatedPortResult(
        items: items,
        total: total,
        page: currentPage,
        limit: limit,
        hasMore: hasMore && items.isNotEmpty,
      );
    } on DioException catch (e) {
      debugPrint('ScheduleApi getPorts error: $e');
      throw DioClient.mapError(e);
    }
  }

  /// Fetches paginated medical personnel via GET /api/v1/medical-personnel?type=:type&page=:page&limit=:limit
  Future<PaginatedPersonnelResult> getMedicalPersonnel({
    required String type,
    int page = 1,
    int limit = 10,
    String? search,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'type': type,
        'page': page,
        'limit': limit,
      };
      if (search != null && search.trim().isNotEmpty) {
        queryParams['search'] = search.trim();
      }

      final response = await _dio.get(
        ApiConfig.medicalPersonnelPath,
        queryParameters: queryParams,
      );
      final data = response.data;
      debugPrint('ScheduleApi [GET medical-personnel?type=$type&page=$page&limit=$limit] response: $data');

      if (data is! Map<String, dynamic>) {
        throw const ApiException('Format data tenaga medis tidak valid.');
      }

      final result = data['result'] ?? data['data'];
      final List rawList;
      int total = 0;
      int totalPages = 1;
      int currentPage = page;
      bool hasMore = false;

      if (result is Map<String, dynamic>) {
        rawList = result['data'] is List
            ? (result['data'] as List)
            : (result['items'] is List
                ? (result['items'] as List)
                : (result['medical_personnel'] is List
                    ? (result['medical_personnel'] as List)
                    : []));
        total = (result['total'] as num?)?.toInt() ??
            (result['total_items'] as num?)?.toInt() ??
            (data['total'] as num?)?.toInt() ??
            rawList.length;
        totalPages = (result['total_pages'] as num?)?.toInt() ??
            (result['totalPages'] as num?)?.toInt() ??
            (data['total_pages'] as num?)?.toInt() ??
            1;
        currentPage = (result['page'] as num?)?.toInt() ?? page;
        hasMore = currentPage < totalPages || rawList.length >= limit;
      } else if (result is List) {
        rawList = result;
        total = (data['total'] as num?)?.toInt() ??
            (data['total_items'] as num?)?.toInt() ??
            rawList.length;
        totalPages = (data['total_pages'] as num?)?.toInt() ??
            (data['totalPages'] as num?)?.toInt() ??
            1;
        currentPage = (data['page'] as num?)?.toInt() ?? page;
        hasMore = currentPage < totalPages || rawList.length >= limit;
      } else {
        rawList = [];
      }

      final items = rawList
          .whereType<Map<String, dynamic>>()
          .map((j) => SchedulePersonnelItem.fromJson(j, defaultType: type))
          .toList();

      return PaginatedPersonnelResult(
        items: items,
        total: total,
        page: currentPage,
        limit: limit,
        hasMore: hasMore && items.isNotEmpty,
      );
    } on DioException catch (e) {
      debugPrint('ScheduleApi getMedicalPersonnel error: $e');
      throw DioClient.mapError(e);
    }
  }

  /// Fetches paginated crews via GET /api/v1/crews?page=:page&limit=:limit
  Future<PaginatedCrewResult> getCrews({
    int page = 1,
    int limit = 10,
    String? search,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'limit': limit,
      };
      if (search != null && search.trim().isNotEmpty) {
        queryParams['search'] = search.trim();
      }

      final response = await _dio.get(
        ApiConfig.crewsPath,
        queryParameters: queryParams,
      );
      final data = response.data;
      debugPrint('ScheduleApi [GET crews?page=$page&limit=$limit] response: $data');

      if (data is! Map<String, dynamic>) {
        throw const ApiException('Format data kru kapal tidak valid.');
      }

      final result = data['result'] ?? data['data'];
      final List rawList;
      int total = 0;
      int totalPages = 1;
      int currentPage = page;
      bool hasMore = false;

      if (result is Map<String, dynamic>) {
        rawList = result['data'] is List
            ? (result['data'] as List)
            : (result['items'] is List
                ? (result['items'] as List)
                : (result['crews'] is List
                    ? (result['crews'] as List)
                    : []));
        total = (result['total'] as num?)?.toInt() ??
            (result['total_items'] as num?)?.toInt() ??
            (data['total'] as num?)?.toInt() ??
            rawList.length;
        totalPages = (result['total_pages'] as num?)?.toInt() ??
            (result['totalPages'] as num?)?.toInt() ??
            (data['total_pages'] as num?)?.toInt() ??
            1;
        currentPage = (result['page'] as num?)?.toInt() ?? page;
        hasMore = currentPage < totalPages || rawList.length >= limit;
      } else if (result is List) {
        rawList = result;
        total = (data['total'] as num?)?.toInt() ??
            (data['total_items'] as num?)?.toInt() ??
            rawList.length;
        totalPages = (data['total_pages'] as num?)?.toInt() ??
            (data['totalPages'] as num?)?.toInt() ??
            1;
        currentPage = (data['page'] as num?)?.toInt() ?? page;
        hasMore = currentPage < totalPages || rawList.length >= limit;
      } else {
        rawList = [];
      }

      final items = rawList
          .whereType<Map<String, dynamic>>()
          .map((j) => ScheduleCrewItem.fromJson(j))
          .toList();

      return PaginatedCrewResult(
        items: items,
        total: total,
        page: currentPage,
        limit: limit,
        hasMore: hasMore && items.isNotEmpty,
      );
    } on DioException catch (e) {
      debugPrint('ScheduleApi getCrews error: $e');
      throw DioClient.mapError(e);
    }
  }

  /// Fetches paginated poliklinik via GET /api/v1/poliklinik?limit=10&page=:page
  Future<PaginatedPoliklinikResult> getPoliklinik({
    int page = 1,
    int limit = 10,
    String? search,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'limit': limit,
      };
      if (search != null && search.trim().isNotEmpty) {
        queryParams['search'] = search.trim();
      }

      final response = await _dio.get(
        ApiConfig.poliklinikPath,
        queryParameters: queryParams,
      );
      final data = response.data;
      debugPrint('ScheduleApi [GET poliklinik?page=$page&limit=$limit] response: $data');

      if (data is! Map<String, dynamic>) {
        throw const ApiException('Format data poliklinik tidak valid.');
      }

      final result = data['result'] ?? data['data'];
      final List rawList;
      int total = 0;
      int totalPages = 1;
      int currentPage = page;
      bool hasMore = false;

      if (result is Map<String, dynamic>) {
        rawList = result['data'] is List
            ? (result['data'] as List)
            : (result['items'] is List
                ? (result['items'] as List)
                : (result['poliklinik'] is List
                    ? (result['poliklinik'] as List)
                    : []));
        total = (result['total'] as num?)?.toInt() ??
            (result['total_items'] as num?)?.toInt() ??
            (data['total'] as num?)?.toInt() ??
            rawList.length;
        totalPages = (result['total_pages'] as num?)?.toInt() ??
            (result['totalPages'] as num?)?.toInt() ??
            (data['total_pages'] as num?)?.toInt() ??
            1;
        currentPage = (result['page'] as num?)?.toInt() ?? page;
        hasMore = currentPage < totalPages || rawList.length >= limit;
      } else if (result is List) {
        rawList = result;
        total = (data['total'] as num?)?.toInt() ??
            (data['total_items'] as num?)?.toInt() ??
            rawList.length;
        totalPages = (data['total_pages'] as num?)?.toInt() ??
            (data['totalPages'] as num?)?.toInt() ??
            1;
        currentPage = (data['page'] as num?)?.toInt() ?? page;
        hasMore = currentPage < totalPages || rawList.length >= limit;
      } else {
        rawList = [];
      }

      final items = rawList
          .whereType<Map<String, dynamic>>()
          .map((j) => PoliklinikItem.fromJson(j))
          .toList();

      return PaginatedPoliklinikResult(
        items: items,
        total: total,
        page: currentPage,
        limit: limit,
        hasMore: hasMore && items.isNotEmpty,
      );
    } on DioException catch (e) {
      debugPrint('ScheduleApi getPoliklinik error: $e');
      throw DioClient.mapError(e);
    }
  }

  /// Fetches schedule counters via GET /api/v1/schedules/ship/:shipCode/counter
  Future<ScheduleCounter> getScheduleCounter(String shipCode) async {
    try {
      final response = await _dio.get(
        ApiConfig.scheduleCounterPath(shipCode),
      );
      final data = response.data;
      debugPrint('ScheduleApi [GET schedules/ship/$shipCode/counter] response: $data');

      if (data is Map<String, dynamic>) {
        final result = data['result'] ?? data['data'] ?? data;
        if (result is Map<String, dynamic>) {
          return ScheduleCounter.fromJson(result);
        }
      }
      return const ScheduleCounter();
    } on DioException catch (e) {
      debugPrint('ScheduleApi getScheduleCounter error: $e');
      throw DioClient.mapError(e);
    }
  }
}
