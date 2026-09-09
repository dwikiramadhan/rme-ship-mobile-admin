import 'package:equatable/equatable.dart';

import '../../../core/utils/clean_text_helper.dart';
import '../../../core/utils/diagnosis_helper.dart';
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
    this.bloodType,
    this.namaWali,
    this.hubunganWali,
    this.keterangan,
    this.kodeKelurahan,
    this.kodePos,
    this.diagnosa,
    this.tindakan,
    this.resep = const [],
    this.resepStatus,
    this.labOrder,
    this.doctorName,
    this.dilihatDokter = false,
    this.dilihatPharmacy = false,
    this.dilihatLab = false,
    this.dilihatDokterLab = false,
    this.registerNo = '',
    this.phone,
    this.poliCode,
    this.poliName,
    this.serviceShipCode,
    this.serviceShipName,
    this.lastVisit,
    this.medicalRecordId,
  });

  final String id;
  final String nama;
  final String nik;
  final Gender jk;
  final int umur;
  final String alamat;

  final String registerNo;
  final String? phone;
  final String? poliCode;
  final String? poliName;
  final String? serviceShipCode;
  final String? serviceShipName;
  final String? lastVisit;
  final String? medicalRecordId;

  final String keluhanUtama;
  final String durasiKeluhan;
  final String lokasiKeluhan;
  final Vitals vitals;

  final String assignedDokterId;
  final String? doctorName;
  final String waktuMasuk;
  final DateTime updatedAt;

  final PatientStatus status;
  final String dbStatus;
  final String? statusPenanganan;

  final String? dob;
  final String? bloodType;
  final String? namaWali;
  final String? hubunganWali;
  final String? keterangan;
  final String? kodeKelurahan;
  final int? kodePos;

  final String? diagnosa;
  final String? tindakan;
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
    String? doctorName,
    String? waktuMasuk,
    DateTime? updatedAt,
    PatientStatus? status,
    String? dbStatus,
    String? statusPenanganan,
    String? dob,
    String? bloodType,
    String? namaWali,
    String? hubunganWali,
    String? keterangan,
    String? kodeKelurahan,
    int? kodePos,
    Object? diagnosa = _unset,
    Object? tindakan = _unset,
    List<ResepItem>? resep,
    Object? resepStatus = _unset,
    Object? labOrder = _unset,
    bool? dilihatDokter,
    bool? dilihatPharmacy,
    bool? dilihatLab,
    bool? dilihatDokterLab,
    String? registerNo,
    String? phone,
    String? poliCode,
    String? poliName,
    String? serviceShipCode,
    String? serviceShipName,
    String? lastVisit,
    Object? medicalRecordId = _unset,
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
      doctorName: doctorName ?? this.doctorName,
      waktuMasuk: waktuMasuk ?? this.waktuMasuk,
      updatedAt: updatedAt ?? this.updatedAt,
      status: status ?? this.status,
      dbStatus: dbStatus ?? this.dbStatus,
      statusPenanganan: statusPenanganan ?? this.statusPenanganan,
      dob: dob ?? this.dob,
      bloodType: bloodType ?? this.bloodType,
      namaWali: namaWali ?? this.namaWali,
      hubunganWali: hubunganWali ?? this.hubunganWali,
      keterangan: keterangan ?? this.keterangan,
      kodeKelurahan: kodeKelurahan ?? this.kodeKelurahan,
      kodePos: kodePos ?? this.kodePos,
      diagnosa: identical(diagnosa, _unset) ? this.diagnosa : diagnosa as String?,
      tindakan: identical(tindakan, _unset) ? this.tindakan : tindakan as String?,
      resep: resep ?? this.resep,
      resepStatus: identical(resepStatus, _unset) ? this.resepStatus : resepStatus as ResepStatus?,
      labOrder: identical(labOrder, _unset) ? this.labOrder : labOrder as LabOrder?,
      dilihatDokter: dilihatDokter ?? this.dilihatDokter,
      dilihatPharmacy: dilihatPharmacy ?? this.dilihatPharmacy,
      dilihatLab: dilihatLab ?? this.dilihatLab,
      dilihatDokterLab: dilihatDokterLab ?? this.dilihatDokterLab,
      registerNo: registerNo ?? this.registerNo,
      phone: phone ?? this.phone,
      poliCode: poliCode ?? this.poliCode,
      poliName: poliName ?? this.poliName,
      serviceShipCode: serviceShipCode ?? this.serviceShipCode,
      serviceShipName: serviceShipName ?? this.serviceShipName,
      lastVisit: lastVisit ?? this.lastVisit,
      medicalRecordId: identical(medicalRecordId, _unset)
          ? this.medicalRecordId
          : medicalRecordId as String?,
    );
  }

  factory Patient.fromApiJson(Map<String, dynamic> json) {
    final String id = json['id']?.toString() ?? '';
    final String name = CleanTextHelper.cleanName(json['name'] ?? json['nama'], fallback: 'Pasien');
    final String nik = CleanTextHelper.cleanCode(json['nik'] ?? json['patient_nik']);
    final String genderStr = json['gender']?.toString().toLowerCase() ?? '';
    final Gender jk = genderStr.contains('perempuan') ? Gender.p : Gender.l;
    final String dobStr = json['dob']?.toString() ?? '';
    final String? bloodType = json['blood_type']?.toString();
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
    String? doctorName = CleanTextHelper.cleanName(
      json['assigned_doctor'] ?? json['doctor'] ?? json['doctor_name'],
    );
    if (doctorName.isEmpty) doctorName = null;
    List<ResepItem> resep = const [];
    ResepStatus? resepStatus;
    PatientStatus status = PatientStatus.menungguDokter;

    String durasi = '-';
    String lokasi = '-';
    Vitals parsedVitals = const Vitals();

    LabOrder? labOrder;
    String? tindakan;
    Map<String, dynamic>? activeRecord;
    if (medRecords is List && medRecords.isNotEmpty) {
      final validRecords = medRecords.whereType<Map<String, dynamic>>().toList();
      // Sort newest to oldest so index 0 is always the latest record
      validRecords.sort((a, b) {
        final dateA = DateTime.tryParse(a['date']?.toString() ?? a['created_at']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
        final dateB = DateTime.tryParse(b['date']?.toString() ?? b['created_at']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
        return dateB.compareTo(dateA);
      });

      // Prioritize active visit (status_penanganan != 'Selesai'), or fallback to the newest record
      activeRecord = validRecords.firstWhere(
        (r) {
          final s = (r['status_penanganan'] ?? r['status'] ?? '').toString().trim().toLowerCase();
          return s.isNotEmpty && s != 'selesai';
        },
        orElse: () => validRecords.first,
      );

      final raw = activeRecord;
      final recComplaint = raw['complaint']?.toString() ?? '';
      final recDiag = raw['diagnosis']?.toString();
      final recTreatment = raw['treatment']?.toString() ?? '';
      final recProcedure = raw['procedure']?.toString() ??
          raw['tindakan']?.toString() ??
          raw['icd9']?.toString();
      final recDocId = raw['doctor_id']?.toString() ?? raw['doctor']?['id']?.toString();
      final recDocName = raw['doctor']?['name']?.toString() ?? raw['doctor_name']?.toString();
      final recNotes = raw['notes']?.toString() ?? '';

      if (recProcedure != null && recProcedure.isNotEmpty) {
        tindakan = recProcedure;
      } else if (recTreatment.isNotEmpty &&
          recTreatment != '—' &&
          recTreatment != '-') {
        tindakan = recTreatment;
      }

      if (recComplaint.contains('•')) {
        final parts = recComplaint.split('•');
        keluhan = parts[0].trim();
        for (final p in parts.skip(1)) {
          final trimmed = p.trim();
          if (trimmed.startsWith('Durasi:')) {
            durasi = trimmed.substring('Durasi:'.length).trim();
          } else if (trimmed.startsWith('Lokasi:')) {
            lokasi = trimmed.substring('Lokasi:'.length).trim();
          }
        }
      } else if (recComplaint.isNotEmpty && recComplaint != 'Pemeriksaan klinis' && recComplaint != 'Pemeriksaan umum') {
        keluhan = recComplaint;
      } else if (keluhan.isEmpty && recComplaint.isNotEmpty) {
        keluhan = recComplaint;
      }

      if (recDocId != null && recDocId.isNotEmpty && assignedDoctorId.isEmpty) {
        assignedDoctorId = recDocId;
      }

      if (recDocName != null && recDocName.isNotEmpty && (doctorName == null || doctorName.isEmpty)) {
        doctorName = recDocName;
      }

      final formattedDiag = formatDiagnoses(
        raw['diagnoses'],
        fallback: recDiag,
      );
      if (formattedDiag != '—' &&
          formattedDiag.isNotEmpty &&
          formattedDiag != 'Pemeriksaan Umum') {
        diagnosa = formattedDiag;
        status = PatientStatus.diperiksa;
      }

      // 1. Read structured vitals from medical record columns
      final vs = raw['vital_signs'] is Map ? raw['vital_signs'] as Map : null;
      final rawBp = raw['blood_pressure']?.toString() ?? vs?['blood_pressure']?.toString() ?? '';
      final rawHr = raw['heart_rate']?.toString() ?? vs?['heart_rate']?.toString() ?? '';
      final rawTemp = raw['temperature']?.toString() ?? vs?['temperature']?.toString() ?? '';
      final rawRr = raw['respiratory_rate']?.toString() ?? vs?['respiratory_rate']?.toString() ?? '';
      final rawSpo2 = raw['oxygen_saturation']?.toString() ?? vs?['oxygen_saturation']?.toString() ?? '';

      if (rawBp.isNotEmpty || rawHr.isNotEmpty || rawTemp.isNotEmpty || rawRr.isNotEmpty || rawSpo2.isNotEmpty) {
        parsedVitals = Vitals(
          tekananDarah: rawBp,
          nadi: rawHr,
          suhu: rawTemp,
          frekuensiNapas: rawRr,
          spo2: rawSpo2,
        );
      }

      // 2. Fallback / supplementary parse from triage notes
      if (recNotes.contains('[Triage]') || recNotes.contains('Durasi:') || recNotes.contains('TD:')) {
        final parts = recNotes.split('|');
        String td = '';
        String hr = '';
        String temp = '';
        String rr = '';
        String spo2 = '';
        for (final rawPart in parts) {
          final part = rawPart.replaceFirst('[Triage]', '').trim();
          if (part.startsWith('Durasi:') && durasi == '-') {
            durasi = part.substring('Durasi:'.length).trim();
          } else if (part.startsWith('Lokasi:') && lokasi == '-') {
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
        if (parsedVitals.isEmpty) {
          parsedVitals = Vitals(
            tekananDarah: td,
            nadi: hr,
            suhu: temp,
            frekuensiNapas: rr,
            spo2: spo2,
          );
        }
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

      final rawPrescription = raw['prescription'] ??
          raw['prescriptions'] ??
          raw['medicines'] ??
          raw['resep'];
      if (rawPrescription is List && rawPrescription.isNotEmpty) {
        resep = rawPrescription
            .whereType<Map<String, dynamic>>()
            .map((j) => ResepItem.fromJson(j))
            .where((r) => r.obat.isNotEmpty)
            .toList();
        if (resep.isNotEmpty) resepStatus = ResepStatus.baru;
      } else if (rawPrescription is String && rawPrescription.isNotEmpty) {
        final parsed = parseResepString(rawPrescription);
        if (parsed.isNotEmpty) {
          resep = parsed;
          resepStatus = ResepStatus.baru;
        }
      } else if (recTreatment.isNotEmpty &&
          !RegExp(r'^[\d.,\s-]+$').hasMatch(recTreatment) &&
          recTreatment != 'Pemeriksaan awal' &&
          recTreatment != 'Menunggu Pemeriksaan Dokter' &&
          recTreatment != 'Pemeriksaan Dokter') {
        final parsed = parseResepString(recTreatment);
        if (parsed.isNotEmpty) {
          resep = parsed;
          resepStatus = ResepStatus.baru;
        }
      }
    }

    final topPrescription = json['prescription'] ??
        json['prescriptions'] ??
        json['medicines'] ??
        json['resep'];
    if (resep.isEmpty && topPrescription is List && topPrescription.isNotEmpty) {
      resep = topPrescription
          .whereType<Map<String, dynamic>>()
          .map((j) => ResepItem.fromJson(j))
          .where((r) => r.obat.isNotEmpty)
          .toList();
      if (resep.isNotEmpty) resepStatus = ResepStatus.baru;
    }

    if (keluhan.isEmpty) {
      keluhan = 'Pemeriksaan umum';
    }

    final String? statusPenanganan = json['status_penanganan']?.toString();
    final String registerNo = CleanTextHelper.cleanCode(
      json['register_no'] ?? json['code'] ?? json['registration_code'] ?? json['no_registrasi'],
    );
    final String? phone = json['phone']?.toString();
    final rawPoliCode = CleanTextHelper.cleanCode(json['poli_code']);
    final String? poliCode = rawPoliCode.isNotEmpty ? rawPoliCode : null;
    final rawPoliName = json['poliklinik'] is Map
        ? CleanTextHelper.cleanName(json['poliklinik']['name'] ?? json['poliklinik']['nama'])
        : CleanTextHelper.cleanName(json['poliklinik'] ?? poliCode);
    final String? poliName = rawPoliName.isNotEmpty ? rawPoliName : null;
    final rawServiceShipCode = CleanTextHelper.cleanCode(json['service_ship_code']);
    final String? serviceShipCode = rawServiceShipCode.isNotEmpty ? rawServiceShipCode : null;
    final rawServiceShipName = json['service_ship'] is Map
        ? CleanTextHelper.cleanName(json['service_ship']['name'] ?? json['service_ship']['nama'])
        : CleanTextHelper.cleanName(json['service_ship'] ?? serviceShipCode);
    final String? serviceShipName = rawServiceShipName.isNotEmpty ? rawServiceShipName : null;
    final String? lastVisit = json['last_visit']?.toString();
    final String? medicalRecordId = (json['medical_record_id'] ??
            json['medicalRecordId'] ??
            json['med_rec_id'] ??
            (json['medical_record'] is Map ? json['medical_record']['id'] : null) ??
            activeRecord?['id'] ??
            (json['medical_records'] is List && (json['medical_records'] as List).isNotEmpty
                ? (json['medical_records'] as List).first['id']
                : null))
        ?.toString();

    if (statusPenanganan == 'Selesai') {
      resepStatus = ResepStatus.selesai;
    }

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
      bloodType: bloodType,
      namaWali: namaWali,
      hubunganWali: hubunganWali,
      keterangan: keterangan,
      kodeKelurahan: kodeKelurahan,
      kodePos: kodePos,
      diagnosa: diagnosa,
      tindakan: tindakan,
      resep: resep,
      resepStatus: resepStatus,
      labOrder: labOrder,
      doctorName: doctorName,
      registerNo: registerNo,
      phone: phone,
      poliCode: poliCode,
      poliName: poliName,
      serviceShipCode: serviceShipCode,
      serviceShipName: serviceShipName,
      lastVisit: lastVisit,
      medicalRecordId: medicalRecordId,
    );
  }

  static String? normalizeBloodType(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim().toUpperCase();
    if (trimmed.isEmpty || trimmed == '-' || trimmed == 'TIDAK TAHU') return null;
    const valid = {'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'};
    if (valid.contains(trimmed)) return trimmed;
    if (trimmed == 'A') return 'A+';
    if (trimmed == 'B') return 'B+';
    if (trimmed == 'AB') return 'AB+';
    if (trimmed == 'O') return 'O+';
    return null;
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

    final normalizedBlood = normalizeBloodType(bloodType ?? this.bloodType);
    final normalizedStatus = (statusStr == 'Active' || statusStr == 'Deleted')
        ? statusStr
        : ((dbStatus == 'Active' || dbStatus == 'Deleted') ? dbStatus : 'Active');

    return {
      'nik': effectiveNik,
      'name': nama,
      'gender': jk == Gender.l ? 'Laki-laki' : 'Perempuan',
      'dob': (dob != null && dob.isNotEmpty) ? dob : (this.dob ?? '1990-01-01'),
      'address': alamat,
      'phone': phone ?? this.phone ?? '08123456789',
      if (normalizedBlood != null) 'blood_type': normalizedBlood,
      'status': normalizedStatus ?? 'Active',
      if (namaWali != null && namaWali.isNotEmpty) 'nama_wali': namaWali,
      if (hubunganWali != null && hubunganWali.isNotEmpty) 'hubungan_wali': hubunganWali,
      if (keterangan != null && keterangan.isNotEmpty) 'keterangan': keterangan,
      if (kodeKelurahan != null && kodeKelurahan.isNotEmpty) 'kode_kelurahan': kodeKelurahan,
      if (kodePos != null) 'kode_pos': kodePos,
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
        doctorName,
        waktuMasuk,
        updatedAt,
        status,
        dbStatus,
        statusPenanganan,
        dob,
        bloodType,
        namaWali,
        hubunganWali,
        keterangan,
        kodeKelurahan,
        kodePos,
        diagnosa,
        tindakan,
        resep,
        resepStatus,
        labOrder,
        dilihatDokter,
        dilihatPharmacy,
        dilihatLab,
        dilihatDokterLab,
        registerNo,
        phone,
        poliCode,
        poliName,
        serviceShipCode,
        serviceShipName,
        lastVisit,
        medicalRecordId,
      ];
}

const Object _unset = Object();

List<Patient> sortRecent(List<Patient> patients) {
  return patients;
}
