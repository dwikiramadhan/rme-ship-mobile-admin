import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_config.dart';
import '../../../core/network/dio_client.dart';
import '../../auth/presentation/auth_controller.dart';

/// Ringkasan kunjungan hari ini untuk dashboard Perawat.
class TodayStats {
  const TodayStats({this.patients = 0, this.waiting = 0, this.visits = 0});

  /// Pasien berbeda yang berkunjung hari ini.
  final int patients;

  /// Kunjungan hari ini yang masih Menunggu Dokter.
  final int waiting;

  /// Semua kunjungan hari ini.
  final int visits;

  factory TodayStats.fromJson(Map<String, dynamic> json) => TodayStats(
    patients: (json['patients'] as num?)?.toInt() ?? 0,
    waiting: (json['waiting'] as num?)?.toInt() ?? 0,
    visits: (json['visits'] as num?)?.toInt() ?? 0,
  );
}

/// GET /api/v1/dashboard/today-stats: tiga angka dari satu query di server,
/// tanpa memuat daftar pasien & kunjungan.
class TodayStatsApi {
  TodayStatsApi({Dio? dio}) : _dio = dio ?? DioClient.instance;

  final Dio _dio;

  /// "Hari ini" = hari kalender di zona waktu perangkat (kapal bisa di WIB,
  /// WITA, atau WIT), dikirim sebagai rentang [from, to).
  Future<TodayStats> fetch({required DateTime now, String? shipId}) async {
    final from = DateTime(now.year, now.month, now.day);
    final to = DateTime(now.year, now.month, now.day + 1);
    try {
      final response = await _dio.get(
        ApiConfig.todayStatsPath,
        queryParameters: {
          'from': from.toUtc().toIso8601String(),
          'to': to.toUtc().toIso8601String(),
          if (shipId != null && shipId.isNotEmpty) 'ship_id': shipId,
        },
      );
      final data = response.data;
      final result = data is Map<String, dynamic>
          ? data['result'] ?? data
          : null;
      return result is Map<String, dynamic>
          ? TodayStats.fromJson(result)
          : const TodayStats();
    } on DioException catch (e) {
      throw DioClient.mapError(e);
    }
  }
}

final todayStatsApiProvider = Provider<TodayStatsApi>((ref) => TodayStatsApi());

/// Statistik hari ini untuk kapal akun yang login.
final todayStatsProvider = FutureProvider.autoDispose<TodayStats>((ref) {
  final shipId = ref.watch(
    authControllerProvider.select((s) => s.session?.user.shipId),
  );
  return ref
      .watch(todayStatsApiProvider)
      .fetch(now: DateTime.now(), shipId: shipId);
});
