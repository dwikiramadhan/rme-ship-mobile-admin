import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bayan_rme/features/auth/domain/user_role.dart';
import 'package:bayan_rme/features/history/presentation/edit_visit_screen.dart';
import 'package:bayan_rme/features/patients/data/patient_api.dart';
import 'package:bayan_rme/features/patients/data/patient_repository.dart';
import 'package:bayan_rme/features/patients/domain/doctor.dart';
import 'package:bayan_rme/features/patients/domain/medical_history.dart';
import 'package:bayan_rme/features/patients/domain/patient.dart';
import 'package:bayan_rme/features/schedule/domain/trip_schedule.dart';
import 'package:bayan_rme/features/schedule/presentation/widgets/poli_umum_note.dart';

/// Records the visit edits sent to the backend.
class _RecordingPatientApi extends PatientApi {
  final patches = <Map<String, dynamic>>[];

  @override
  Future<Map<String, dynamic>> patchMedicalRecord(
    String patientId,
    String recordId,
    Map<String, dynamic> body,
  ) async {
    patches.add({'patient_id': patientId, 'record_id': recordId, ...body});
    return body;
  }
}

const _doctors = [
  Doctor(id: 'doc-1', nama: 'dr. Putri', spesialisasi: 'Umum', online: true),
  Doctor(id: 'doc-2', nama: 'dr. Andika', spesialisasi: 'Gigi', online: true),
];

MedicalHistory _visit({String poli = 'GIGI', String? doctorId = 'doc-1'}) =>
    MedicalHistory(
      id: 'rec-1',
      code: 'RJ22102026-00001',
      patientId: 'patient-1',
      patientName: 'Budi',
      poliCode: poli,
      doctorId: doctorId,
      complaint: 'Sakit gigi • Durasi: 2 hari • Lokasi: Geraham kiri',
      statusPenanganan: 'Menunggu Dokter',
      bloodPressure: '120/80',
      heartRate: 80,
    );

/// Saving first checks the outbox on the device (async).
Future<void> saveAndWait(WidgetTester tester, bool Function() done) async {
  await tester.tap(find.text('Simpan Perubahan'));
  for (var i = 0; i < 10 && !done(); i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
}

void main() {
  Future<_RecordingPatientApi> pumpEdit(
    WidgetTester tester,
    MedicalHistory record, {
    VoidCallback? onSaved,
  }) async {
    tester.view.physicalSize = const Size(900, 2400);
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
        ],
        child: MaterialApp(
          home: Scaffold(
            body: EditVisitScreen(
              record: record,
              onBack: () {},
              onSaved: onSaved ?? () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return api;
  }

  testWidgets('the saved visit is filled in, and the edit is sent', (
    tester,
  ) async {
    var saved = false;
    final api = await pumpEdit(tester, _visit(), onSaved: () => saved = true);

    // Complaint split back into its fields.
    expect(find.text('Sakit gigi'), findsOneWidget);
    expect(find.text('2 hari'), findsOneWidget);
    expect(find.text('Geraham kiri'), findsOneWidget);
    expect(find.text('dr. Putri'), findsOneWidget);

    await tester.tap(find.text('dr. Putri'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('dr. Andika').last);
    await tester.pumpAndSettle();
    await saveAndWait(tester, () => saved);

    expect(api.patches, hasLength(1));
    final body = api.patches.single;
    expect(body['record_id'], 'rec-1');
    expect(body['doctor_id'], 'doc-2');
    expect(body['poli_code'], 'GIGI');
    expect(
      body['complaint'],
      'Sakit gigi • Durasi: 2 hari • Lokasi: Geraham kiri',
    );
    expect(body['systolic'], 120);
    expect(body['diastolic'], 80);
    expect(body['heart_rate'], 80);
    // The handling status stays "Menunggu Dokter".
    expect(body.containsKey('status_penanganan'), isFalse);
    expect(saved, isTrue);

    // Let the post-save refresh and snackbar timers finish.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 30));
  });

  testWidgets('Poli Umum: no doctor is picked, the doctor is cleared', (
    tester,
  ) async {
    final api = await pumpEdit(tester, _visit(poli: 'UMUM', doctorId: null));

    expect(find.byType(PoliUmumDoctorsNote), findsOneWidget);
    expect(find.text('Dokter Pemeriksa'), findsNothing);

    await saveAndWait(tester, () => api.patches.isNotEmpty);

    expect(api.patches.single['doctor_id'], '');
    expect(api.patches.single['poli_code'], 'UMUM');

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 30));
  });

  test('only a waiting visit, edited by the ones who register visits', () {
    expect(isWaitingForDoctor('Menunggu Dokter'), isTrue);
    expect(isWaitingForDoctor('Diperiksa'), isFalse);
    expect(isWaitingForDoctor(null), isFalse);
    expect(canEditVisits(UserRole.perawat), isTrue);
    expect(canEditVisits(UserRole.adminKapal), isTrue);
    expect(canEditVisits(UserRole.dokter), isFalse);
    expect(canEditVisits(UserRole.pharmacy), isFalse);
  });

  test('the patient list gives the latest visit and its status', () {
    final patient = Patient.fromApiJson(const {
      'id': 'patient-1',
      'name': 'Budi',
      'latest_medical_record_id': 'rec-9',
      'latest_status_penanganan': 'Menunggu Dokter',
    });
    expect(patient.medicalRecordId, 'rec-9');
    expect(patient.statusPenanganan, 'Menunggu Dokter');
  });
}
