import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One ship-stock medicine row (Stok Obat Kapal in the RBAC matrix).
class StokObat extends Equatable {
  const StokObat({
    required this.id,
    required this.nama,
    required this.kategori,
    required this.satuan,
    required this.jumlah,
    required this.minimum,
    this.kadaluarsa,
  });

  final String id;
  final String nama;
  final String kategori;
  final String satuan;
  final int jumlah;
  final int minimum;
  final DateTime? kadaluarsa;

  bool get menipis => jumlah <= minimum;

  StokObat copyWith({
    String? nama,
    String? kategori,
    String? satuan,
    int? jumlah,
    int? minimum,
    DateTime? kadaluarsa,
  }) {
    return StokObat(
      id: id,
      nama: nama ?? this.nama,
      kategori: kategori ?? this.kategori,
      satuan: satuan ?? this.satuan,
      jumlah: jumlah ?? this.jumlah,
      minimum: minimum ?? this.minimum,
      kadaluarsa: kadaluarsa ?? this.kadaluarsa,
    );
  }

  @override
  List<Object?> get props => [id, nama, kategori, satuan, jumlah, minimum, kadaluarsa];
}

/// In-memory ship stock notifier.
/// RBAC (Ship Web Admin matrix): Pharmacist C/R/U/D, Doctor R, Perawat R.
class StokObatNotifier extends StateNotifier<List<StokObat>> {
  StokObatNotifier() : super(const []);

  int _next = 1;

  void add({required String nama, required String kategori, required String satuan, required int jumlah, required int minimum, DateTime? kadaluarsa}) {
    final id = 'S${_next.toString().padLeft(3, '0')}';
    _next++;
    state = [...state, StokObat(id: id, nama: nama, kategori: kategori, satuan: satuan, jumlah: jumlah, minimum: minimum, kadaluarsa: kadaluarsa)];
  }

  void update(String id, StokObat Function(StokObat) updater) {
    state = [for (final s in state) if (s.id == id) updater(s) else s];
  }

  void remove(String id) {
    state = state.where((s) => s.id != id).toList();
  }
}

final stokObatProvider = StateNotifierProvider<StokObatNotifier, List<StokObat>>((ref) {
  return StokObatNotifier();
});
