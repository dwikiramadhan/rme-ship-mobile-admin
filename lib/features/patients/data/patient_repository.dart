import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/websocket_service.dart';
import '../domain/doctor.dart';
import '../domain/lab_order.dart';
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
  Timer? _fallbackSyncTimer;

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

    // Fallback slow sync (30s) only if WS is disconnected, saving server load
    _fallbackSyncTimer?.cancel();
    _fallbackSyncTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!_wsService.isConnected && !_isLoading && !_isLoadingMore) {
        _silentPoll();
      }
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
    _fallbackSyncTimer?.cancel();
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
      final medRecords = await _api.getMedicalRecords(id);
      if (medRecords.isNotEmpty) {
        String? diag;
        String? complaint;
        String? docId;
        String? durasi;
        String? lokasi;
        Vitals? parsedVitals;
        List<ResepItem> resepItems = const [];

        for (final raw in medRecords) {
          final recDiag = raw['diagnosis']?.toString();
          final recTreatment = raw['treatment']?.toString() ?? '';
          final recComplaint = raw['complaint']?.toString();
          final recDocId = raw['doctor_id']?.toString() ?? raw['doctor']?['id']?.toString();
          final notes = raw['notes']?.toString() ?? '';

          if (recComplaint != null && recComplaint.isNotEmpty && recComplaint != 'Pemeriksaan klinis' && recComplaint != 'Pemeriksaan umum') {
            complaint = recComplaint;
          } else if (complaint == null && recComplaint != null && recComplaint.isNotEmpty) {
            complaint = recComplaint;
          }

          if (recDocId != null && recDocId.isNotEmpty) {
            docId = recDocId;
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

          if (recTreatment.isNotEmpty &&
              recTreatment != 'Menunggu Pemeriksaan Dokter' &&
              recTreatment != 'Pemeriksaan awal' &&
              recTreatment != 'Pemeriksaan Dokter') {
            resepItems = [
              ResepItem(obat: recTreatment, dosis: '1x1', instruksi: notes.startsWith('Order Lab:') ? '' : notes),
            ];
          }
        }

        final isExamined = diag != null && diag.isNotEmpty && diag != 'Pemeriksaan Umum';

        _update(id, (p) => p.copyWith(
          diagnosa: isExamined ? diag : p.diagnosa,
          status: isExamined ? PatientStatus.diperiksa : p.status,
          resep: resepItems.isNotEmpty ? resepItems : p.resep,
          resepStatus: resepItems.isNotEmpty ? (p.resepStatus ?? ResepStatus.baru) : p.resepStatus,
          keluhanUtama: (complaint != null && complaint.isNotEmpty && !complaint.startsWith('Kondisi:')) ? complaint : p.keluhanUtama,
          durasiKeluhan: durasi ?? p.durasiKeluhan,
          lokasiKeluhan: lokasi ?? p.lokasiKeluhan,
          vitals: parsedVitals ?? p.vitals,
          assignedDokterId: (docId != null && docId.isNotEmpty) ? docId : p.assignedDokterId,
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

  Future<Patient> updatePatient(Patient patient) async {
    final updated = await _api.updatePatient(patient.id, patient.toCreatePatientJson(
      dob: patient.dob,
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
    required List<ResepItem> resep,
    LabOrder? labOrder,
    String? doctorId,
    String? shipId,
    String? portId,
  }) async {
    _update(
      id,
      (p) => p.copyWith(
        status: PatientStatus.diperiksa,
        statusPenanganan: 'Menunggu Obat',
        diagnosa: diagnosa,
        resep: resep,
        resepStatus: ResepStatus.baru,
        labOrder: labOrder ?? p.labOrder,
        dilihatDokter: true,
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

      await _api.addMedicalRecord(id, {
        'doctor_id': effectiveDoctorId,
        'ship_id': effectiveShipId,
        'port_id': effectivePortId,
        'diagnosis': diagnosa,
        'treatment': treatmentText.isNotEmpty ? treatmentText : 'Pemeriksaan Dokter',
        'complaint': complaint.isNotEmpty ? complaint : 'Pemeriksaan klinis',
        'date': DateTime.now().toIso8601String().split('T').first,
        'status': 'Monitoring',
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

