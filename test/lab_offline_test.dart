import 'dart:io';
import 'dart:typed_data';

import 'package:bayan_rme/core/network/api_exception.dart';
import 'package:bayan_rme/core/offline/sync_service.dart';
import 'package:bayan_rme/features/patients/data/patient_api.dart';
import 'package:bayan_rme/features/patients/data/patient_repository.dart';
import 'package:bayan_rme/features/patients/domain/lab_order.dart';
import 'package:bayan_rme/features/patients/domain/medical_history.dart';
import 'package:bayan_rme/features/patients/domain/patient.dart';
import 'package:bayan_rme/features/patients/domain/vitals.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/offline_fakes.dart';

const _offline = ApiException(
  'Tidak dapat terhubung ke server.',
  isOffline: true,
);

/// A backend that can't be reached, listing [waiting] as "Menunggu Lab".
class _PatientApi extends PatientApi {
  List<MedicalHistory> waiting = const [];

  @override
  Future<Map<String, dynamic>> submitLabExaminations(
    String medRecId,
    dynamic data,
  ) async => throw _offline;

  @override
  Future<PaginatedPatients> getPatientsPaginated({
    int page = 1,
    int limit = 10,
    String? search,
    String? status,
  }) async => PaginatedPatients(
    data: const [],
    page: 1,
    limit: limit,
    total: 0,
    totalPages: 1,
  );

  @override
  Future<PaginatedMedicalHistory> getMedicalHistoryPaginated({
    int page = 1,
    int limit = 10,
    String? search,
    String? statusPenanganan,
    String? userId,
    bool includePendingPrescriptions = false,
    bool includeReferred = false,
    String sortBy = 'created_at',
    String order = 'desc',
  }) async => PaginatedMedicalHistory(
    data: waiting,
    page: 1,
    limit: limit,
    total: waiting.length,
    totalPages: 1,
  );
}

final _patient = Patient(
  id: 'srv-7',
  nama: 'Budi',
  nik: '3173051208950007',
  jk: Gender.l,
  umur: 30,
  alamat: 'Jl. Pelabuhan No. 12',
  keluhanUtama: 'Demam',
  durasiKeluhan: '',
  lokasiKeluhan: '',
  vitals: const Vitals(),
  assignedDokterId: 'doc-1',
  waktuMasuk: '10:00',
  updatedAt: DateTime(2026, 10, 18),
  labOrder: const LabOrder(id: 'lab-1', jenis: 'Darah lengkap'),
);

void main() {
  late FakeServerAdapter server;
  late InMemoryOutboxStore store;
  late SyncService sync;
  late _PatientApi api;
  late PatientsNotifier patients;
  late Directory tempDir;
  late Directory filesDir;

  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('lab_test');
    filesDir = await Directory('${tempDir.path}/outbox').create();
    server = FakeServerAdapter((_) => null); // offline
    store = InMemoryOutboxStore();
    sync = SyncService(
      store: store,
      dio: fakeDio(server),
      currentUserId: () async => 'lab-1',
      filesDir: () async => filesDir,
      retryInterval: null,
    );
    api = _PatientApi();
    patients = PatientsNotifier(api: api, sync: sync, autoFetch: false)
      ..upsertPatient(_patient);
  });

  tearDown(() async {
    patients.dispose();
    sync.dispose();
    await tempDir.delete(recursive: true);
  });

  Future<void> submit({String? filePath, List<int>? bytes}) =>
      patients.submitLabExaminations(
        medicalRecordId: 'rec-1',
        patientId: 'srv-7',
        notes: 'Normal',
        items: [
          {'parameter': 'Hb', 'value': '14'},
        ],
        fileName: 'hasil_darah.pdf',
        filePath: filePath,
        fileBytes: bytes == null ? null : Uint8List.fromList(bytes),
      );

  test('offline: the result is queued with a copy of its file', () async {
    final picked = File('${tempDir.path}/picker_tmp_123.pdf')
      ..writeAsBytesSync([1, 2, 3]);
    await submit(filePath: picked.path);

    final entry = store.rows.single;
    expect(
      '${entry.method} ${entry.path}',
      'POST /api/v1/medical-records/rec-1/lab-examinations',
    );
    expect(entry.label, 'Hasil lab: Budi');
    expect(entry.body?['notes'], 'Normal');
    // Kept under the file's own name, even if the picker's copy goes away.
    final kept = File(entry.files['file']!);
    expect(kept.path, endsWith('${Platform.pathSeparator}hasil_darah.pdf'));
    picked.deleteSync();
    expect(kept.existsSync(), isTrue);
    // Shown as done right away.
    expect(patients.state.single.labOrder?.status, LabOrderStatus.selesai);
  });

  test(
    'back online: sent as multipart under its name, then the copy is removed',
    () async {
      await submit(bytes: [1, 2, 3]);
      final kept = File(store.rows.single.files['file']!);

      server.handler = (_) => (status: 201, body: {});
      server.seen.clear();
      await sync.syncNow();

      final sent = server.seen.single.data as FormData;
      expect(sent.files.single.value.filename, 'hasil_darah.pdf');
      expect(Map.fromEntries(sent.fields)['notes'], 'Normal');
      expect(store.rows, isEmpty);
      expect(kept.existsSync(), isFalse);
      expect(filesDir.listSync(), isEmpty); // its folder too
    },
  );

  test('the lab queue hides visits whose result is queued', () async {
    api.waiting = [
      const MedicalHistory(
        id: 'rec-1',
        code: 'R1',
        patientId: 'srv-7',
        patientName: 'Budi',
      ),
      const MedicalHistory(
        id: 'rec-2',
        code: 'R2',
        patientId: 'srv-8',
        patientName: 'Ani',
      ),
    ];
    final queue = MedicalHistoryNotifier(
      api: api,
      autoFetch: false,
      statusPenanganan: 'Menunggu Lab',
      queuedVisitIds: () => visitsQueuedFor(sync, 'lab-examinations'),
    );
    addTearDown(queue.dispose);

    await submit();
    await queue.fetchHistory(refresh: true);

    expect(queue.state.map((h) => h.id), ['rec-2']);
  });
}
