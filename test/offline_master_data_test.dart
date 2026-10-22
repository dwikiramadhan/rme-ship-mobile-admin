import 'package:bayan_rme/core/offline/http_cache.dart';
import 'package:bayan_rme/features/nurse/presentation/patient_form.dart';
import 'package:bayan_rme/features/patients/data/region_api.dart';
import 'package:bayan_rme/features/schedule/domain/trip_schedule.dart';
import 'package:bayan_rme/features/schedule/presentation/widgets/poli_umum_note.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/offline_fakes.dart';

class _EmptyWilayahApi extends WilayahApi {
  @override
  Future<List<WilayahProvinsi>> getProvinsi() async => const [];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('regions come from the app asset, no connection needed', () {
    final api = WilayahApi();

    test('every province', () async {
      final provinsi = await api.getProvinsi();
      expect(provinsi, hasLength(38));
      expect(
        provinsi.map((p) => p.namaProvinsi),
        contains('Kalimantan Timur'),
      );
    });

    test('province → regency → district → village, with postal code', () async {
      final kab = await api.getKabupatenKota(64);
      final kukar = kab.singleWhere((k) => k.kodeKabkota == 64.02);
      expect(kukar.namaKabkota, 'Kabupaten Kutai Kartanegara');

      final kec = await api.getKecamatan(kukar.kodeKabkota);
      final muaraMuntai = kec.singleWhere((k) => k.kodeKecamatan == '64.02.01');
      expect(muaraMuntai.namaKecamatan, 'Muara Muntai');

      final kel = await api.getKelurahan(muaraMuntai.kodeKecamatan);
      final perian = kel.singleWhere((k) => k.kodeKelurahan == '64.02.01.2001');
      expect(perian.namaKelurahan, 'Perian');
      expect(perian.kodePos, 75562);
    });

    test('a regency code ending in 0 still finds its districts', () async {
      // 11.10 is stored as a `real` (11.1) in the backend.
      final kec = await api.getKecamatan(11.10);
      expect(kec, isNotEmpty);
      expect(kec.first.kodeKecamatan, startsWith('11.10.'));
    });

    test('an unknown code gives an empty list', () async {
      expect(await api.getKelurahan('99.99.99'), isEmpty);
    });
  });

  test('doctors and harbors stay cached after logout; patient data does not', () async {
    final cache = InMemoryHttpCache();
    final server = FakeServerAdapter((_) => (status: 200, body: {'result': []}));
    final dio = fakeDio(server)..interceptors.add(OfflineCacheInterceptor(cache));

    await dio.get<dynamic>('/api/v1/medical-personnel', queryParameters: {'type': 'Doctor'});
    await dio.get<dynamic>('/api/v1/ports', queryParameters: {'limit': 100});
    await dio.get<dynamic>('/api/v1/patients');
    await cache.clearUserData(); // logout

    server.handler = (_) => null; // offline
    final doctors = await dio.get<dynamic>(
      '/api/v1/medical-personnel',
      queryParameters: {'type': 'Doctor'},
    );
    expect(doctors.extra['fromCache'], isTrue);
    final ports = await dio.get<dynamic>('/api/v1/ports', queryParameters: {'limit': 100});
    expect(ports.extra['fromCache'], isTrue);
    expect(() => dio.get<dynamic>('/api/v1/patients'), throwsA(isA<DioException>()));
  });

  testWidgets('no doctors on the trip: says so, offers no placeholder doctors', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(640, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          wilayahApiProvider.overrideWithValue(_EmptyWilayahApi()),
          tripDoctorsProvider.overrideWith((ref) async => const []),
          poliklinikOptionsProvider.overrideWith(
            (ref) async => defaultPoliklinik,
          ),
          portsProvider.overrideWith((ref) async => const <PortItem>[]),
        ],
        child: MaterialApp(
          home: Scaffold(body: PatientForm(onBack: () {}, onSaved: () {})),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Outside Poli Umum a doctor from the ongoing trip has to be picked.
    await tester.tap(find.text('Poli Umum').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Poli Gigi').last);
    await tester.pumpAndSettle();
    expect(find.text(noTripDoctorsMessage), findsOneWidget);

    await tester.tap(find.text('Pilih dokter pemeriksa...'));
    await tester.pumpAndSettle();
    // The old hardcoded fallback list.
    expect(find.text('Dr. Budi Santoso Soedibyo'), findsNothing);
  });
}
