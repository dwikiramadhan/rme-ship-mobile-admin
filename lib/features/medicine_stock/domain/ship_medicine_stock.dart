import 'package:equatable/equatable.dart';

import '../../../core/utils/clean_text_helper.dart';

/// Single item representation of Ship Medicine Stock
/// from GET /api/v1/ship-medicines/stocks/:ship_code
class ShipMedicineStock extends Equatable {
  const ShipMedicineStock({
    required this.shipId,
    required this.shipCode,
    required this.shipName,
    required this.medicineId,
    required this.medicineSku,
    required this.medicineName,
    required this.category,
    required this.unitOfMeasurement,
    this.shipMedicineId,
    this.stock = 0,
    this.minStock = 0,
    this.lastUpdate,
    this.notes,
  });

  final String shipId;
  final String shipCode;
  final String shipName;
  final String medicineId;
  final String medicineSku;
  final String medicineName;
  final String category;
  final String unitOfMeasurement;
  final String? shipMedicineId;
  final int stock;
  final int minStock;
  final DateTime? lastUpdate;
  final String? notes;

  bool get isOutOfStock => stock <= 0;
  bool get isLowStock => stock > 0 && minStock > 0 && stock <= minStock;
  bool get isAvailable => stock > 0 && (minStock <= 0 || stock > minStock);

  factory ShipMedicineStock.fromJson(Map<String, dynamic> json) {
    DateTime? parsedDate;
    final rawDate = json['last_update'] ?? json['updated_at'] ?? json['created_at'];
    if (rawDate != null) {
      parsedDate = DateTime.tryParse(rawDate.toString())?.toLocal();
    }

    Map<String, dynamic>? medMap;
    if (json['medicine'] is Map) {
      medMap = Map<String, dynamic>.from(json['medicine'] as Map);
    }

    final rawName = medMap?['name'] ??
        medMap?['nama'] ??
        medMap?['medicine_name'] ??
        medMap?['nama_obat'] ??
        json['medicine_name'] ??
        json['nama_obat'] ??
        json['name'] ??
        json['nama'] ??
        json['medicine'];
    final cleanName = CleanTextHelper.cleanName(rawName);

    final rawSku = medMap?['sku'] ??
        medMap?['code'] ??
        medMap?['kode'] ??
        medMap?['medicine_sku'] ??
        json['medicine_sku'] ??
        json['sku'] ??
        json['code'] ??
        json['kode'];
    final cleanSku = CleanTextHelper.cleanCode(rawSku);

    return ShipMedicineStock(
      shipId: (json['ship_id'] ?? '').toString(),
      shipCode: CleanTextHelper.cleanCode(json['ship_code']),
      shipName: CleanTextHelper.cleanName(json['ship_name']),
      medicineId: (json['medicine_id'] ?? json['id'] ?? medMap?['id'] ?? '').toString(),
      medicineSku: cleanSku.isNotEmpty ? cleanSku : (CleanTextHelper.cleanCode(rawName)),
      medicineName: cleanName.isNotEmpty ? cleanName : 'Obat',
      category: (json['category'] ?? json['type'] ?? json['tipe'] ?? medMap?['category'] ?? medMap?['type'] ?? '').toString(),
      unitOfMeasurement: (json['unit_of_measurement'] ?? json['unit'] ?? json['satuan'] ?? medMap?['unit'] ?? medMap?['satuan'] ?? '').toString(),
      shipMedicineId: json['ship_medicine_id']?.toString(),
      stock: (json['stock'] as num?)?.toInt() ?? 0,
      minStock: (json['min_stock'] as num?)?.toInt() ?? 0,
      lastUpdate: parsedDate,
      notes: json['notes']?.toString(),
    );
  }

  ShipMedicineStock copyWith({
    String? shipId,
    String? shipCode,
    String? shipName,
    String? medicineId,
    String? medicineSku,
    String? medicineName,
    String? category,
    String? unitOfMeasurement,
    String? shipMedicineId,
    int? stock,
    int? minStock,
    DateTime? lastUpdate,
    String? notes,
  }) {
    return ShipMedicineStock(
      shipId: shipId ?? this.shipId,
      shipCode: shipCode ?? this.shipCode,
      shipName: shipName ?? this.shipName,
      medicineId: medicineId ?? this.medicineId,
      medicineSku: medicineSku ?? this.medicineSku,
      medicineName: medicineName ?? this.medicineName,
      category: category ?? this.category,
      unitOfMeasurement: unitOfMeasurement ?? this.unitOfMeasurement,
      shipMedicineId: shipMedicineId ?? this.shipMedicineId,
      stock: stock ?? this.stock,
      minStock: minStock ?? this.minStock,
      lastUpdate: lastUpdate ?? this.lastUpdate,
      notes: notes ?? this.notes,
    );
  }

  @override
  List<Object?> get props => [
        shipId,
        shipCode,
        shipName,
        medicineId,
        medicineSku,
        medicineName,
        category,
        unitOfMeasurement,
        shipMedicineId,
        stock,
        minStock,
        lastUpdate,
        notes,
      ];
}

class PaginatedShipMedicineStocks {
  const PaginatedShipMedicineStocks({
    required this.items,
    required this.total,
    required this.page,
    required this.limit,
    required this.totalPages,
  });

  final List<ShipMedicineStock> items;
  final int total;
  final int page;
  final int limit;
  final int totalPages;
}
