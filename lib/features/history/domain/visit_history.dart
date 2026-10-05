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
    this.dokterId,
  });

  final String id;
  final String pasienNama;
  final String pasienNik;
  final DateTime tanggal;
  final String keluhan;
  final String diagnosa;
  final String tindakan;
  final String dokterNama;
  final String? dokterId;

  RiwayatKunjungan copyWith({
    String? keluhan,
    String? diagnosa,
    String? tindakan,
    String? dokterNama,
    String? dokterId,
  }) {
    return RiwayatKunjungan(
      id: id,
      pasienNama: pasienNama,
      pasienNik: pasienNik,
      tanggal: tanggal,
      keluhan: keluhan ?? this.keluhan,
      diagnosa: diagnosa ?? this.diagnosa,
      tindakan: tindakan ?? this.tindakan,
      dokterNama: dokterNama ?? this.dokterNama,
      dokterId: dokterId ?? this.dokterId,
    );
  }

  @override
  List<Object?> get props => [id, pasienNama, pasienNik, tanggal, keluhan, diagnosa, tindakan, dokterNama, dokterId];
}

/// In-memory visit history state notifier.
class RiwayatKunjunganNotifier extends StateNotifier<List<RiwayatKunjungan>> {
  RiwayatKunjunganNotifier() : super(const []);

  int _next = 1;

  void add({
    required String pasienNama,
    required String pasienNik,
    required String keluhan,
    required String diagnosa,
    required String tindakan,
    required String dokterNama,
    String? dokterId,
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
        dokterId: dokterId,
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
