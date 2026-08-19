import 'package:equatable/equatable.dart';

class ObatPenggantian extends Equatable {
  const ObatPenggantian({required this.dari, required this.alasan});

  final String dari;
  final String alasan;

  @override
  List<Object?> get props => [dari, alasan];
}

/// One prescription line item. `penggantian` is set when Apotek substitutes
/// the originally-prescribed drug (e.g. out of stock).
class ResepItem extends Equatable {
  const ResepItem({
    required this.obat,
    required this.dosis,
    required this.instruksi,
    this.penggantian,
  });

  final String obat;
  final String dosis;
  final String instruksi;
  final ObatPenggantian? penggantian;

  ResepItem copyWith({String? obat, String? dosis, String? instruksi, ObatPenggantian? penggantian}) {
    return ResepItem(
      obat: obat ?? this.obat,
      dosis: dosis ?? this.dosis,
      instruksi: instruksi ?? this.instruksi,
      penggantian: penggantian ?? this.penggantian,
    );
  }

  @override
  List<Object?> get props => [obat, dosis, instruksi, penggantian];
}

enum ResepStatus { baru, diproses, selesai }
