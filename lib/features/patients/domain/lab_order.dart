import 'package:equatable/equatable.dart';

enum LabOrderStatus { baru, diproses, selesai }

class LabExaminationItem extends Equatable {
  const LabExaminationItem({
    required this.testName,
    required this.testCategory,
    required this.unit,
    required this.referenceRange,
    this.notes = '',
  });

  final String testName;
  final String testCategory;
  final String unit;
  final String referenceRange;
  final String notes;

  Map<String, dynamic> toJson() => {
        'test_name': testName,
        'test_category': testCategory,
        'unit': unit,
        'reference_range': referenceRange,
        'notes': notes,
      };

  factory LabExaminationItem.fromJson(Map<String, dynamic> json) =>
      LabExaminationItem(
        testName: json['test_name']?.toString() ?? '',
        testCategory: json['test_category']?.toString() ?? '',
        unit: json['unit']?.toString() ?? '',
        referenceRange: json['reference_range']?.toString() ?? '',
        notes: json['notes']?.toString() ?? '',
      );

  @override
  List<Object?> get props => [testName, testCategory, unit, referenceRange, notes];
}

class LabHasil extends Equatable {
  const LabHasil({
    required this.catatanHasil,
    this.fileName,
    this.items = const [],
  });

  final String catatanHasil;
  final String? fileName;
  final List<LabExaminationItem> items;

  @override
  List<Object?> get props => [catatanHasil, fileName, items];
}

class LabOrder extends Equatable {
  const LabOrder({
    required this.id,
    required this.jenis,
    this.catatan = '',
    this.status = LabOrderStatus.baru,
    this.hasil,
  });

  final String id;
  final String jenis;
  final String catatan;
  final LabOrderStatus status;
  final LabHasil? hasil;

  LabOrder copyWith({String? id, String? jenis, String? catatan, LabOrderStatus? status, LabHasil? hasil}) {
    return LabOrder(
      id: id ?? this.id,
      jenis: jenis ?? this.jenis,
      catatan: catatan ?? this.catatan,
      status: status ?? this.status,
      hasil: hasil ?? this.hasil,
    );
  }

  @override
  List<Object?> get props => [id, jenis, catatan, status, hasil];
}
