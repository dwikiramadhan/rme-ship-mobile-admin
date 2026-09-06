import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_config.dart';
import '../../../core/network/dio_client.dart';
import '../domain/medicine_item.dart';

class MedicinesApi {
  MedicinesApi({Dio? dio}) : _dio = dio ?? DioClient.instance;

  final Dio _dio;

  /// Fetches paginated medicines.
  /// If [shipCode] is provided, uses:
  /// GET /api/v1/ship-medicines/stocks/:ship_code?page=1&limit=10&search=...
  /// Otherwise falls back to /api/v1/medicines.
  Future<PaginatedMedicines> fetchMedicines({
    String? shipCode,
    String query = '',
    int page = 1,
    int limit = 10,
  }) async {
    try {
      final String path;
      if (shipCode != null && shipCode.trim().isNotEmpty) {
        final cleanCode = Uri.encodeComponent(shipCode.trim());
        path = '/api/v1/ship-medicines/stocks/$cleanCode';
      } else {
        path = ApiConfig.medicinesPath;
      }

      final response = await _dio.get(
        path,
        queryParameters: {
          'page': page,
          'limit': limit,
          if (query.trim().isNotEmpty) 'search': query.trim(),
        },
      );

      final data = response.data;
      if (data is! Map<String, dynamic>) {
        return const PaginatedMedicines(
          data: [],
          total: 0,
          page: 1,
          limit: 10,
          totalPages: 1,
        );
      }

      final result = data['result'] ?? data['data'];
      final List rawList;
      int total = 0;
      int totalPages = 1;
      int currentPage = page;

      if (result is Map<String, dynamic>) {
        rawList = result['data'] is List ? (result['data'] as List) : [];
        total = (result['total'] as num?)?.toInt() ?? rawList.length;
        totalPages = (result['total_pages'] as num?)?.toInt() ?? 1;
        currentPage = (result['page'] as num?)?.toInt() ?? page;
      } else if (result is List) {
        rawList = result;
        total = rawList.length;
      } else {
        rawList = [];
      }

      final list = rawList
          .whereType<Map<String, dynamic>>()
          .map((j) => MedicineItem.fromJson(j))
          .toList();

      return PaginatedMedicines(
        data: list,
        total: total,
        page: currentPage,
        limit: limit,
        totalPages: totalPages,
      );
    } on DioException catch (e) {
      debugPrint('MedicinesApi fetchMedicines DioException: $e');
      return const PaginatedMedicines(
        data: [],
        total: 0,
        page: 1,
        limit: 10,
        totalPages: 1,
      );
    } catch (e) {
      debugPrint('MedicinesApi fetchMedicines error: $e');
      return const PaginatedMedicines(
        data: [],
        total: 0,
        page: 1,
        limit: 10,
        totalPages: 1,
      );
    }
  }
}

final medicinesApiProvider = Provider<MedicinesApi>((ref) => MedicinesApi());
