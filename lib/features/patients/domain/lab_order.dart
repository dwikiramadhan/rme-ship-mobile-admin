import 'package:equatable/equatable.dart';

enum LabOrderStatus { baru, diproses, selesai }

class LabHasil extends Equatable {
  const LabHasil({required this.catatanHasil, this.fileName});

  final String catatanHasil;
  final String? fileName;

  @override
  List<Object?> get props => [catatanHasil, fileName];
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
