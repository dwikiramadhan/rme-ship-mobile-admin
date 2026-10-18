import 'package:dio/dio.dart';

import '../../../core/network/api_config.dart';
import '../../../core/offline/outbox_entry.dart';
import '../../../core/offline/sync_service.dart';

/// The ship's whole stock list as saved on the device (downloaded by
/// `MedicinesApi.downloadShipStocks`), searched when the server can't be
/// reached. Medicines dispensed and stock added while offline still wait in
/// the outbox; they are counted in, so the list shows what is on board now.
class ShipStockList {
  ShipStockList(this._dio, [this._sync]);

  final Dio _dio;
  final SyncService? _sync;

  /// The rows matching [query] like the backend does (in the medicine's
  /// name or SKU, ignoring case), most stock first, then by name. Null when
  /// the list was never downloaded.
  Future<List<Map<String, dynamic>>?> search(
    String shipCode,
    String query,
  ) async {
    final List rows;
    try {
      // Answered from the offline cache.
      final response = await _dio.get(
        ApiConfig.shipMedicineStocksPath(shipCode.trim()),
        queryParameters: {'all': 'true'},
      );
      final data = response.data;
      final result = data is Map ? data['result'] ?? data['data'] : null;
      rows = switch (result) {
        {'data': final List list} => list,
        final List list => list,
        _ => const [],
      };
    } on DioException {
      return null;
    }

    final changes = await _pendingChanges(shipCode);
    final q = query.trim().toLowerCase();
    final matches = [
      for (final row in rows.whereType<Map<String, dynamic>>())
        if (q.isEmpty ||
            _key(row['medicine_name']).contains(q) ||
            _key(row['medicine_sku']).contains(q))
          changes.isEmpty ? row : {...row, 'stock': _stockOf(row, changes)},
    ];
    if (changes.isNotEmpty) {
      // A changed stock can move a medicine up or down the list.
      matches.sort((a, b) {
        final byStock = _int(b['stock']).compareTo(_int(a['stock']));
        if (byStock != 0) return byStock;
        return _key(a['medicine_name']).compareTo(_key(b['medicine_name']));
      });
    }
    return matches;
  }

  /// Stock waiting in the outbox, per medicine id (stock added) or SKU
  /// (dispensed, as a negative number).
  Future<Map<String, int>> _pendingChanges(String shipCode) async {
    final sync = _sync;
    if (sync == null) return const {};
    final changes = <String, int>{};
    void count(Object? medicine, int quantity) {
      final key = _key(medicine);
      if (key.isNotEmpty) changes[key] = (changes[key] ?? 0) + quantity;
    }

    for (final entry in await sync.entries()) {
      if (entry.status != OutboxStatus.pending || entry.method != 'POST') {
        continue;
      }
      final body = entry.body ?? const {};
      if (entry.path == ApiConfig.shipMedicinesPath) {
        if (_key(body['ship_code']) == _key(shipCode)) {
          count(body['medicine_id'], _int(body['stock']));
        }
      } else if (entry.path.endsWith('/dispense')) {
        final items = body['items'] is List ? body['items'] as List : const [];
        for (final item in items.whereType<Map>()) {
          count(item['dispensed_sku'], -_int(item['dispensed_quantity']));
        }
      }
    }
    return changes;
  }

  /// The row's stock after the waiting changes. Like the backend, it can go
  /// below zero when more was dispensed than was on board.
  static int _stockOf(Map<String, dynamic> row, Map<String, int> changes) =>
      _int(row['stock']) +
      (changes[_key(row['medicine_id'])] ?? 0) +
      (changes[_key(row['medicine_sku'])] ?? 0);

  static String _key(Object? value) =>
      (value?.toString() ?? '').trim().toLowerCase();

  static int _int(Object? value) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? 0;
}
