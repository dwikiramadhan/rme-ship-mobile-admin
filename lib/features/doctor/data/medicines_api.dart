import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_config.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/offline/sync_service.dart';
import '../../medicine_stock/data/ship_stock_list.dart';
import '../../sync/presentation/sync_providers.dart';
import '../domain/medicine_item.dart';

class MedicinesApi {
  MedicinesApi({Dio? dio, SyncService? sync})
    : _dio = dio ?? DioClient.instance,
      _stocks = ShipStockList(dio ?? DioClient.instance, sync);

  final Dio _dio;
  final ShipStockList _stocks;

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
  /// [downloadShipStocks] (same matching and order as the backend, with the
  /// stock dispensed or added offline counted in). The master list (no
  /// [shipCode]) is then searched in [offlineShipCode]'s copy, which holds
  /// every medicine too.
  Future<PaginatedMedicines> fetchMedicines({
    String? shipCode,
    String? offlineShipCode,
    String query = '',
    int page = 1,
    int limit = 10,
  }) async {
    final hasShip = shipCode != null && shipCode.trim().isNotEmpty;
    final path = hasShip
        ? ApiConfig.shipMedicineStocksPath(shipCode.trim())
        : ApiConfig.medicinesPath;
    final offlineShip = (hasShip ? shipCode : offlineShipCode)?.trim() ?? '';
    try {
      final response = await _dio.get(
        path,
        queryParameters: {
          'page': page,
          'limit': limit,
          if (query.trim().isNotEmpty) 'search': query.trim(),
        },
      );
      // An old page from the offline cache: the downloaded list is newer.
      if (response.extra['fromCache'] == true && offlineShip.isNotEmpty) {
        final downloaded = await _searchDownloaded(
          offlineShip,
          query: query,
          page: page,
          limit: limit,
        );
        if (downloaded != null) return downloaded;
      }
      return _parsePage(response.data, page: page, limit: limit);
    } on DioException catch (e) {
      // No answer from the server: search the downloaded stock list.
      if (offlineShip.isNotEmpty && e.response == null) {
        final downloaded = await _searchDownloaded(
          offlineShip,
          query: query,
          page: page,
          limit: limit,
        );
        if (downloaded != null) return downloaded;
        debugPrint('MedicinesApi offline: no stock list on the device');
        return _empty;
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

  /// Page [page] of the downloaded stock list matching [query]; null when
  /// the list was never downloaded.
  Future<PaginatedMedicines?> _searchDownloaded(
    String shipCode, {
    required String query,
    required int page,
    required int limit,
  }) async {
    final rows = await _stocks.search(shipCode, query);
    if (rows == null) return null;
    final matches = _parseItems(rows);
    return PaginatedMedicines(
      data: matches.skip((page - 1) * limit).take(limit).toList(),
      total: matches.length,
      page: page,
      limit: limit,
      totalPages: matches.isEmpty ? 1 : (matches.length / limit).ceil(),
    );
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

final medicinesApiProvider = Provider<MedicinesApi>(
  (ref) => MedicinesApi(sync: ref.watch(syncServiceProvider)),
);
