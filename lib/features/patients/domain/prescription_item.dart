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

  factory ResepItem.fromJson(Map<String, dynamic> json) {
    final name = json['obat']?.toString() ??
        json['medicine']?.toString() ??
        json['medicine_name']?.toString() ??
        json['nama_obat']?.toString() ??
        json['drug_name']?.toString() ??
        json['name']?.toString() ??
        '';
    final dose = json['dosis']?.toString() ??
        json['dosage']?.toString() ??
        json['dose']?.toString() ??
        '1x1';
    final instruction = json['instruksi']?.toString() ??
        json['instruction']?.toString() ??
        json['instructions']?.toString() ??
        json['aturan_pakai']?.toString() ??
        json['signa']?.toString() ??
        'Sesudah makan';

    ObatPenggantian? penggantian;
    if (json['penggantian'] is Map<String, dynamic>) {
      penggantian = ObatPenggantian(
        dari: json['penggantian']['dari']?.toString() ?? '',
        alasan: json['penggantian']['alasan']?.toString() ?? '',
      );
    }

    return ResepItem(
      obat: name,
      dosis: dose,
      instruksi: instruction,
      penggantian: penggantian,
    );
  }

  Map<String, dynamic> toJson() => {
        'obat': obat,
        'dosis': dosis,
        'instruksi': instruksi,
      };

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

List<ResepItem> parseResepString(String text) {
  if (text.trim().isEmpty || text == '—' || text == '-') return [];
  if (RegExp(r'^[\d.,\s-]+$').hasMatch(text.trim())) return [];

  final items = <ResepItem>[];
  final lines = text.contains('\n')
      ? text.split('\n')
      : (text.contains(';') ? text.split(';') : [text]);

  for (final line in lines) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) continue;

    final matchWithParen = RegExp(
      r'^(.*?)\s+(\d+x\d+|Sesuai\s+kebutuhan.*?)\s*\((.*?)\)$',
      caseSensitive: false,
    ).firstMatch(trimmed);
    if (matchWithParen != null) {
      items.add(ResepItem(
        obat: matchWithParen.group(1)?.trim() ?? trimmed,
        dosis: matchWithParen.group(2)?.trim() ?? '1x1',
        instruksi: matchWithParen.group(3)?.trim() ?? 'Sesudah makan',
      ));
      continue;
    }

    final matchDose = RegExp(
      r'^(.*?)\s+(\d+x\d+|PRN)(.*)$',
      caseSensitive: false,
    ).firstMatch(trimmed);
    if (matchDose != null) {
      final obat = matchDose.group(1)?.trim() ?? '';
      final dosis = matchDose.group(2)?.trim() ?? '1x1';
      final rest = matchDose
              .group(3)
              ?.trim()
              .replaceAll(RegExp(r'^[()]|[()]$'), '') ??
          'Sesudah makan';
      items.add(ResepItem(
        obat: obat.isNotEmpty ? obat : trimmed,
        dosis: dosis,
        instruksi: rest.isNotEmpty ? rest : 'Sesudah makan',
      ));
      continue;
    }

    items.add(ResepItem(
      obat: trimmed,
      dosis: '1x1',
      instruksi: 'Sesudah makan',
    ));
  }
  return items;
}

enum ResepStatus { baru, diproses, selesai }

typedef PrescriptionItem = ResepItem;
typedef PrescriptionStatus = ResepStatus;
typedef MedicineSubstitution = ObatPenggantian;
