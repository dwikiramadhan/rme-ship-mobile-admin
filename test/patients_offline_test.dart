import 'dart:io';

import 'package:bayan_rme/core/network/api_exception.dart';
import 'package:bayan_rme/core/offline/outbox_entry.dart';
import 'package:bayan_rme/core/offline/sync_service.dart';
import 'package:bayan_rme/features/patients/data/patient_api.dart';
import 'package:bayan_rme/features/patients/data/patient_repository.dart';
import 'package:bayan_rme/features/patients/domain/patient.dart';
import 'package:bayan_rme/features/patients/domain/vitals.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/offline_fakes.dart';

const _offline = ApiException('Tidak dapat terhubung ke server.', isOffline: true);

/// A backend that can't be reached, or (once [online]) answers with
/// [serverPatients]. Counts the writes that reached it.
class _PatientApi extends PatientApi {
  bool online = false;
  int writes = 0;
  List<Patient> serverPatients = const [];

  Future<void> _write() async {
    if (!online) throw _offline;
    writes++;
  }

  @override
  Future<Patient> createPatient(Map<String, dynamic> body) async {
    await _write();
    return _patient.copyWith(id: 'srv-1');
  }

  @override
  Future<void> addMedicalRecord(String patientId, Map<String, dynamic> body) =>
      _write();

  @override
  Future<Patient> updatePatient(String id, Map<String, dynamic> body) async {
    await _write();
    return _patient.copyWith(id: id);
  }

  @override
  Future<Map<String, dynamic>> patchMedicalRecord(
    String patientId,
    String recordId,
    Map<String, dynamic> body,
  ) async {
    await _write();
    return {};
  }

  @override
  Future<String> uploadPatientPhoto(File photo) async {
    await _write();
    return '/uploads/photo.jpg';
  }

  @override
  Future<PaginatedPatients> getPatientsPaginated({
    int page = 1,
    int limit = 10,
    String? search,
    String? status,
  }) async {
    return PaginatedPatients(
      data: serverPatients,
      page: 1,
      limit: limit,
      total: serverPatients.length,
      totalPages: 1,
    );
  }
}

final _patient = Patient(
  id: 'Q123',
  nama: 'Budi',
  nik: '3173051208950007',
  jk: Gender.l,
  umur: 30,
  alamat: 'Jl. Pelabuhan No. 12',
  keluhanUtama: 'Demam',
  durasiKeluhan: '',
  lokasiKeluhan: '',
  vitals: const Vitals(nadi: '80'),
  assignedDokterId: 'doc-1',
  waktuMasuk: '10:00',
  serviceShipCode: 'RSK-001',
  updatedAt: DateTime(2026, 10, 16),
);

