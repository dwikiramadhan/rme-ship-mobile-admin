import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/websocket_service.dart';
import '../domain/doctor.dart';
import '../domain/lab_order.dart';
import '../domain/medical_history.dart';
import '../domain/patient.dart';
import '../domain/prescription_item.dart';
import '../domain/vitals.dart';
import '../../auth/presentation/auth_controller.dart';
import 'patient_api.dart';
import 'seen_notification_storage.dart';

/// Patient state management wired directly to [PatientApi] and real-time [WebSocketService]
/// for instant sub-second event pushes (Perawat -> Dokter, Dokter -> Farmasi/Lab).
class PatientsNotifier extends StateNotifier<List<Patient>> {
  PatientsNotifier({
    PatientApi? api,
    SeenNotificationStorage? seenStorage,
    WebSocketService? wsService,
    bool autoFetch = true,
  })  : _api = api ?? PatientApi(),
        _seenStorage = seenStorage ?? SeenNotificationStorage(),
        _wsService = wsService ?? WebSocketService(),
        super(const []) {
    if (autoFetch) {
      Future.microtask(() => fetchPatients());
      _initWebSocket();
    }
  }

  final PatientApi _api;
  final SeenNotificationStorage _seenStorage;
  final WebSocketService _wsService;
  StreamSubscription? _wsSubscription;

  bool _isLoading = false;
  bool _isLoadingMore = false;
  int _currentPage = 1;
  int _totalPages = 1;
  int _total = 0;
  final int _limit = 10;
  bool _hasMore = true;

  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  int get total => _total;
  int get currentPage => _currentPage;

  void _initWebSocket() {
    _wsService.connect();
    _wsSubscription?.cancel();
    _wsSubscription = _wsService.onEvent.listen((event) {
      final type = event['type'] ?? event['event'];
      if (type == 'ping' || type == 'pong') return;
      debugPrint('⚡ [PatientsNotifier] Real-time WS push received: $type');
      final patientId = event['patient_id']?.toString();
      final statusPenanganan = event['status_penanganan']?.toString();
      if (patientId != null && statusPenanganan != null) {
        _update(patientId, (p) => p.copyWith(
          statusPenanganan: statusPenanganan,
          resepStatus: statusPenanganan == 'Menunggu Obat' ? (p.resepStatus ?? ResepStatus.baru) : p.resepStatus,
        ));
      }
      _silentPoll();
    });
  }

