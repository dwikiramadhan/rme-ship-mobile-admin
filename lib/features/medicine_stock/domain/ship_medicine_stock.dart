import 'package:equatable/equatable.dart';

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

    return ShipMedicineStock(
      shipId: (json['ship_id'] ?? '').toString(),
      shipCode: (json['ship_code'] ?? '').toString(),
      shipName: (json['ship_name'] ?? '').toString(),
      medicineId: (json['medicine_id'] ?? json['id'] ?? '').toString(),
      medicineSku: (json['medicine_sku'] ?? json['sku'] ?? '').toString(),
      medicineName: (json['medicine_name'] ?? json['name'] ?? '').toString(),
      category: (json['category'] ?? json['type'] ?? json['tipe'] ?? '').toString(),
      unitOfMeasurement: (json['unit_of_measurement'] ?? json['unit'] ?? json['satuan'] ?? '').toString(),
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
