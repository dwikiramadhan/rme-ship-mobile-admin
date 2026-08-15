import 'package:equatable/equatable.dart';

import 'lab_order.dart';
import 'resep_item.dart';
import 'vitals.dart';

enum Gender { l, p }

extension GenderLabel on Gender {
  String get label => this == Gender.l ? 'Laki-laki' : 'Perempuan';
}

enum PatientStatus { menungguDokter, diperiksa }

/// One patient's clinical record as it moves through the Perawat -> Dokter
/// -> Apotek / Lab flow. Field names mirror the prototype's mock data 1:1
/// (`nik`, `jk`, `keluhanUtama`, `waktuMasuk`, `dilihatDokter`, ...) so the
/// behaviour ported from `Bayan RME - Alur Klinis.html` stays traceable.
class Patient extends Equatable {
  const Patient({
    required this.id,
    required this.nama,
    required this.nik,
    required this.jk,
    required this.umur,
    required this.alamat,
    required this.keluhanUtama,
    required this.durasiKeluhan,
    required this.lokasiKeluhan,
    required this.vitals,
    required this.assignedDokterId,
    required this.waktuMasuk,
    required this.updatedAt,
    this.status = PatientStatus.menungguDokter,
    this.diagnosa,
    this.resep = const [],
    this.resepStatus,
    this.labOrder,
    this.dilihatDokter = false,
    this.dilihatPharmacy = false,
    this.dilihatLab = false,
    this.dilihatDokterLab = false,
  });

  final String id;
  final String nama;
  final String nik;
  final Gender jk;
  final int umur;
  final String alamat;

  final String keluhanUtama;
  final String durasiKeluhan;
  final String lokasiKeluhan;
  final Vitals vitals;

  final String assignedDokterId;
  final String waktuMasuk;
  final DateTime updatedAt;

  final PatientStatus status;
  final String? diagnosa;
  final List<ResepItem> resep;
  final ResepStatus? resepStatus;
  final LabOrder? labOrder;

  final bool dilihatDokter;
  final bool dilihatPharmacy;
  final bool dilihatLab;
  final bool dilihatDokterLab;

  Patient copyWith({
    String? nama,
    String? nik,
    Gender? jk,
    int? umur,
    String? alamat,
    String? keluhanUtama,
    String? durasiKeluhan,
    String? lokasiKeluhan,
    Vitals? vitals,
    String? assignedDokterId,
    String? waktuMasuk,
    DateTime? updatedAt,
    PatientStatus? status,
    Object? diagnosa = _unset,
    List<ResepItem>? resep,
    Object? resepStatus = _unset,
    Object? labOrder = _unset,
    bool? dilihatDokter,
    bool? dilihatPharmacy,
    bool? dilihatLab,
    bool? dilihatDokterLab,
  }) {
    return Patient(
      id: id,
      nama: nama ?? this.nama,
      nik: nik ?? this.nik,
      jk: jk ?? this.jk,
      umur: umur ?? this.umur,
      alamat: alamat ?? this.alamat,
      keluhanUtama: keluhanUtama ?? this.keluhanUtama,
      durasiKeluhan: durasiKeluhan ?? this.durasiKeluhan,
      lokasiKeluhan: lokasiKeluhan ?? this.lokasiKeluhan,
      vitals: vitals ?? this.vitals,
      assignedDokterId: assignedDokterId ?? this.assignedDokterId,
      waktuMasuk: waktuMasuk ?? this.waktuMasuk,
      updatedAt: updatedAt ?? this.updatedAt,
      status: status ?? this.status,
      diagnosa: identical(diagnosa, _unset) ? this.diagnosa : diagnosa as String?,
      resep: resep ?? this.resep,
      resepStatus: identical(resepStatus, _unset) ? this.resepStatus : resepStatus as ResepStatus?,
      labOrder: identical(labOrder, _unset) ? this.labOrder : labOrder as LabOrder?,
      dilihatDokter: dilihatDokter ?? this.dilihatDokter,
      dilihatPharmacy: dilihatPharmacy ?? this.dilihatPharmacy,
      dilihatLab: dilihatLab ?? this.dilihatLab,
      dilihatDokterLab: dilihatDokterLab ?? this.dilihatDokterLab,
    );
  }

  @override
  List<Object?> get props => [
        id,
        nama,
        nik,
        jk,
        umur,
        alamat,
        keluhanUtama,
        durasiKeluhan,
        lokasiKeluhan,
        vitals,
        assignedDokterId,
        waktuMasuk,
        updatedAt,
        status,
        diagnosa,
        resep,
        resepStatus,
        labOrder,
        dilihatDokter,
        dilihatPharmacy,
        dilihatLab,
        dilihatDokterLab,
      ];
}

/// Sentinel used so `copyWith` can distinguish "leave unchanged" from
/// "explicitly set to null" for nullable fields (diagnosa, resepStatus, labOrder).
const Object _unset = Object();

List<Patient> sortRecent(List<Patient> patients) {
  final sorted = [...patients];
  sorted.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  return sorted;
}
