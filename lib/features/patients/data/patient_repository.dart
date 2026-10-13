import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/websocket_service.dart';
import '../../../core/notifications/in_app_notification_manager.dart';
import '../../../core/notifications/in_app_notification_model.dart';
import '../domain/doctor.dart';
import '../domain/lab_order.dart';
import '../domain/medical_history.dart';
import '../domain/patient.dart';
import '../domain/prescription_item.dart';
import '../domain/vitals.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../auth/domain/user_role.dart';
import 'patient_api.dart';
import 'seen_notification_storage.dart';
import '../../../core/utils/ship_code_helper.dart';
import '../../notifications/domain/notification_rules.dart';

/// Patient state management wired directly to [PatientApi] and real-time [WebSocketService]
/// for instant sub-second event pushes (Perawat -> Dokter, Dokter -> Farmasi/Lab).
/// The patient was registered, but their first visit could not be created.
/// Saving again would register the patient twice, so the visit has to be
/// added from "Tambah Kunjungan" instead.
class VisitNotCreatedException implements Exception {
  const VisitNotCreatedException(this.patient, this.cause);

  final Patient patient;
  final Object cause;

  @override
  String toString() =>
      'Pasien tersimpan, tetapi kunjungan gagal dibuat: $cause. '
      'Tambahkan kunjungan lewat menu Tambah Kunjungan.';
}

class PatientsNotifier extends StateNotifier<List<Patient>> {
  PatientsNotifier({
    PatientApi? api,
    SeenNotificationStorage? seenStorage,
    WebSocketService? wsService,
    bool autoFetch = true,
  }) : _api = api ?? PatientApi(),
       _seenStorage = seenStorage ?? SeenNotificationStorage(),
       _wsService = wsService ?? WebSocketService(),
       _ownsWsService = wsService == null,
       super(const []) {
    if (autoFetch) {
      Future.microtask(() => fetchPatients());
      _initWebSocket();
    }
  }

