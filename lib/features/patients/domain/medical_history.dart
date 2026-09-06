import 'patient.dart';
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

    if (json['patient'] is Map<String, dynamic>) {
      final pMap = json['patient'] as Map<String, dynamic>;
      parsedPatient = Patient.fromApiJson(pMap);
      patientName = parsedPatient.nama;
      patientNik = parsedPatient.nik;
    }

    if (patientName.isEmpty) {
      patientName = json['patient_name']?.toString() ??
          json['name']?.toString() ??
          'Pasien';
    }
    if (patientNik.isEmpty) {
      patientNik = json['patient_nik']?.toString() ??
          json['nik']?.toString() ??
          '';
    }

    // Doctor info
    String? docName;
    String? docSip;
    if (json['doctor'] is Map<String, dynamic>) {
      final dMap = json['doctor'] as Map<String, dynamic>;
      docName = dMap['name']?.toString();
      docSip = dMap['sip']?.toString();
    }

    // Ship info
    String? sCode;
    String? sName;
    if (json['ship'] is Map<String, dynamic>) {
      final sMap = json['ship'] as Map<String, dynamic>;
      sCode = sMap['code']?.toString();
      sName = sMap['name']?.toString();
    }

    // Port info
    String? pName;
    if (json['port'] is Map<String, dynamic>) {
      final portMap = json['port'] as Map<String, dynamic>;
      pName = portMap['name']?.toString();
    }

    // Poliklinik info
    String? polCode = json['poli_code']?.toString();
    String? polName;
    if (json['poliklinik'] is Map<String, dynamic>) {
      final polMap = json['poliklinik'] as Map<String, dynamic>;
      polCode ??= polMap['code']?.toString();
      polName = polMap['name']?.toString();
    }

    // Vitals from API (keys: systolic, diastolic, blood_pressure, heart_rate, temperature, respiratory_rate, oxygen_saturation)
    Map<String, dynamic> vitalsMap = json;
    if (json['vitals'] is Map<String, dynamic>) {
      vitalsMap = {
        ...json,
        ...json['vitals'] as Map<String, dynamic>,
      };
    }
    final parsedVitals = Vitals.fromJson(vitalsMap);
    final effectiveVitals = !parsedVitals.isEmpty
        ? parsedVitals
        : (parsedPatient?.vitals ?? const Vitals());

    return MedicalHistory(
      id: json['id']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
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
      bloodPressure: effectiveVitals.bloodPressure ??
          (effectiveVitals.tekananDarah.isNotEmpty ? effectiveVitals.tekananDarah : null),
      heartRate: effectiveVitals.heartRate,
      temperature: effectiveVitals.temperature,
      respiratoryRate: effectiveVitals.respiratoryRate,
      oxygenSaturation: effectiveVitals.oxygenSaturation,
      rawJson: json,
    );
  }

  /// Converts or falls back to a [Patient] object for patient detail navigation.
  Patient toPatient() {
    if (patient != null) {
      return patient!.copyWith(
        registerNo: code.isNotEmpty ? code : patient!.registerNo,
        statusPenanganan: statusPenanganan ?? patient!.statusPenanganan,
        poliName: poliName ?? patient!.poliName,
        keluhanUtama: complaint ?? patient!.keluhanUtama,
        diagnosa: diagnosis ?? patient!.diagnosa,
        vitals: !vitals.isEmpty ? vitals : patient!.vitals,
      );
    }
    return Patient(
      id: patientId,
      nama: patientName,
      nik: patientNik,
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
      registerNo: code,
      poliName: poliName,
      statusPenanganan: statusPenanganan,
      diagnosa: diagnosis,
      tindakan: treatment,
    );
  }
}