void main() {
  late InMemoryOutboxStore store;
  late FakeServerAdapter server;
  late SyncService sync;
  late _PatientApi api;
  late PatientsNotifier notifier;
  late Directory tempDir;

  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    // The exam marks notifications seen in secure storage.
    FlutterSecureStorage.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('outbox_test');
    store = InMemoryOutboxStore();
    server = FakeServerAdapter((_) => null);
    sync = SyncService(
      store: store,
      dio: fakeDio(server),
      currentUserId: () async => 'nurse-1',
      filesDir: () async => tempDir,
      retryInterval: null,
    );
    api = _PatientApi();
    notifier = PatientsNotifier(api: api, sync: sync, autoFetch: false);
  });

  tearDown(() async {
    notifier.dispose();
    sync.dispose();
    await tempDir.delete(recursive: true);
  });

  test('offline: a new patient and first visit are kept and listed', () async {
    final local = await notifier.addPatient(
      _patient,
      shipId: 'ship-1',
      portId: 'port-bpn',
    );

    expect(local.id, isNot('Q123'));
    expect(notifier.state.map((p) => p.id), [local.id]);

    final [create, visit] = store.rows;
    expect(create.path, '/api/v1/patients');
    expect(create.body?['id'], local.id);
    expect(create.produces, {local.id: 'result.id'});
    expect(visit.path, '/api/v1/patients/${local.id}/medical-records');
    expect(visit.body?['port_id'], 'port-bpn');
  });

  test('back online: sent under the server id, then the list reloads', () async {
    final local = await notifier.addPatient(
      _patient,
      shipId: 'ship-1',
      portId: 'port-bpn',
    );
    await sync.syncNow();

    api.serverPatients = [_patient.copyWith(id: 'srv-1')];
    server.handler = (r) => r.path == '/api/v1/patients'
        ? (status: 201, body: {'result': {'id': 'srv-1'}})
        : (status: 201, body: {});
    server.seen.clear();
    await sync.syncNow();
    await pumpEventQueue();

    expect(server.seen.map((r) => r.path), [
      '/api/v1/patients',
      '/api/v1/patients/srv-1/medical-records',
    ]);
    expect(store.rows, isEmpty);
    // The offline copy is replaced by the server's patient.
    expect(notifier.state.map((p) => p.id), ['srv-1']);
    expect(notifier.state.map((p) => p.id), isNot(contains(local.id)));
  });

  test('a list refresh while offline keeps the offline patient', () async {
    final local = await notifier.addPatient(
      _patient,
      shipId: 'ship-1',
      portId: 'port-bpn',
    );
    api.serverPatients = [_patient.copyWith(id: 'srv-old', nama: 'Ani')];
    await notifier.fetchPatients();

    expect(notifier.state.map((p) => p.id), [local.id, 'srv-old']);
  });

  test('offline: a new visit and its patient update are kept', () async {
    await notifier.addKunjungan(
      patientId: 'srv-7',
      recordData: {'doctor_id': 'doc-1', 'complaint': 'Pusing'},
      patientUpdates: {'status_penanganan': 'Menunggu Dokter'},
    );

    expect(store.rows.map((e) => '${e.method} ${e.path}'), [
      'POST /api/v1/patients/srv-7/medical-records',
      'PUT /api/v1/patients/srv-7',
    ]);
  });

  test("offline: the doctor's exam and the patient's status are kept", () async {
    notifier.upsertPatient(_patient.copyWith(id: 'srv-7'));
    await notifier.patchMedicalRecord(
      patientId: 'srv-7',
      recordId: 'rec-1',
      body: {'diagnosis': 'A00', 'status_penanganan': 'Menunggu Obat'},
    );

    expect(store.rows.map((e) => '${e.method} ${e.path}'), [
      'PATCH /api/v1/patients/srv-7/medical-records/rec-1',
      'PUT /api/v1/patients/srv-7',
    ]);
    expect(store.rows.last.body?['status_penanganan'], 'Menunggu Obat');
    // Shown right away.
    expect(notifier.state.single.diagnosa, 'A00');
    expect(notifier.state.single.statusPenanganan, 'Menunggu Obat');
  });

  test('while writes are waiting, new ones queue behind them', () async {
    await notifier.addKunjungan(
      patientId: 'srv-7',
      recordData: {'doctor_id': 'doc-1'},
    );
    api.online = true; // reachable, but the queue hasn't been sent yet

    await notifier.updatePatient(_patient.copyWith(id: 'srv-7'));

    expect(api.writes, 0);
    expect(store.rows.last.method, 'PUT');
  });

  test('a server rejection is still shown, not queued', () async {
    final rejecting = _RejectingApi();
    final n = PatientsNotifier(api: rejecting, sync: sync, autoFetch: false);
    addTearDown(n.dispose);

    await expectLater(
      n.updatePatient(_patient.copyWith(id: 'srv-7')),
      throwsA(isA<ApiException>()),
    );
    expect(store.rows, isEmpty);
  });

  test('offline photo: uploaded first, its URL put into the patient', () async {
    final photo = File('${tempDir.path}/ktp.jpg')..writeAsBytesSync([1, 2, 3]);
    final placeholder = await notifier.uploadPhoto(photo);
    expect(placeholder, startsWith('offline-photo:'));

    await notifier.addPatient(
      _patient.copyWith(photoUrl: placeholder),
      shipId: 'ship-1',
      portId: 'port-bpn',
    );
    final upload = store.rows.first;
    expect(upload.files['photo'], isNot(photo.path)); // a kept copy
    expect(File(upload.files['photo']!).existsSync(), isTrue);

    server.handler = (r) => switch (r.path) {
          '/api/v1/patients/upload-photo' =>
            (status: 200, body: {'result': {'url': '/uploads/ktp.jpg'}}),
          '/api/v1/patients' => (status: 201, body: {'result': {'id': 'srv-1'}}),
          _ => (status: 201, body: {}),
        };
    server.seen.clear();
    await sync.syncNow();

    final create = server.seen.firstWhere((r) => r.path == '/api/v1/patients');
    expect((create.data as Map)['photo_url'], '/uploads/ktp.jpg');
    expect(store.rows.where((e) => e.status == OutboxStatus.pending), isEmpty);
  });
}

class _RejectingApi extends _PatientApi {
  @override
  Future<Patient> updatePatient(String id, Map<String, dynamic> body) async {
    throw const ApiException('NIK sudah terdaftar', statusCode: 422);
  }
}
