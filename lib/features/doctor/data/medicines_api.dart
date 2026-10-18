import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_config.dart';
import '../../../core/network/dio_client.dart';
import '../domain/medicine_item.dart';

class MedicinesApi {
  MedicinesApi({Dio? dio}) : _dio = dio ?? DioClient.instance;

  final Dio _dio;

  static const _empty = PaginatedMedicines(
    data: [],
    total: 0,
    page: 1,
    limit: 10,
    totalPages: 1,
  );

  /// Fetches paginated medicines.
  /// If [shipCode] is provided, uses:
  /// GET /api/v1/ship-medicines/stocks/:ship_code?page=1&limit=10&search=...
  /// Otherwise falls back to /api/v1/medicines.
  ///
  /// Offline, a ship's list is searched on the device in the copy saved by
  /// [downloadShipStocks] (same matching and order as the backend).
  Future<PaginatedMedicines> fetchMedicines({
    String? shipCode,
    String query = '',
    int page = 1,
    int limit = 10,
  }) async {
    final hasShip = shipCode != null && shipCode.trim().isNotEmpty;
    final path = hasShip
        ? ApiConfig.shipMedicineStocksPath(shipCode.trim())
        : ApiConfig.medicinesPath;
    try {
      final response = await _dio.get(
        path,
        queryParameters: {
          'page': page,
          'limit': limit,
          if (query.trim().isNotEmpty) 'search': query.trim(),
        },
      );
      return _parsePage(response.data, page: page, limit: limit);
    } on DioException catch (e) {
      // No answer from the server: search the downloaded stock list.
      if (hasShip && e.response == null) {
        return _searchDownloaded(path, query: query, page: page, limit: limit);
      }
      debugPrint('MedicinesApi fetchMedicines DioException: $e');
      return _empty;
    } catch (e) {
      debugPrint('MedicinesApi fetchMedicines error: $e');
      return _empty;
    }
  }

  /// Downloads the ship's whole stock list (every medicine with its stock on
  /// board, ~1,400 rows) so it can be searched offline. The offline cache
  /// keeps the response (see `masterDataPaths`).
  Future<void> downloadShipStocks(String shipCode) async {
    await _dio.get(
      ApiConfig.shipMedicineStocksPath(shipCode.trim()),
      queryParameters: {'all': 'true'},
    );
  }

  /// Page [page] of the downloaded stock list matching [query] like the
  /// backend does: in the name or the SKU, ignoring case. The list is kept in
  /// the backend's order (most stock first, then by name).
  Future<PaginatedMedicines> _searchDownloaded(
    String path, {
    required String query,
    required int page,
    required int limit,
  }) async {
    try {
      // Answered from the offline cache; fails if never downloaded.
      final response = await _dio.get(
        path,
        queryParameters: {'all': 'true'},
      );
      final all = _parseItems(_resultOf(response.data));
      final q = query.trim().toLowerCase();
      final matches = q.isEmpty
          ? all
          : [
              for (final m in all)
                if (m.name.toLowerCase().contains(q) ||
                    m.sku.toLowerCase().contains(q))
                  m,
            ];
      return PaginatedMedicines(
        data: matches.skip((page - 1) * limit).take(limit).toList(),
        total: matches.length,
        page: page,
        limit: limit,
        totalPages: matches.isEmpty ? 1 : (matches.length / limit).ceil(),
      );
    } catch (e) {
      debugPrint('MedicinesApi offline search: no stock list on the device');
      return _empty;
    }
  }

  static Object? _resultOf(Object? data) =>
      data is Map<String, dynamic> ? data['result'] ?? data['data'] : null;

  static List<MedicineItem> _parseItems(Object? result) {
    final List rawList = switch (result) {
      {'data': final List list} => list,
      final List list => list,
      _ => const [],
    };
    return rawList
        .whereType<Map<String, dynamic>>()
        .map(MedicineItem.fromJson)
        .toList();
  }

  static PaginatedMedicines _parsePage(
    Object? data, {
    required int page,
    required int limit,
  }) {
    if (data is! Map<String, dynamic>) return _empty;
    final result = _resultOf(data);
    final list = _parseItems(result);
    if (result is Map<String, dynamic>) {
      return PaginatedMedicines(
        data: list,
        total: (result['total'] as num?)?.toInt() ?? list.length,
        page: (result['page'] as num?)?.toInt() ?? page,
        limit: limit,
        totalPages: (result['total_pages'] as num?)?.toInt() ?? 1,
      );
    }
    return PaginatedMedicines(
      data: list,
      total: list.length,
      page: page,
      limit: limit,
      totalPages: 1,
    );
  }
}

final medicinesApiProvider = Provider<MedicinesApi>((ref) => MedicinesApi());
