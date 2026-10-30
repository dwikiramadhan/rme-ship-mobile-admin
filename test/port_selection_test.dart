import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bayan_rme/core/utils/ship_code_helper.dart';
import 'package:bayan_rme/features/environment/presentation/environment_controller.dart';
import 'package:bayan_rme/features/history/presentation/add_visit_screen.dart';
import 'package:bayan_rme/features/nurse/presentation/patient_form.dart';
import 'package:bayan_rme/features/patients/data/patient_api.dart';
import 'package:bayan_rme/features/patients/data/patient_repository.dart';
import 'package:bayan_rme/features/patients/data/region_api.dart';
import 'package:bayan_rme/features/patients/domain/doctor.dart';
import 'package:bayan_rme/features/patients/domain/patient.dart';
import 'package:bayan_rme/features/patients/domain/vitals.dart';
import 'package:bayan_rme/features/schedule/domain/trip_schedule.dart';
import 'package:bayan_rme/features/schedule/presentation/widgets/current_port_info.dart';
import 'package:bayan_rme/features/schedule/presentation/widgets/poli_umum_note.dart';

const _currentStop = ScheduleStop(
  id: 'stop-2',
  portId: 'port-mkq',
  portCode: 'IDMKQ',
  portName: 'Pelabuhan Makassar',
  stopOrder: 2,
);

JadwalPerjalanan _trip(List<ScheduleStop> stops) => JadwalPerjalanan(
  id: 'sched-1',
  shipCode: 'RSK-001',
  namaKapal: 'KM Bayan 01',
  pelabuhanAsal: 'Pelabuhan Balikpapan',
  kodeAsal: 'IDBPN',
  pelabuhanTujuan: 'Pelabuhan Sorong',
  kodeTujuan: 'IDSOQ',
  berangkat: DateTime(2026, 10, 1, 8),
  tiba: DateTime(2026, 10, 20, 8),
  status: 'Ongoing',
  stops: stops,
);

/// Records the medical records (visits) sent to the backend.
class _RecordingPatientApi extends PatientApi {
  final created = <Map<String, dynamic>>[];
  final visits = <Map<String, dynamic>>[];

  @override
  Future<Patient> createPatient(Map<String, dynamic> body) async {
    created.add(body);
    return _patient;
  }

  @override
  Future<void> addMedicalRecord(
    String patientId,
    Map<String, dynamic> body,
  ) async {
    visits.add(body);
  }
}

/// Registers the patient, then rejects the first visit.
class _VisitRejectingPatientApi extends _RecordingPatientApi {
  @override
  Future<void> addMedicalRecord(
    String patientId,
    Map<String, dynamic> body,
  ) async {
    throw Exception('port_id not found');
  }
}

class _EmptyWilayahApi extends WilayahApi {
  @override
  Future<List<WilayahProvinsi>> getProvinsi() async => const [];
}

final _patient = Patient(
  id: 'patient-1',
  nama: 'Pierre Gasly',
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
  serviceShipCode: 'RSK-001',
  updatedAt: DateTime(2026, 10, 13),
);

const _doctors = [
  Doctor(id: 'doc-1', nama: 'dr. Putri', spesialisasi: 'Umum', online: true),
];

