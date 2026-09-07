import 'package:equatable/equatable.dart';

import '../../../core/utils/clean_text_helper.dart';

/// Single item representation of Ship Medicine History
/// from GET /api/v1/ship-medicines/history
class ShipMedicineHistory extends Equatable {
  const ShipMedicineHistory({
    required this.id,
    required this.shipCode,
    this.shipName,
    required this.medicineSku,
    required this.medicineName,
    required this.medicineCategory,
    this.unitOfMeasurement = '',
    required this.quantity,
    required this.notes,
    this.userId,
    required this.userName,
    required this.createdAt,
  });

  final String id;
  final String shipCode;
  final String? shipName;
  final String medicineSku;
  final String medicineName;
  final String medicineCategory;
  final String unitOfMeasurement;
  final int quantity;
  final String notes;
  final String? userId;
  final String userName;
  final DateTime createdAt;

  factory ShipMedicineHistory.fromJson(Map<String, dynamic> json) {
    // Nested Medicine object
    final medicineJson = json['medicine'] is Map
        ? Map<String, dynamic>.from(json['medicine'] as Map)
        : null;

    // Nested User object
    final userJson = json['user'] is Map
        ? Map<String, dynamic>.from(json['user'] as Map)
        : null;

    // Nested Ship object
    final shipJson = json['ship'] is Map
        ? Map<String, dynamic>.from(json['ship'] as Map)
        : null;

    final medSku = CleanTextHelper.cleanCode(
      json['medicine_sku'] ??
          json['sku'] ??
          json['code'] ??
          medicineJson?['sku'] ??
          medicineJson?['code'],
    );

    final medName = CleanTextHelper.cleanName(
      medicineJson?['name'] ??
          medicineJson?['nama'] ??
          json['medicine_name'] ??
          json['name'] ??
          json['medicine'],
      fallback: medSku.isNotEmpty ? medSku : 'Obat',
    );

    final medCat = (medicineJson?['category'] ??
            medicineJson?['type'] ??
            json['category'] ??
            json['type'] ??
            '')
        .toString();

    final unit = (medicineJson?['unit_of_measurement'] ??
            medicineJson?['unit'] ??
            medicineJson?['satuan'] ??
            json['unit_of_measurement'] ??
            json['unit'] ??
            json['satuan'] ??
            '')
        .toString();

    final userName = (userJson?['full_name'] ??
            userJson?['name'] ??
            json['input_by'] ??
            json['diinput_oleh'] ??
            json['user_name'] ??
            '-')
        .toString();

    DateTime parsedCreated = DateTime.now();
    final rawDate = json['created_at'] ?? json['waktu_input'] ?? json['waktu'];
    if (rawDate != null) {
      parsedCreated = DateTime.tryParse(rawDate.toString())?.toLocal() ?? DateTime.now();
    }

    return ShipMedicineHistory(
      id: (json['id'] ?? '').toString(),
      shipCode: (json['ship_code'] ?? '').toString(),
      shipName: shipJson?['name']?.toString() ?? json['ship_name']?.toString(),
      medicineSku: medSku,
      medicineName: medName,
      medicineCategory: medCat,
      unitOfMeasurement: unit,
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      notes: (json['notes'] ?? json['catatan'] ?? '').toString(),
      userId: json['user_id']?.toString(),
      userName: userName,
      createdAt: parsedCreated,
    );
  }

  @override
  List<Object?> get props => [
        id,
        shipCode,
        shipName,
        medicineSku,
        medicineName,
        medicineCategory,
        unitOfMeasurement,
        quantity,
        notes,
        userId,
        userName,
        createdAt,
      ];
}

class PaginatedShipMedicineHistories {
  const PaginatedShipMedicineHistories({
    required this.items,
    required this.total,
    required this.page,
    required this.limit,
    required this.totalPages,
  });

  final List<ShipMedicineHistory> items;
  final int total;
  final int page;
  final int limit;
  final int totalPages;
}
