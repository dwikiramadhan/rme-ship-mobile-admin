import 'package:equatable/equatable.dart';

import '../../../core/utils/clean_text_helper.dart';

class ObatPenggantian extends Equatable {
  const ObatPenggantian({
    required this.dari,
    required this.alasan,
    this.notes,
    this.sku,
  });

  final String dari;
  final String alasan;
  final String? notes;
  final String? sku;

  @override
  List<Object?> get props => [dari, alasan, notes, sku];
}

/// One prescription line item. `penggantian` is set when Apotek substitutes
/// the originally-prescribed drug (e.g. out of stock).
class ResepItem extends Equatable {
  const ResepItem({
    this.id,
    required this.obat,
    required this.dosis,
    required this.instruksi,
    this.sku,
    this.jumlah,
    this.satuan,
    this.unitOfMeasurement,
    this.penggantian,
  });

  final String? id;
  final String obat;
  final String dosis;
  final String instruksi;
  final String? sku;
  final dynamic jumlah;
  final String? satuan;
  final String? unitOfMeasurement;
  final ObatPenggantian? penggantian;

  factory ResepItem.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'] ??
        json['prescription_id'] ??
        json['prescriptionId'] ??
        json['uuid'];
    final id = rawId?.toString();

    Map<String, dynamic>? medMap;
    if (json['medicine'] is Map) {
      medMap = Map<String, dynamic>.from(json['medicine'] as Map);
    } else if (json['obat'] is Map) {
      medMap = Map<String, dynamic>.from(json['obat'] as Map);
    } else if (json['drug'] is Map) {
      medMap = Map<String, dynamic>.from(json['drug'] as Map);
    }

    final rawName = medMap?['name'] ??
        medMap?['nama'] ??
        medMap?['nama_obat'] ??
        medMap?['medicine_name'] ??
        json['obat'] ??
        json['medicine_name'] ??
        json['nama_obat'] ??
        json['drug_name'] ??
        (json['medicine'] is String ? json['medicine'] : null) ??
        json['name'] ??
        json['medicine'];
    final name = CleanTextHelper.cleanName(rawName);

    final rawSku = medMap?['sku'] ??
        medMap?['code'] ??
        medMap?['kode'] ??
        medMap?['medicine_sku'] ??
        json['sku'] ??
        json['dispensed_sku'] ??
        json['medicine_sku'] ??
        json['code'] ??
        json['kode'];
    String? sku = CleanTextHelper.cleanCode(rawSku);
    if (sku.isEmpty) {
      sku = CleanTextHelper.cleanCode(rawName);
    }
    if (sku.isEmpty || sku == name) {
      sku = null;
    }

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
    final jumlah = json['jumlah'] ??
        json['qty'] ??
        json['quantity'] ??
        json['dispensed_quantity'] ??
        json['total'] ??
        json['amount'];
    final unitOfMeasurement = json['unit_of_measurement']?.toString() ??
        medMap?['unit_of_measurement']?.toString() ??
        json['satuan']?.toString() ??
        medMap?['satuan']?.toString() ??
        json['unit']?.toString() ??
        medMap?['unit']?.toString();

    ObatPenggantian? penggantian;
    if (json['penggantian'] is Map<String, dynamic>) {
      penggantian = ObatPenggantian(
        dari: json['penggantian']['dari']?.toString() ?? '',
        alasan: json['penggantian']['alasan']?.toString() ?? '',
        notes: json['penggantian']['notes']?.toString(),
        sku: json['penggantian']['sku']?.toString(),
      );
    } else if (json['is_substituted'] == true) {
      penggantian = ObatPenggantian(
        dari: json['original_medicine']?.toString() ?? '',
        alasan: json['substitution_reason']?.toString() ?? '',
        notes: json['substitution_notes']?.toString(),
        sku: json['dispensed_sku']?.toString(),
      );
    }

    return ResepItem(
      id: id,
      obat: name,
      dosis: dose,
      instruksi: instruction,
      sku: sku,
      jumlah: jumlah,
      satuan: unitOfMeasurement,
      unitOfMeasurement: unitOfMeasurement,
      penggantian: penggantian,
    );
  }

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'obat': obat,
        'dosis': dosis,
        'instruksi': instruksi,
        if (sku != null) 'sku': sku,
        if (jumlah != null) 'jumlah': jumlah,
        if (satuan != null || unitOfMeasurement != null)
          'unit_of_measurement': unitOfMeasurement ?? satuan,
        if (satuan != null || unitOfMeasurement != null)
          'satuan': satuan ?? unitOfMeasurement,
        if (penggantian != null)
          'penggantian': {
            'dari': penggantian!.dari,
            'alasan': penggantian!.alasan,
            if (penggantian!.notes != null) 'notes': penggantian!.notes,
            if (penggantian!.sku != null) 'sku': penggantian!.sku,
          },
      };

  ResepItem copyWith({
    String? id,
    String? obat,
    String? dosis,
    String? instruksi,
    String? sku,
    dynamic jumlah,
    String? satuan,
    String? unitOfMeasurement,
    ObatPenggantian? penggantian,
  }) {
    return ResepItem(
      id: id ?? this.id,
      obat: obat ?? this.obat,
      dosis: dosis ?? this.dosis,
      instruksi: instruksi ?? this.instruksi,
      sku: sku ?? this.sku,
      jumlah: jumlah ?? this.jumlah,
      satuan: satuan ?? this.satuan,
      unitOfMeasurement: unitOfMeasurement ?? this.unitOfMeasurement,
      penggantian: penggantian ?? this.penggantian,
    );
  }

  @override
  List<Object?> get props =>
      [id, obat, dosis, instruksi, sku, jumlah, satuan, unitOfMeasurement, penggantian];
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
