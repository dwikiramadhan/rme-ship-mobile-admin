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
    this.operation,
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
  final String? operation;
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

  MedicalHistory copyWith({
    String? id,
    String? code,
    String? patientId,
    Patient? patient,
    String? patientName,
    String? patientNik,
    String? doctorId,
    String? doctorName,
    String? doctorSip,
    String? shipCode,
    String? shipName,
    String? portName,
    String? poliCode,
    String? poliName,
    String? date,
    String? complaint,
    String? diagnosis,
    String? diagnosisDetail,
    String? treatment,
    String? tindakanDetail,
    String? operation,
    String? notes,
    String? status,
    String? statusPenanganan,
    String? createdAt,
    String? updatedAt,
    Vitals? vitals,
    int? systolic,
    int? diastolic,
    String? bloodPressure,
    int? heartRate,
    double? temperature,
    int? respiratoryRate,
    double? oxygenSaturation,
    Map<String, dynamic>? rawJson,
  }) {
    return MedicalHistory(
      id: id ?? this.id,
      code: code ?? this.code,
      patientId: patientId ?? this.patientId,
      patient: patient ?? this.patient,
      patientName: patientName ?? this.patientName,
      patientNik: patientNik ?? this.patientNik,
      doctorId: doctorId ?? this.doctorId,
      doctorName: doctorName ?? this.doctorName,
      doctorSip: doctorSip ?? this.doctorSip,
      shipCode: shipCode ?? this.shipCode,
      shipName: shipName ?? this.shipName,
      portName: portName ?? this.portName,
      poliCode: poliCode ?? this.poliCode,
      poliName: poliName ?? this.poliName,
      date: date ?? this.date,
      complaint: complaint ?? this.complaint,
      diagnosis: diagnosis ?? this.diagnosis,
      diagnosisDetail: diagnosisDetail ?? this.diagnosisDetail,
      treatment: treatment ?? this.treatment,
      tindakanDetail: tindakanDetail ?? this.tindakanDetail,
      operation: operation ?? this.operation,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      statusPenanganan: statusPenanganan ?? this.statusPenanganan,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      vitals: vitals ?? this.vitals,
      systolic: systolic ?? this.systolic,
      diastolic: diastolic ?? this.diastolic,
      bloodPressure: bloodPressure ?? this.bloodPressure,
      heartRate: heartRate ?? this.heartRate,
      temperature: temperature ?? this.temperature,
      respiratoryRate: respiratoryRate ?? this.respiratoryRate,
      oxygenSaturation: oxygenSaturation ?? this.oxygenSaturation,
      rawJson: rawJson ?? this.rawJson,
    );
  }

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
      operation: json['operation']?.toString(),
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

    List<ResepItem> effectiveResep = const [];
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
    if (effectiveResep.isEmpty && patient != null) {
      effectiveResep = patient!.resep;
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

    if (effectiveLabOrder != null && isSelesai) {
      effectiveLabOrder = effectiveLabOrder.copyWith(
        status: LabOrderStatus.selesai,
      );
    }

    final rawExamination = rawJson['lab_examination'] ??
        rawJson['lab_examinations'] ??
        rawJson['labExamination'] ??
        rawJson['labExaminations'];
    if (rawExamination != null) {
      final List<LabExaminationItem> items = [];
      String hasilNotes = '';
      String? fileName;
      if (rawExamination is Map) {
        final eMap = Map<String, dynamic>.from(rawExamination);
        hasilNotes = (eMap['notes'] ?? eMap['catatan'] ?? '').toString();
        fileName = (eMap['attachment_url'] ??
                eMap['file_name'] ??
                eMap['file_url'] ??
                eMap['file_path'] ??
                eMap['fileName'] ??
                eMap['filePath'] ??
                eMap['url'])
            ?.toString();
        if (fileName != null && fileName.trim().isEmpty) {
          fileName = null;
        }
        if (eMap['items'] is List) {
          for (final it in eMap['items']) {
            if (it is Map) {
              items.add(
                LabExaminationItem.fromJson(Map<String, dynamic>.from(it)),
              );
            }
          }
        }
      } else if (rawExamination is List) {
        for (final exam in rawExamination) {
          if (exam is Map) {
            final eMap = Map<String, dynamic>.from(exam);
            if ((eMap['notes'] != null || eMap['catatan'] != null) &&
                hasilNotes.isEmpty) {
              hasilNotes = (eMap['notes'] ?? eMap['catatan']).toString();
            }
            if (eMap['attachment_url'] != null ||
                eMap['file_name'] != null ||
                eMap['file_url'] != null ||
                eMap['file_path'] != null) {
              fileName ??= (eMap['attachment_url'] ??
                      eMap['file_name'] ??
                      eMap['file_url'] ??
                      eMap['file_path'])
                  ?.toString();
            }
            if (eMap['items'] is List) {
              for (final it in eMap['items']) {
                if (it is Map) {
                  items.add(
                    LabExaminationItem.fromJson(Map<String, dynamic>.from(it)),
                  );
                }
              }
            }
          }
        }
      }

      final examCode =
          (rawExamination is Map) ? (rawExamination['code']?.toString() ?? '') : '';
      final currentJenis = effectiveLabOrder?.jenis;
      final jenisName = (currentJenis != null &&
              currentJenis.isNotEmpty &&
              currentJenis != 'Pemeriksaan Laboratorium')
          ? currentJenis
          : (examCode.isNotEmpty
              ? 'Pemeriksaan Lab ($examCode)'
              : 'Pemeriksaan Laboratorium');

      effectiveLabOrder = (effectiveLabOrder ??
              LabOrder(
                id: id,
                jenis: jenisName,
                status: LabOrderStatus.selesai,
              ))
          .copyWith(
        status: LabOrderStatus.selesai,
        hasil: LabHasil(
          catatanHasil: hasilNotes,
          fileName: fileName,
          items: items,
        ),
      );
    }

    final rawPhoto = rawJson['patient'] is Map
        ? (rawJson['patient']['photo_url'] ?? rawJson['patient']['photo'])
        : (rawJson['photo_url'] ?? rawJson['photo']);
    final effectivePhotoUrl = rawPhoto?.toString() ?? patient?.photoUrl;

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
        photoUrl: patient!.photoUrl ?? effectivePhotoUrl,
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
        doctorName: doctorName ?? patient!.doctorName,
        assignedDokterId: (doctorId != null && doctorId!.isNotEmpty)
            ? doctorId!
            : patient!.assignedDokterId,
      );
    }
    return Patient(
      id: patientId,
      nama: cleanPatientName,
      nik: cleanPatientNik,
      photoUrl: effectivePhotoUrl,
      jk: Gender.l,
      umur: 0,
      alamat: '',
      keluhanUtama: complaint ?? '',
      durasiKeluhan: '',
      lokasiKeluhan: '',
      vitals: vitals,
      assignedDokterId: doctorId ?? '',
      doctorName: doctorName,
      waktuMasuk: createdAt ?? '',
      createdAt: DateTime.tryParse(createdAt ?? ''),
      updatedAt:
          DateTime.tryParse(updatedAt ?? '') ??
          DateTime.tryParse(createdAt ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
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

  /// Returns the lab_examination object from rawJson
  Map<String, dynamic>? get labExamination {
    final raw = rawJson['lab_examination'] ??
        rawJson['lab_examinations'] ??
        rawJson['labExamination'] ??
        rawJson['labExaminations'];
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    if (raw is List && raw.isNotEmpty) {
      final first = raw.first;
      if (first is Map) {
        return Map<String, dynamic>.from(first);
      }
    }
    return null;
  }

  /// Extracts lab examination items from lab_examination['items']
  List<LabExaminationItem> get labExaminationItems {
    final exam = labExamination;
    if (exam != null && exam['items'] is List) {
      final List<LabExaminationItem> result = [];
      for (final it in exam['items'] as List) {
        if (it is Map) {
          result.add(
            LabExaminationItem.fromJson(Map<String, dynamic>.from(it)),
          );
        }
      }
      return result;
    }
    if (patient?.labOrder?.hasil?.items != null &&
        patient!.labOrder!.hasil!.items.isNotEmpty) {
      return patient!.labOrder!.hasil!.items;
    }
    return const [];
  }

  /// Lab examination code (e.g. LAB06102026-00003)
  String? get labExaminationCode {
    return labExamination?['code']?.toString();
  }

  /// Lab attachment url or filename
  String? get labAttachmentUrl {
    final exam = labExamination;
    final candidateValues = [
      exam?['attachment_url'],
      exam?['file_name'],
      exam?['file_url'],
      exam?['file_path'],
      exam?['fileName'],
      exam?['filePath'],
      exam?['url'],
      exam?['document_url'],
      exam?['hasil_file'],
      rawJson['attachment_url'],
      rawJson['file_name'],
      rawJson['file_url'],
      rawJson['file_path'],
      if (rawJson['lab_order'] is Map) ...[
        (rawJson['lab_order'] as Map)['attachment_url'],
        (rawJson['lab_order'] as Map)['file_name'],
        (rawJson['lab_order'] as Map)['file_url'],
      ],
      if (rawJson['order_lab'] is Map) ...[
        (rawJson['order_lab'] as Map)['attachment_url'],
        (rawJson['order_lab'] as Map)['file_name'],
      ],
      patient?.labOrder?.hasil?.fileName,
    ];
    for (final val in candidateValues) {
      if (val != null) {
        final s = val.toString().trim();
        if (s.isNotEmpty && s != '-' && s != '—') {
          return s;
        }
      }
    }
    return null;
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
      rawJson: {
        if (p.labOrder != null) ...{
          'lab_order': {
            'jenis': p.labOrder!.jenis,
            'catatan': p.labOrder!.catatan,
            'status': p.labOrder!.status.name,
            if (p.labOrder!.hasil?.fileName != null)
              'attachment_url': p.labOrder!.hasil!.fileName,
          },
          if (p.labOrder!.hasil != null)
            'lab_examination': {
              'notes': p.labOrder!.hasil!.catatanHasil,
              if (p.labOrder!.hasil!.fileName != null)
                'attachment_url': p.labOrder!.hasil!.fileName,
              'items': [
                for (final it in p.labOrder!.hasil!.items)
                  it.toJson(),
              ],
            },
        },
      },
    );
  }
}

extension PatientToMedicalHistoryExtension on Patient {
  MedicalHistory toMedicalHistory() => MedicalHistory.fromPatient(this);
}
