import 'package:bayan_rme/features/doctor/data/icd_catalog.dart';
import 'package:bayan_rme/features/patients/data/region_api.dart';
import 'package:bayan_rme/features/sync/presentation/master_data_status.dart';
import 'package:bayan_rme/features/sync/presentation/offline_data_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/offline_fakes.dart';

class _FakeWilayahApi extends WilayahApi {
  @override
  Future<DateTime?> exportedAt() async => DateTime(2026, 10, 18);
}

class _FakeIcdCatalog extends IcdCatalog {
  _FakeIcdCatalog() : super(IcdCatalog.icd10Asset);

  @override
  Future<DateTime?> exportedAt() async => DateTime(2026, 10, 18);
}

/// Doctors downloaded 10 days ago; harbors and medicines never.
List<Override> _overrides() {
  final cache = InMemoryHttpCache()
    ..storedAt['/api/v1/medical-personnel?type=Doctor'] =
        DateTime.now().subtract(const Duration(days: 10));
  return [
    httpCacheStoreProvider.overrideWithValue(cache),
    wilayahApiProvider.overrideWithValue(_FakeWilayahApi()),
    shipCodeResolverProvider.overrideWithValue(() async => 'RSK-1'),
    icdCatalogProvider.overrideWithValue(_FakeIcdCatalog()),
  ];
}

void main() {
  test('reports how recent each list on the device is', () async {
    final container = ProviderContainer(overrides: _overrides());
    addTearDown(container.dispose);

    final status = await container.read(masterDataStatusProvider.future);
    final [doctors, ports, medicines, wilayah, icd] = status.entries;

    expect(doctors.label, 'Dokter');
    expect(doctors.isStale, isTrue);
    expect(ports.updatedAt, isNull);
    expect(wilayah.bundled, isTrue);
    expect(wilayah.isStale, isFalse); // bundled data never goes stale
    expect(wilayah.updatedAt, DateTime(2026, 10, 18));
    expect(medicines.updatedAt, isNull); // stock list never downloaded
    expect(icd.bundled, isTrue);
    expect(icd.updatedAt, DateTime(2026, 10, 18));
  });

  testWidgets('profile card shows missing and stale lists', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: _overrides(),
        child: const MaterialApp(
          home: Scaffold(
            body: Column(children: [OfflineDataCard(), DoctorsStaleNote()]),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Harbors and the medicine stock list.
    expect(find.text('Belum tersimpan di perangkat'), findsNWidgets(2));
    expect(find.textContaining('perlu diperbarui'), findsOneWidget); // doctors
    // Regions and ICD.
    expect(find.textContaining('Bawaan aplikasi'), findsNWidgets(2));
    expect(find.text('Perbarui sekarang'), findsOneWidget);
    expect(
      find.textContaining('Daftar dokter terakhir diperbarui 10 hari lalu'),
      findsOneWidget,
    );
  });
}