  Future<void> _silentPoll() async {
    try {
      await _seenStorage.load();
      final paginated = await _api.getPatientsPaginated(
        page: 1,
        limit: _limit,
      );

      final existingMap = {for (final p in state) p.id: p};
      final updatedList = paginated.data.map((p) {
        final existing = existingMap[p.id];
        if (existing != null) {
          return p.copyWith(
            status: p.status != PatientStatus.menungguDokter ? p.status : existing.status,
            dbStatus: p.dbStatus,
            diagnosa: p.diagnosa ?? existing.diagnosa,
            tindakan: p.tindakan ?? existing.tindakan,
            resep: p.resep.isNotEmpty ? p.resep : existing.resep,
            resepStatus: p.resepStatus ?? existing.resepStatus,
            labOrder: p.labOrder ?? existing.labOrder,
            vitals: existing.vitals,
            dilihatDokter: existing.dilihatDokter || _seenStorage.isDoctorSeen(p.id),
            dilihatPharmacy: existing.dilihatPharmacy || _seenStorage.isPharmacySeen(p.id),
            dilihatLab: existing.dilihatLab || _seenStorage.isLabSeen(p.id),
            dilihatDokterLab: existing.dilihatDokterLab || _seenStorage.isDoctorLabSeen(p.id),
          );
        }
        return p.copyWith(
          dilihatDokter: _seenStorage.isDoctorSeen(p.id),
          dilihatPharmacy: _seenStorage.isPharmacySeen(p.id),
          dilihatLab: _seenStorage.isLabSeen(p.id),
          dilihatDokterLab: _seenStorage.isDoctorLabSeen(p.id),
        );
      }).toList();

      if (!listEquals(state, updatedList)) {
        state = updatedList;
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    _wsService.dispose();
    super.dispose();
  }

  /// Fetches patients from GET /api/v1/patients.
  /// If [refresh] is true, resets pagination and fetches page 1.
  Future<void> fetchPatients({bool refresh = true, String? search, String? status}) async {
    if (refresh) {
      _isLoading = true;
      _currentPage = 1;
    } else {
      if (_isLoadingMore || !_hasMore) return;
      _isLoadingMore = true;
    }

    try {
      await _seenStorage.load();

      if (!refresh) {
        await Future<void>.delayed(const Duration(milliseconds: 350));
      }

      final targetPage = refresh ? 1 : _currentPage + 1;
      final paginated = await _api.getPatientsPaginated(
        page: targetPage,
        limit: _limit,
        search: search,
        status: status,
      );

      _currentPage = paginated.page;
      _totalPages = paginated.totalPages;
      _total = paginated.total;
      _hasMore = _currentPage < _totalPages;
      if (refresh) {
        final existingMap = {for (final p in state) p.id: p};
        state = paginated.data.map((p) {
          final existing = existingMap[p.id];
          if (existing != null) {
            return p.copyWith(
              keluhanUtama: (p.keluhanUtama.isNotEmpty && p.keluhanUtama != 'Pemeriksaan umum')
                  ? p.keluhanUtama
                  : existing.keluhanUtama,
              durasiKeluhan: (p.durasiKeluhan.isNotEmpty && p.durasiKeluhan != '-')
                  ? p.durasiKeluhan
                  : existing.durasiKeluhan,
              lokasiKeluhan: (p.lokasiKeluhan.isNotEmpty && p.lokasiKeluhan != '-')
                  ? p.lokasiKeluhan
                  : existing.lokasiKeluhan,
              status: p.status != PatientStatus.menungguDokter ? p.status : existing.status,
              dbStatus: p.dbStatus,
              statusPenanganan: (p.statusPenanganan != null && p.statusPenanganan!.isNotEmpty)
                  ? p.statusPenanganan
                  : existing.statusPenanganan,
              diagnosa: p.diagnosa ?? existing.diagnosa,
              tindakan: p.tindakan ?? existing.tindakan,
              resep: p.resep.isNotEmpty ? p.resep : existing.resep,
              resepStatus: p.resepStatus ?? existing.resepStatus,
              labOrder: p.labOrder ?? existing.labOrder,
              vitals: p.vitals.tekananDarah.isNotEmpty ? p.vitals : existing.vitals,
              dilihatDokter: existing.dilihatDokter || _seenStorage.isDoctorSeen(p.id),
              dilihatPharmacy: existing.dilihatPharmacy || _seenStorage.isPharmacySeen(p.id),
              dilihatLab: existing.dilihatLab || _seenStorage.isLabSeen(p.id),
              dilihatDokterLab: existing.dilihatDokterLab || _seenStorage.isDoctorLabSeen(p.id),
            );
          }
          return p.copyWith(
            dilihatDokter: _seenStorage.isDoctorSeen(p.id),
            dilihatPharmacy: _seenStorage.isPharmacySeen(p.id),
            dilihatLab: _seenStorage.isLabSeen(p.id),
            dilihatDokterLab: _seenStorage.isDoctorLabSeen(p.id),
          );
        }).toList();
      } else {
        // Prevent duplicate IDs when appending
        final existingIds = state.map((p) => p.id).toSet();
        final newItems = paginated.data.where((p) => !existingIds.contains(p.id)).map((p) {
          return p.copyWith(
            dilihatDokter: _seenStorage.isDoctorSeen(p.id),
            dilihatPharmacy: _seenStorage.isPharmacySeen(p.id),
            dilihatLab: _seenStorage.isLabSeen(p.id),
            dilihatDokterLab: _seenStorage.isDoctorLabSeen(p.id),
          );
        }).toList();
        state = [...state, ...newItems];
      }
    } catch (e) {
      debugPrint('fetchPatients error: $e');
    } finally {
      _isLoading = false;
      _isLoadingMore = false;
    }
  }

  /// Fetches medical records on-demand when a patient detail is viewed/clicked
  Future<void> fetchPatientDetail(String id) async {
    try {
      try {
        final detailedPatient = await _api.getPatient(id);
        _update(id, (p) => p.copyWith(
          diagnosa: detailedPatient.diagnosa ?? p.diagnosa,
          tindakan: detailedPatient.tindakan ?? p.tindakan,
          status: detailedPatient.diagnosa != null ? PatientStatus.diperiksa : p.status,
          resep: detailedPatient.resep.isNotEmpty ? detailedPatient.resep : p.resep,
          resepStatus: detailedPatient.resepStatus ?? p.resepStatus,
          labOrder: detailedPatient.labOrder ?? p.labOrder,
          keluhanUtama: detailedPatient.keluhanUtama.isNotEmpty ? detailedPatient.keluhanUtama : p.keluhanUtama,
          durasiKeluhan: detailedPatient.durasiKeluhan != '-' ? detailedPatient.durasiKeluhan : p.durasiKeluhan,
          lokasiKeluhan: detailedPatient.lokasiKeluhan != '-' ? detailedPatient.lokasiKeluhan : p.lokasiKeluhan,
          vitals: detailedPatient.vitals.tekananDarah.isNotEmpty ? detailedPatient.vitals : p.vitals,
          assignedDokterId: detailedPatient.assignedDokterId.isNotEmpty ? detailedPatient.assignedDokterId : p.assignedDokterId,
          doctorName: detailedPatient.doctorName ?? p.doctorName,
          bloodType: detailedPatient.bloodType ?? p.bloodType,
        ));
      } catch (_) {}

      final medRecords = await _api.getMedicalRecords(id);
      if (medRecords.isNotEmpty) {
        String? diag;
        String? tindakan;
        String? complaint;
        String? docId;
        String? docName;
        String? durasi;
        String? lokasi;
        Vitals? parsedVitals;
        List<ResepItem> resepItems = const [];

        for (final raw in medRecords) {
          final recDiag = raw['diagnosis']?.toString();
          final recTreatment = raw['treatment']?.toString() ?? '';
          final recProcedure = raw['procedure']?.toString() ??
              raw['tindakan']?.toString() ??
              raw['icd9']?.toString();
          final recComplaint = raw['complaint']?.toString();
          final recDocId = raw['doctor_id']?.toString() ?? raw['doctor']?['id']?.toString();
          final recDocName = raw['doctor']?['name']?.toString() ?? raw['doctor_name']?.toString();
          final notes = raw['notes']?.toString() ?? '';

          if (recProcedure != null && recProcedure.isNotEmpty) {
            tindakan = recProcedure;
          } else if (recTreatment.isNotEmpty &&
              recTreatment != '—' &&
              recTreatment != '-' &&
              recTreatment != 'Menunggu Pemeriksaan Dokter' &&
              recTreatment != 'Pemeriksaan awal' &&
              recTreatment != 'Pemeriksaan Dokter') {
            tindakan = recTreatment;
          }

          if (recComplaint != null && recComplaint.isNotEmpty && recComplaint != 'Pemeriksaan klinis' && recComplaint != 'Pemeriksaan umum') {
            complaint = recComplaint;
          } else if (complaint == null && recComplaint != null && recComplaint.isNotEmpty) {
            complaint = recComplaint;
          }

          if (recDocId != null && recDocId.isNotEmpty) {
            docId = recDocId;
          }
          if (recDocName != null && recDocName.isNotEmpty) {
            docName = recDocName;
          }

          if (recDiag != null && recDiag.isNotEmpty && recDiag != 'Pemeriksaan Umum') {
            diag = recDiag;
          }

          if (notes.contains('[Triage]') || notes.contains('Durasi:') || notes.contains('TD:')) {
            final parts = notes.split('|');
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

          final rawPrescription = raw['prescription'] ??
              raw['prescriptions'] ??
              raw['medicines'] ??
              raw['resep'];
          if (rawPrescription is List && rawPrescription.isNotEmpty) {
            resepItems = rawPrescription
                .whereType<Map<String, dynamic>>()
                .map((j) => ResepItem.fromJson(j))
                .where((r) => r.obat.isNotEmpty)
                .toList();
          } else if (rawPrescription is String && rawPrescription.isNotEmpty) {
            final parsed = parseResepString(rawPrescription);
            if (parsed.isNotEmpty) resepItems = parsed;
          } else if (recTreatment.isNotEmpty &&
              recTreatment != tindakan &&
              !RegExp(r'^[\d.,\s-]+$').hasMatch(recTreatment) &&
              recTreatment != 'Pemeriksaan awal' &&
              recTreatment != 'Menunggu Pemeriksaan Dokter' &&
              recTreatment != 'Pemeriksaan Dokter') {
            final parsed = parseResepString(recTreatment);
            if (parsed.isNotEmpty) resepItems = parsed;
          }
        }

        final isExamined = diag != null && diag.isNotEmpty && diag != 'Pemeriksaan Umum';

        _update(id, (p) => p.copyWith(
          diagnosa: isExamined ? diag : p.diagnosa,
          tindakan: (tindakan != null && tindakan.isNotEmpty) ? tindakan : p.tindakan,
          status: isExamined ? PatientStatus.diperiksa : p.status,
          resep: resepItems.isNotEmpty ? resepItems : p.resep,
          resepStatus: resepItems.isNotEmpty ? (p.resepStatus ?? ResepStatus.baru) : p.resepStatus,
          keluhanUtama: (complaint != null && complaint.isNotEmpty && !complaint.startsWith('Kondisi:')) ? complaint : p.keluhanUtama,
          durasiKeluhan: durasi ?? p.durasiKeluhan,
          lokasiKeluhan: lokasi ?? p.lokasiKeluhan,
          vitals: parsedVitals ?? p.vitals,
          assignedDokterId: (docId != null && docId.isNotEmpty) ? docId : p.assignedDokterId,
          doctorName: (docName != null && docName.isNotEmpty) ? docName : p.doctorName,
        ));
      }
    } catch (e) {
      debugPrint('fetchPatientDetail error: $e');
    }
  }

  String? _currentSearch;
  String? get currentSearch => _currentSearch;

  /// Searches patients by name/NIK via backend API
  Future<void> searchPatients(String query) async {
    _currentSearch = query.trim().isNotEmpty ? query.trim() : null;
    await fetchPatients(refresh: true, search: _currentSearch);
  }

  /// Triggers loading next page on scroll
  Future<void> loadMore({String? search, String? status}) async {
    if (!_hasMore || _isLoading || _isLoadingMore) return;
    await fetchPatients(refresh: false, search: search ?? _currentSearch, status: status);
  }

  void _update(String id, Patient Function(Patient) updater) {
    state = [
      for (final p in state)
        if (p.id == id) updater(p) else p,
    ];
  }

  Future<Patient> addPatient(Patient patient) async {
    final created = await _api.createPatient(patient.toCreatePatientJson(
      dob: patient.dob,
      bloodType: patient.bloodType,
      kodeKelurahan: patient.kodeKelurahan,
      namaWali: patient.namaWali,
      hubunganWali: patient.hubunganWali,
      keterangan: patient.keterangan,
    ));

    // Attach local clinical intake fields (keluhan, vitals, assigned doctor)
    final fullPatient = created.copyWith(
      keluhanUtama: patient.keluhanUtama.isNotEmpty ? patient.keluhanUtama : created.keluhanUtama,
      durasiKeluhan: patient.durasiKeluhan,
      lokasiKeluhan: patient.lokasiKeluhan,
      vitals: patient.vitals,
      assignedDokterId: patient.assignedDokterId,
      dob: patient.dob ?? created.dob,
      bloodType: patient.bloodType ?? created.bloodType,
      namaWali: patient.namaWali ?? created.namaWali,
      hubunganWali: patient.hubunganWali ?? created.hubunganWali,
      keterangan: patient.keterangan ?? created.keterangan,
      kodeKelurahan: patient.kodeKelurahan ?? created.kodeKelurahan,
      kodePos: patient.kodePos ?? created.kodePos,
    );

    if (patient.assignedDokterId.isNotEmpty) {
      try {
        final triageNotes = StringBuffer('[Triage]');
        if (patient.durasiKeluhan.isNotEmpty && patient.durasiKeluhan != '-') {
          triageNotes.write(' Durasi: ${patient.durasiKeluhan} |');
        }
        if (patient.lokasiKeluhan.isNotEmpty && patient.lokasiKeluhan != '-') {
          triageNotes.write(' Lokasi: ${patient.lokasiKeluhan} |');
        }
        if (patient.vitals.tekananDarah.isNotEmpty) {
          triageNotes.write(' TD: ${patient.vitals.tekananDarah} |');
        }
        if (patient.vitals.nadi.isNotEmpty) {
          triageNotes.write(' Nadi: ${patient.vitals.nadi} |');
        }
        if (patient.vitals.suhu.isNotEmpty) {
          triageNotes.write(' Suhu: ${patient.vitals.suhu} |');
        }
        if (patient.vitals.frekuensiNapas.isNotEmpty) {
          triageNotes.write(' RR: ${patient.vitals.frekuensiNapas} |');
        }
        if (patient.vitals.spo2.isNotEmpty) {
          triageNotes.write(' SpO2: ${patient.vitals.spo2} |');
        }
        var finalNotes = triageNotes.toString();
        if (finalNotes.endsWith('|')) {
          finalNotes = finalNotes.substring(0, finalNotes.length - 1).trim();
        }
        if (finalNotes == '[Triage]') {
          finalNotes = 'Triage Awal Perawat';
        }

        await _api.addMedicalRecord(created.id, {
          'doctor_id': patient.assignedDokterId,
          'ship_id': '3a7ff982-e187-49f8-a34e-95f775afda61',
          'port_id': 'f7d71b54-4c2c-4b10-a601-b82a604c7315',
          'complaint': patient.keluhanUtama.isNotEmpty ? patient.keluhanUtama : 'Pemeriksaan awal',
          'diagnosis': 'Pemeriksaan Umum',
          'treatment': 'Menunggu Pemeriksaan Dokter',
          'notes': finalNotes,
          'date': DateTime.now().toIso8601String().split('T').first,
        });
      } catch (e) {
        debugPrint('addPatient medical record error: $e');
      }
    }

    _wsService.send({
      'type': 'patient_assigned',
      'patient_id': created.id,
      'doctor_id': patient.assignedDokterId,
      'nama': fullPatient.nama,
    });

    state = [fullPatient, ...state.where((p) => p.id != patient.id && p.id != created.id)];
    return fullPatient;
  }

  /// Adds a new clinical visit (medical record) to an existing patient
  /// via POST /api/v1/patients/:id/medical-records and updates patient vitals / status
  Future<void> addKunjungan({
    required String patientId,
    required Map<String, dynamic> recordData,
    Map<String, dynamic>? patientUpdates,
  }) async {
    // 1. Post to /api/v1/patients/:id/medical-records
    await _api.addMedicalRecord(patientId, recordData);

    // 2. Update patient vitals & status_penanganan if provided
    if (patientUpdates != null && patientUpdates.isNotEmpty) {
      try {
        await _api.updatePatient(patientId, patientUpdates);
      } catch (e) {
        debugPrint('updatePatient error in addKunjungan: $e');
      }
    }

    // 3. Notify WS
    _wsService.send({
      'type': 'patient_assigned',
      'patient_id': patientId,
      'doctor_id': recordData['doctor_id'],
      'status_penanganan': 'Menunggu Dokter',
    });

    // 4. Update local state
    _update(patientId, (p) {
      Vitals? newVitals;
      final vitalsMap = patientUpdates?['vitals'];
      if (vitalsMap is Map) {
        newVitals = Vitals(
          tekananDarah: vitalsMap['tekanan_darah']?.toString() ?? p.vitals.tekananDarah,
          nadi: vitalsMap['nadi']?.toString() ?? p.vitals.nadi,
          suhu: vitalsMap['suhu']?.toString() ?? p.vitals.suhu,
          frekuensiNapas: vitalsMap['frekuensi_napas']?.toString() ?? p.vitals.frekuensiNapas,
          spo2: vitalsMap['spo2']?.toString() ?? p.vitals.spo2,
        );
      }
      return p.copyWith(
        status: PatientStatus.menungguDokter,
        statusPenanganan: 'Menunggu Dokter',
        assignedDokterId: recordData['doctor_id']?.toString() ?? p.assignedDokterId,
        keluhanUtama: recordData['complaint']?.toString() ?? p.keluhanUtama,
        durasiKeluhan: patientUpdates?['durasi_keluhan']?.toString() ?? p.durasiKeluhan,
        lokasiKeluhan: patientUpdates?['lokasi_keluhan']?.toString() ?? p.lokasiKeluhan,
        vitals: newVitals ?? p.vitals,
      );
    });
  }

  Future<Patient> updatePatient(Patient patient) async {
    final updated = await _api.updatePatient(patient.id, patient.toCreatePatientJson(
      dob: patient.dob,
      bloodType: patient.bloodType,
      kodeKelurahan: patient.kodeKelurahan,
      namaWali: patient.namaWali,
      hubunganWali: patient.hubunganWali,
      keterangan: patient.keterangan,
    ));
    final fullPatient = patient.copyWith(
      nama: updated.nama,
      nik: updated.nik,
      jk: updated.jk,
      umur: updated.umur,
      alamat: updated.alamat,
      dob: updated.dob ?? patient.dob,
      bloodType: updated.bloodType ?? patient.bloodType,
      namaWali: updated.namaWali ?? patient.namaWali,
      hubunganWali: updated.hubunganWali ?? patient.hubunganWali,
      keterangan: updated.keterangan ?? patient.keterangan,
      kodeKelurahan: updated.kodeKelurahan ?? patient.kodeKelurahan,
      kodePos: updated.kodePos ?? patient.kodePos,
      updatedAt: updated.updatedAt,
      assignedDokterId: patient.assignedDokterId,
      keluhanUtama: patient.keluhanUtama,
      durasiKeluhan: patient.durasiKeluhan,
      lokasiKeluhan: patient.lokasiKeluhan,
      vitals: patient.vitals,
    );

    if (patient.assignedDokterId.isNotEmpty) {
      try {
        final triageNotes = StringBuffer('[Triage]');
        if (patient.durasiKeluhan.isNotEmpty && patient.durasiKeluhan != '-') {
          triageNotes.write(' Durasi: ${patient.durasiKeluhan} |');
        }
        if (patient.lokasiKeluhan.isNotEmpty && patient.lokasiKeluhan != '-') {
          triageNotes.write(' Lokasi: ${patient.lokasiKeluhan} |');
        }
        if (patient.vitals.tekananDarah.isNotEmpty) {
          triageNotes.write(' TD: ${patient.vitals.tekananDarah} |');
        }
        if (patient.vitals.nadi.isNotEmpty) {
          triageNotes.write(' Nadi: ${patient.vitals.nadi} |');
        }
        if (patient.vitals.suhu.isNotEmpty) {
          triageNotes.write(' Suhu: ${patient.vitals.suhu} |');
        }
        if (patient.vitals.frekuensiNapas.isNotEmpty) {
          triageNotes.write(' RR: ${patient.vitals.frekuensiNapas} |');
        }
        if (patient.vitals.spo2.isNotEmpty) {
          triageNotes.write(' SpO2: ${patient.vitals.spo2} |');
        }
        var finalNotes = triageNotes.toString();
        if (finalNotes.endsWith('|')) {
          finalNotes = finalNotes.substring(0, finalNotes.length - 1).trim();
        }
        if (finalNotes == '[Triage]') {
          finalNotes = 'Update Penugasan Dokter';
        }

        await _api.addMedicalRecord(patient.id, {
          'doctor_id': patient.assignedDokterId,
          'ship_id': '3a7ff982-e187-49f8-a34e-95f775afda61',
          'port_id': 'f7d71b54-4c2c-4b10-a601-b82a604c7315',
          'complaint': patient.keluhanUtama.isNotEmpty ? patient.keluhanUtama : 'Pemeriksaan awal',
          'diagnosis': patient.diagnosa ?? 'Pemeriksaan Umum',
          'treatment': patient.resep.isNotEmpty
              ? patient.resep.map((r) => '${r.obat} ${r.dosis} (${r.instruksi})').join(', ')
              : 'Menunggu Pemeriksaan Dokter',
          'notes': finalNotes,
          'date': DateTime.now().toIso8601String().split('T').first,
        });
      } catch (e) {
        debugPrint('updatePatient medical record error: $e');
      }
    }

    _wsService.send({
      'type': 'patient_assigned',
      'patient_id': patient.id,
      'doctor_id': patient.assignedDokterId,
      'nama': fullPatient.nama,
    });

    _update(patient.id, (_) => fullPatient);
    return fullPatient;
  }

  void markDilihatDokter(String id) {
    _seenStorage.markDoctorSeen(id);
    _update(id, (p) => p.copyWith(dilihatDokter: true));
  }

  void markDilihatDokterLab(String id) {
    _seenStorage.markDoctorLabSeen(id);
    _update(id, (p) => p.copyWith(dilihatDokterLab: true));
  }

  void markDilihatPharmacy(String id) {
    _seenStorage.markPharmacySeen(id);
    _update(id, (p) => p.copyWith(dilihatPharmacy: true));
  }

  void markDilihatLab(String id) {
    _seenStorage.markLabSeen(id);
    _update(id, (p) => p.copyWith(dilihatLab: true));
  }

  Future<void> submitDiagnosaResep({
    required String id,
    required String diagnosa,
    String? tindakan,
    required List<ResepItem> resep,
    LabOrder? labOrder,
    String? doctorId,
    String? shipId,
    String? portId,
    String? statusKondisi,
  }) async {
    final matchedDoc = kDoctors.where((d) => d.id == doctorId).firstOrNull;
    _update(
      id,
      (p) => p.copyWith(
        status: PatientStatus.diperiksa,
        statusPenanganan: 'Menunggu Obat',
        diagnosa: diagnosa,
        tindakan: tindakan ?? p.tindakan,
        resep: resep,
        resepStatus: ResepStatus.baru,
        labOrder: labOrder ?? p.labOrder,
        dilihatDokter: true,
        assignedDokterId: (doctorId != null && doctorId.isNotEmpty) ? doctorId : p.assignedDokterId,
        doctorName: matchedDoc?.nama ?? (p.doctorName?.isNotEmpty == true ? p.doctorName : 'Dr. Budi Santoso'),
      ),
    );

    try {
      final patient = state.where((p) => p.id == id).firstOrNull;
      final assignedDoctorId = patient?.assignedDokterId ?? '';
      final complaint = patient?.keluhanUtama ?? '';
      final treatmentText = resep.map((r) => '${r.obat} ${r.dosis} (${r.instruksi})').join(', ');

      final validDoctorIds = kDoctors.map((d) => d.id).toSet();
      String effectiveDoctorId = '8afc72cb-b1c5-4ea1-a438-b06c6ae4a99b'; // Dr. Budi Santoso fallback
      if (doctorId != null && doctorId.isNotEmpty && (validDoctorIds.contains(doctorId) || doctorId.length > 20)) {
        effectiveDoctorId = doctorId;
      } else if (assignedDoctorId.isNotEmpty && (validDoctorIds.contains(assignedDoctorId) || assignedDoctorId.length > 20)) {
        effectiveDoctorId = assignedDoctorId;
      }

      final effectiveShipId = (shipId != null && shipId.isNotEmpty)
          ? shipId
          : '3a7ff982-e187-49f8-a34e-95f775afda61'; // RSK dr. Lie Dharmawan Bayan Peduli I

      final effectivePortId = (portId != null && portId.isNotEmpty)
          ? portId
          : 'f7d71b54-4c2c-4b10-a601-b82a604c7315'; // Pelabuhan Tanjung Priok default

      final effectiveTreatment = (tindakan != null && tindakan.isNotEmpty)
          ? tindakan
          : (treatmentText.isNotEmpty ? treatmentText : 'Pemeriksaan Dokter');

      await _api.addMedicalRecord(id, {
        'doctor_id': effectiveDoctorId,
        'ship_id': effectiveShipId,
        'port_id': effectivePortId,
        'diagnosis': diagnosa,
        'treatment': effectiveTreatment,
        if (tindakan != null && tindakan.isNotEmpty) 'procedure': tindakan,
        if (tindakan != null && tindakan.isNotEmpty) 'tindakan': tindakan,
        if (tindakan != null && tindakan.isNotEmpty) 'icd9': tindakan,
        if (treatmentText.isNotEmpty) 'prescription': treatmentText,
        if (treatmentText.isNotEmpty) 'recipe': treatmentText,
        'prescriptions': resep.map((r) => r.toJson()).toList(),
        'medicines': resep.map((r) => r.toJson()).toList(),
        'complaint': complaint.isNotEmpty ? complaint : 'Pemeriksaan klinis',
        'date': DateTime.now().toIso8601String().split('T').first,
        'status': statusKondisi?.isNotEmpty == true ? statusKondisi! : 'Stable',
        if (labOrder != null) 'notes': 'Order Lab: ${labOrder.jenis} (${labOrder.catatan})',
      });

      // Update patient status_penanganan to 'Menunggu Obat' in backend database
      try {
        await _api.updatePatient(id, {
          'status_penanganan': 'Menunggu Obat',
        });
      } catch (e) {
        debugPrint('Failed to sync status_penanganan to backend: $e');
      }

      _wsService.send({
        'type': 'prescription_created',
        'target_role': 'pharmacy',
        'patient_id': id,
        'patient_name': patient?.nama ?? '',
        'doctor_id': effectiveDoctorId,
        'status_penanganan': 'Menunggu Obat',
        'resep_count': resep.length,
        'timestamp': DateTime.now().toIso8601String(),
      });

      if (labOrder != null) {
        _wsService.send({
          'type': 'lab_order_created',
          'target_role': 'lab',
          'patient_id': id,
          'patient_name': patient?.nama ?? '',
          'doctor_id': effectiveDoctorId,
          'status_penanganan': 'Menunggu Lab',
          'timestamp': DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      debugPrint('Failed to sync medical record to API: $e');
      rethrow;
    }
  }

  /// Patches a patient's medical record via PATCH /api/v1/patients/:id/medical-records/:recordId
  Future<void> patchMedicalRecord({
    required String patientId,
    required String recordId,
    required Map<String, dynamic> body,
    List<ResepItem>? resep,
    LabOrder? labOrder,
  }) async {
    final statusPenanganan = body['status_penanganan']?.toString() ?? 'Menunggu Obat';

    _update(
      patientId,
      (p) => p.copyWith(
        status: PatientStatus.diperiksa,
        statusPenanganan: statusPenanganan,
        diagnosa: body['diagnosis']?.toString() ?? p.diagnosa,
        tindakan: body['treatment']?.toString() ?? p.tindakan,
        resep: resep ?? p.resep,
        resepStatus: ResepStatus.baru,
        labOrder: labOrder ?? p.labOrder,
        dilihatDokter: true,
      ),
    );

    try {
      await _api.patchMedicalRecord(patientId, recordId, body);

      // Sync status_penanganan to patient endpoint
      try {
        await _api.updatePatient(patientId, {
          'status_penanganan': statusPenanganan,
        });
      } catch (e) {
        debugPrint('Failed to sync status_penanganan to patient: $e');
      }

      final patient = state.where((p) => p.id == patientId).firstOrNull;
      _wsService.send({
        'type': 'prescription_created',
        'target_role': 'pharmacy',
        'patient_id': patientId,
        'patient_name': patient?.nama ?? '',
        'status_penanganan': statusPenanganan,
        'resep_count': resep?.length ?? 0,
        'timestamp': DateTime.now().toIso8601String(),
      });

      if (labOrder != null) {
        _wsService.send({
          'type': 'lab_order_created',
          'target_role': 'lab',
          'patient_id': patientId,
          'patient_name': patient?.nama ?? '',
          'status_penanganan': 'Menunggu Lab',
          'timestamp': DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      debugPrint('Failed to patch medical record: $e');
      rethrow;
    }
  }

  void gantiObat(String id, int index, String obatBaru, String alasan) {
    _update(id, (p) {
      final resep = [...p.resep];
      final row = resep[index];
      resep[index] = row.copyWith(
        obat: obatBaru,
        penggantian: ObatPenggantian(dari: row.penggantian?.dari ?? row.obat, alasan: alasan),
      );
      return p.copyWith(resep: resep);
    });
  }

  Future<void> setResepStatus(String id, ResepStatus status) async {
    final newStatusPenanganan = status == ResepStatus.selesai ? 'Selesai' : null;
    _update(
      id,
      (p) => p.copyWith(
        resepStatus: status,
        statusPenanganan: newStatusPenanganan ?? p.statusPenanganan,
      ),
    );

    if (status == ResepStatus.selesai) {
      _seenStorage.markPharmacySeen(id);
      try {
        await _api.updatePatient(id, {
          'status_penanganan': 'Selesai',
        });
        debugPrint('✅ [setResepStatus] Successfully updated status_penanganan to Selesai on API for patient $id');
      } catch (e) {
        debugPrint('❌ [setResepStatus] Failed to sync status_penanganan Selesai to API: $e');
        rethrow;
      }

      _wsService.send({
        'type': 'prescription_completed',
        'patient_id': id,
        'status_penanganan': 'Selesai',
        'timestamp': DateTime.now().toIso8601String(),
      });
    }
  }

  void submitLabHasil({required String id, required String catatanHasil, String? fileName}) {
    _update(id, (p) {
      final order = p.labOrder;
      if (order == null) return p;
      return p.copyWith(
        labOrder: order.copyWith(status: LabOrderStatus.selesai, hasil: LabHasil(catatanHasil: catatanHasil, fileName: fileName)),
        dilihatDokterLab: false,
      );
    });

    _wsService.send({
      'type': 'lab_result_ready',
      'patient_id': id,
    });
  }
}

final patientApiProvider = Provider<PatientApi>((ref) {
  return PatientApi();
});

final webSocketServiceProvider = Provider<WebSocketService>((ref) {
  final ws = WebSocketService();
  ref.onDispose(() => ws.dispose());
  return ws;
});

/// Dedicated notifier for unread active notifications.
/// Completely independent of patient directory pagination/scrolling.
class NotificationsNotifier extends StateNotifier<List<Patient>> {
  NotificationsNotifier({
    PatientApi? api,
    SeenNotificationStorage? seenStorage,
    WebSocketService? wsService,
  })  : _api = api ?? PatientApi(),
        _seenStorage = seenStorage ?? SeenNotificationStorage(),
        _wsService = wsService ?? WebSocketService(),
        super(const []) {
    Future.microtask(() => fetchRecentNotifications());
    _initWebSocket();
  }

  final PatientApi _api;
  final SeenNotificationStorage _seenStorage;
  final WebSocketService _wsService;
  StreamSubscription? _wsSubscription;

  void _initWebSocket() {
    _wsSubscription = _wsService.onEvent.listen((event) async {
      final type = event['type'] ?? event['event'];
      if (type == 'ping' || type == 'pong') return;
      debugPrint('⚡ [NotificationsNotifier] Event received: $type');

      final patientId = event['patient_id']?.toString();
      if (type == 'prescription_created' && patientId != null) {
        await _seenStorage.unmarkPharmacySeen(patientId);
      } else if (type == 'patient_assigned' && patientId != null) {
        await _seenStorage.unmarkDoctorSeen(patientId);
      } else if (type == 'lab_result_ready' && patientId != null) {
        await _seenStorage.unmarkDoctorLabSeen(patientId);
      } else if (type == 'lab_order_created' && patientId != null) {
        await _seenStorage.unmarkLabSeen(patientId);
      }

      await fetchRecentNotifications(targetPatientId: patientId);
    });
  }

  Future<void> fetchRecentNotifications({String? targetPatientId}) async {
    try {
      await _seenStorage.load();
      // Fetch recent triage/intake patients (page 1 with limit 50)
      final paginated = await _api.getPatientsPaginated(page: 1, limit: 50);
      var patientList = paginated.data;

      // If a specific target patient was notified but not on page 1, fetch it individually
      if (targetPatientId != null && !patientList.any((p) => p.id == targetPatientId)) {
        try {
          final target = await _api.getPatient(targetPatientId);
          patientList = [target, ...patientList];
        } catch (_) {}
      }

      final unread = patientList.where((p) {
        final isUnreadDoc = (p.status == PatientStatus.menungguDokter) && !_seenStorage.isDoctorSeen(p.id);
        final isUnreadDocLab = (p.labOrder?.status == LabOrderStatus.selesai) && !_seenStorage.isDoctorLabSeen(p.id);
        final isUnreadPharm = (p.statusPenanganan == 'Menunggu Obat' || p.resepStatus == ResepStatus.baru || (p.resep.isNotEmpty && p.resepStatus != ResepStatus.selesai)) && !_seenStorage.isPharmacySeen(p.id);
        final isUnreadLab = (p.statusPenanganan == 'Menunggu Lab' || (p.labOrder != null && p.labOrder!.status == LabOrderStatus.baru)) && !_seenStorage.isLabSeen(p.id);
        return isUnreadDoc || isUnreadDocLab || isUnreadPharm || isUnreadLab;
      }).toList();

      state = unread;
    } catch (_) {}
  }

  void markDoctorSeen(String id) {
    _seenStorage.markDoctorSeen(id);
    state = state.where((p) => !(p.id == id && p.status == PatientStatus.menungguDokter)).toList();
  }

  void markDoctorLabSeen(String id) {
    _seenStorage.markDoctorLabSeen(id);
    state = state.where((p) => !(p.id == id && p.labOrder?.status == LabOrderStatus.selesai)).toList();
  }

  void markPharmacySeen(String id) {
    _seenStorage.markPharmacySeen(id);
    state = state.where((p) => p.id != id).toList();
  }

  void markLabSeen(String id) {
    _seenStorage.markLabSeen(id);
    state = state.where((p) => !(p.id == id && p.labOrder?.status == LabOrderStatus.baru)).toList();
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    super.dispose();
  }
}

final notificationsProvider = StateNotifierProvider<NotificationsNotifier, List<Patient>>((ref) {
  final api = ref.watch(patientApiProvider);
  final ws = ref.watch(webSocketServiceProvider);
  return NotificationsNotifier(api: api, wsService: ws);
});

final patientsProvider = StateNotifierProvider<PatientsNotifier, List<Patient>>((ref) {
  final api = ref.watch(patientApiProvider);
  final ws = ref.watch(webSocketServiceProvider);
  final authState = ref.watch(authControllerProvider);
  final hasSession = authState.session != null;
  return PatientsNotifier(api: api, wsService: ws, autoFetch: hasSession);
});

final doctorsProvider = FutureProvider<List<Doctor>>((ref) async {
  final api = ref.watch(patientApiProvider);
  final authState = ref.watch(authControllerProvider);
  if (authState.session == null) return [];
  try {
    final doctors = await api.getDoctors();
    return doctors;
  } catch (e) {
    debugPrint('doctorsProvider error: $e');
    return [];
  }
});

/// Fetches full patient details directly from GET /api/v1/patients/:id
final patientDetailProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, id) async {
  final api = ref.watch(patientApiProvider);
  final detail = await api.getPatientDetailRaw(id);
  // Also fetch medical records in case they are separated
  try {
    final records = await api.getMedicalRecords(id);
    if (records.isNotEmpty) {
      final existing = detail['medical_records'];
      if (existing == null || (existing is List && existing.isEmpty)) {
        final merged = Map<String, dynamic>.from(detail);
        merged['medical_records'] = records;
        return merged;
      }
    }
  } catch (_) {}
  return detail;
});

class MedicalHistoryNotifier extends StateNotifier<List<MedicalHistory>> {
  MedicalHistoryNotifier({
    PatientApi? api,
    bool autoFetch = true,
  })  : _api = api ?? PatientApi(),
        super(const []) {
    if (autoFetch) {
      Future.microtask(() => fetchHistory());
    }
  }

  final PatientApi _api;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  int _currentPage = 1;
  int _totalPages = 1;
  int _total = 0;
  final int _limit = 10;
  bool _hasMore = true;
  String _currentSearch = '';
  Timer? _debounceTimer;

  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  int get total => _total;
  int get totalPages => _totalPages;
  int get currentPage => _currentPage;


  Future<void> fetchHistory({bool refresh = false}) async {
    if (refresh) {
      _currentPage = 1;
      _hasMore = true;
    }
    _isLoading = true;
    state = state;
    try {
      final res = await _api.getMedicalHistoryPaginated(
        page: 1,
        limit: _limit,
        search: _currentSearch,
        sortBy: 'created_at',
        order: 'desc',
      );
      _currentPage = res.page;
      _totalPages = res.totalPages;
      _total = res.total;
      _hasMore = res.page < res.totalPages;
      state = res.data;
    } catch (e) {
      debugPrint('MedicalHistoryNotifier.fetchHistory error: $e');
    } finally {
      _isLoading = false;
      state = [...state];
    }
  }

  Future<void> loadMore() async {
    if (_isLoadingMore || !_hasMore || _isLoading) return;
    _isLoadingMore = true;
    state = state;
    try {
      final nextPage = _currentPage + 1;
      final res = await _api.getMedicalHistoryPaginated(
        page: nextPage,
        limit: _limit,
        search: _currentSearch,
        sortBy: 'created_at',
        order: 'desc',
      );
      _currentPage = res.page;
      _totalPages = res.totalPages;
      _total = res.total;
      _hasMore = res.page < res.totalPages;
      final existingIds = {for (final m in state) m.id};
      final newItems =
          res.data.where((m) => !existingIds.contains(m.id)).toList();
      state = [...state, ...newItems];
    } catch (e) {
      debugPrint('MedicalHistoryNotifier.loadMore error: $e');
    } finally {
      _isLoadingMore = false;
      state = [...state];
    }
  }

  void searchHistory(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 350), () {
      _currentSearch = query.trim();
      fetchHistory(refresh: true);
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}

final medicalHistoryProvider =
    StateNotifierProvider<MedicalHistoryNotifier, List<MedicalHistory>>((ref) {
  final api = ref.watch(patientApiProvider);
  final authState = ref.watch(authControllerProvider);
  final hasSession = authState.session != null;
  return MedicalHistoryNotifier(api: api, autoFetch: hasSession);
});



