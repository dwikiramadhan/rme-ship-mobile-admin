import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One past clinical visit (Riwayat Kunjungan / Rekam Medis in the RBAC
/// matrix). Doctor C/R/U; Perawat R.
class RiwayatKunjungan extends Equatable {
  const RiwayatKunjungan({
    required this.id,
    required this.pasienNama,
    required this.pasienNik,
    required this.tanggal,
    required this.keluhan,
    required this.diagnosa,
    required this.tindakan,
    required this.dokterNama,
  });

  final String id;
  final String pasienNama;
  final String pasienNik;
  final DateTime tanggal;
  final String keluhan;
  final String diagnosa;
  final String tindakan;
  final String dokterNama;

  RiwayatKunjungan copyWith({
    String? keluhan,
    String? diagnosa,
    String? tindakan,
  }) {
    return RiwayatKunjungan(
      id: id,
      pasienNama: pasienNama,
      pasienNik: pasienNik,
      tanggal: tanggal,
      keluhan: keluhan ?? this.keluhan,
      diagnosa: diagnosa ?? this.diagnosa,
      tindakan: tindakan ?? this.tindakan,
      dokterNama: dokterNama,
    );
  }

  @override
  List<Object?> get props => [id, pasienNama, pasienNik, tanggal, keluhan, diagnosa, tindakan, dokterNama];
}

/// In-memory visit history, same mock pattern as the patient repository.
class RiwayatKunjunganNotifier extends StateNotifier<List<RiwayatKunjungan>> {
  RiwayatKunjunganNotifier() : super(_seed());

  static List<RiwayatKunjungan> _seed() {
    final now = DateTime.now();
    return [
      RiwayatKunjungan(
        id: 'R001',
        pasienNama: 'Budi Santoso',
        pasienNik: '3374031203680001',
        tanggal: now.subtract(const Duration(days: 30)),
        keluhan: 'Pusing dan tekanan darah tinggi saat kontrol rutin',
        diagnosa: 'Hipertensi esensial (I10)',
        tindakan: 'Pemberian Amlodipine 5mg, edukasi diet rendah garam',
        dokterNama: 'dr. Ahmad Fauzi',
      ),
      RiwayatKunjungan(
        id: 'R002',
        pasienNama: 'Siti Rahayu',
        pasienNik: '3171065506940002',
        tanggal: now.subtract(const Duration(days: 12)),
        keluhan: 'Batuk berdahak 1 minggu',
        diagnosa: 'ISPA (J06.9)',
        tindakan: 'Terapi simtomatik, istirahat cukup',
        dokterNama: 'dr. Rina Melati',
      ),
    ];
  }

  int _next = 3;

  void add({
    required String pasienNama,
    required String pasienNik,
    required String keluhan,
    required String diagnosa,
    required String tindakan,
    required String dokterNama,
  }) {
    final id = 'R${_next.toString().padLeft(3, '0')}';
    _next++;
    state = [
      ...state,
      RiwayatKunjungan(
        id: id,
        pasienNama: pasienNama,
        pasienNik: pasienNik,
        tanggal: DateTime.now(),
        keluhan: keluhan,
        diagnosa: diagnosa,
        tindakan: tindakan,
        dokterNama: dokterNama,
      ),
    ];
  }

  void update(String id, RiwayatKunjungan Function(RiwayatKunjungan) updater) {
    state = [for (final r in state) if (r.id == id) updater(r) else r];
  }
}

final riwayatKunjunganProvider = StateNotifierProvider<RiwayatKunjunganNotifier, List<RiwayatKunjungan>>((ref) {
  return RiwayatKunjunganNotifier();
});
