import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_config.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/websocket_service.dart';
import '../../../core/offline/outbox_entry.dart';
import '../../../core/offline/sync_service.dart';
import '../../sync/presentation/sync_providers.dart';
import '../../../core/notifications/in_app_notification_manager.dart';
import '../../../core/notifications/in_app_notification_model.dart';
import '../domain/doctor.dart';
import '../domain/lab_order.dart';
import '../domain/lab_parameter.dart';
import '../domain/lab_test_type.dart';
import '../domain/medical_history.dart';
import '../domain/patient.dart';
import '../domain/pending_prescription.dart';
import '../domain/poli.dart';
import '../domain/prescription_item.dart';
import '../domain/vitals.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../auth/domain/user_role.dart';
import '../../auth/data/session_storage.dart';
import 'patient_api.dart';
import 'queued_records.dart';
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

/// [p] with prescription row [index] replaced by [obatBaru]; the row keeps
/// the originally prescribed medicine and the [alasan] for the change.
Patient withSubstitutedMedicine(
  Patient p,
  int index,
  String obatBaru,
  String alasan, {
  String? newSku,
  dynamic newJumlah,
  String? notes,
}) {
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
}

class PatientsNotifier extends StateNotifier<List<Patient>> {
  PatientsNotifier({
    PatientApi? api,
    SeenNotificationStorage? seenStorage,
    WebSocketService? wsService,
    SyncService? sync,
    bool autoFetch = true,
  }) : _api = api ?? PatientApi(),
       _seenStorage = seenStorage ?? SeenNotificationStorage(),
       _wsService = wsService ?? WebSocketService(),
       _ownsWsService = wsService == null,
       _sync = sync,
       super(const []) {
    if (autoFetch) {
      Future.microtask(() => fetchPatients());
      _initWebSocket();
    }
    _syncedSubscription = sync?.onSynced.listen((_) => _onSynced());
  }

  final PatientApi _api;

  /// Offline outbox; null means writes always go straight to the server.
  final SyncService? _sync;
  StreamSubscription<void>? _syncedSubscription;

  /// Patients registered while offline, by their outbox entry id, kept in
  /// the list until the server has them.
  final Map<String, Patient> _offlinePatients = {};
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

      final updatedList = _withQueuedStatus(
        [...brandNew, ...mergedExisting],
        await _queuedPatientStatus(),
      );
      if (!listEquals(state, updatedList) && mounted) {
        state = updatedList;
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _silentPollTimer?.cancel();
    _wsSubscription?.cancel();
    _syncedSubscription?.cancel();
    if (_ownsWsService) _wsService.dispose();
    super.dispose();
  }

