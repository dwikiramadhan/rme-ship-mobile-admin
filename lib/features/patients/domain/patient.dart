import 'package:equatable/equatable.dart';

import 'lab_order.dart';
import 'prescription_item.dart';
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
    this.dbStatus = 'Monitoring',
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
  final String dbStatus;
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
    String? dbStatus,
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
      dbStatus: dbStatus ?? this.dbStatus,
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

  factory Patient.fromApiJson(Map<String, dynamic> json) {
    final String id = json['id']?.toString() ?? '';
    final String name = json['name']?.toString() ?? '';
    final String nik = json['nik']?.toString() ?? '';
    final String genderStr = json['gender']?.toString().toLowerCase() ?? '';
    final Gender jk = genderStr.contains('perempuan') ? Gender.p : Gender.l;
    final String dobStr = json['dob']?.toString() ?? '';
    final String address = json['address']?.toString() ?? '';
    final String dbStatus = json['status']?.toString() ?? 'Monitoring';

    int umur = 0;
    if (dobStr.isNotEmpty) {
      try {
        final birth = DateTime.parse(dobStr);
        final today = DateTime.now();
        umur = today.year - birth.year;
        if (today.month < birth.month || (today.month == birth.month && today.day < birth.day)) {
          umur--;
        }
        if (umur < 0) umur = 0;
      } catch (_) {}
    }

    final createdAt = DateTime.tryParse(json['created_at']?.toString() ?? '');
    final updatedAt = DateTime.tryParse(json['updated_at']?.toString() ?? '') ?? DateTime.now();
    final localCreated = createdAt?.toLocal();
    final waktuMasuk = localCreated != null
        ? '${localCreated.day.toString().padLeft(2, '0')}/${localCreated.month.toString().padLeft(2, '0')}/${localCreated.year} ${localCreated.hour.toString().padLeft(2, '0')}:${localCreated.minute.toString().padLeft(2, '0')}'
        : '${DateTime.now().day.toString().padLeft(2, '0')}/${DateTime.now().month.toString().padLeft(2, '0')}/${DateTime.now().year} ${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}';

    final medRecords = json['medical_records'];
    String keluhan = '';
    String? diagnosa;
    String assignedDoctorId = '';
    List<ResepItem> resep = const [];
    ResepStatus? resepStatus;
    PatientStatus status = PatientStatus.menungguDokter;

    if (medRecords is List && medRecords.isNotEmpty) {
      final latest = medRecords.last as Map<String, dynamic>;
      keluhan = latest['complaint']?.toString() ?? '';
      diagnosa = latest['diagnosis']?.toString();
      assignedDoctorId = latest['doctor_id']?.toString() ?? '';
      final treatment = latest['treatment']?.toString() ?? '';
      if (treatment.isNotEmpty) {
        resep = [
          ResepItem(obat: treatment, dosis: '1x1', instruksi: latest['notes']?.toString() ?? ''),
        ];
        resepStatus = ResepStatus.diproses;
      }
      if (diagnosa != null && diagnosa.isNotEmpty) {
        status = PatientStatus.diperiksa;
      }
    }

    if (keluhan.isEmpty) {
      final generalStatus = json['status']?.toString();
      keluhan = generalStatus != null && generalStatus.isNotEmpty
          ? 'Kondisi: $generalStatus'
          : 'Pemeriksaan umum';
    }

    return Patient(
      id: id,
      nama: name,
      nik: nik,
      jk: jk,
      umur: umur,
      alamat: address,
      keluhanUtama: keluhan,
      durasiKeluhan: '-',
      lokasiKeluhan: '-',
      vitals: const Vitals(),
      assignedDokterId: assignedDoctorId,
      waktuMasuk: waktuMasuk,
      updatedAt: updatedAt,
      status: status,
      dbStatus: dbStatus,
      diagnosa: diagnosa,
      resep: resep,
      resepStatus: resepStatus,
    );
  }

  Map<String, dynamic> toCreatePatientJson({String? dob, String? phone, String? bloodType, String? statusStr}) {
    final effectiveNik = nik.trim().isNotEmpty
        ? nik.trim()
        : '3171${DateTime.now().millisecondsSinceEpoch.toString().padRight(12, '0').substring(0, 12)}';

    final birthYear = umur > 0 ? (DateTime.now().year - umur) : 1995;
    final effectiveDob = dob ?? '${birthYear.toString().padLeft(4, '0')}-01-01';

    return {
      'nik': effectiveNik,
      'name': nama.trim(),
      'dob': effectiveDob,
      'gender': jk == Gender.p ? 'Perempuan' : 'Laki-laki',
      'blood_type': bloodType ?? 'O+',
      'address': alamat.trim().isNotEmpty ? alamat.trim() : 'Kalimantan Timur',
      'phone': phone ?? '',
      'status': statusStr ?? dbStatus,
    };
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
        dbStatus,
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
  return patients;
}