void main() {
  test('a new patient\'s first visit uses the given ship and harbor', () async {
    final api = _RecordingPatientApi();
    final notifier = PatientsNotifier(api: api, autoFetch: false);
    addTearDown(notifier.dispose);

    await notifier.addPatient(_patient, shipId: 'ship-1', portId: 'port-bpn');

    // The patient record keeps the harbor they were registered at too.
    expect(api.created.single['port_id'], 'port-bpn');
    expect(api.visits, hasLength(1));
    expect(api.visits.single['ship_id'], 'ship-1');
    expect(api.visits.single['port_id'], 'port-bpn');
    // No placeholder diagnosis: the doctor fills it in.
    expect(api.visits.single.containsKey('diagnosis'), isFalse);
    expect(api.visits.single.containsKey('treatment'), isFalse);
  });

  test('a Poli Umum patient\'s first visit goes out without a doctor', () async {
    final api = _RecordingPatientApi();
    final notifier = PatientsNotifier(api: api, autoFetch: false);
    addTearDown(notifier.dispose);

    await notifier.addPatient(
      _patient.copyWith(assignedDokterId: '', poliCode: 'UMUM'),
      shipId: 'ship-1',
      portId: 'port-bpn',
    );

    expect(api.visits, hasLength(1));
    expect(api.visits.single['doctor_id'], isNull);
    expect(api.visits.single['poli_code'], 'UMUM');
  });

  test('a failed first visit is reported, with the patient kept', () async {
    final notifier = PatientsNotifier(
      api: _VisitRejectingPatientApi(),
      autoFetch: false,
    );
    addTearDown(notifier.dispose);

    await expectLater(
      notifier.addPatient(_patient, shipId: 'ship-1', portId: 'port-bpn'),
      throwsA(
        isA<VisitNotCreatedException>().having(
          (e) => e.toString(),
          'message',
          allOf(contains('Pasien tersimpan'), contains('port_id not found')),
        ),
      ),
    );
    // Already registered on the server, so still listed.
    expect(notifier.state.map((p) => p.id), contains('patient-1'));
  });

  group('current stop of a trip', () {
    final trip = _trip([
      // Listed out of order: the stop order decides.
      ScheduleStop(
        id: 'stop-3',
        portId: 'port-soq',
        portCode: 'IDSOQ',
        portName: 'Pelabuhan Sorong',
        stopOrder: 3,
        arrival: DateTime(2026, 10, 20, 8),
      ),
      ScheduleStop(
        id: 'stop-1',
        portId: 'port-bpn',
        portCode: 'IDBPN',
        portName: 'Pelabuhan Balikpapan',
        stopOrder: 1,
        departure: DateTime(2026, 10, 1, 8),
      ),
      ScheduleStop(
        id: 'stop-2',
        portId: 'port-mkq',
        portCode: 'IDMKQ',
        portName: 'Pelabuhan Makassar',
        stopOrder: 2,
        arrival: DateTime(2026, 10, 5, 8),
        departure: DateTime(2026, 10, 7, 8),
      ),
    ]);

    test('before the first arrival: the first stop', () {
      expect(trip.currentStop(DateTime(2026, 10, 2))?.portId, 'port-bpn');
    });

    test('at a stop, and sailing on from it: that stop', () {
      expect(trip.currentStop(DateTime(2026, 10, 5, 8))?.portId, 'port-mkq');
      expect(trip.currentStop(DateTime(2026, 10, 10))?.portId, 'port-mkq');
    });

    test('after the last arrival: the last stop', () {
      expect(trip.currentStop(DateTime(2026, 10, 25))?.portId, 'port-soq');
    });

    test('no stops: none', () {
      expect(_trip(const []).currentStop(DateTime(2026, 10, 5)), isNull);
    });
  });

  testWidgets('new patient form shows the harbor of the ongoing trip', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(640, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          patientApiProvider.overrideWithValue(_RecordingPatientApi()),
          wilayahApiProvider.overrideWithValue(_EmptyWilayahApi()),
          tripDoctorsProvider.overrideWith((ref) async => _doctors),
          tripClinicsProvider.overrideWith((ref) async => defaultPoliklinik),
          currentPortProvider.overrideWith((ref) async => _currentStop),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: PatientForm(onBack: () {}, onSaved: () {}),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Required label: "Pelabuhan *", with the harbor shown, not picked.
    expect(find.textContaining(RegExp(r'^Pelabuhan( \*)?$')), findsOneWidget);
    expect(find.text('Pelabuhan Makassar'), findsOneWidget);
    expect(find.text('Pilih pelabuhan...'), findsNothing);
  });

  test('a clinic deactivated or deleted from the master list is not active', () {
    ScheduleClinicItem clinic(Map<String, dynamic> poli) =>
        ScheduleClinicItem.fromJson({'poliklinik_id': 'p-1', 'poliklinik': poli});
    expect(clinic({'code': 'UMUM', 'status': 'Aktif'}).poliActive, isTrue);
    expect(clinic({'code': 'GIGI', 'status': 'Tidak Aktif'}).poliActive, isFalse);
    expect(
      clinic({'code': 'KIA', 'deleted_at': '2026-10-01T00:00:00Z'}).poliActive,
      isFalse,
    );
  });

  testWidgets('new patient form offers only the clinics of the ongoing trip', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(640, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    Future<void> pumpForm(List<PoliklinikItem> clinics) async {
      // A fresh scope each time: overrides are fixed once a scope exists.
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            patientApiProvider.overrideWithValue(_RecordingPatientApi()),
            wilayahApiProvider.overrideWithValue(_EmptyWilayahApi()),
            tripDoctorsProvider.overrideWith((ref) async => _doctors),
            // The master list has more clinics than the trip.
            poliklinikOptionsProvider.overrideWith(
              (ref) async => defaultPoliklinik,
            ),
            tripClinicsProvider.overrideWith((ref) async => clinics),
            currentPortProvider.overrideWith((ref) async => _currentStop),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: PatientForm(onBack: () {}, onSaved: () {}),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    // No Poli Umum on this trip: the first clinic is preselected.
    await pumpForm(const [
      PoliklinikItem(id: 'p-gigi', code: 'GIGI', name: 'Poli Gigi'),
      PoliklinikItem(id: 'p-mata', code: 'MATA', name: 'Poli Mata'),
    ]);
    expect(find.text('Poli Gigi'), findsOneWidget);
    await tester.tap(find.text('Poli Gigi'));
    await tester.pumpAndSettle();
    expect(find.text('Poli Mata'), findsWidgets);
    expect(find.text('Poli Umum'), findsNothing);
    expect(find.text('Poli KIA'), findsNothing);

    // A trip without clinics says so.
    await pumpForm(const []);
    expect(find.text(noTripClinicsMessage), findsOneWidget);
  });

  Future<_RecordingPatientApi> pumpVisitScreen(
    WidgetTester tester, {
    String? activeShipId,
    ScheduleStop? currentStop = _currentStop,
    bool vitals = true,
  }) async {
    tester.view.physicalSize = const Size(900, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final api = _RecordingPatientApi();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          patientApiProvider.overrideWithValue(api),
          tripDoctorsProvider.overrideWith((ref) async => _doctors),
          poliklinikOptionsProvider.overrideWith(
            (ref) async => defaultPoliklinik,
          ),
          currentPortProvider.overrideWith((ref) async => currentStop),
          activeEnvironmentShipIdProvider.overrideWithValue(activeShipId),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: TambahKunjunganScreen(
              initialPatient: _patient,
              onBack: () {},
              onSaved: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.descendant(
        of: find
            .ancestor(
              of: find.textContaining(RegExp(r'^Keluhan Utama( \*)?$')),
              matching: find.byType(Column),
            )
            .first,
        matching: find.byType(TextField),
      ),
      'Demam sejak kemarin',
    );
    // Blood pressure, pulse and temperature are required.
    if (vitals) {
      for (final (hint, value) in [
        ('Sistolik (120)', '120'),
        ('Diastolik (80)', '80'),
        ('Contoh: 78', '78'),
        ('Contoh: 37.8', '36.8'),
      ]) {
        await tester.enterText(find.widgetWithText(TextField, hint), value);
      }
    }
    return api;
  }

  Future<void> pickPoli(WidgetTester tester, String name) async {
    await tester.tap(find.text('Poli Umum').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text(name).last);
    await tester.pumpAndSettle();
  }

  Future<void> pickDoctor(WidgetTester tester) async {
    await tester.tap(find.text('Pilih Dokter...'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('dr. Putri').last);
    await tester.pumpAndSettle();
  }

  /// Saving first reads the active ship from device storage (async).
  Future<void> saveAndWait(WidgetTester tester, bool Function() done) async {
    await tester.tap(find.text('Simpan Kunjungan'));
    for (var i = 0; i < 10 && !done(); i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
  }

  testWidgets(
    'outside Poli Umum a visit needs a doctor from the ongoing trip',
    (tester) async {
      final api = await pumpVisitScreen(tester, activeShipId: 'ship-1');
      await pickPoli(tester, 'Poli Gigi');

      // Nothing is preselected: the doctor has to be chosen first...
      await tester.tap(find.text('Simpan Kunjungan'));
      await tester.pump();
      expect(find.text('Dokter pemeriksa wajib dipilih.'), findsOneWidget);
      expect(api.visits, isEmpty);

      // The harbor is shown from the trip, not picked.
      expect(find.text('Pelabuhan Makassar'), findsOneWidget);
      await pickDoctor(tester);

      await saveAndWait(tester, () => api.visits.isNotEmpty);

      expect(api.visits, hasLength(1));
      expect(api.visits.single['ship_id'], 'ship-1');
      expect(api.visits.single['port_id'], 'port-mkq');
      expect(api.visits.single['doctor_id'], 'doc-1');
      expect(api.visits.single['poli_code'], 'GIGI');
      // No placeholder diagnosis: the doctor fills it in.
      expect(api.visits.single.containsKey('diagnosis'), isFalse);
      expect(api.visits.single.containsKey('treatment'), isFalse);

      // Let the post-save refreshes and snackbar timers finish.
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 30));
    },
  );

  testWidgets(
    'Poli Umum: no doctor is assigned, the trip\'s doctors are told',
    (tester) async {
      final api = await pumpVisitScreen(tester, activeShipId: 'ship-1');

      // Poli Umum is the default: no doctor picker, a note instead.
      expect(find.text('Pilih Dokter...'), findsNothing);
      expect(find.byType(PoliUmumDoctorsNote), findsOneWidget);
      expect(find.textContaining('(1 dokter)'), findsOneWidget);

      await saveAndWait(tester, () => api.visits.isNotEmpty);

      expect(api.visits, hasLength(1));
      expect(api.visits.single['doctor_id'], isNull);
      expect(api.visits.single['poli_code'], 'UMUM');
      expect(api.visits.single['port_id'], 'port-mkq');

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 30));
    },
  );

  testWidgets('new visit is not saved without blood pressure, pulse and temperature', (
    tester,
  ) async {
    final api = await pumpVisitScreen(
      tester,
      activeShipId: 'ship-1',
      vitals: false,
    );

    await saveAndWait(
      tester,
      () => find
          .text('Tekanan darah, nadi, dan suhu wajib diisi.')
          .evaluate()
          .isNotEmpty,
    );

    expect(find.text('Tekanan darah, nadi, dan suhu wajib diisi.'), findsOneWidget);
    expect(api.visits, isEmpty);
  });

  testWidgets('new visit is not saved without an active ship', (
    tester,
  ) async {
    final api = await pumpVisitScreen(tester);

    await saveAndWait(
      tester,
      () => find.text(noActiveShipMessage).evaluate().isNotEmpty,
    );

    expect(find.text(noActiveShipMessage), findsOneWidget);
    expect(api.visits, isEmpty);
  });

  testWidgets('new visit is not saved without an ongoing trip', (
    tester,
  ) async {
    final api = await pumpVisitScreen(
      tester,
      activeShipId: 'ship-1',
      currentStop: null,
    );
    // The form says so before saving.
    expect(find.text(noCurrentPortMessage), findsOneWidget);

    await saveAndWait(
      tester,
      () => find.text(noCurrentPortMessage).evaluate().length > 1,
    );

    expect(find.text(noCurrentPortMessage), findsNWidgets(2));
    expect(api.visits, isEmpty);
  });
}
