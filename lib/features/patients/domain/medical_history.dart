import '../../../core/utils/clean_text_helper.dart';
import '../../../core/utils/diagnosis_helper.dart';
import 'lab_order.dart';
import 'patient.dart';
import 'prescription_item.dart';
import 'vitals.dart';

/// Represents a medical history entry (riwayat kunjungan) from GET /api/v1/medical-history
class MedicalHistory {
  const MedicalHistory({
    required this.id,
    required this.code,
    required this.patientId,
    this.patient,
    required this.patientName,
    this.patientNik = '',
    this.doctorId,
    this.doctorName,
    this.doctorSip,
    this.shipCode,
    this.shipName,
    this.portName,
    this.poliCode,
    this.poliName,
    this.date,
    this.complaint,
    this.diagnosis,
    this.diagnosisDetail,
    this.treatment,
    this.tindakanDetail,
    this.notes,
    this.status,
    this.statusPenanganan,
    this.createdAt,
    this.updatedAt,
    this.vitals = const Vitals(),
    this.systolic,
    this.diastolic,
    this.bloodPressure,
    this.heartRate,
    this.temperature,
    this.respiratoryRate,
    this.oxygenSaturation,
    this.rawJson = const {},
  });

  final String id;
  final String code;
  final String patientId;
  final Patient? patient;
  final String patientName;
  final String patientNik;
  final String? doctorId;
  final String? doctorName;
  final String? doctorSip;
  final String? shipCode;
  final String? shipName;
  final String? portName;
  final String? poliCode;
  final String? poliName;
  final String? date;
  final String? complaint;
  final String? diagnosis;
  final String? diagnosisDetail;
  final String? treatment;
  final String? tindakanDetail;
  final String? notes;
  final String? status;
  final String? statusPenanganan;
  final String? createdAt;
  final String? updatedAt;
  final Vitals vitals;
  final int? systolic;
  final int? diastolic;
  final String? bloodPressure;
  final int? heartRate;
  final double? temperature;
  final int? respiratoryRate;
  final double? oxygenSaturation;
  final Map<String, dynamic> rawJson;

