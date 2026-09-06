import 'package:equatable/equatable.dart';

/// Single item representation of Medicine from GET /api/v1/medicines
class MedicineItem extends Equatable {
  const MedicineItem({
    required this.id,
    required this.sku,
    required this.name,
    required this.category,
    required this.unitOfMeasurement,
    this.stock = 0,
    this.expiry,
  });

  final String id;
  final String sku;
  final String name;
  final String category;
  final String unitOfMeasurement;
  final int stock;
  final String? expiry;

  factory MedicineItem.fromJson(Map<String, dynamic> json) {
    return MedicineItem(
      id: json['id']?.toString() ?? '',
      sku: json['sku']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      unitOfMeasurement: json['unit_of_measurement']?.toString() ?? '',
      stock: (json['stock'] as num?)?.toInt() ?? 0,
      expiry: json['expiry']?.toString(),
    );
  }

  @override
  List<Object?> get props => [
        id,
        sku,
        name,
        category,
        unitOfMeasurement,
        stock,
        expiry,
      ];
}

class PaginatedMedicines {
  const PaginatedMedicines({
    required this.data,
    required this.total,
    required this.page,
    required this.limit,
    required this.totalPages,
  });

  final List<MedicineItem> data;
  final int total;
  final int page;
  final int limit;
  final int totalPages;
}
