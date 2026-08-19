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

/// In-memory ship stock, mirroring the mock patient repository pattern.
/// RBAC (Ship Web Admin matrix): Pharmacist C/R/U/D, Doctor R, Perawat R.
class StokObatNotifier extends StateNotifier<List<StokObat>> {
  StokObatNotifier() : super(_seed());

  static List<StokObat> _seed() {
    final now = DateTime.now();
    return [
      StokObat(id: 'S001', nama: 'Paracetamol 500mg', kategori: 'Analgesik', satuan: 'tablet', jumlah: 240, minimum: 50, kadaluarsa: now.add(const Duration(days: 365))),
      StokObat(id: 'S002', nama: 'Amlodipine 5mg', kategori: 'Antihipertensi', satuan: 'tablet', jumlah: 90, minimum: 30, kadaluarsa: now.add(const Duration(days: 540))),
      StokObat(id: 'S003', nama: 'Omeprazole 20mg', kategori: 'Antasida', satuan: 'kapsul', jumlah: 25, minimum: 30, kadaluarsa: now.add(const Duration(days: 300))),
      StokObat(id: 'S004', nama: 'Cairan Infus NaCl 0.9%', kategori: 'Cairan', satuan: 'botol', jumlah: 40, minimum: 10, kadaluarsa: now.add(const Duration(days: 700))),
    ];
  }

  int _next = 5;

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
