import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/doctor.dart';
import '../domain/lab_order.dart';
import '../domain/patient.dart';
import '../domain/prescription_item.dart';
import '../../auth/presentation/auth_controller.dart';
import 'patient_api.dart';

/// Patient state management wired directly to [PatientApi] (GET/POST /api/v1/patients)
/// with support for pagination and infinite scroll (load more).
class PatientsNotifier extends StateNotifier<List<Patient>> {
  PatientsNotifier({PatientApi? api, bool autoFetch = true})
      : _api = api ?? PatientApi(),
        super(const []) {
    if (autoFetch) {
      Future.microtask(() => fetchPatients());
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

  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  int get total => _total;
  int get currentPage => _currentPage;

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
              status: p.status != PatientStatus.menungguDokter ? p.status : existing.status,
              dbStatus: p.dbStatus,
              diagnosa: p.diagnosa ?? existing.diagnosa,
              resep: p.resep.isNotEmpty ? p.resep : existing.resep,
              resepStatus: p.resepStatus ?? existing.resepStatus,
              labOrder: p.labOrder ?? existing.labOrder,
              vitals: existing.vitals,
              dilihatDokter: existing.dilihatDokter,
              dilihatPharmacy: existing.dilihatPharmacy,
              dilihatLab: existing.dilihatLab,
              dilihatDokterLab: existing.dilihatDokterLab,
            );
          }
          return p;
        }).toList();
      } else {
        // Prevent duplicate IDs when appending
        final existingIds = state.map((p) => p.id).toSet();
        final newItems = paginated.data.where((p) => !existingIds.contains(p.id)).toList();
        state = [...state, ...newItems];
      }
    } catch (e) {
      debugPrint('PatientsNotifier.fetchPatients error: $e');
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
        final latest = medRecords.last;
        final diag = latest['diagnosis']?.toString();
        final treatment = latest['treatment']?.toString() ?? '';
        final complaint = latest['complaint']?.toString();
        final docId = latest['doctor_id']?.toString() ?? latest['doctor']?['id']?.toString();

        List<ResepItem> resepItems = const [];
        if (treatment.isNotEmpty && treatment != 'Menunggu Pemeriksaan Dokter' && treatment != 'Pemeriksaan awal') {
          resepItems = [
            ResepItem(obat: treatment, dosis: '1x1', instruksi: latest['notes']?.toString() ?? ''),
          ];
        }

        final isExamined = diag != null && diag.isNotEmpty && diag != 'Pemeriksaan Umum';

        _update(id, (p) => p.copyWith(
          diagnosa: isExamined ? diag : p.diagnosa,
          status: isExamined ? PatientStatus.diperiksa : p.status,
          resep: resepItems.isNotEmpty ? resepItems : p.resep,
          resepStatus: resepItems.isNotEmpty ? (p.resepStatus ?? ResepStatus.baru) : p.resepStatus,
          keluhanUtama: (complaint != null && complaint.isNotEmpty && !complaint.startsWith('Kondisi:')) ? complaint : p.keluhanUtama,
          assignedDokterId: (docId != null && docId.isNotEmpty) ? docId : p.assignedDokterId,
        ));
      }
    } catch (e) {
      debugPrint('fetchPatientDetail error: $e');
    }
  }

  /// Triggers loading next page on scroll
  Future<void> loadMore({String? search, String? status}) async {
    if (!_hasMore || _isLoading || _isLoadingMore) return;
    await fetchPatients(refresh: false, search: search, status: status);
  }

  void _update(String id, Patient Function(Patient) updater) {
    state = [
      for (final p in state)
        if (p.id == id) updater(p) else p,
    ];
  }

  Future<Patient> addPatient(Patient patient) async {
    final created = await _api.createPatient(patient.toCreatePatientJson());

    // Attach local clinical intake fields (keluhan, vitals, assigned doctor)
    final fullPatient = created.copyWith(
      keluhanUtama: patient.keluhanUtama.isNotEmpty ? patient.keluhanUtama : created.keluhanUtama,
      durasiKeluhan: patient.durasiKeluhan,
      lokasiKeluhan: patient.lokasiKeluhan,
      vitals: patient.vitals,
      assignedDokterId: patient.assignedDokterId,
    );

    if (patient.assignedDokterId.isNotEmpty) {
      try {
        await _api.addMedicalRecord(created.id, {
          'doctor_id': patient.assignedDokterId,
          'ship_id': '3a7ff982-e187-49f8-a34e-95f775afda61',
          'port_id': 'f7d71b54-4c2c-4b10-a601-b82a604c7315',
          'complaint': patient.keluhanUtama.isNotEmpty ? patient.keluhanUtama : 'Pemeriksaan awal',
          'diagnosis': 'Pemeriksaan Umum',
          'treatment': 'Menunggu Pemeriksaan Dokter',
          'notes': 'Triage Awal Perawat',
          'date': DateTime.now().toIso8601String().split('T').first,
        });
      } catch (e) {
        debugPrint('addPatient medical record error: $e');
      }
    }

    state = [fullPatient, ...state.where((p) => p.id != patient.id && p.id != created.id)];
    return fullPatient;
  }

  Future<Patient> updatePatient(Patient patient) async {
    final updated = await _api.updatePatient(patient.id, patient.toCreatePatientJson());
    final fullPatient = patient.copyWith(
      nama: updated.nama,
      nik: updated.nik,
      jk: updated.jk,
      umur: updated.umur,
      alamat: updated.alamat,
      updatedAt: updated.updatedAt,
      assignedDokterId: patient.assignedDokterId,
      keluhanUtama: patient.keluhanUtama,
      durasiKeluhan: patient.durasiKeluhan,
      lokasiKeluhan: patient.lokasiKeluhan,
      vitals: patient.vitals,
    );

    if (patient.assignedDokterId.isNotEmpty) {
      try {
        await _api.addMedicalRecord(patient.id, {
          'doctor_id': patient.assignedDokterId,
          'ship_id': '3a7ff982-e187-49f8-a34e-95f775afda61',
          'port_id': 'f7d71b54-4c2c-4b10-a601-b82a604c7315',
          'complaint': patient.keluhanUtama.isNotEmpty ? patient.keluhanUtama : 'Pemeriksaan awal',
          'diagnosis': patient.diagnosa ?? 'Pemeriksaan Umum',
          'treatment': patient.resep.isNotEmpty
              ? patient.resep.map((r) => '${r.obat} ${r.dosis} (${r.instruksi})').join(', ')
              : 'Menunggu Pemeriksaan Dokter',
          'notes': 'Update Penugasan Dokter',
          'date': DateTime.now().toIso8601String().split('T').first,
        });
      } catch (e) {
        debugPrint('updatePatient medical record error: $e');
      }
    }

    _update(patient.id, (_) => fullPatient);
    return fullPatient;
  }

  void markDilihatDokter(String id) => _update(id, (p) => p.copyWith(dilihatDokter: true));
  void markDilihatDokterLab(String id) => _update(id, (p) => p.copyWith(dilihatDokterLab: true));
  void markDilihatPharmacy(String id) => _update(id, (p) => p.copyWith(dilihatPharmacy: true));
  void markDilihatLab(String id) => _update(id, (p) => p.copyWith(dilihatLab: true));

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
        diagnosa: diagnosa,
        resep: resep,
        resepStatus: ResepStatus.baru,
        labOrder: labOrder ?? p.labOrder,
        dilihatDokter: true,
      ),
    );

    try {
      final patient = state.firstWhere((p) => p.id == id);
      final treatmentText = resep.map((r) => '${r.obat} ${r.dosis} (${r.instruksi})').join(', ');

      final validDoctorIds = kDoctors.map((d) => d.id).toSet();
      String effectiveDoctorId = '8afc72cb-b1c5-4ea1-a438-b06c6ae4a99b'; // Dr. Budi Santoso fallback
      if (doctorId != null && doctorId.isNotEmpty && (validDoctorIds.contains(doctorId) || doctorId.length > 20)) {
        effectiveDoctorId = doctorId;
      } else if (patient.assignedDokterId.isNotEmpty && (validDoctorIds.contains(patient.assignedDokterId) || patient.assignedDokterId.length > 20)) {
        effectiveDoctorId = patient.assignedDokterId;
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
        'complaint': patient.keluhanUtama.isNotEmpty ? patient.keluhanUtama : 'Pemeriksaan klinis',
        'date': DateTime.now().toIso8601String().split('T').first,
        'status': 'Monitoring',
        if (labOrder != null) 'notes': 'Order Lab: ${labOrder.jenis} (${labOrder.catatan})',
      });
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

  void setResepStatus(String id, ResepStatus status) => _update(id, (p) => p.copyWith(resepStatus: status));

  void submitLabHasil({required String id, required String catatanHasil, String? fileName}) {
    _update(id, (p) {
      final order = p.labOrder;
      if (order == null) return p;
      return p.copyWith(
        labOrder: order.copyWith(status: LabOrderStatus.selesai, hasil: LabHasil(catatanHasil: catatanHasil, fileName: fileName)),
        dilihatDokterLab: false,
      );
    });
  }
}

final patientApiProvider = Provider<PatientApi>((ref) {
  return PatientApi();
});

final patientsProvider = StateNotifierProvider<PatientsNotifier, List<Patient>>((ref) {
  final api = ref.watch(patientApiProvider);
  final authState = ref.watch(authControllerProvider);
  final hasSession = authState.session != null;
  return PatientsNotifier(api: api, autoFetch: hasSession);
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

