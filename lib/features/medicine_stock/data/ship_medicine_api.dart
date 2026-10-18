import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_config.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/offline/sync_service.dart';
import '../../sync/presentation/sync_providers.dart';
import '../domain/ship_medicine_history.dart';
import '../domain/ship_medicine_stock.dart';
import 'ship_stock_list.dart';

class ShipMedicineApi {
  ShipMedicineApi({Dio? dio, SyncService? sync})
    : _dio = dio ?? DioClient.instance,
      _sync = sync,
      _stocks = ShipStockList(dio ?? DioClient.instance, sync);

  final Dio _dio;
  final SyncService? _sync;
  final ShipStockList _stocks;

  /// Adds [quantity] to the ship's stock of a medicine (the backend creates
  /// the ship's entry for a medicine it doesn't carry yet) and records it in
  /// the stock history: POST /api/v1/ship-medicines.
  ///
  /// Offline it is kept in the outbox and sent once the server is reachable;
  /// returns true then.
  Future<bool> addStock({
    required String shipCode,
    required String medicineId,
    required int quantity,
    String medicineName = '',
    String notes = '',
  }) async {
    final body = {
      'ship_code': shipCode.trim(),
      'medicine_id': medicineId,
      'stock': quantity,
      if (notes.trim().isNotEmpty) 'notes': notes.trim(),
    };
    final sync = _sync;
    Future<bool> queue() async {
      await sync!.enqueue(
        method: 'POST',
        path: ApiConfig.shipMedicinesPath,
        label: 'Tambah stok: ${medicineName.isEmpty ? medicineId : medicineName}'
            ' +$quantity',
        body: body,
      );
      return true;
    }

    // Earlier writes are still waiting: this one goes behind them.
    if (sync != null && await sync.hasPending()) return queue();
    try {
      await _dio.post(ApiConfig.shipMedicinesPath, data: body);
      return false;
    } on DioException catch (e) {
      final error = DioClient.mapError(e);
      if (sync != null && error.isOffline) return queue();
      throw error;
    }
  }

  /// Fetches paginated ship medicine stocks:
  /// GET /api/v1/ship-medicines/stocks/:ship_code?page=1&limit=15&search=...
  ///
  /// Offline, the stock list downloaded to the device is searched instead,
  /// with the stock dispensed or added offline counted in.
  Future<PaginatedShipMedicineStocks> fetchStocks({
    required String shipCode,
    String search = '',
    int page = 1,
    int limit = 15,
  }) async {
    try {
      final cleanCode = shipCode.trim();
      final path = ApiConfig.shipMedicineStocksPath(cleanCode);

      final Response response;
      try {
        response = await _dio.get(
          path,
          queryParameters: {
            'page': page,
            'limit': limit,
            if (search.trim().isNotEmpty) 'search': search.trim(),
          },
        );
      } on DioException catch (e) {
        if (e.response != null) rethrow;
        // No answer from the server.
        final downloaded = await _searchDownloaded(
          cleanCode,
          search: search,
          page: page,
          limit: limit,
        );
        if (downloaded != null) return downloaded;
        rethrow;
      }
      // An old page from the offline cache: the downloaded list is newer.
      if (response.extra['fromCache'] == true) {
        final downloaded = await _searchDownloaded(
          cleanCode,
          search: search,
          page: page,
          limit: limit,
        );
        if (downloaded != null) return downloaded;
      }

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

  /// Page [page] of the downloaded stock list matching [search]; null when
  /// the list was never downloaded.
  Future<PaginatedShipMedicineStocks?> _searchDownloaded(
    String shipCode, {
    required String search,
    required int page,
    required int limit,
  }) async {
    final rows = await _stocks.search(shipCode, search);
    if (rows == null) return null;
    final matches = rows.map(ShipMedicineStock.fromJson).toList();
    return PaginatedShipMedicineStocks(
      items: matches.skip((page - 1) * limit).take(limit).toList(),
      total: matches.length,
      page: page,
      limit: limit,
      totalPages: matches.isEmpty ? 1 : (matches.length / limit).ceil(),
    );
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
  return ShipMedicineApi(sync: ref.watch(syncServiceProvider));
});