  /// Requests the list's first page as the screen opens it (no search),
  /// only so the offline cache has it; the list shown doesn't change.
  Future<void> warmCache() async {
    await _api.getPatientsPaginated(limit: _limit);
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
      if (refresh) await _restoreOfflinePatients();

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
      final queuedStatus = await _queuedPatientStatus();
      if (seq != _requestSeq || !mounted) return;

      _currentPage = paginated.page;
      _totalPages = paginated.totalPages;
      _total = paginated.total;
      _hasMore = _currentPage < _totalPages;
      if (refresh) {
        final existingMap = {for (final p in state) p.id: p};
        state = _withOfflinePatients(paginated.data.map((p) {
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
        }).toList());
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
      state = _withQueuedStatus(state, queuedStatus);
    } catch (e) {
      debugPrint('fetchPatients error: $e');
      // Offline without a cached list: still list the patients registered
      // offline.
      if (refresh && mounted) state = _withOfflinePatients(state);
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

  /// Uploads an identity photo and returns its URL. Offline, the photo is
  /// kept in the outbox and a placeholder is returned in its place; the
  /// outbox puts the real URL into the patient data when it is sent.
  Future<String> uploadPhoto(File photo) async {
    if (!await _mustQueue()) {
      try {
        return await _api.uploadPatientPhoto(photo);
      } on ApiException catch (e) {
        if (!_canQueue(e)) rethrow;
      }
    }
    final sync = _sync!;
    final placeholder = 'offline-photo:${SyncService.newId()}';
    await sync.enqueue(
      method: 'POST',
      path: '${ApiConfig.patientsPath}/upload-photo',
      label: 'Foto identitas pasien',
      files: {'photo': await sync.keepFile(photo)},
      produces: {placeholder: 'result.url'},
    );
    return placeholder;
  }

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

    final createBody = patient.toCreatePatientJson(
      dob: patient.dob,
      bloodType: patient.bloodType,
      kodeKelurahan: patient.kodeKelurahan,
      namaWali: patient.namaWali,
      hubunganWali: patient.hubunganWali,
      keterangan: patient.keterangan,
      alergi: patient.alergi,
      photoUrl: patient.photoUrl,
      serviceShipCode: effectiveShipCode,
    );
    // Poli Umum needs no doctor: the first one to examine takes the visit.
    final visitBody =
        patient.assignedDokterId.isNotEmpty || isPoliUmum(patient.poliCode)
        ? _firstVisitBody(
            patient,
            shipId: shipId,
            portId: portId,
            effectiveShipCode: effectiveShipCode,
          )
        : null;

    if (await _mustQueue()) {
      return _queueNewPatient(patient, createBody, visitBody, effectiveShipCode);
    }
    final Patient created;
    try {
      created = await _api.createPatient(createBody);
    } on ApiException catch (e) {
      if (!_canQueue(e)) rethrow;
      return _queueNewPatient(patient, createBody, visitBody, effectiveShipCode);
    }

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
    if (visitBody != null) {
      try {
        await _api.addMedicalRecord(created.id, visitBody);
      } on ApiException catch (e) {
        if (_canQueue(e)) {
          // The patient is on the server; only the visit waits.
          await _sync!.enqueue(
            method: 'POST',
            path: _medicalRecordsPath(created.id),
            label: 'Kunjungan pertama: ${fullPatient.nama}',
            body: visitBody,
          );
        } else {
          debugPrint('addPatient medical record error: $e');
          visitError = e;
        }
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

    return fullPatient;
  }

  /// The first visit opened when a patient is registered: the nurse's triage
  /// (complaint, vitals) for the assigned doctor on ship [shipId] at harbor
  /// [portId]. Diagnosis and treatment are left for the doctor.
  Map<String, dynamic> _firstVisitBody(
    Patient patient, {
    required String shipId,
    required String portId,
    required String? effectiveShipCode,
  }) {
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

    return {
      'doctor_id': patient.assignedDokterId.isNotEmpty
          ? patient.assignedDokterId
          : null,
      if (patient.poliCode != null && patient.poliCode!.isNotEmpty)
        'poli_code': patient.poliCode,
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
    };
  }

  /// Keeps a new patient (and their first visit) on the device, to be sent
  /// once the server is reachable. The patient gets a client-made id; the
  /// outbox swaps it for the server's id before sending the visit.
  Future<Patient> _queueNewPatient(
    Patient patient,
    Map<String, dynamic> createBody,
    Map<String, dynamic>? visitBody,
    String? effectiveShipCode,
  ) async {
    final sync = _sync!;
    final localId = SyncService.newId();
    final entry = await sync.enqueue(
      method: 'POST',
      path: ApiConfig.patientsPath,
      label: 'Pasien baru: ${patient.nama}',
      body: {...createBody, 'id': localId},
      produces: {localId: 'result.id'},
    );
    if (visitBody != null) {
      await sync.enqueue(
        method: 'POST',
        path: _medicalRecordsPath(localId),
        label: 'Kunjungan pertama: ${patient.nama}',
        body: visitBody,
      );
    }

    final local = patient.copyWith(
      id: localId,
      serviceShipCode: effectiveShipCode,
      statusPenanganan: visitBody != null ? 'Menunggu Dokter' : null,
    );
    _offlinePatients[entry.id] = local;
    state = [local, ...state.where((p) => p.id != patient.id)];
    return local;
  }

  static String _medicalRecordsPath(String patientId) =>
      '${ApiConfig.patientsPath}/$patientId/medical-records';

  /// Whether a write must wait in the outbox: earlier writes are still
  /// queued and this one has to follow them.
  Future<bool> _mustQueue() async =>
      _sync != null && await _sync.hasPending();

  /// Whether a failed write can be queued: it never reached the server.
  bool _canQueue(ApiException e) => _sync != null && e.isOffline;

  /// Re-adds the patients registered offline (not on the server yet) to a
  /// freshly fetched list.
  /// The handling status of each patient whose update still waits in the
  /// outbox (e.g. after the doctor's exam offline), by patient id.
  Future<Map<String, String>> _queuedPatientStatus() async {
    final sync = _sync;
    if (sync == null) return const {};
    const prefix = '${ApiConfig.patientsPath}/';
    return {
      for (final e in await sync.entries())
        if (e.status == OutboxStatus.pending &&
            e.method == 'PUT' &&
            e.path.startsWith(prefix) &&
            !e.path.substring(prefix.length).contains('/') &&
            e.body?['status_penanganan'] is String)
          e.path.substring(prefix.length): e.body!['status_penanganan'] as String,
    };
  }

  /// [patients] showing the status from [queued] (offline the fetched list
  /// is the cached one, from before the change).
  static List<Patient> _withQueuedStatus(
    List<Patient> patients,
    Map<String, String> queued,
  ) {
    if (queued.isEmpty) return patients;
    return [
      for (final p in patients)
        queued[p.id] == null
            ? p
            : p.copyWith(statusPenanganan: queued[p.id]),
    ];
  }

  /// The patients registered offline, read back from the outbox (kept on
  /// the device), e.g. when the app was restarted before they were sent.
  Future<void> _restoreOfflinePatients() async {
    final sync = _sync;
    if (sync == null) return;
    for (final entry in await sync.entries()) {
      final body = entry.body;
      if (entry.status != OutboxStatus.pending ||
          entry.method != 'POST' ||
          entry.path != ApiConfig.patientsPath ||
          body == null ||
          _offlinePatients.containsKey(entry.id)) {
        continue;
      }
      _offlinePatients[entry.id] = Patient.fromApiJson(body);
    }
  }

  List<Patient> _withOfflinePatients(List<Patient> fetched) {
    if (_offlinePatients.isEmpty) return fetched;
    final ids = {for (final p in fetched) p.id};
    return [
      ..._offlinePatients.values.where((p) => !ids.contains(p.id)),
      ...fetched,
    ];
  }

  /// After the outbox sent something: forget the offline patients whose
  /// registration has gone out, and reload the server's version.
  Future<void> _onSynced() async {
    final waiting = {for (final e in await _sync!.entries()) e.id};
    _offlinePatients.removeWhere((entryId, _) => !waiting.contains(entryId));
    if (mounted) await fetchPatients();
  }

  /// Adds a new clinical visit (medical record) to an existing patient
  /// via POST /api/v1/patients/:id/medical-records and updates patient vitals / status.
  /// Offline, both are kept in the outbox and sent later.
  Future<void> addKunjungan({
    required String patientId,
    required Map<String, dynamic> recordData,
    Map<String, dynamic>? patientUpdates,
  }) async {
    var queued = await _mustQueue();
    if (!queued) {
      // 1. Post to /api/v1/patients/:id/medical-records
      try {
        await _api.addMedicalRecord(patientId, recordData);
      } on ApiException catch (e) {
        if (!_canQueue(e)) rethrow;
        queued = true;
      }
    }

    final hasUpdates = patientUpdates != null && patientUpdates.isNotEmpty;
    if (queued) {
      final nama = state.where((p) => p.id == patientId).firstOrNull?.nama;
      await _sync!.enqueue(
        method: 'POST',
        path: _medicalRecordsPath(patientId),
        label: 'Kunjungan baru: ${nama ?? 'pasien'}',
        body: recordData,
      );
      if (hasUpdates) {
        await _sync.enqueue(
          method: 'PUT',
          path: '${ApiConfig.patientsPath}/$patientId',
          label: 'Status & vital pasien: ${nama ?? 'pasien'}',
          body: patientUpdates,
        );
      }
    } else {
      // 2. Update patient vitals & status_penanganan if provided
      if (hasUpdates) {
        try {
          await _api.updatePatient(patientId, patientUpdates);
        } catch (e) {
          debugPrint('updatePatient error in addKunjungan: $e');
        }
      }

    }

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
  /// Offline, the change is kept in the outbox and shown right away.
  Future<Patient> updatePatient(Patient patient) async {
    final body = patient.toCreatePatientJson(
      dob: patient.dob,
      bloodType: patient.bloodType,
      kodeKelurahan: patient.kodeKelurahan,
      namaWali: patient.namaWali,
      hubunganWali: patient.hubunganWali,
      keterangan: patient.keterangan,
      alergi: patient.alergi,
      photoUrl: patient.photoUrl,
    );
    if (await _mustQueue()) return _queuePatientUpdate(patient, body);
    final Patient updated;
    try {
      updated = await _api.updatePatient(patient.id, body);
    } on ApiException catch (e) {
      if (!_canQueue(e)) rethrow;
      return _queuePatientUpdate(patient, body);
    }
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

  Future<Patient> _queuePatientUpdate(
    Patient patient,
    Map<String, dynamic> body,
  ) async {
    await _sync!.enqueue(
      method: 'PUT',
      path: '${ApiConfig.patientsPath}/${patient.id}',
      label: 'Ubah data pasien: ${patient.nama}',
      body: body,
    );
    // A patient registered offline: keep their local copy current too.
    for (final MapEntry(key: entryId, value: p) in [
      ..._offlinePatients.entries,
    ]) {
      if (p.id == patient.id) _offlinePatients[entryId] = patient;
    }
    _update(patient.id, (_) => patient);
    return patient;
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

  /// The nurse's edit of a visit still waiting for the doctor (clinic,
  /// doctor, complaint, vitals): PATCH /patients/:id/medical-records/:record,
  /// kept in the outbox while offline. The handling status is left as is.
  Future<void> updateVisit({
    required String patientId,
    required String recordId,
    required Map<String, dynamic> body,
  }) async {
    final path = '${_medicalRecordsPath(patientId)}/$recordId';
    final nama = state.where((p) => p.id == patientId).firstOrNull?.nama;
    Future<void> queue() => _sync!.enqueue(
      method: 'PATCH',
      path: path,
      label: 'Edit kunjungan: ${nama ?? 'pasien'}',
      body: body,
    );
    if (await _mustQueue()) return queue();
    try {
      await _api.patchMedicalRecord(patientId, recordId, body);
    } on ApiException catch (e) {
      if (!_canQueue(e)) rethrow;
      await queue();
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
    final statusPenanganan =
        body['status_penanganan']?.toString() ?? 'Menunggu Obat';
    // Referred: the other doctor takes the patient over.
    final referredTo = body['referral'] is Map
        ? (body['referral'] as Map)['to_doctor_id']?.toString()
        : null;

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
        assignedDokterId: referredTo ?? p.assignedDokterId,
        dilihatDokter: true,
      ),
    );

    // Built now, so a queued update carries this exam's status.
    final currentPatient = state.where((p) => p.id == patientId).firstOrNull;
    final updatePayload = currentPatient?.toCreatePatientJson(
      statusPenanganan: statusPenanganan,
    );

    // Offline: kept in the outbox, sent with the patient update later.
    if (await _mustQueue()) {
      return _queueExam(patientId, recordId, body, updatePayload);
    }

    try {
      try {
        await _api.patchMedicalRecord(patientId, recordId, body);
      } on ApiException catch (e) {
        if (!_canQueue(e)) rethrow;
        return await _queueExam(patientId, recordId, body, updatePayload);
      }

      // Sync status_penanganan to patient endpoint
      try {
        if (updatePayload != null) {
          await _api.updatePatient(patientId, updatePayload);
          debugPrint(
            '✅ [patchMedicalRecord] Successfully updated patient status_penanganan to $statusPenanganan',
          );
        }
      } catch (e) {
        debugPrint('Failed to sync status_penanganan to patient: $e');
      }
    } catch (e) {
      debugPrint('Failed to patch medical record: $e');
      rethrow;
    }
  }

  /// The doctor's exam (diagnosis, treatment, prescription, lab order) and
  /// the patient's new handling status, kept in the outbox while offline.
  Future<void> _queueExam(
    String patientId,
    String recordId,
    Map<String, dynamic> body,
    Map<String, dynamic>? patientUpdate,
  ) async {
    final sync = _sync!;
    final nama = state.where((p) => p.id == patientId).firstOrNull?.nama;
    await sync.enqueue(
      method: 'PATCH',
      path: '${_medicalRecordsPath(patientId)}/$recordId',
      label: 'Pemeriksaan dokter: ${nama ?? 'pasien'}',
      body: body,
    );
    if (patientUpdate != null) {
      await sync.enqueue(
        method: 'PUT',
        path: '${ApiConfig.patientsPath}/$patientId',
        label: 'Status pasien: ${nama ?? 'pasien'}',
        body: patientUpdate,
      );
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
    _update(
      id,
      (p) => withSubstitutedMedicine(
        p,
        index,
        obatBaru,
        alasan,
        newSku: newSku,
        newJumlah: newJumlah,
        notes: notes,
      ),
    );
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

    void markDispensed() => _update(
      patientId,
      (p) => p.copyWith(
        resepStatus: ResepStatus.selesai,
        statusPenanganan: 'Selesai',
      ),
    );

    // Offline: kept in the outbox, shown as handed over right away.
    Future<void> queue() async {
      final nama = state.where((p) => p.id == patientId).firstOrNull?.nama;
      await _sync!.enqueue(
        method: 'POST',
        path: ApiConfig.medicalRecordDispensePath(medRecId),
        label: 'Penyerahan obat: ${nama ?? 'pasien'}',
        body: body,
      );
      markDispensed();
    }

    if (await _mustQueue()) return queue();
    try {
      await _api.dispensePrescription(medRecId, body);
      debugPrint(
        '✅ [dispensePrescription] Successfully dispensed prescription for medRecId $medRecId',
      );
    } on ApiException catch (e) {
      if (_canQueue(e)) return queue();
      debugPrint(
        '❌ [dispensePrescription] Failed to dispense prescription for medRecId $medRecId: $e',
      );
      rethrow;
    }

    markDispensed();

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
    String? sampleReceivedAt,
    String? fileName,
    String? filePath,
    Uint8List? fileBytes,
  }) async {
    final map = <String, dynamic>{
      'notes': notes,
      'conclusion': conclusion ?? '',
      'status': status,
      'items': jsonEncode(items),
      'sample_received_at': ?sampleReceivedAt,
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

    final hasPath = filePath != null && filePath.isNotEmpty;
    final hasBytes = fileBytes != null && fileBytes.isNotEmpty;

    void markDone() {
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
    }

    // Offline: kept in the outbox with a copy of the file.
    Future<void> queue() async {
      final sync = _sync!;
      final nama = state.where((p) => p.id == patientId).firstOrNull?.nama;
      await sync.enqueue(
        method: 'POST',
        path: ApiConfig.medicalRecordLabExaminationsPath(medicalRecordId),
        label: 'Hasil lab: ${nama ?? 'pasien'}',
        body: map,
        files: {
          if (hasPath)
            'file': await sync.keepFile(File(filePath), name: fileName)
          else if (hasBytes)
            'file': await sync.keepBytes(
              fileBytes,
              fileName ?? 'hasil_lab.pdf',
            ),
        },
      );
      markDone();
      await _seenStorage.markLabSeen(patientId);
      await _seenStorage.unmarkDoctorLabSeen(patientId);
    }

    if (await _mustQueue()) return queue();

    final formData = FormData.fromMap({
      ...map,
      if (hasPath)
        'file': await MultipartFile.fromFile(
          filePath,
          filename: fileName ?? filePath.split(Platform.pathSeparator).last,
        )
      else if (hasBytes)
        'file': MultipartFile.fromBytes(
          fileBytes,
          filename: fileName ?? 'hasil_lab.pdf',
        ),
    });

    debugPrint(
      '🚀 [submitLabExaminations] POST /api/v1/medical-records/$medicalRecordId/lab-examinations (multipart/form-data) notes: $notes, conclusion: $conclusion, status: $status, items: ${jsonEncode(items)}, file: ${fileName ?? filePath}',
    );
    try {
      await _api.submitLabExaminations(medicalRecordId, formData);
    } on ApiException catch (e) {
      if (_canQueue(e)) return queue();
      debugPrint('⚠️ [submitLabExaminations] API error: $e');
      rethrow;
    }

    markDone();
    await _seenStorage.markLabSeen(patientId);
    await _seenStorage.unmarkDoctorLabSeen(patientId);

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
  final ws = WebSocketService(
    // The stored session has the refreshed token; a session that wasn't
    // remembered is only in memory.
    accessToken: () async =>
        (await SessionStorage().read())?.token ??
        ref.read(authControllerProvider).session?.token,
  );
  ref.onDispose(() => ws.dispose());
  // Only a signed-in user may connect; a new login may be another ship.
  ref.listen<String?>(
    authControllerProvider.select((s) => s.session?.user.id),
    (previous, userId) {
      ws.disconnect();
      if (userId != null) ws.connect();
    },
  );
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
        includePendingPrescriptions: currentRole == UserRole.pharmacy,
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
    final sync = ref.watch(syncServiceProvider);
    final hasSession = ref.watch(
      authControllerProvider.select((s) => s.session != null),
    );
    return PatientsNotifier(
      api: api,
      wsService: ws,
      seenStorage: seenStorage,
      sync: sync,
      autoFetch: hasSession,
    );
  },
);

/// Shown when [doctorsProvider] has no doctors: offline before the list was
/// ever downloaded on this device.
const String doctorsUnavailableMessage =
    'Daftar dokter belum tersimpan di perangkat. Sambungkan ke internet '
    'sekali agar daftar dokter terunduh.';

/// The ship's doctors. Offline, the last list kept on the device is used
/// (see `masterDataPaths`); empty when there is none yet.
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

/// The lab request form's tests. Offline, the last list kept on the device
/// is used (see `masterDataPaths`); empty when there is none yet.
/// The lab result form rows (master data, kept for offline use).
final labParametersProvider = FutureProvider<List<LabParameter>>((ref) async {
  try {
    return await ref.watch(patientApiProvider).getLabParameters();
  } catch (e) {
    debugPrint('labParametersProvider error: $e');
    return [];
  }
});

final labTestsProvider = FutureProvider<List<LabTestType>>((ref) async {
  try {
    return await ref.watch(patientApiProvider).getLabTests();
  } catch (e) {
    debugPrint('labTestsProvider error: $e');
    return [];
  }
});

/// Fetches full patient details directly from GET /api/v1/patients/:id
final patientDetailProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, id) async {
      final api = ref.watch(patientApiProvider);
      final queued = await QueuedRecords.of(ref.watch(syncServiceProvider));
      final queuedVisits = queued.visitsOf(id);
      // Registered offline: not on the server yet, shown from the device.
      final newPatient = queued.patients[id];
      if (newPatient != null) {
        return {...newPatient, 'medical_records': queuedVisits};
      }

      // Fetch detail and medical records in parallel.
      final recordsFuture = api.getMedicalRecords(id);
      unawaited(recordsFuture.then((_) {}, onError: (_) {}));
      var detail = await api.getPatientDetailRaw(id);
      // Also fetch medical records in case they are separated
      try {
        final records = await recordsFuture;
        if (records.isNotEmpty) {
          final existing = detail['medical_records'];
          if (existing == null || (existing is List && existing.isEmpty)) {
            detail = {...detail, 'medical_records': records};
          }
        }
      } catch (_) {}
      // Visits added offline, not on the server (or in its cached copy) yet.
      if (queuedVisits.isNotEmpty) {
        final records = detail['medical_records'];
        detail = {
          ...detail,
          'medical_records': [
            ...queuedVisits,
            if (records is List) ...records,
          ],
        };
      }
      return detail;
    });

class MedicalHistoryNotifier extends StateNotifier<List<MedicalHistory>> {
  MedicalHistoryNotifier({
    PatientApi? api,
    bool autoFetch = true,
    this.statusPenanganan,
    this.userId,
    this.oldestFirst = false,
    this.includePendingPrescriptions = false,
    this.includeReferred = false,
    this.queuedVisitIds,
    this.queuedExams,
    this.queuedVisits,
  }) : _api = api ?? PatientApi(),
       _defaultStatus = statusPenanganan,
       _defaultUserId = userId,
       super([]) {
    if (autoFetch) {
      Future.microtask(() => fetchHistory());
    }
  }

  /// Queue order (oldest first) instead of newest first.
  final bool oldestFirst;

  /// The pharmacy queue: "Menunggu Obat" also lists the visits with medicine
  /// still to dispense (a prescription given with a lab referral).
  final bool includePendingPrescriptions;

  /// A doctor's history: also the visits they referred to another doctor.
  final bool includeReferred;

  bool _withPending(String? status) =>
      includePendingPrescriptions && includesPharmacyQueue(status);

  // The list as it opens, before any filter the user picks.
  final String? _defaultStatus;
  final String? _defaultUserId;

  /// Requests the list's first page as it opens (its own filter, no search),
  /// only so the offline cache has it; the list shown doesn't change.
  Future<void> warmCache() async {
    await _api.getMedicalHistoryPaginated(
      limit: _limit,
      search: '',
      statusPenanganan: _defaultStatus,
      userId: _defaultUserId,
      includePendingPrescriptions: _withPending(_defaultStatus),
      includeReferred: includeReferred,
      order: oldestFirst ? 'asc' : 'desc',
    );
  }

  /// The visits already handled on this device whose change still waits in
  /// the outbox. A queue list (e.g. "Menunggu Obat") hides them: offline its
  /// pages come from the cache, which still lists them.
  final Future<Set<String>> Function()? queuedVisitIds;

  /// The doctor's exams still waiting in the outbox, by visit (see
  /// [examsQueuedFor]). Shown in the list right away: offline its pages
  /// come from the cache, from before the exam.
  final Future<Map<String, Map<String, dynamic>>> Function()? queuedExams;

  /// The visits registered offline, not on the server yet: listed on top
  /// when they fit the list's filter (see [_queuedVisitsShown]).
  final Future<List<MedicalHistory>> Function()? queuedVisits;

  /// The [queuedVisits] this list shows: not already in [fetched], with the
  /// list's status, and matching the search. Lists of one user's visits
  /// leave them out (the server decides whose visit it is).
  Future<List<MedicalHistory>> _queuedVisitsShown(
    List<MedicalHistory> fetched,
  ) async {
    if (queuedVisits == null || userId != null) return const [];
    final ids = {for (final h in fetched) h.id};
    final search = _currentSearch.toLowerCase();
    return [
      for (final h in await queuedVisits!())
        if (!ids.contains(h.id) &&
            (statusPenanganan == null ||
                h.statusPenanganan == statusPenanganan) &&
            (search.isEmpty || h.patientName.toLowerCase().contains(search)))
          h,
    ];
  }

  /// [fetched] with the changes still in the outbox: visits handled offline
  /// hidden ([queuedVisitIds]), exams applied ([queuedExams]). Also returns
  /// how many were hidden.
  Future<(List<MedicalHistory>, int)> _withQueued(
    List<MedicalHistory> fetched,
  ) async {
    final hidden = await queuedVisitIds?.call() ?? const <String>{};
    final exams = await queuedExams?.call() ?? const {};
    if (hidden.isEmpty && exams.isEmpty) return (fetched, 0);
    final kept = [
      for (final h in fetched)
        if (!hidden.contains(h.id))
          exams[h.id] == null ? h : _withExam(h, exams[h.id]!),
    ];
    return (kept, fetched.length - kept.length);
  }

  /// [h] after the doctor's exam [exam] (the PATCH body), as
  /// [updateHistoryStatus] shows it.
  static MedicalHistory _withExam(MedicalHistory h, Map<String, dynamic> exam) {
    String? text(String key) {
      final value = exam[key]?.toString().trim();
      return (value == null || value.isEmpty) ? null : value;
    }

    return h.copyWith(
      statusPenanganan: text('status_penanganan') ?? h.statusPenanganan,
      // A nurse's edit of a visit still waiting for the doctor.
      complaint: text('complaint') ?? h.complaint,
      poliCode: text('poli_code') ?? h.poliCode,
      diagnosis: text('diagnosis') ?? h.diagnosis,
      treatment: text('treatment') ?? h.treatment,
      notes: exam.containsKey('note') ? exam['note']?.toString() : h.notes,
    );
  }

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
        includePendingPrescriptions: _withPending(statusPenanganan),
        includeReferred: includeReferred,
        order: oldestFirst ? 'asc' : 'desc',
      );
      final (data, hidden) = await _withQueued(res.data);
      final offline = await _queuedVisitsShown(data);
      if (seq != _requestSeq) return;
      _currentPage = res.page;
      _totalPages = res.totalPages;
      _total = res.total - hidden + offline.length;
      _hasMore = res.page < res.totalPages && res.data.isNotEmpty;
      if (mounted) {
        final list = [...offline, ...data];
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
        includePendingPrescriptions: _withPending(statusPenanganan),
        includeReferred: includeReferred,
        order: oldestFirst ? 'asc' : 'desc',
      );
      final (data, hidden) = await _withQueued(res.data);
      // The list was reset (search/filter/refresh) while this page loaded.
      if (seq != _requestSeq) return;
      _currentPage = res.page;
      _totalPages = res.totalPages;
      _total = res.total - hidden;
      _hasMore = res.page < res.totalPages && res.data.isNotEmpty;
      final existingIds = {for (final m in state) m.id};
      final newItems = data
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
      final sync = ref.watch(syncServiceProvider);
      return MedicalHistoryNotifier(
        api: api,
        autoFetch: hasSession,
        userId: userId,
        queuedExams: () => examsQueuedFor(sync),
        queuedVisits: () => _queuedVisitHistories(ref),
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
  final sync = ref.watch(syncServiceProvider);
  return MedicalHistoryNotifier(
    api: api,
    autoFetch: hasSession,
    userId: userId,
    includeReferred: true,
    queuedExams: () => examsQueuedFor(sync),
  );
});

/// Alias for backwards compatibility
final medicalHistoryByDoctorProvider = medicalHistoryByUserProvider;

/// Dedicated medical history provider for Pharmacy (Antrian Resep) filtered by status_penanganan = 'Menunggu Obat',
/// plus the visits with a prescription given with a lab referral.
final pharmacyPrescriptionHistoryProvider =
    StateNotifierProvider<MedicalHistoryNotifier, List<MedicalHistory>>((ref) {
      final api = ref.watch(patientApiProvider);
      final hasSession = ref.watch(
        authControllerProvider.select((s) => s.session != null),
      );
      final sync = ref.watch(syncServiceProvider);
      return MedicalHistoryNotifier(
        api: api,
        autoFetch: hasSession,
        statusPenanganan: 'Menunggu Obat',
        oldestFirst: true,
        includePendingPrescriptions: true,
        queuedVisitIds: () => visitsQueuedFor(sync, 'dispense'),
        queuedExams: () => examsQueuedFor(sync),
      );
    });

/// The visits with a `POST /medical-records/{id}/[action]` (e.g.
/// 'dispense') still waiting in the outbox.
/// The visits registered offline (see [QueuedRecords]), with their patient
/// and doctor filled in from what the device knows.
Future<List<MedicalHistory>> _queuedVisitHistories(Ref ref) async {
  final queued = await QueuedRecords.of(ref.read(syncServiceProvider));
  if (queued.visits().isEmpty) return const [];
  final patients = ref.read(patientsProvider);
  final doctors = ref.read(doctorsProvider).valueOrNull ?? const <Doctor>[];
  return [
    for (final visit in queued.visits(
      patient: (id) =>
          patients.where((p) => p.id == id).firstOrNull?.toCreatePatientJson(),
      doctor: (id) => switch (doctors.where((d) => d.id == id).firstOrNull) {
        final d? => {'id': d.id, 'name': d.nama, 'sip': ?d.sip},
        null => null,
      },
    ))
      MedicalHistory.fromApiJson(visit),
  ];
}

/// The doctor's exams (`PATCH /patients/{id}/medical-records/{record}`)
/// still waiting in the outbox: each visit's fields, later exams on top.
Future<Map<String, Map<String, dynamic>>> examsQueuedFor(
  SyncService? sync,
) async {
  if (sync == null) return const {};
  final pattern = RegExp(r'/patients/[^/]+/medical-records/([^/]+)$');
  final exams = <String, Map<String, dynamic>>{};
  for (final entry in await sync.entries()) {
    if (entry.status != OutboxStatus.pending || entry.method != 'PATCH') {
      continue;
    }
    final recordId = pattern.firstMatch(entry.path)?.group(1);
    if (recordId != null) {
      exams[recordId] = {...?exams[recordId], ...?entry.body};
    }
  }
  return exams;
}

Future<Set<String>> visitsQueuedFor(SyncService? sync, String action) async {
  if (sync == null) return const {};
  final pattern = RegExp('/medical-records/([^/]+)/$action\$');
  return {
    for (final entry in await sync.entries())
      if (entry.status == OutboxStatus.pending && entry.method == 'POST')
        if (pattern.firstMatch(entry.path) case final match?) match.group(1)!,
  };
}

/// Dedicated medical history provider for Lab (Daftar Order Lab) filtered by status_penanganan = 'Menunggu Lab'
final labOrderHistoryProvider =
    StateNotifierProvider<MedicalHistoryNotifier, List<MedicalHistory>>((ref) {
      final api = ref.watch(patientApiProvider);
      final hasSession = ref.watch(
        authControllerProvider.select((s) => s.session != null),
      );
      final sync = ref.watch(syncServiceProvider);
      return MedicalHistoryNotifier(
        api: api,
        autoFetch: hasSession,
        statusPenanganan: 'Menunggu Lab',
        queuedVisitIds: () => visitsQueuedFor(sync, 'lab-examinations'),
        queuedExams: () => examsQueuedFor(sync),
      );
    });
