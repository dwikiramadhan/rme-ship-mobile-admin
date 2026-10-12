import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bayan_rme/features/patients/data/patient_api.dart';
import 'package:bayan_rme/features/patients/data/patient_repository.dart';
import 'package:bayan_rme/features/patients/domain/medical_history.dart';

MedicalHistory _visit(String id, String createdAt) =>
    MedicalHistory.fromApiJson({
      'id': id,
      'code': id,
      'patient_id': 'p-$id',
      'patient': {'id': 'p-$id', 'name': 'Pasien $id'},
      'status_penanganan': 'Menunggu Obat',
      'created_at': createdAt,
    });

/// Returns visits in a scrambled order and records the requested sort.
class _FakeApi extends PatientApi {
  final orders = <String>[];

  @override
  Future<PaginatedMedicalHistory> getMedicalHistoryPaginated({
    int page = 1,
    int limit = 10,
    String? search,
    String? statusPenanganan,
    String? userId,
    String sortBy = 'created_at',
    String order = 'desc',
  }) async {
    orders.add(order);
    return PaginatedMedicalHistory(
      data: [
        _visit('b', '2026-10-12T09:00:00Z'),
        _visit('a', '2026-10-12T08:00:00Z'),
        _visit('c', '2026-10-12T10:00:00Z'),
      ],
      page: 1,
      limit: limit,
      total: 3,
      totalPages: 1,
    );
  }
}

void main() {
  test('Antrian Resep lists the oldest prescription first', () async {
    final api = _FakeApi();
    final container = ProviderContainer(
      overrides: [patientApiProvider.overrideWithValue(api)],
    );
    addTearDown(container.dispose);

    await container
        .read(pharmacyPrescriptionHistoryProvider.notifier)
        .fetchHistory(refresh: true);

    // The server sorts too, so later pages continue in the same order.
    expect(api.orders.last, 'asc');
    expect(
      container.read(pharmacyPrescriptionHistoryProvider).map((h) => h.id),
      ['a', 'b', 'c'],
    );
  });

  test('other history lists stay newest first', () async {
    final api = _FakeApi();
    final notifier = MedicalHistoryNotifier(api: api, autoFetch: false);
    addTearDown(notifier.dispose);

    await notifier.fetchHistory(refresh: true);

    expect(api.orders.single, 'desc');
    expect(notifier.state.map((h) => h.id), ['c', 'b', 'a']);
  });
}
