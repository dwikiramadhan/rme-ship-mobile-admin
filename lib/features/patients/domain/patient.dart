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
/// -> Apotek / Lab flow.
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
    this.statusPenanganan,
    this.dob,
    this.namaWali,
    this.hubunganWali,
    this.keterangan,
    this.kodeKelurahan,
    this.kodePos,
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
  final String? statusPenanganan;

  final String? dob;
  final String? namaWali;
  final String? hubunganWali;
  final String? keterangan;
  final String? kodeKelurahan;
  final int? kodePos;

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
    String? statusPenanganan,
    String? dob,
    String? namaWali,
    String? hubunganWali,
    String? keterangan,
    String? kodeKelurahan,
    int? kodePos,
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
      statusPenanganan: statusPenanganan ?? this.statusPenanganan,
      dob: dob ?? this.dob,
      namaWali: namaWali ?? this.namaWali,
      hubunganWali: hubunganWali ?? this.hubunganWali,
      keterangan: keterangan ?? this.keterangan,
      kodeKelurahan: kodeKelurahan ?? this.kodeKelurahan,
      kodePos: kodePos ?? this.kodePos,
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

    final String? namaWali = json['nama_wali']?.toString();
    final String? hubunganWali = json['hubungan_wali']?.toString();
    final String? keterangan = json['keterangan']?.toString();
    final String? kodeKelurahan = json['kode_kelurahan']?.toString();
    final int? kodePos = (json['kode_pos'] as num?)?.toInt();

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

    String durasi = '-';
    String lokasi = '-';
    Vitals parsedVitals = const Vitals();

    LabOrder? labOrder;
    if (medRecords is List && medRecords.isNotEmpty) {
      for (final raw in medRecords) {
        if (raw is! Map<String, dynamic>) continue;
        final recComplaint = raw['complaint']?.toString() ?? '';
        final recDiag = raw['diagnosis']?.toString();
        final recTreatment = raw['treatment']?.toString() ?? '';
        final recDocId = raw['doctor_id']?.toString() ?? raw['doctor']?['id']?.toString();
        final recNotes = raw['notes']?.toString() ?? '';

        if (recComplaint.isNotEmpty && recComplaint != 'Pemeriksaan klinis' && recComplaint != 'Pemeriksaan umum') {
          keluhan = recComplaint;
        } else if (keluhan.isEmpty && recComplaint.isNotEmpty) {
          keluhan = recComplaint;
        }

        if (recDocId != null && recDocId.isNotEmpty && assignedDoctorId.isEmpty) {
          assignedDoctorId = recDocId;
        }

        if (recDiag != null && recDiag.isNotEmpty && recDiag != 'Pemeriksaan Umum') {
          diagnosa = recDiag;
          status = PatientStatus.diperiksa;
        }

        if (recNotes.contains('[Triage]') || recNotes.contains('Durasi:') || recNotes.contains('TD:')) {
          final parts = recNotes.split('|');
          String td = '';
          String hr = '';
          String temp = '';
          String rr = '';
          String spo2 = '';
          for (final rawPart in parts) {
            final part = rawPart.replaceFirst('[Triage]', '').trim();
            if (part.startsWith('Durasi:')) {
              durasi = part.substring('Durasi:'.length).trim();
            } else if (part.startsWith('Lokasi:')) {
              lokasi = part.substring('Lokasi:'.length).trim();
            } else if (part.startsWith('TD:')) {
              td = part.substring('TD:'.length).trim();
            } else if (part.startsWith('Nadi:') || part.startsWith('HR:')) {
              hr = part.replaceFirst('Nadi:', '').replaceFirst('HR:', '').trim();
            } else if (part.startsWith('Suhu:') || part.startsWith('Temp:')) {
              temp = part.replaceFirst('Suhu:', '').replaceFirst('Temp:', '').trim();
            } else if (part.startsWith('RR:')) {
              rr = part.substring('RR:'.length).trim();
            } else if (part.startsWith('SpO2:')) {
              spo2 = part.substring('SpO2:'.length).trim();
            }
          }
          parsedVitals = Vitals(
            tekananDarah: td,
            nadi: hr,
            suhu: temp,
            frekuensiNapas: rr,
            spo2: spo2,
          );
        }

        if (recNotes.startsWith('Order Lab:')) {
          final rawText = recNotes.replaceFirst('Order Lab:', '').trim();
          final openParen = rawText.indexOf('(');
          final closeParen = rawText.lastIndexOf(')');
          String jenis = rawText;
          String catatan = '';
          if (openParen != -1 && closeParen != -1 && closeParen > openParen) {
            jenis = rawText.substring(0, openParen).trim();
            catatan = rawText.substring(openParen + 1, closeParen).trim();
          }
          labOrder = LabOrder(
            id: raw['id']?.toString() ?? id,
            jenis: jenis.isNotEmpty ? jenis : 'Pemeriksaan Lab',
            catatan: catatan,
            status: LabOrderStatus.baru,
          );
        }

        if (recTreatment.isNotEmpty &&
            recTreatment != 'Pemeriksaan awal' &&
            recTreatment != 'Menunggu Pemeriksaan Dokter' &&
            recTreatment != 'Pemeriksaan Dokter') {
          resep = [
            ResepItem(obat: recTreatment, dosis: '1x1', instruksi: recNotes.startsWith('Order Lab:') ? '' : recNotes),
          ];
          resepStatus = ResepStatus.baru;
        }
      }
    }

    if (keluhan.isEmpty) {
      keluhan = 'Pemeriksaan umum';
    }

    final String? statusPenanganan = json['status_penanganan']?.toString();

    return Patient(
      id: id,
      nama: name,
      nik: nik,
      jk: jk,
      umur: umur,
      alamat: address,
      keluhanUtama: keluhan,
      durasiKeluhan: durasi,
      lokasiKeluhan: lokasi,
      vitals: parsedVitals,
      assignedDokterId: assignedDoctorId,
      waktuMasuk: waktuMasuk,
      updatedAt: updatedAt,
      status: status,
      dbStatus: dbStatus,
      statusPenanganan: statusPenanganan,
      dob: dobStr,
      namaWali: namaWali,
      hubunganWali: hubunganWali,
      keterangan: keterangan,
      kodeKelurahan: kodeKelurahan,
      kodePos: kodePos,
      diagnosa: diagnosa,
      resep: resep,
      resepStatus: resepStatus,
      labOrder: labOrder,
    );
  }

  Map<String, dynamic> toCreatePatientJson({
    String? dob,
    String? phone,
    String? bloodType,
    String? statusStr,
    String? namaWali,
    String? hubunganWali,
    String? keterangan,
    String? kodeKelurahan,
  }) {
    final effectiveNik = nik.trim().isNotEmpty
        ? nik.trim()
        : '3171${DateTime.now().millisecondsSinceEpoch.toString().padRight(12, '0').substring(0, 12)}';

    final effectiveDob = dob ?? this.dob ?? '1995-01-01';

    return {
      'nik': effectiveNik,
      'name': nama.trim(),
      'dob': effectiveDob,
      'gender': jk == Gender.p ? 'Perempuan' : 'Laki-laki',
      'blood_type': bloodType ?? 'O+',
      'address': alamat.trim().isNotEmpty ? alamat.trim() : 'Kalimantan Timur',
      'phone': phone ?? '',
      'status': statusStr ?? dbStatus,
      if (statusPenanganan != null && statusPenanganan!.isNotEmpty) 'status_penanganan': statusPenanganan,
      if (kodeKelurahan != null && kodeKelurahan.isNotEmpty) 'kode_kelurahan': kodeKelurahan,
      if (namaWali != null && namaWali.isNotEmpty) 'nama_wali': namaWali,
      if (hubunganWali != null && hubunganWali.isNotEmpty) 'hubungan_wali': hubunganWali,
      if (keterangan != null && keterangan.isNotEmpty) 'keterangan': keterangan,
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
        statusPenanganan,
        dob,
        namaWali,
        hubunganWali,
        keterangan,
        kodeKelurahan,
        kodePos,
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

const Object _unset = Object();

List<Patient> sortRecent(List<Patient> patients) {
  return patients;
}
