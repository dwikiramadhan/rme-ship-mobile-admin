import 'dart:io';

import 'package:bayan_rme/core/network/api_exception.dart';
import 'package:bayan_rme/core/offline/http_cache.dart';
import 'package:bayan_rme/core/offline/sync_service.dart';
import 'package:bayan_rme/features/doctor/data/medicines_api.dart';
import 'package:bayan_rme/features/medicine_stock/data/ship_medicine_api.dart';
import 'package:bayan_rme/features/patients/data/patient_api.dart';
import 'package:bayan_rme/features/patients/data/patient_repository.dart';
import 'package:bayan_rme/features/patients/domain/medical_history.dart';
import 'package:bayan_rme/features/patients/domain/patient.dart';
import 'package:bayan_rme/features/patients/domain/prescription_item.dart';
import 'package:bayan_rme/features/patients/domain/vitals.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/offline_fakes.dart';

const _offline = ApiException(
  'Tidak dapat terhubung ke server.',
  isOffline: true,
);

/// A backend that can't be reached, listing [waiting] as "Menunggu Obat".
class _PatientApi extends PatientApi {
  List<MedicalHistory> waiting = const [];

  @override
  Future<void> dispensePrescription(
    String medRecId,
    Map<String, dynamic> body,
  ) async => throw _offline;

  @override
  Future<PaginatedMedicalHistory> getMedicalHistoryPaginated({
    int page = 1,
    int limit = 10,
    String? search,
    String? statusPenanganan,
    String? userId,
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

Map<String, dynamic> _stock(String sku, String name, int stock) => {
  'medicine_id': 'id-$sku',
  'medicine_sku': sku,
  'medicine_name': name,
  'stock': stock,
};

MedicalHistory _visit(String id) =>
    MedicalHistory(id: id, code: id, patientId: 'srv-$id', patientName: id);

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
);

void main() {
  // The backend's order: most stock first, then by name.
  final shipStocks = [
    _stock('PCT500', 'Paracetamol 500mg', 40),
    _stock('AMX500', 'Amoxicillin 500mg', 12),
    _stock('OMZ20', 'Omeprazole 20mg', 0),
  ];

  late FakeServerAdapter server;
  late Dio dio;
  late InMemoryOutboxStore store;
  late SyncService sync;
  late _PatientApi patientApi;
  late PatientsNotifier patients;
  late MedicinesApi medicines;
  late ShipMedicineApi shipMedicines;
  late Directory tempDir;

  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('pharmacy_test');
    server = FakeServerAdapter(
      (r) => r.options.queryParameters['all'] == 'true'
          ? (status: 200, body: {'result': shipStocks})
          : (
              status: 200,
              body: {
                'result': {'data': shipStocks, 'total': 3},
              },
            ),
    );
    dio = fakeDio(server)
      ..interceptors.add(OfflineCacheInterceptor(InMemoryHttpCache()));
    store = InMemoryOutboxStore();
    sync = SyncService(
      store: store,
      dio: fakeDio(server),
      currentUserId: () async => 'pharmacist-1',
      filesDir: () async => tempDir,
      retryInterval: null,
    );
    patientApi = _PatientApi();
    patients = PatientsNotifier(api: patientApi, sync: sync, autoFetch: false)
      ..upsertPatient(_patient);
    medicines = MedicinesApi(dio: dio, sync: sync);
    shipMedicines = ShipMedicineApi(dio: dio, sync: sync);

    await medicines.downloadShipStocks('RSK-1');
    server.handler = (_) => null; // offline from here on
  });

  tearDown(() async {
    patients.dispose();
    sync.dispose();
    await tempDir.delete(recursive: true);
  });

  Future<void> dispense(String recordId, String sku, int quantity) =>
      patients.dispensePrescription(
        medRecId: recordId,
        patientId: 'srv-7',
        dispensedById: 'pharmacist-1',
        items: [
          ResepItem(
            id: 'rx-1',
            obat: sku,
            dosis: '3x1',
            instruksi: '',
            sku: sku,
            jumlah: quantity,
          ),
        ],
      );

  test(
    'offline: dispensing is queued, the patient shown as handed over',
    () async {
      await dispense('rec-1', 'PCT500', 5);

      final entry = store.rows.single;
      expect(
        '${entry.method} ${entry.path}',
        'POST /api/v1/medical-records/rec-1/dispense',
      );
      expect(entry.label, 'Penyerahan obat: Budi');
      expect(patients.state.single.resepStatus, ResepStatus.selesai);
      expect(patients.state.single.statusPenanganan, 'Selesai');
    },
  );

  test('offline: stock added is queued', () async {
    final savedOffline = await shipMedicines.addStock(
      shipCode: 'RSK-1',
      medicineId: 'id-AMX500',
      medicineName: 'Amoxicillin 500mg',
      quantity: 30,
    );

    expect(savedOffline, isTrue);
    expect(store.rows.single.path, '/api/v1/ship-medicines');
    expect(store.rows.single.label, 'Tambah stok: Amoxicillin 500mg +30');
  });

  test('online: stock added reaches the server', () async {
    server.handler = (_) => (status: 201, body: {});
    final savedOffline = await shipMedicines.addStock(
      shipCode: 'RSK-1',
      medicineId: 'id-AMX500',
      quantity: 30,
    );

    expect(savedOffline, isFalse);
    expect(store.rows, isEmpty);
  });

  test(
    'offline: the stock list counts in what was dispensed and added',
    () async {
      await dispense('rec-1', 'PCT500', 5);
      await shipMedicines.addStock(
        shipCode: 'RSK-1',
        medicineId: 'id-AMX500',
        quantity: 30,
      );

      final stocks = await shipMedicines.fetchStocks(shipCode: 'RSK-1');
      expect(
        stocks.items.map((s) => '${s.medicineSku} ${s.stock}'),
        ['AMX500 42', 'PCT500 35', 'OMZ20 0'], // re-sorted by stock
      );

      // The doctor's and pharmacist's medicine search see the same.
      final search = await medicines.fetchMedicines(
        shipCode: 'RSK-1',
        query: 'pct',
      );
      expect(search.data.single.stock, 35);
    },
  );

  test(
    'offline: an old cached page gives way to the downloaded list',
    () async {
      server.handler = (r) => (
        status: 200,
        body: {
          'result': {'data': shipStocks, 'total': 3},
        },
      );
      await shipMedicines.fetchStocks(shipCode: 'RSK-1'); // cached
      server.handler = (_) => null;

      await dispense('rec-1', 'PCT500', 5);
      final stocks = await shipMedicines.fetchStocks(shipCode: 'RSK-1');
      expect(stocks.items.first.stock, 35);
    },
  );

  test('offline: the master list is searched in the ship list', () async {
    final res = await medicines.fetchMedicines(
      offlineShipCode: 'RSK-1',
      query: 'amox',
    );
    expect(res.data.single.id, 'id-AMX500');
  });

  test('the pharmacy queue hides visits dispensed offline', () async {
    patientApi.waiting = [_visit('rec-1'), _visit('rec-2')];
    final queue = MedicalHistoryNotifier(
      api: patientApi,
      autoFetch: false,
      statusPenanganan: 'Menunggu Obat',
      queuedVisitIds: () => visitsQueuedFor(sync, 'dispense'),
    );
    addTearDown(queue.dispose);

    await dispense('rec-1', 'PCT500', 5);
    await queue.fetchHistory(refresh: true);

    expect(queue.state.map((h) => h.id), ['rec-2']);
  });
}
