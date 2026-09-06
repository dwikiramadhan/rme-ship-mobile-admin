import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_config.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import '../domain/ship_medicine_history.dart';
import '../domain/ship_medicine_stock.dart';

class ShipMedicineApi {
  ShipMedicineApi({Dio? dio}) : _dio = dio ?? DioClient.instance;

  final Dio _dio;

  /// Fetches paginated ship medicine stocks:
  /// GET /api/v1/ship-medicines/stocks/:ship_code?page=1&limit=15&search=...
  Future<PaginatedShipMedicineStocks> fetchStocks({
    required String shipCode,
    String search = '',
    int page = 1,
    int limit = 15,
  }) async {
    try {
      final cleanCode = shipCode.trim();
      final path = ApiConfig.shipMedicineStocksPath(cleanCode);

      final response = await _dio.get(
        path,
        queryParameters: {
          'page': page,
          'limit': limit,
          if (search.trim().isNotEmpty) 'search': search.trim(),
        },
      );

      final data = response.data;
      if (data is! Map<String, dynamic>) {
        return const PaginatedShipMedicineStocks(
          items: [],
          total: 0,
          page: 1,
          limit: 15,
          totalPages: 1,
        );
      }

      final result = data['result'] ?? data['data'];
      final List rawList;
      int total = 0;
      int totalPages = 1;
      int currentPage = page;

      if (result is Map<String, dynamic>) {
        rawList = result['data'] is List
            ? (result['data'] as List)
            : (result['items'] is List ? (result['items'] as List) : []);
        total = (result['total'] as num?)?.toInt() ?? rawList.length;
        totalPages = (result['total_pages'] as num?)?.toInt() ?? 1;
        currentPage = (result['page'] as num?)?.toInt() ?? page;
      } else if (result is List) {
        rawList = result;
        total = rawList.length;
      } else {
        rawList = [];
      }

      final items = rawList
          .whereType<Map<String, dynamic>>()
          .map((j) => ShipMedicineStock.fromJson(j))
          .toList();

      return PaginatedShipMedicineStocks(
        items: items,
        total: total,
        page: currentPage,
        limit: limit,
        totalPages: totalPages,
      );
    } on DioException catch (e) {
      debugPrint('ShipMedicineApi fetchStocks DioException: $e');
      throw DioClient.mapError(e);
    } catch (e) {
      debugPrint('ShipMedicineApi fetchStocks error: $e');
      throw ApiException(e.toString());
    }
  }

  /// Fetches paginated ship medicine histories:
  /// GET /api/v1/ship-medicines/history?page=1&limit=15&ship_code=...&search=...
  Future<PaginatedShipMedicineHistories> fetchHistories({
    String? shipCode,
    String search = '',
    int page = 1,
    int limit = 15,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'limit': limit,
      };

      if (shipCode != null && shipCode.trim().isNotEmpty) {
        queryParams['ship_code'] = shipCode.trim();
      }

      if (search.trim().isNotEmpty) {
        final query = search.trim();
        queryParams['search'] = query;
        queryParams['medicine_sku'] = query;
      }

      final response = await _dio.get(
        ApiConfig.shipMedicineHistoryPath,
        queryParameters: queryParams,
      );

      final data = response.data;
      if (data is! Map<String, dynamic>) {
        return const PaginatedShipMedicineHistories(
          items: [],
          total: 0,
          page: 1,
          limit: 15,
          totalPages: 1,
        );
      }

      final result = data['result'] ?? data['data'];
      final List rawList;
      int total = 0;
      int totalPages = 1;
      int currentPage = page;

      if (result is Map<String, dynamic>) {
        rawList = result['data'] is List
            ? (result['data'] as List)
            : (result['items'] is List ? (result['items'] as List) : []);
        total = (result['total'] as num?)?.toInt() ?? rawList.length;
        totalPages = (result['total_pages'] as num?)?.toInt() ?? 1;
        currentPage = (result['page'] as num?)?.toInt() ?? page;
      } else if (result is List) {
        rawList = result;
        total = rawList.length;
      } else {
        rawList = [];
      }

      final items = rawList
          .whereType<Map<String, dynamic>>()
          .map((j) => ShipMedicineHistory.fromJson(j))
          .toList();

      return PaginatedShipMedicineHistories(
        items: items,
        total: total,
        page: currentPage,
        limit: limit,
        totalPages: totalPages,
      );
    } on DioException catch (e) {
      debugPrint('ShipMedicineApi fetchHistories DioException: $e');
      throw DioClient.mapError(e);
    } catch (e) {
      debugPrint('ShipMedicineApi fetchHistories error: $e');
      throw ApiException(e.toString());
    }
  }
}

final shipMedicineApiProvider = Provider<ShipMedicineApi>((ref) {
  return ShipMedicineApi();
});
