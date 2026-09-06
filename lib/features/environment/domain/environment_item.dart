import 'package:equatable/equatable.dart';

/// Represents a ship environment record from GET /api/v1/environments.
class EnvironmentItem extends Equatable {
  const EnvironmentItem({
    required this.id,
    required this.code,
    required this.name,
    this.shipId,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String code;
  final String name;
  final String? shipId;
  final String? createdAt;
  final String? updatedAt;

  factory EnvironmentItem.fromJson(Map<String, dynamic> json) {
    return EnvironmentItem(
      id: (json['id'] ?? '').toString(),
      code: (json['code'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      shipId: json['ship_id']?.toString() ?? json['shipId']?.toString(),
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'code': code,
        'name': name,
        if (shipId != null) 'ship_id': shipId,
        if (createdAt != null) 'created_at': createdAt,
        if (updatedAt != null) 'updated_at': updatedAt,
      };

  @override
  List<Object?> get props => [id, code, name, shipId, createdAt, updatedAt];
}