  final PatientApi _api;
  final SeenNotificationStorage _seenStorage;
  final WebSocketService _wsService;
  // The injected service is the app-wide shared socket (owned by
  // webSocketServiceProvider) and must outlive this notifier.
  final bool _ownsWsService;
  StreamSubscription? _wsSubscription;
  Timer? _silentPollTimer;
  // Bumped by every refresh (page 1). Older responses, including an
  // in-flight loadMore, are dropped so they can't overwrite newer results.
  int _requestSeq = 0;

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
        _update(
          patientId,
          (p) => p.copyWith(
            statusPenanganan: statusPenanganan,
            resepStatus: statusPenanganan == 'Menunggu Obat'
                ? (p.resepStatus ?? ResepStatus.baru)
                : p.resepStatus,
          ),
        );
      }
      _scheduleSilentPoll();
    });
  }

  /// Coalesces bursts of WS events into a single list refresh.
  void _scheduleSilentPoll() {
    _silentPollTimer?.cancel();
    _silentPollTimer = Timer(const Duration(milliseconds: 500), _silentPoll);
  }

  Future<void> _silentPoll() async {
    try {
      await _seenStorage.load();
      final paginated = await _api.getPatientsPaginated(
        limit: _limit,
        search: _currentSearch,
      );

      final existingMap = {for (final p in state) p.id: p};
      final updatedPage1 = paginated.data.map((p) {
        final existing = existingMap[p.id];
        if (existing != null) {
          return p.copyWith(
            status: p.status != PatientStatus.menungguDokter
                ? p.status
                : existing.status,
            dbStatus: p.dbStatus,
            diagnosa: p.diagnosa ?? existing.diagnosa,
            tindakan: p.tindakan ?? existing.tindakan,
            resep: p.resep.isNotEmpty ? p.resep : existing.resep,
            resepStatus: p.resepStatus ?? existing.resepStatus,
            labOrder: p.labOrder ?? existing.labOrder,
            vitals: p.vitals.tekananDarah.isNotEmpty
                ? p.vitals
                : existing.vitals,
            dilihatDokter: _seenStorage.isDoctorSeen(p.id),
            dilihatPharmacy: _seenStorage.isPharmacySeen(p.id),
            dilihatLab: _seenStorage.isLabSeen(p.id),
            dilihatDokterLab: _seenStorage.isDoctorLabSeen(p.id),
          );
        }
        return p.copyWith(
          dilihatDokter: _seenStorage.isDoctorSeen(p.id),
          dilihatPharmacy: _seenStorage.isPharmacySeen(p.id),
          dilihatLab: _seenStorage.isLabSeen(p.id),
          dilihatDokterLab: _seenStorage.isDoctorLabSeen(p.id),
        );
      }).toList();

      final page1Map = {for (final p in updatedPage1) p.id: p};
      final mergedExisting = state.map((p) => page1Map[p.id] ?? p).toList();
      final existingStateIds = {for (final p in state) p.id};
      final brandNew = updatedPage1
          .where((p) => !existingStateIds.contains(p.id))
          .toList();

      final updatedList = [...brandNew, ...mergedExisting];
      if (!listEquals(state, updatedList) && mounted) {
        state = updatedList;
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _silentPollTimer?.cancel();
    _wsSubscription?.cancel();
    if (_ownsWsService) _wsService.dispose();
    super.dispose();
  }

  /// Fetches patients from GET /api/v1/patients.
  /// If [refresh] is true, resets pagination and fetches page 1.
  Future<void> fetchPatients({
    bool refresh = true,
    String? search,
    String? status,
  }) async {
    if (search != null) {
      _currentSearch = search.trim().isNotEmpty ? search.trim() : null;
    }
    final effectiveSearch = search ?? _currentSearch;

    final int seq;
    if (refresh) {
      seq = ++_requestSeq;
      _isLoading = true;
      _currentPage = 1;
      if (mounted) state = [...state];
    } else {
      if (_isLoadingMore || !_hasMore) return;
      seq = _requestSeq;
      _isLoadingMore = true;
      if (mounted) state = [...state];
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
        search: effectiveSearch,
        status: status,
      );
      if (seq != _requestSeq || !mounted) return;

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
              keluhanUtama:
                  (p.keluhanUtama.isNotEmpty &&
                      p.keluhanUtama != 'Pemeriksaan umum')
                  ? p.keluhanUtama
                  : existing.keluhanUtama,
              durasiKeluhan:
                  (p.durasiKeluhan.isNotEmpty && p.durasiKeluhan != '-')
                  ? p.durasiKeluhan
                  : existing.durasiKeluhan,
              lokasiKeluhan:
                  (p.lokasiKeluhan.isNotEmpty && p.lokasiKeluhan != '-')
                  ? p.lokasiKeluhan
                  : existing.lokasiKeluhan,
              status: p.status != PatientStatus.menungguDokter
                  ? p.status
                  : existing.status,
              dbStatus: p.dbStatus,
              statusPenanganan:
                  (p.statusPenanganan != null && p.statusPenanganan!.isNotEmpty)
                  ? p.statusPenanganan
                  : existing.statusPenanganan,
              diagnosa: p.diagnosa ?? existing.diagnosa,
              tindakan: p.tindakan ?? existing.tindakan,
              resep: p.resep.isNotEmpty ? p.resep : existing.resep,
              resepStatus: p.resepStatus ?? existing.resepStatus,
              labOrder: p.labOrder ?? existing.labOrder,
              vitals: p.vitals.tekananDarah.isNotEmpty
                  ? p.vitals
                  : existing.vitals,
              dilihatDokter: _seenStorage.isDoctorSeen(p.id),
              dilihatPharmacy: _seenStorage.isPharmacySeen(p.id),
              dilihatLab: _seenStorage.isLabSeen(p.id),
              dilihatDokterLab: _seenStorage.isDoctorLabSeen(p.id),
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
        final newItems = paginated.data
            .where((p) => !existingIds.contains(p.id))
            .map((p) {
              return p.copyWith(
                dilihatDokter: _seenStorage.isDoctorSeen(p.id),
                dilihatPharmacy: _seenStorage.isPharmacySeen(p.id),
                dilihatLab: _seenStorage.isLabSeen(p.id),
                dilihatDokterLab: _seenStorage.isDoctorLabSeen(p.id),
              );
            })
            .toList();
        state = [...state, ...newItems];
      }
    } catch (e) {
      debugPrint('fetchPatients error: $e');
    } finally {
      if (refresh) {
        // A newer refresh owns the loading flag now.
        if (seq == _requestSeq) _isLoading = false;
      } else {
        _isLoadingMore = false;
      }
      if (mounted) state = [...state];
    }
  }

  final Map<String, Future<void>> _detailInFlight = {};

  /// Fetches medical records on-demand when a patient detail is viewed/clicked.
  /// Concurrent calls for the same patient share one request (e.g. the list
  /// selection and the detail pane both asking at once).
  Future<void> fetchPatientDetail(String id) {
    return _detailInFlight[id] ??= _fetchPatientDetail(
      id,
    ).whenComplete(() {
      // Block body on purpose: returning the removed Future would make
      // whenComplete wait on itself and never complete.
      _detailInFlight.remove(id);
    });
  }

  Future<void> _fetchPatientDetail(String id) async {
    try {
      // Start the records request alongside the patient request instead of
      // after it. Its result/error is still consumed below; the no-op handler
      // only keeps an early failure from being reported as unhandled.
      final recordsFuture = _api.getMedicalRecords(id);
      unawaited(recordsFuture.then((_) {}, onError: (_) {}));

      try {
        final detailedPatient = await _api.getPatient(id);
        if (!mounted) return;
        if (!state.any((p) => p.id == id)) {
          state = [...state, detailedPatient];
        }
        _update(
          id,
          (p) => p.copyWith(
            diagnosa: detailedPatient.diagnosa ?? p.diagnosa,
            tindakan: detailedPatient.tindakan ?? p.tindakan,
            status: detailedPatient.diagnosa != null
                ? PatientStatus.diperiksa
                : p.status,
            resep: detailedPatient.resep.isNotEmpty
                ? detailedPatient.resep
                : p.resep,
            resepStatus: detailedPatient.resepStatus ?? p.resepStatus,
            labOrder: detailedPatient.labOrder ?? p.labOrder,
            keluhanUtama: detailedPatient.keluhanUtama.isNotEmpty
                ? detailedPatient.keluhanUtama
                : p.keluhanUtama,
            durasiKeluhan: detailedPatient.durasiKeluhan != '-'
                ? detailedPatient.durasiKeluhan
                : p.durasiKeluhan,
            lokasiKeluhan: detailedPatient.lokasiKeluhan != '-'
                ? detailedPatient.lokasiKeluhan
                : p.lokasiKeluhan,
            vitals: detailedPatient.vitals.tekananDarah.isNotEmpty
                ? detailedPatient.vitals
                : p.vitals,
            assignedDokterId: detailedPatient.assignedDokterId.isNotEmpty
                ? detailedPatient.assignedDokterId
                : p.assignedDokterId,
            doctorName: detailedPatient.doctorName ?? p.doctorName,
            bloodType: detailedPatient.bloodType ?? p.bloodType,
          ),
        );
      } catch (_) {}

      final medRecords = await recordsFuture;
      if (!mounted) return;
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

        final sortedRecords = List<Map<String, dynamic>>.from(medRecords);
        sortedRecords.sort((a, b) {
          final dateA =
              DateTime.tryParse(
                a['date']?.toString() ?? a['created_at']?.toString() ?? '',
              ) ??
              DateTime.fromMillisecondsSinceEpoch(0);
          final dateB =
              DateTime.tryParse(
                b['date']?.toString() ?? b['created_at']?.toString() ?? '',
              ) ??
              DateTime.fromMillisecondsSinceEpoch(0);
          return dateB.compareTo(dateA);
        });

        final raw = sortedRecords.firstWhere((r) {
          final s = (r['status_penanganan'] ?? r['status'] ?? '')
              .toString()
              .trim()
              .toLowerCase();
          return s.isNotEmpty && s != 'selesai';
        }, orElse: () => sortedRecords.first);

        final recDiag = raw['diagnosis']?.toString();
        final recTreatment = raw['treatment']?.toString() ?? '';
        final recProcedure =
            raw['procedure']?.toString() ??
            raw['tindakan']?.toString() ??
            raw['icd9']?.toString();
        final recComplaint = raw['complaint']?.toString();
        final recDocId =
            raw['doctor_id']?.toString() ?? raw['doctor']?['id']?.toString();
        final recDocName =
            raw['doctor']?['name']?.toString() ??
            raw['doctor_name']?.toString();
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

        if (recComplaint != null && recComplaint.isNotEmpty) {
          if (recComplaint.contains('•')) {
            final parts = recComplaint.split('•');
            complaint = parts[0].trim();
            for (final p in parts.skip(1)) {
              final trimmed = p.trim();
              if (trimmed.startsWith('Durasi:')) {
                durasi = trimmed.substring('Durasi:'.length).trim();
              } else if (trimmed.startsWith('Lokasi:')) {
                lokasi = trimmed.substring('Lokasi:'.length).trim();
              }
            }
          } else {
            complaint = recComplaint;
          }
        }

        if (recDocId != null && recDocId.isNotEmpty) {
          docId = recDocId;
        }
        if (recDocName != null && recDocName.isNotEmpty) {
          docName = recDocName;
        }

        if (recDiag != null &&
            recDiag.isNotEmpty &&
            recDiag != 'Pemeriksaan Umum') {
          diag = recDiag;
        }

        // 1. Read structured vitals from medical record columns
        final vs = raw['vital_signs'] is Map ? raw['vital_signs'] as Map : null;
        final rawBp =
            raw['blood_pressure']?.toString() ??
            vs?['blood_pressure']?.toString() ??
            '';
        final rawHr =
            raw['heart_rate']?.toString() ??
            vs?['heart_rate']?.toString() ??
            '';
        final rawTemp =
            raw['temperature']?.toString() ??
            vs?['temperature']?.toString() ??
            '';
        final rawRr =
            raw['respiratory_rate']?.toString() ??
            vs?['respiratory_rate']?.toString() ??
            '';
        final rawSpo2 =
            raw['oxygen_saturation']?.toString() ??
            vs?['oxygen_saturation']?.toString() ??
            '';

        if (rawBp.isNotEmpty ||
            rawHr.isNotEmpty ||
            rawTemp.isNotEmpty ||
            rawRr.isNotEmpty ||
            rawSpo2.isNotEmpty) {
          parsedVitals = Vitals(
            tekananDarah: rawBp,
            nadi: rawHr,
            suhu: rawTemp,
            frekuensiNapas: rawRr,
            spo2: rawSpo2,
          );
        }

        // 2. Fallback / supplementary parse from triage notes
        if (notes.contains('[Triage]') ||
            notes.contains('Durasi:') ||
            notes.contains('TD:')) {
          final parts = notes.split('|');
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
              hr = part
                  .replaceFirst('Nadi:', '')
                  .replaceFirst('HR:', '')
                  .trim();
            } else if (part.startsWith('Suhu:') || part.startsWith('Temp:')) {
              temp = part
                  .replaceFirst('Suhu:', '')
                  .replaceFirst('Temp:', '')
                  .trim();
            } else if (part.startsWith('RR:')) {
              rr = part.substring('RR:'.length).trim();
            } else if (part.startsWith('SpO2:')) {
              spo2 = part.substring('SpO2:'.length).trim();
            }
          }
          if (parsedVitals == null || parsedVitals.isEmpty) {
            parsedVitals = Vitals(
              tekananDarah: td,
              nadi: hr,
              suhu: temp,
              frekuensiNapas: rr,
              spo2: spo2,
            );
          }
        }

        final rawPrescription =
            raw['prescription'] ??
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

        final isExamined =
            diag != null && diag.isNotEmpty && diag != 'Pemeriksaan Umum';

        _update(
          id,
          (p) => p.copyWith(
            diagnosa: isExamined ? diag : p.diagnosa,
            tindakan: (tindakan != null && tindakan.isNotEmpty)
                ? tindakan
                : p.tindakan,
            status: isExamined ? PatientStatus.diperiksa : p.status,
            resep: resepItems.isNotEmpty ? resepItems : p.resep,
            resepStatus: resepItems.isNotEmpty
                ? (p.resepStatus ?? ResepStatus.baru)
                : p.resepStatus,
            medicalRecordId: raw['id']?.toString() ?? p.medicalRecordId,
            keluhanUtama:
                (complaint != null &&
                    complaint.isNotEmpty &&
                    !complaint.startsWith('Kondisi:'))
                ? complaint
                : p.keluhanUtama,
            durasiKeluhan: durasi ?? p.durasiKeluhan,
            lokasiKeluhan: lokasi ?? p.lokasiKeluhan,
            vitals: parsedVitals ?? p.vitals,
            assignedDokterId: (docId != null && docId.isNotEmpty)
                ? docId
                : p.assignedDokterId,
            doctorName: (docName != null && docName.isNotEmpty)
                ? docName
                : p.doctorName,
          ),
        );
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
    await fetchPatients(search: _currentSearch);
  }

  /// Triggers loading next page on scroll
  Future<void> loadMore({String? search, String? status}) async {
    if (!_hasMore || _isLoading || _isLoadingMore) return;
    await fetchPatients(
      refresh: false,
      search: search ?? _currentSearch,
      status: status,
    );
  }

  void _update(String id, Patient Function(Patient) updater) {
    state = [
      for (final p in state)
        if (p.id == id) updater(p) else p,
    ];
  }

  void upsertPatient(Patient patient) {
    if (state.any((p) => p.id == patient.id)) {
      state = [
        for (final p in state)
          if (p.id == patient.id) patient else p,
      ];
    } else {
      state = [...state, patient];
    }
  }

  Future<String> uploadPhoto(File photo) => _api.uploadPatientPhoto(photo);

  /// Registers [patient] and opens their first visit on ship [shipId] at
  /// harbor [portId].
  Future<Patient> addPatient(
    Patient patient, {
    required String shipId,
    required String portId,
  }) async {
    String? effectiveShipCode = patient.serviceShipCode;
    if (effectiveShipCode == null || effectiveShipCode.trim().isEmpty) {
      try {
        final resolved = await resolveLocalStorageShipCode();
        if (resolved.isNotEmpty) {
          effectiveShipCode = resolved;
        }
      } catch (_) {}
    }

    final created = await _api.createPatient(
      patient.toCreatePatientJson(
        dob: patient.dob,
        bloodType: patient.bloodType,
        kodeKelurahan: patient.kodeKelurahan,
        namaWali: patient.namaWali,
        hubunganWali: patient.hubunganWali,
        keterangan: patient.keterangan,
        alergi: patient.alergi,
        photoUrl: patient.photoUrl,
        serviceShipCode: effectiveShipCode,
      ),
    );

    // Attach local clinical intake fields (keluhan, vitals, assigned doctor)
    final fullPatient = created.copyWith(
      keluhanUtama: patient.keluhanUtama.isNotEmpty
          ? patient.keluhanUtama
          : created.keluhanUtama,
      durasiKeluhan: patient.durasiKeluhan,
      lokasiKeluhan: patient.lokasiKeluhan,
      vitals: patient.vitals,
      assignedDokterId: patient.assignedDokterId,
      photoUrl: patient.photoUrl ?? created.photoUrl,
      dob: patient.dob ?? created.dob,
      bloodType: patient.bloodType ?? created.bloodType,
      namaWali: patient.namaWali ?? created.namaWali,
      hubunganWali: patient.hubunganWali ?? created.hubunganWali,
      keterangan: patient.keterangan ?? created.keterangan,
      alergi: patient.alergi ?? created.alergi,
      kodeKelurahan: patient.kodeKelurahan ?? created.kodeKelurahan,
      kodePos: patient.kodePos ?? created.kodePos,
      serviceShipCode: effectiveShipCode ?? created.serviceShipCode,
    );

    Object? visitError;
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

        int? systolic;
        int? diastolic;
        if (patient.vitals.tekananDarah.contains('/')) {
          final parts = patient.vitals.tekananDarah.split('/');
          systolic = int.tryParse(parts[0].trim());
          diastolic = int.tryParse(parts[1].trim());
        }
        final heartRate = int.tryParse(
          patient.vitals.nadi.replaceAll(RegExp(r'[^\d]'), ''),
        );
        final temperature = double.tryParse(
          patient.vitals.suhu
              .replaceAll(',', '.')
              .replaceAll(RegExp(r'[^\d.]'), ''),
        );
        final respiratoryRate = int.tryParse(
          patient.vitals.frekuensiNapas.replaceAll(RegExp(r'[^\d]'), ''),
        );
        final oxygenSaturation = double.tryParse(
          patient.vitals.spo2
              .replaceAll(',', '.')
              .replaceAll(RegExp(r'[^\d.]'), ''),
        );

        var formattedComplaint = patient.keluhanUtama.isNotEmpty
            ? patient.keluhanUtama
            : 'Pemeriksaan awal';
        final extraComplaint = <String>[];
        if (patient.durasiKeluhan.isNotEmpty && patient.durasiKeluhan != '-') {
          extraComplaint.add('Durasi: ${patient.durasiKeluhan}');
        }
        if (patient.lokasiKeluhan.isNotEmpty && patient.lokasiKeluhan != '-') {
          extraComplaint.add('Lokasi: ${patient.lokasiKeluhan}');
        }
        if (extraComplaint.isNotEmpty) {
          formattedComplaint =
              '$formattedComplaint • ${extraComplaint.join(' • ')}';
        }

        await _api.addMedicalRecord(created.id, {
          'doctor_id': patient.assignedDokterId,
          'ship_id': shipId,
          if (effectiveShipCode != null && effectiveShipCode.isNotEmpty) ...{
            'ship_code': effectiveShipCode,
            'service_ship_code': effectiveShipCode,
          },
          'port_id': portId,
          'complaint': formattedComplaint,
          // Diagnosis and treatment are left for the doctor to fill.
          'notes': finalNotes,
          'date': DateTime.now().toIso8601String().split('T').first,
          'status': 'Stable',
          'status_penanganan': 'Menunggu Dokter',
          if (patient.vitals.tekananDarah.isNotEmpty)
            'blood_pressure': patient.vitals.tekananDarah,
          'systolic': ?systolic,
          'diastolic': ?diastolic,
          'heart_rate': ?heartRate,
          'temperature': ?temperature,
          'respiratory_rate': ?respiratoryRate,
          'oxygen_saturation': ?oxygenSaturation,
        });
      } catch (e) {
        debugPrint('addPatient medical record error: $e');
        visitError = e;
      }
    }

    // The patient exists on the server either way, so keep them listed.
    state = [
      fullPatient,
      ...state.where((p) => p.id != patient.id && p.id != created.id),
    ];
    if (visitError != null) {
      throw VisitNotCreatedException(fullPatient, visitError);
    }

    _wsService.send({
      'type': 'patient_assigned',
      'patient_id': created.id,
      'doctor_id': patient.assignedDokterId,
      'nama': fullPatient.nama,
    });
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
          tekananDarah:
              vitalsMap['tekanan_darah']?.toString() ?? p.vitals.tekananDarah,
          nadi: vitalsMap['nadi']?.toString() ?? p.vitals.nadi,
          suhu: vitalsMap['suhu']?.toString() ?? p.vitals.suhu,
          frekuensiNapas:
              vitalsMap['frekuensi_napas']?.toString() ??
              p.vitals.frekuensiNapas,
          spo2: vitalsMap['spo2']?.toString() ?? p.vitals.spo2,
        );
      }
      return p.copyWith(
        status: PatientStatus.menungguDokter,
        statusPenanganan: 'Menunggu Dokter',
        assignedDokterId:
            recordData['doctor_id']?.toString() ?? p.assignedDokterId,
        keluhanUtama: recordData['complaint']?.toString() ?? p.keluhanUtama,
        durasiKeluhan:
            patientUpdates?['durasi_keluhan']?.toString() ?? p.durasiKeluhan,
        lokasiKeluhan:
            patientUpdates?['lokasi_keluhan']?.toString() ?? p.lokasiKeluhan,
        vitals: newVitals ?? p.vitals,
      );
    });
  }

  /// Updates the patient's own data (identity, address, guardian, notes).
  /// It does not create a visit: new visits go through "Input Kunjungan
  /// Baru", so editing a typo never adds a medical record.
  Future<Patient> updatePatient(Patient patient) async {
    final updated = await _api.updatePatient(
      patient.id,
      patient.toCreatePatientJson(
        dob: patient.dob,
        bloodType: patient.bloodType,
        kodeKelurahan: patient.kodeKelurahan,
        namaWali: patient.namaWali,
        hubunganWali: patient.hubunganWali,
        keterangan: patient.keterangan,
        alergi: patient.alergi,
        photoUrl: patient.photoUrl,
      ),
    );
    final fullPatient = patient.copyWith(
      nama: updated.nama,
      nik: updated.nik,
      jk: updated.jk,
      umur: updated.umur,
      alamat: updated.alamat,
      photoUrl: updated.photoUrl ?? patient.photoUrl,
      dob: updated.dob ?? patient.dob,
      bloodType: updated.bloodType ?? patient.bloodType,
      namaWali: updated.namaWali ?? patient.namaWali,
      hubunganWali: updated.hubunganWali ?? patient.hubunganWali,
      keterangan: updated.keterangan ?? patient.keterangan,
      alergi: updated.alergi ?? patient.alergi,
      kodeKelurahan: updated.kodeKelurahan ?? patient.kodeKelurahan,
      kodePos: updated.kodePos ?? patient.kodePos,
      updatedAt: updated.updatedAt,
    );

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

  /// Patches a patient's medical record via PATCH /api/v1/patients/:id/medical-records/:recordId
  Future<void> patchMedicalRecord({
    required String patientId,
    required String recordId,
    required Map<String, dynamic> body,
    List<ResepItem>? resep,
    LabOrder? labOrder,
  }) async {
    final statusPenanganan =
        body['status_penanganan']?.toString() ?? 'Menunggu Obat';

    await _seenStorage.markDoctorSeen(patientId);
    if (statusPenanganan == 'Menunggu Lab' || labOrder != null) {
      await _seenStorage.unmarkLabSeen(patientId);
    } else {
      await _seenStorage.unmarkPharmacySeen(patientId);
    }

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
        final currentPatient = state
            .where((p) => p.id == patientId)
            .firstOrNull;
        if (currentPatient != null) {
          final updatePayload = currentPatient.toCreatePatientJson(
            statusPenanganan: statusPenanganan,
          );
          await _api.updatePatient(patientId, updatePayload);
          debugPrint(
            '✅ [patchMedicalRecord] Successfully updated patient status_penanganan to $statusPenanganan',
          );
        }
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

  void gantiObat(
    String id,
    int index,
    String obatBaru,
    String alasan, {
    String? newSku,
    dynamic newJumlah,
    String? notes,
  }) {
    _update(id, (p) {
      final resep = [...p.resep];
      final row = resep[index];
      resep[index] = row.copyWith(
        obat: obatBaru,
        sku: newSku ?? row.sku,
        jumlah: newJumlah ?? row.jumlah,
        penggantian: ObatPenggantian(
          dari: row.penggantian?.dari ?? row.obat,
          alasan: alasan,
          notes: notes,
          sku: newSku ?? row.sku,
        ),
      );
      return p.copyWith(resep: resep);
    });
  }

  Future<void> dispensePrescription({
    required String medRecId,
    required String patientId,
    required String dispensedById,
    required List<ResepItem> items,
  }) async {
    final payloadItems = items.map((r) {
      final isSubstituted = r.penggantian != null;
      final qty = int.tryParse(r.jumlah?.toString() ?? '1') ?? 1;

      String sku = r.sku ?? '';
      if (sku.isEmpty) {
        final match = RegExp(r'\(([^)]+)\)').firstMatch(r.obat);
        if (match != null) {
          sku = match.group(1)?.trim() ?? '';
        }
      }

      final itemMap = <String, dynamic>{
        'prescription_id': r.id ?? '',
        'dispensed_sku': sku,
        'dispensed_quantity': qty,
        'is_substituted': isSubstituted,
      };

      if (isSubstituted) {
        final reason = r.penggantian?.alasan ?? '';
        if (reason.isNotEmpty) {
          itemMap['substitution_reason'] = reason;
        }
        final notes = r.penggantian?.notes ?? r.penggantian?.alasan ?? '';
        if (notes.isNotEmpty) {
          itemMap['substitution_notes'] = notes;
        }
      }

      return itemMap;
    }).toList();

    final body = <String, dynamic>{
      'dispensed_by_id': dispensedById,
      'items': payloadItems,
    };

    debugPrint(
      '🚀 [dispensePrescription] POST /api/v1/medical-records/$medRecId/dispense body: $body',
    );

    try {
      await _api.dispensePrescription(medRecId, body);
      debugPrint(
        '✅ [dispensePrescription] Successfully dispensed prescription for medRecId $medRecId',
      );
    } catch (e) {
      debugPrint(
        '❌ [dispensePrescription] Failed to dispense prescription for medRecId $medRecId: $e',
      );
      rethrow;
    }

    _update(
      patientId,
      (p) => p.copyWith(
        resepStatus: ResepStatus.selesai,
        statusPenanganan: 'Selesai',
      ),
    );

    _wsService.send({
      'type': 'prescription_completed',
      'patient_id': patientId,
      'medical_record_id': medRecId,
      'status_penanganan': 'Selesai',
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  Future<void> setResepStatus(String id, ResepStatus status) async {
    final newStatusPenanganan = status == ResepStatus.selesai
        ? 'Selesai'
        : null;
    _update(
      id,
      (p) => p.copyWith(
        resepStatus: status,
        statusPenanganan: newStatusPenanganan ?? p.statusPenanganan,
      ),
    );

    if (status == ResepStatus.selesai) {
      await _seenStorage.markPharmacySeen(id);
      try {
        final currentPatient = state.where((p) => p.id == id).firstOrNull;
        if (currentPatient != null) {
          final updatePayload = currentPatient.toCreatePatientJson(
            statusPenanganan: 'Selesai',
          );
          await _api.updatePatient(id, updatePayload);
          debugPrint(
            '✅ [setResepStatus] Successfully updated status_penanganan to Selesai on API for patient $id',
          );
        }
      } catch (e) {
        debugPrint(
          '❌ [setResepStatus] Failed to sync status_penanganan Selesai to API: $e',
        );
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

  Future<void> submitLabExaminations({
    required String medicalRecordId,
    required String patientId,
    String? doctorId,
    String? labPersonnelId,
    required String notes,
    String? conclusion,
    String status = 'Completed',
    required List<Map<String, dynamic>> items,
    String? fileName,
    String? filePath,
    Uint8List? fileBytes,
  }) async {
    final map = <String, dynamic>{
      'notes': notes,
      'conclusion': conclusion ?? '',
      'status': status,
      'items': jsonEncode(items),
    };
    if (medicalRecordId.isNotEmpty) {
      map['medical_record_id'] = medicalRecordId;
    }
    if (patientId.isNotEmpty) {
      map['patient_id'] = patientId;
    }
    if (doctorId != null && doctorId.isNotEmpty) {
      map['doctor_id'] = doctorId;
    }
    if (labPersonnelId != null && labPersonnelId.isNotEmpty) {
      map['lab_personnel_id'] = labPersonnelId;
    }

    if (filePath != null && filePath.isNotEmpty) {
      final name = fileName ?? filePath.split(Platform.pathSeparator).last;
      map['file'] = await MultipartFile.fromFile(filePath, filename: name);
    } else if (fileBytes != null && fileBytes.isNotEmpty) {
      map['file'] = MultipartFile.fromBytes(
        fileBytes,
        filename: fileName ?? 'hasil_lab.pdf',
      );
    }

    final formData = FormData.fromMap(map);

    debugPrint(
      '🚀 [submitLabExaminations] POST /api/v1/medical-records/$medicalRecordId/lab-examinations (multipart/form-data) notes: $notes, conclusion: $conclusion, status: $status, items: ${jsonEncode(items)}, file: ${fileName ?? filePath}',
    );
    try {
      await _api.submitLabExaminations(medicalRecordId, formData);
    } catch (e) {
      debugPrint('⚠️ [submitLabExaminations] API error: $e');
      rethrow;
    }

    final parsedItems = items
        .map((i) => LabExaminationItem.fromJson(i))
        .toList();
    _update(patientId, (p) {
      final order = p.labOrder;
      if (order == null) return p;
      return p.copyWith(
        labOrder: order.copyWith(
          status: LabOrderStatus.selesai,
          hasil: LabHasil(
            catatanHasil: notes,
            fileName: fileName,
            items: parsedItems,
          ),
        ),
        dilihatDokterLab: false,
      );
    });

    await _seenStorage.markLabSeen(patientId);
    await _seenStorage.unmarkDoctorLabSeen(patientId);

    _wsService.send({
      'type': 'lab_result_ready',
      'patient_id': patientId,
      'medical_record_id': medicalRecordId,
    });
  }

  Future<void> submitLabHasil({
    required String id,
    required String catatanHasil,
    String? fileName,
    List<LabExaminationItem> items = const [],
  }) async {
    _update(id, (p) {
      final order = p.labOrder;
      if (order == null) return p;
      return p.copyWith(
        labOrder: order.copyWith(
          status: LabOrderStatus.selesai,
          hasil: LabHasil(
            catatanHasil: catatanHasil,
            fileName: fileName,
            items: items,
          ),
        ),
        dilihatDokterLab: false,
      );
    });

    await _seenStorage.markLabSeen(id);
    await _seenStorage.unmarkDoctorLabSeen(id);

    _wsService.send({'type': 'lab_result_ready', 'patient_id': id});
  }
}

final seenNotificationStorageProvider = Provider<SeenNotificationStorage>((
  ref,
) {
  return SeenNotificationStorage();
});

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
/// The signed-in user's unread notifications. Each one is a visit (medical
/// record) waiting for this role, shown as a [Patient] (see
/// [MedicalHistory.toPatient]):
/// - doctor: their own visits waiting for them (also back from the lab),
/// - pharmacy: visits waiting for medicine,
/// - lab: visits waiting for the lab.
/// Only visits with activity in the last [window] notify; older ones are
/// still in the role's own lists.
class NotificationsNotifier extends StateNotifier<List<Patient>> {
  NotificationsNotifier({
    PatientApi? api,
    SeenNotificationStorage? seenStorage,
    WebSocketService? wsService,
    this.inAppNotifier,
    this.currentRole,
    this.currentUserId,
    DateTime Function()? clock,
  }) : _api = api ?? PatientApi(),
       _seenStorage = seenStorage ?? SeenNotificationStorage(),
       _wsService = wsService ?? WebSocketService(),
       _clock = clock ?? DateTime.now,
       super(const []) {
    // Without a session the request would only bounce with 401.
    if (currentRole != null) {
      Future.microtask(() => fetchRecentNotifications());
    }
    _initWebSocket();
    _initConnectionMonitor();
  }

  static const window = Duration(hours: 24);

  final PatientApi _api;
  final SeenNotificationStorage _seenStorage;
  final WebSocketService _wsService;
  final DateTime Function() _clock;
  final InAppNotificationNotifier? inAppNotifier;
  final UserRole? currentRole;

  /// The signed-in user's id; a doctor is only notified about visits
  /// assigned to them (the backend maps it to their medical personnel).
  final String? currentUserId;

  StreamSubscription? _wsSubscription;
  StreamSubscription? _connSubscription;
  bool _isFirstLoad = true;

  // The visits behind [state], by record id (see [recordFor]).
  Map<String, MedicalHistory> _records = const {};

  // WS events arriving close together are merged into one fetch.
  Timer? _eventFetchTimer;
  String? _pendingBannerPatientId;
  // Only the newest fetch may write state (older responses are dropped).
  int _fetchSeq = 0;

  /// The backend status of the visits this role is notified about.
  String? get _status => switch (currentRole) {
    UserRole.dokter => 'Menunggu Dokter',
    UserRole.pharmacy => 'Menunggu Obat',
    UserRole.lab => 'Menunggu Lab',
    _ => null,
  };

  /// WS events that may bring this role a new notification.
  bool _isEventForRole(Object? type) => switch (currentRole) {
    UserRole.dokter =>
      type == 'patient_assigned' ||
          type == 'patient_registered' ||
          type == 'lab_result_ready',
    UserRole.pharmacy => type == 'prescription_created',
    UserRole.lab => type == 'lab_order_created',
    _ => false,
  };

  void _initWebSocket() {
    _wsSubscription = _wsService.onEvent.listen((event) {
      final type = event['type'] ?? event['event'];
      if (type == 'ping' || type == 'pong') return;
      debugPrint('⚡ [NotificationsNotifier] Event received: $type');

      final patientId = event['patient_id']?.toString();
      if (patientId != null && _isEventForRole(type)) {
        _pendingBannerPatientId = patientId;
      }
      _scheduleEventFetch();
    });
  }

  void _scheduleEventFetch() {
    _eventFetchTimer?.cancel();
    _eventFetchTimer = Timer(const Duration(milliseconds: 400), () {
      final banner = _pendingBannerPatientId;
      _pendingBannerPatientId = null;
      fetchRecentNotifications(triggerBannerForPatientId: banner);
    });
  }

  void _initConnectionMonitor() {
    _connSubscription = _wsService.onConnectionChanged.listen((connected) {
      if (connected) {
        debugPrint(
          '🔄 [NotificationsNotifier] Reconnected to ship Wi-Fi! Triggering catch-up sync...',
        );
        fetchRecentNotifications();
      }
    });
  }

  /// Triggered when tablet screen wakes up / resumes from background.
  /// Only reconnects WebSocket if disconnected, without performing any HTTP requests.
  void ensureWebSocketConnected() {
    if (!_wsService.isConnected) {
      _wsService.connect();
    }
  }

  /// Triggered manually when tablet screen wakes up or user taps manual sync
  Future<void> catchUpSync() async {
    if (!_wsService.isConnected) {
      unawaited(_wsService.connect());
    }
    await fetchRecentNotifications();
  }

  /// The visit behind notification [p], to open it in the role's list.
  MedicalHistory? recordFor(Patient p) => _records[notificationKey(p)];

  bool _isUnread(Patient p) {
    final key = notificationKey(p);
    return switch (currentRole) {
      UserRole.dokter =>
        isLabResultForDoctor(p)
            ? !_seenStorage.isDoctorLabSeen(key)
            : !_seenStorage.isDoctorSeen(key),
      UserRole.pharmacy => !_seenStorage.isPharmacySeen(key),
      UserRole.lab => !_seenStorage.isLabSeen(key),
      _ => false,
    };
  }

  Future<void> fetchRecentNotifications({
    String? triggerBannerForPatientId,
  }) async {
    final status = _status;
    // A doctor without a known id would see everyone's patients.
    final userId = currentRole == UserRole.dokter ? currentUserId : null;
    if (status == null ||
        (currentRole == UserRole.dokter && (userId ?? '').isEmpty)) {
      state = const [];
      return;
    }

    final seq = ++_fetchSeq;
    try {
      await _seenStorage.load();
      final page = await _api.getMedicalHistoryPaginated(
        limit: 50,
        statusPenanganan: status,
        userId: userId,
      );
      if (!mounted || seq != _fetchSeq) return;

      final since = _clock().subtract(window);
      final recent = page.data.where((h) {
        final at = DateTime.tryParse(h.updatedAt ?? h.createdAt ?? '');
        return at != null && at.isAfter(since);
      }).toList();
      _records = {for (final h in recent) h.id: h};

      final unread = recent
          .map((h) => _withReadFlags(h.toPatient()))
          .where(_isUnread)
          .toList();

      // A floating banner for the visit that just came in.
      if (inAppNotifier != null) {
        Patient? fresh;
        if (triggerBannerForPatientId != null) {
          fresh = unread
              .where((p) => p.id == triggerBannerForPatientId)
              .firstOrNull;
        } else if (!_isFirstLoad) {
          final known = state.map(notificationKey).toSet();
          fresh = unread
              .where((p) => !known.contains(notificationKey(p)))
              .firstOrNull;
        }
        if (fresh != null) _dispatchBanner(fresh);
      }

      _isFirstLoad = false;
      state = unread;
    } catch (_) {}
  }

  Patient _withReadFlags(Patient p) {
    final key = notificationKey(p);
    return p.copyWith(
      dilihatDokter: _seenStorage.isDoctorSeen(key),
      dilihatDokterLab: _seenStorage.isDoctorLabSeen(key),
      dilihatPharmacy: _seenStorage.isPharmacySeen(key),
      dilihatLab: _seenStorage.isLabSeen(key),
    );
  }

  void _dispatchBanner(Patient p) {
    final identifier = p.nik.isNotEmpty ? p.nik : p.registerNo;
    final id = '${notificationKey(p)}_${DateTime.now().millisecondsSinceEpoch}';

    final item = switch (currentRole) {
      UserRole.dokter when isLabResultForDoctor(p) => InAppNotificationItem(
        id: 'lab_res_$id',
        title: 'Hasil Lab Selesai',
        message:
            'Hasil pemeriksaan laboratorium untuk ${p.nama} telah selesai.',
        type: InAppNotificationType.lab,
        patientId: p.id,
      ),
      UserRole.dokter => InAppNotificationItem(
        id: 'doc_$id',
        title: 'Pasien Siap Diperiksa',
        message: '${p.nama} ($identifier) menunggu di antrian dokter.',
        type: InAppNotificationType.doctor,
        patientId: p.id,
      ),
      UserRole.pharmacy => InAppNotificationItem(
        id: 'pharm_$id',
        title: 'Order Resep Baru',
        message: 'Resep obat baru untuk pasien ${p.nama} siap diracik.',
        type: InAppNotificationType.pharmacy,
        patientId: p.id,
      ),
      UserRole.lab => InAppNotificationItem(
        id: 'lab_ord_$id',
        title: 'Order Pemeriksaan Lab',
        message: 'Permintaan lab baru untuk pasien ${p.nama}.',
        type: InAppNotificationType.lab,
        patientId: p.id,
      ),
      _ => null,
    };
    if (item != null) inAppNotifier?.showNotification(item);
  }

  /// Drops the notification of visit [visitId] from the list.
  void _remove(String visitId) {
    state = state.where((n) => notificationKey(n) != visitId).toList();
  }

  /// Marks visit [visitId] (see [notificationKey]) as read.
  void markDoctorSeen(String visitId) {
    _seenStorage.markDoctorSeen(visitId);
    _remove(visitId);
  }

  void markDoctorLabSeen(String visitId) {
    _seenStorage.markDoctorLabSeen(visitId);
    _remove(visitId);
  }

  void markAllDoctorSeen() {
    _seenStorage.markAllDoctorSeen(
      state.where(isWaitingForDoctor).map(notificationKey),
    );
    _seenStorage.markAllDoctorLabSeen(
      state.where(isLabResultForDoctor).map(notificationKey),
    );
    state = const [];
  }

  void markPharmacySeen(String visitId) {
    _seenStorage.markPharmacySeen(visitId);
    _remove(visitId);
  }

  void markAllPharmacySeen() {
    _seenStorage.markAllPharmacySeen(state.map(notificationKey));
    state = const [];
  }

  void markLabSeen(String visitId) {
    _seenStorage.markLabSeen(visitId);
    _remove(visitId);
  }

  void markAllLabSeen() {
    _seenStorage.markAllLabSeen(state.map(notificationKey));
    state = const [];
  }

  @override
  void dispose() {
    _eventFetchTimer?.cancel();
    _wsSubscription?.cancel();
    _connSubscription?.cancel();
    super.dispose();
  }
}

final notificationsProvider =
    StateNotifierProvider<NotificationsNotifier, List<Patient>>((ref) {
      final api = ref.watch(patientApiProvider);
      final ws = ref.watch(webSocketServiceProvider);
      final seenStorage = ref.watch(seenNotificationStorageProvider);
      final inAppNotifier = ref.watch(inAppNotificationProvider.notifier);
      // Only rebuild (and refetch) when the signed-in role actually changes,
      // not on every auth status transition.
      final userRole = ref.watch(
        authControllerProvider.select((s) => s.session?.user.role),
      );
      final userId = ref.watch(
        authControllerProvider.select((s) => s.session?.user.id),
      );
      return NotificationsNotifier(
        api: api,
        wsService: ws,
        seenStorage: seenStorage,
        inAppNotifier: inAppNotifier,
        currentRole: userRole,
        currentUserId: userId,
      );
    });

final patientsProvider = StateNotifierProvider<PatientsNotifier, List<Patient>>(
  (ref) {
    final api = ref.watch(patientApiProvider);
    final ws = ref.watch(webSocketServiceProvider);
    final seenStorage = ref.watch(seenNotificationStorageProvider);
    final hasSession = ref.watch(
      authControllerProvider.select((s) => s.session != null),
    );
    return PatientsNotifier(
      api: api,
      wsService: ws,
      seenStorage: seenStorage,
      autoFetch: hasSession,
    );
  },
);

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
final patientDetailProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, id) async {
      final api = ref.watch(patientApiProvider);
      // Fetch detail and medical records in parallel.
      final recordsFuture = api.getMedicalRecords(id);
      unawaited(recordsFuture.then((_) {}, onError: (_) {}));
      final detail = await api.getPatientDetailRaw(id);
      // Also fetch medical records in case they are separated
      try {
        final records = await recordsFuture;
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
    this.statusPenanganan,
    this.userId,
    this.oldestFirst = false,
  }) : _api = api ?? PatientApi(),
       super([]) {
    if (autoFetch) {
      Future.microtask(() => fetchHistory());
    }
  }

  /// Queue order (oldest first) instead of newest first.
  final bool oldestFirst;

  int _byTime(MedicalHistory a, MedicalHistory b) {
    final timeA = a.createdAt ?? a.date ?? '';
    final timeB = b.createdAt ?? b.date ?? '';
    return oldestFirst ? timeA.compareTo(timeB) : timeB.compareTo(timeA);
  }

  final PatientApi _api;
  String? statusPenanganan;
  String? userId;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  int _currentPage = 1;
  int _totalPages = 1;
  int _total = 0;
  final int _limit = 10;
  bool _hasMore = true;
  String _currentSearch = '';
  Timer? _debounceTimer;
  // Bumped by every page-1 fetch. Responses from older requests (including
  // an in-flight loadMore) are dropped so they can't overwrite newer results.
  int _requestSeq = 0;

  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  int get total => _total;
  int get totalPages => _totalPages;
  int get currentPage => _currentPage;

  void setStatusPenanganan(String? newStatus) {
    if (statusPenanganan == newStatus) return;
    statusPenanganan = newStatus;
    fetchHistory(refresh: true);
  }

  void setUserId(String? newUserId) {
    if (userId == newUserId) return;
    userId = newUserId;
    fetchHistory(refresh: true);
  }

  void setDoctorId(String? newDoctorId) => setUserId(newDoctorId);

  Future<void> fetchHistory({bool refresh = false}) async {
    final seq = ++_requestSeq;
    if (refresh) {
      _currentPage = 1;
      _hasMore = true;
    }
    _isLoading = true;
    if (mounted) state = [...state];
    try {
      final res = await _api.getMedicalHistoryPaginated(
        limit: _limit,
        search: _currentSearch,
        statusPenanganan: statusPenanganan,
        userId: userId,
        order: oldestFirst ? 'asc' : 'desc',
      );
      if (seq != _requestSeq) return;
      _currentPage = res.page;
      _totalPages = res.totalPages;
      _total = res.total;
      _hasMore = res.page < res.totalPages && res.data.isNotEmpty;
      if (mounted) {
        final list = List<MedicalHistory>.from(res.data);
        list.sort(_byTime);
        state = list;
      }
    } catch (e) {
      debugPrint('MedicalHistoryNotifier.fetchHistory error: $e');
    } finally {
      // A newer fetch owns the loading flag now.
      if (seq == _requestSeq) {
        _isLoading = false;
        if (mounted) state = [...state];
      }
    }
  }

  Future<void> loadMore() async {
    if (_isLoadingMore || !_hasMore || _isLoading) return;
    final seq = _requestSeq;
    _isLoadingMore = true;
    if (mounted) state = [...state];
    try {
      final nextPage = _currentPage + 1;
      final res = await _api.getMedicalHistoryPaginated(
        page: nextPage,
        limit: _limit,
        search: _currentSearch,
        statusPenanganan: statusPenanganan,
        userId: userId,
        order: oldestFirst ? 'asc' : 'desc',
      );
      // The list was reset (search/filter/refresh) while this page loaded.
      if (seq != _requestSeq) return;
      _currentPage = res.page;
      _totalPages = res.totalPages;
      _total = res.total;
      _hasMore = res.page < res.totalPages && res.data.isNotEmpty;
      final existingIds = {for (final m in state) m.id};
      final newItems = res.data
          .where((m) => !existingIds.contains(m.id))
          .toList();
      final combined = [...state, ...newItems];
      combined.sort(_byTime);
      if (mounted) state = combined;
    } catch (e) {
      debugPrint('MedicalHistoryNotifier.loadMore error: $e');
    } finally {
      _isLoadingMore = false;
      if (mounted) state = [...state];
    }
  }

  void searchHistory(String query, {bool debounce = false}) {
    _debounceTimer?.cancel();
    final trimmed = query.trim();
    if (!debounce) {
      _currentSearch = trimmed;
      fetchHistory(refresh: true);
      return;
    }
    _debounceTimer = Timer(const Duration(milliseconds: 350), () {
      _currentSearch = trimmed;
      fetchHistory(refresh: true);
    });
  }

  /// Adds [history] or replaces the same visit. Other visits of the same
  /// patient stay as they are.
  void upsertHistory(MedicalHistory history) {
    final idx = state.indexWhere((h) => h.id == history.id);
    List<MedicalHistory> updated;
    if (idx >= 0) {
      updated = [...state.sublist(0, idx), history, ...state.sublist(idx + 1)];
    } else {
      updated = [history, ...state];
      _total++;
    }
    updated.sort(_byTime);
    state = updated;
  }

  void updateHistoryStatus({
    required String recordId,
    String? patientId,
    required String statusPenanganan,
    String? diagnosis,
    String? treatment,
    String? notes,
  }) {
    final idx = state.indexWhere(
      (h) =>
          h.id == recordId ||
          (patientId != null &&
              patientId.isNotEmpty &&
              h.patientId == patientId),
    );
    if (idx >= 0) {
      final current = state[idx];
      final updated = current.copyWith(
        statusPenanganan: statusPenanganan,
        diagnosis: (diagnosis != null && diagnosis.isNotEmpty)
            ? diagnosis
            : current.diagnosis,
        treatment: (treatment != null && treatment.isNotEmpty)
            ? treatment
            : current.treatment,
        notes: notes ?? current.notes,
      );
      state = [
        ...state.sublist(0, idx),
        updated,
        ...state.sublist(idx + 1),
      ];
    }
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
      // Rebuild (and refetch) only when the session/doctor filter changes,
      // not on every auth status transition.
      final (:hasSession, :userId) = ref.watch(
        authControllerProvider.select((s) {
          final user = s.session?.user;
          return (
            hasSession: s.session != null,
            userId: (user != null && user.role == UserRole.dokter)
                ? user.id
                : null,
          );
        }),
      );
      return MedicalHistoryNotifier(
        api: api,
        autoFetch: hasSession,
        userId: userId,
      );
    });

/// Provider family for fetching medical history filtered by a specific user ID via query param (?user_id=...)
final medicalHistoryByUserProvider = StateNotifierProvider.family<
    MedicalHistoryNotifier,
    List<MedicalHistory>,
    String?>((ref, userId) {
  final api = ref.watch(patientApiProvider);
  final hasSession = ref.watch(
    authControllerProvider.select((s) => s.session != null),
  );
  return MedicalHistoryNotifier(
    api: api,
    autoFetch: hasSession,
    userId: userId,
  );
});

/// Alias for backwards compatibility
final medicalHistoryByDoctorProvider = medicalHistoryByUserProvider;

/// Dedicated medical history provider for Pharmacy (Antrian Resep) filtered by status_penanganan = 'Menunggu Obat'
final pharmacyPrescriptionHistoryProvider =
    StateNotifierProvider<MedicalHistoryNotifier, List<MedicalHistory>>((ref) {
      final api = ref.watch(patientApiProvider);
      final hasSession = ref.watch(
        authControllerProvider.select((s) => s.session != null),
      );
      return MedicalHistoryNotifier(
        api: api,
        autoFetch: hasSession,
        statusPenanganan: 'Menunggu Obat',
        oldestFirst: true,
      );
    });

/// Dedicated medical history provider for Lab (Daftar Order Lab) filtered by status_penanganan = 'Menunggu Lab'
final labOrderHistoryProvider =
    StateNotifierProvider<MedicalHistoryNotifier, List<MedicalHistory>>((ref) {
      final api = ref.watch(patientApiProvider);
      final hasSession = ref.watch(
        authControllerProvider.select((s) => s.session != null),
      );
      return MedicalHistoryNotifier(
        api: api,
        autoFetch: hasSession,
        statusPenanganan: 'Menunggu Lab',
      );
    });