  factory MedicalHistory.fromApiJson(Map<String, dynamic> json) {
    Patient? parsedPatient;
    String patientName = '';
    String patientNik = '';

    if (json['patient'] is Map) {
      final pMap = Map<String, dynamic>.from(json['patient'] as Map);
      parsedPatient = Patient.fromApiJson(pMap);
      patientName = parsedPatient.nama;
      patientNik = parsedPatient.nik;
    }

    if (patientName.isEmpty) {
      patientName = CleanTextHelper.cleanName(
        json['patient_name'] ?? json['name'] ?? json['patient'],
        fallback: 'Pasien',
      );
    }
    patientName = CleanTextHelper.cleanName(patientName, fallback: 'Pasien');

    if (patientNik.isEmpty) {
      patientNik = CleanTextHelper.cleanCode(
        json['patient_nik'] ?? json['nik'],
      );
    }
    patientNik = CleanTextHelper.cleanCode(patientNik);

    final rawCode =
        json['code'] ??
        json['register_no'] ??
        json['registration_code'] ??
        json['visit_code'] ??
        json['no_registrasi'] ??
        parsedPatient?.registerNo;
    final code = CleanTextHelper.cleanCode(rawCode);

    // Doctor info
    final String? docName;
    final String? docSip;
    if (json['doctor'] is Map) {
      final dMap = Map<String, dynamic>.from(json['doctor'] as Map);
      final n = CleanTextHelper.cleanName(dMap['name'] ?? dMap['nama']);
      final s = CleanTextHelper.cleanCode(dMap['sip']);
      docName = n.isNotEmpty ? n : null;
      docSip = s.isNotEmpty ? s : null;
    } else {
      final n = CleanTextHelper.cleanName(json['doctor_name']);
      final s = CleanTextHelper.cleanCode(json['doctor_sip']);
      docName = n.isNotEmpty ? n : null;
      docSip = s.isNotEmpty ? s : null;
    }

    // Ship info
    final String? sCode;
    final String? sName;
    if (json['ship'] is Map) {
      final sMap = Map<String, dynamic>.from(json['ship'] as Map);
      final c = CleanTextHelper.cleanCode(sMap['code'] ?? sMap['kode']);
      final n = CleanTextHelper.cleanName(sMap['name'] ?? sMap['nama']);
      sCode = c.isNotEmpty ? c : null;
      sName = n.isNotEmpty ? n : null;
    } else {
      final c = CleanTextHelper.cleanCode(json['ship_code']);
      final n = CleanTextHelper.cleanName(json['ship_name']);
      sCode = c.isNotEmpty ? c : null;
      sName = n.isNotEmpty ? n : null;
    }

    // Port info
    final String? pName;
    if (json['port'] is Map) {
      final portMap = Map<String, dynamic>.from(json['port'] as Map);
      final n = CleanTextHelper.cleanName(portMap['name'] ?? portMap['nama']);
      pName = n.isNotEmpty ? n : null;
    } else {
      final n = CleanTextHelper.cleanName(json['port_name']);
      pName = n.isNotEmpty ? n : null;
    }

    // Poliklinik info
    final String? polCode;
    final String? polName;
    if (json['poliklinik'] is Map) {
      final polMap = Map<String, dynamic>.from(json['poliklinik'] as Map);
      final c = CleanTextHelper.cleanCode(
        polMap['code'] ?? polMap['kode'] ?? json['poli_code'],
      );
      final n = CleanTextHelper.cleanName(polMap['name'] ?? polMap['nama']);
      polCode = c.isNotEmpty ? c : null;
      polName = n.isNotEmpty ? n : null;
    } else {
      final c = CleanTextHelper.cleanCode(json['poli_code']);
      final n = CleanTextHelper.cleanName(json['poli_name']);
      polCode = c.isNotEmpty ? c : null;
      polName = n.isNotEmpty ? n : null;
    }

    // Vitals from API (keys: systolic, diastolic, blood_pressure, heart_rate, temperature, respiratory_rate, oxygen_saturation)
    Map<String, dynamic> vitalsMap = json;
    if (json['vitals'] is Map) {
      vitalsMap = {
        ...json,
        ...Map<String, dynamic>.from(json['vitals'] as Map),
      };
    }
    final parsedVitals = Vitals.fromJson(vitalsMap);
    final effectiveVitals = !parsedVitals.isEmpty
        ? parsedVitals
        : (parsedPatient?.vitals ?? const Vitals());

    return MedicalHistory(
      id: json['id']?.toString() ?? '',
      code: code,
      patientId: json['patient_id']?.toString() ?? parsedPatient?.id ?? '',
      patient: parsedPatient,
      patientName: patientName,
      patientNik: patientNik,
      doctorId: json['doctor_id']?.toString(),
      doctorName: docName,
      doctorSip: docSip,
      shipCode: sCode,
      shipName: sName,
      portName: pName,
      poliCode: polCode,
      poliName: polName,
      date: json['date']?.toString(),
      complaint: json['complaint']?.toString(),
      diagnosis: json['diagnosis']?.toString(),
      diagnosisDetail: json['diagnosis_detail']?.toString(),
      treatment: json['treatment']?.toString(),
      tindakanDetail: json['tindakan_detail']?.toString(),
      notes: json['notes']?.toString(),
      status: json['status']?.toString(),
      statusPenanganan: json['status_penanganan']?.toString(),
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
      vitals: effectiveVitals,
      systolic: effectiveVitals.systolic,
      diastolic: effectiveVitals.diastolic,
      bloodPressure:
          effectiveVitals.bloodPressure ??
          (effectiveVitals.tekananDarah.isNotEmpty
              ? effectiveVitals.tekananDarah
              : null),
      heartRate: effectiveVitals.heartRate,
      temperature: effectiveVitals.temperature,
      respiratoryRate: effectiveVitals.respiratoryRate,
      oxygenSaturation: effectiveVitals.oxygenSaturation,
      rawJson: json,
    );
  }

