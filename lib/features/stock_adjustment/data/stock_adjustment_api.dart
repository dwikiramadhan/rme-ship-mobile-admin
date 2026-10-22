import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_config.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/offline/sync_service.dart';
import '../../sync/presentation/sync_providers.dart';
import '../domain/stock_adjustment.dart';

/// Report file formats of GET /api/v1/stock-adjustments/report/download.
enum AdjustmentReportFormat { pdf, xlsx }

class StockAdjustmentApi {
  StockAdjustmentApi({Dio? dio, this.sync}) : _dio = dio ?? DioClient.instance;

  final Dio _dio;

  /// The outbox writes wait in while offline.
  final SyncService? sync;

  /// Saves an adjustment. Offline (or behind earlier writes still waiting)
  /// it is kept in the outbox and sent later; returns true then.
  Future<bool> create(Map<String, dynamic> body, {String label = ''}) async {
    final sync = this.sync;
    Future<bool> queue() async {
      await sync!.enqueue(
        method: 'POST',
        path: ApiConfig.stockAdjustmentsPath,
        label: label.isEmpty ? 'Adjustment stok' : label,
        body: body,
      );
      return true;
    }

    if (sync != null && await sync.hasPending()) return queue();
    try {
      await _dio.post(ApiConfig.stockAdjustmentsPath, data: body);
      return false;
    } on DioException catch (e) {
      final error = DioClient.mapError(e);
      if (sync != null && error.isOffline) return queue();
      throw error;
    }
  }

  /// Report rows matching [query] (see adjustmentReportQuery).
  Future<List<AdjustmentReportRow>> fetchReport(
    Map<String, String> query,
  ) async {
    try {
      final res = await _dio.get(
        ApiConfig.stockAdjustmentReportPath,
        queryParameters: query,
      );
      final data = res.data;
      final result = data is Map ? data['result'] ?? data['data'] : data;
      return [
        if (result is List)
          for (final row in result)
            if (row is Map)
              AdjustmentReportRow.fromJson(Map<String, dynamic>.from(row)),
      ];
    } on DioException catch (e) {
      throw DioClient.mapError(e);
    }
  }

  /// Path (with query) of the report file in [format].
  static String reportDownloadPath(
    AdjustmentReportFormat format,
    Map<String, String> query,
  ) => Uri(
    path: ApiConfig.stockAdjustmentReportDownloadPath,
    queryParameters: {'format': format.name, ...query},
  ).toString();

  /// Downloads the report file in [format]: its bytes and file name.
  Future<({Uint8List bytes, String fileName})> download(
    AdjustmentReportFormat format,
    Map<String, String> query,
  ) async {
    try {
      final res = await _dio.get<List<int>>(
        reportDownloadPath(format, query),
        options: Options(responseType: ResponseType.bytes),
      );
      final disposition = res.headers.value('content-disposition') ?? '';
      final name = RegExp(r'filename="?([^";]+)"?').firstMatch(disposition);
      return (
        bytes: Uint8List.fromList(res.data ?? const []),
        fileName: name?.group(1) ?? 'laporan-adjustment-stok.${format.name}',
      );
    } on DioException catch (e) {
      throw DioClient.mapError(e);
    }
  }
}

final stockAdjustmentApiProvider = Provider<StockAdjustmentApi>((ref) {
  return StockAdjustmentApi(sync: ref.watch(syncServiceProvider));
});
