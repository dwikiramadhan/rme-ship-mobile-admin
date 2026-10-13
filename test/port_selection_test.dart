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

const _ports = [
  PortItem(id: 'port-bpn', code: 'IDBPN', name: 'Pelabuhan Balikpapan'),
  PortItem(id: 'port-mkq', code: 'IDMKQ', name: 'Pelabuhan Makassar'),
];

/// Records the medical records (visits) sent to the backend.
class _RecordingPatientApi extends PatientApi {
  final visits = <Map<String, dynamic>>[];

  @override
  Future<Patient> createPatient(Map<String, dynamic> body) async => _patient;

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

    expect(api.visits, hasLength(1));
    expect(api.visits.single['ship_id'], 'ship-1');
    expect(api.visits.single['port_id'], 'port-bpn');
    // No placeholder diagnosis: the doctor fills it in.
    expect(api.visits.single.containsKey('diagnosis'), isFalse);
    expect(api.visits.single.containsKey('treatment'), isFalse);
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

  testWidgets('new patient form offers the harbors from the server', (
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
          doctorsProvider.overrideWith((ref) async => _doctors),
          portsProvider.overrideWith((ref) async => _ports),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: PatientForm(onBack: () {}, onSaved: () {}),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Required, and nothing is picked for the nurse.
    // Required label: "Pelabuhan *".
    expect(find.textContaining(RegExp(r'^Pelabuhan( \*)?$')), findsOneWidget);
    expect(find.text('Pilih pelabuhan...'), findsOneWidget);

    await tester.tap(find.text('Pilih pelabuhan...'));
    await tester.pumpAndSettle();
    expect(find.text('Pelabuhan Balikpapan'), findsWidgets);
    expect(find.text('Pelabuhan Makassar'), findsWidgets);
  });

  Future<_RecordingPatientApi> pumpVisitScreen(
    WidgetTester tester, {
    String? activeShipId,
  }) async {
    tester.view.physicalSize = const Size(900, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final api = _RecordingPatientApi();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          patientApiProvider.overrideWithValue(api),
          doctorsProvider.overrideWith((ref) async => _doctors),
          portsProvider.overrideWith((ref) async => _ports),
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
    return api;
  }

  Future<void> pickDoctorAndHarbor(WidgetTester tester) async {
    await tester.tap(find.text('Pilih Dokter...'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('dr. Putri').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pilih pelabuhan...'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pelabuhan Makassar').last);
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
    'new visit needs a doctor and a harbor and sends the chosen ones',
    (tester) async {
      final api = await pumpVisitScreen(tester, activeShipId: 'ship-1');

      // Nothing is preselected: the doctor has to be chosen first...
      await tester.tap(find.text('Simpan Kunjungan'));
      await tester.pump();
      expect(find.text('Dokter pemeriksa wajib dipilih.'), findsOneWidget);
      expect(api.visits, isEmpty);

      await tester.tap(find.text('Pilih Dokter...'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('dr. Putri').last);
      await tester.pumpAndSettle();

      // ...then the harbor.
      await tester.tap(find.text('Simpan Kunjungan'));
      await tester.pump();
      expect(find.text('Pelabuhan wajib dipilih.'), findsOneWidget);
      expect(api.visits, isEmpty);

      await tester.tap(find.text('Pilih pelabuhan...'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pelabuhan Makassar').last);
      await tester.pumpAndSettle();

      await saveAndWait(tester, () => api.visits.isNotEmpty);

      expect(api.visits, hasLength(1));
      expect(api.visits.single['ship_id'], 'ship-1');
      expect(api.visits.single['port_id'], 'port-mkq');
      expect(api.visits.single['doctor_id'], 'doc-1');
      // No placeholder diagnosis: the doctor fills it in.
      expect(api.visits.single.containsKey('diagnosis'), isFalse);
      expect(api.visits.single.containsKey('treatment'), isFalse);

      // Let the post-save refreshes and snackbar timers finish.
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 30));
    },
  );

  testWidgets('new visit is not saved without an active ship', (
    tester,
  ) async {
    final api = await pumpVisitScreen(tester);
    await pickDoctorAndHarbor(tester);

    await saveAndWait(
      tester,
      () => find.text(noActiveShipMessage).evaluate().isNotEmpty,
    );

    expect(find.text(noActiveShipMessage), findsOneWidget);
    expect(api.visits, isEmpty);
  });
}