  /// Converts or falls back to a [Patient] object for patient detail navigation.
  Patient toPatient() {
    String? effectiveDiagnosa;
    if (rawJson['diagnoses'] is List &&
        (rawJson['diagnoses'] as List).isNotEmpty) {
      final formatted = DiagnosisHelper.formatDiagnoses(rawJson['diagnoses']);
      if (formatted.isNotEmpty && formatted != '—') {
        effectiveDiagnosa = formatted;
      }
    }
    effectiveDiagnosa ??=
        (diagnosisDetail != null &&
            diagnosisDetail!.trim().isNotEmpty &&
            diagnosisDetail != '—' &&
            diagnosisDetail != '-')
        ? diagnosisDetail
        : (diagnosis ?? patient?.diagnosa);
    final effectiveTindakan =
        (tindakanDetail != null &&
            tindakanDetail!.trim().isNotEmpty &&
            tindakanDetail != '—' &&
            tindakanDetail != '-')
        ? tindakanDetail
        : (treatment ?? patient?.tindakan);

    List<ResepItem> effectiveResep = patient?.resep ?? const [];
    if (effectiveResep.isEmpty) {
      final rawRx =
          rawJson['prescription'] ??
          rawJson['prescriptions'] ??
          rawJson['medicines'] ??
          rawJson['resep'];
      if (rawRx is List && rawRx.isNotEmpty) {
        effectiveResep = rawRx
            .whereType<Map>()
            .map((j) => ResepItem.fromJson(Map<String, dynamic>.from(j)))
            .where((r) => r.obat.isNotEmpty)
            .toList();
      } else if (rawRx is String && rawRx.isNotEmpty) {
        effectiveResep = parseResepString(rawRx);
      }
    }

    final cleanPatientName = CleanTextHelper.cleanName(
      patientName,
      fallback: 'Pasien',
    );
    final cleanPatientNik = CleanTextHelper.cleanCode(patientNik);
    final cleanCode = CleanTextHelper.cleanCode(code);

    final effectiveStatusPenanganan =
        statusPenanganan ?? patient?.statusPenanganan;
    final isSelesai =
        effectiveStatusPenanganan == 'Selesai' || status == 'Selesai';
    final effectiveResepStatus = isSelesai
        ? ResepStatus.selesai
        : (effectiveStatusPenanganan == 'Menunggu Obat'
              ? ResepStatus.baru
              : (patient?.resepStatus ??
                    (effectiveResep.isNotEmpty ? ResepStatus.baru : null)));

    LabOrder? effectiveLabOrder = patient?.labOrder;
    if (effectiveLabOrder == null) {
      String labJenis = '';
      String labCatatan = '';
      LabOrderStatus labStatus = LabOrderStatus.baru;

      if (rawJson['lab_order'] is Map<String, dynamic>) {
        final lo = rawJson['lab_order'] as Map<String, dynamic>;
        labJenis = (lo['jenis'] ?? lo['name'] ?? lo['test_name'] ?? '')
            .toString();
        labCatatan = (lo['catatan'] ?? lo['notes'] ?? '').toString();
        final rawStatus = lo['status']?.toString().toLowerCase() ?? '';
        if (rawStatus == 'selesai' || rawStatus == 'done') {
          labStatus = LabOrderStatus.selesai;
        } else if (rawStatus == 'diproses' || rawStatus == 'process') {
          labStatus = LabOrderStatus.diproses;
        }
      } else if (rawJson['order_lab'] is Map<String, dynamic>) {
        final lo = rawJson['order_lab'] as Map<String, dynamic>;
        labJenis = (lo['jenis'] ?? lo['name'] ?? lo['test_name'] ?? '')
            .toString();
        labCatatan = (lo['catatan'] ?? lo['notes'] ?? '').toString();
      }

      final recNotes = (notes ?? '').trim();
      if (labJenis.isEmpty && recNotes.contains('Order Lab:')) {
        final rawText = recNotes
            .substring(recNotes.indexOf('Order Lab:') + 'Order Lab:'.length)
            .trim();
        final openParen = rawText.indexOf('(');
        final closeParen = rawText.lastIndexOf(')');
        if (openParen != -1 && closeParen != -1 && closeParen > openParen) {
          labJenis = rawText.substring(0, openParen).trim();
          labCatatan = rawText.substring(openParen + 1, closeParen).trim();
        } else {
          labJenis = rawText;
        }
      }

      if (labJenis.isEmpty && effectiveStatusPenanganan == 'Menunggu Lab') {
        if (tindakanDetail != null &&
            tindakanDetail!.trim().isNotEmpty &&
            tindakanDetail != '—' &&
            tindakanDetail != '-') {
          labJenis = tindakanDetail!;
        } else if (treatment != null &&
            treatment!.trim().isNotEmpty &&
            treatment != '—' &&
            treatment != '-' &&
            treatment != 'Pemeriksaan awal' &&
            treatment != 'Pemeriksaan Dokter') {
          labJenis = treatment!;
        } else {
          labJenis = 'Pemeriksaan Laboratorium';
        }
        if (labCatatan.isEmpty && notes != null && notes!.isNotEmpty) {
          labCatatan = notes!;
        }
      }

      if (labJenis.isNotEmpty) {
        effectiveLabOrder = LabOrder(
          id: id,
          jenis: labJenis,
          catatan: labCatatan,
          status: isSelesai ? LabOrderStatus.selesai : labStatus,
        );
      }
    }

    if (patient != null) {
      return patient!.copyWith(
        nama: patient!.nama.isNotEmpty
            ? CleanTextHelper.cleanName(
                patient!.nama,
                fallback: cleanPatientName,
              )
            : cleanPatientName,
        nik: patient!.nik.isNotEmpty
            ? CleanTextHelper.cleanCode(patient!.nik, fallback: cleanPatientNik)
            : cleanPatientNik,
        registerNo: cleanCode.isNotEmpty
            ? cleanCode
            : CleanTextHelper.cleanCode(patient!.registerNo),
        statusPenanganan: effectiveStatusPenanganan,
        resepStatus: effectiveResepStatus,
        poliName: poliName ?? patient!.poliName,
        keluhanUtama: complaint ?? patient!.keluhanUtama,
        diagnosa: effectiveDiagnosa,
        tindakan: effectiveTindakan,
        vitals: !vitals.isEmpty ? vitals : patient!.vitals,
        resep: effectiveResep.isNotEmpty ? effectiveResep : patient!.resep,
        medicalRecordId: id,
        labOrder: effectiveLabOrder ?? patient!.labOrder,
      );
    }
    return Patient(
      id: patientId,
      nama: cleanPatientName,
      nik: cleanPatientNik,
      jk: Gender.l,
      umur: 0,
      alamat: '',
      keluhanUtama: complaint ?? '',
      durasiKeluhan: '',
      lokasiKeluhan: '',
      vitals: vitals,
      assignedDokterId: doctorId ?? '',
      waktuMasuk: createdAt ?? '',
      updatedAt: DateTime.tryParse(updatedAt ?? '') ?? DateTime.now(),
      registerNo: cleanCode,
      poliName: poliName,
      statusPenanganan: effectiveStatusPenanganan,
      resepStatus: effectiveResepStatus,
      diagnosa: effectiveDiagnosa,
      tindakan: effectiveTindakan,
      resep: effectiveResep,
      medicalRecordId: id,
      labOrder: effectiveLabOrder,
    );
  }

  /// Creates a [MedicalHistory] from a [Patient] instance so it can be navigated to in Riwayat Kunjungan.
  static MedicalHistory fromPatient(Patient p) {
    return MedicalHistory(
      id: p.medicalRecordId?.isNotEmpty == true ? p.medicalRecordId! : p.id,
      code: p.registerNo.isNotEmpty ? p.registerNo : p.id,
      patientId: p.id,
      patient: p,
      patientName: p.nama,
      patientNik: p.nik,
      doctorId: p.assignedDokterId,
      doctorName: p.doctorName,
      poliCode: p.poliCode,
      poliName: p.poliName,
      date: p.waktuMasuk,
      complaint: p.keluhanUtama,
      diagnosis: p.diagnosa,
      treatment: p.tindakan,
      statusPenanganan: p.statusPenanganan,
      createdAt: p.updatedAt.toIso8601String(),
      vitals: p.vitals,
    );
  }
}

extension PatientToMedicalHistoryExtension on Patient {
  MedicalHistory toMedicalHistory() => MedicalHistory.fromPatient(this);
}

