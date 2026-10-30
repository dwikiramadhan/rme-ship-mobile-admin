import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bayan_rme/features/nurse/presentation/patient_form.dart';
import 'package:bayan_rme/features/patients/data/patient_api.dart';
import 'package:bayan_rme/features/patients/data/patient_repository.dart';
import 'package:bayan_rme/features/patients/data/region_api.dart';
import 'package:bayan_rme/features/patients/domain/doctor.dart';
import 'package:bayan_rme/features/patients/domain/patient.dart';
import 'package:bayan_rme/features/patients/domain/vitals.dart';
import 'package:bayan_rme/features/patients/presentation/patient_detail_screen.dart';

/// Records what the edit form sends; never touches the network.
class _RecordingPatientApi extends PatientApi {
  final updates = <Map<String, dynamic>>[];
  int medicalRecordsCreated = 0;

  @override
  Future<Patient> updatePatient(String id, Map<String, dynamic> body) async {
    updates.add(body);
    return _patient;
  }

  @override
  Future<void> addMedicalRecord(String patientId, Map<String, dynamic> body) async {
    medicalRecordsCreated++;
  }
}

/// Two provinces / regencies / districts / villages, so a wrong default
/// selection would be visible.
class _FakeWilayahApi extends WilayahApi {
  @override
  Future<List<WilayahProvinsi>> getProvinsi() async => const [
        WilayahProvinsi(kodeProvinsi: 61, namaProvinsi: 'Kalimantan Barat'),
        WilayahProvinsi(kodeProvinsi: 64, namaProvinsi: 'Kalimantan Timur'),
      ];

  @override
  Future<List<WilayahKabupatenKota>> getKabupatenKota(int kodeProvinsi) async => [
        WilayahKabupatenKota(kodeKabkota: kodeProvinsi + 0.01, namaKabkota: 'Kab. Satu', kodeProvinsi: kodeProvinsi),
        WilayahKabupatenKota(kodeKabkota: kodeProvinsi + 0.07, namaKabkota: 'Kabupaten Bengkayang', kodeProvinsi: kodeProvinsi),
      ];

  @override
  Future<List<WilayahKecamatan>> getKecamatan(double kodeKabkota) async {
    final kab = kodeKabkota.toStringAsFixed(2);
    return [
      WilayahKecamatan(kodeKecamatan: '$kab.01', namaKecamatan: 'Kec. Satu', kodeKabkota: kodeKabkota),
      WilayahKecamatan(kodeKecamatan: '$kab.04', namaKecamatan: 'Bengkayang', kodeKabkota: kodeKabkota),
    ];
  }

  @override
  Future<List<WilayahKelurahan>> getKelurahan(String kodeKecamatan) async => [
        WilayahKelurahan(kodeKelurahan: '$kodeKecamatan.1001', namaKelurahan: 'Desa Satu', kodeKecamatan: kodeKecamatan, kodePos: 11111),
        WilayahKelurahan(kodeKelurahan: '$kodeKecamatan.2006', namaKelurahan: 'Bani Amas', kodeKecamatan: kodeKecamatan, kodePos: 79211),
      ];
}

final _patient = Patient(
  id: 'patient-1',
  nama: 'Syafruddin',
  nik: '3171012304950001',
  jk: Gender.l,
  umur: 31,
  dob: '1995-04-23',
  alamat: 'Jl. Pelabuhan Semayang No. 12, Kel. Bani Amas, Kec. Bengkayang, '
      'Kabupaten Bengkayang, Kalimantan Barat, 79211',
  kodeKelurahan: '61.07.04.2006',
  // Foto identitas wajib; NIK opsional.
  photoUrl: '/uploads/patients/syafruddin.jpg',
  // Known ship, so saving doesn't look it up in device storage.
  serviceShipCode: 'RSK-001',
  // As opened from the patient detail: no doctor or complaint on the patient.
  keluhanUtama: '',
  durasiKeluhan: '',
  lokasiKeluhan: '',
  vitals: const Vitals(),
  assignedDokterId: '',
  waktuMasuk: '',
  updatedAt: DateTime(2026, 10, 11),
);

void main() {
  testWidgets('edit form only edits patient data and keeps the address region', (tester) async {
    tester.view.physicalSize = const Size(640, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final api = _RecordingPatientApi();
    var saved = false;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          patientApiProvider.overrideWithValue(api),
          wilayahApiProvider.overrideWithValue(_FakeWilayahApi()),
          doctorsProvider.overrideWith((ref) async => []),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: PatientForm(
              initialPatient: _patient,
              onBack: () {},
              onSaved: () => saved = true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Triage belongs to visits, not to editing the patient.
    expect(find.text('DOKTER PEMERIKSA'), findsNothing);
    expect(find.text('Keluhan Utama'), findsNothing);
    // Allergies are patient data, so they stay editable here.
    expect(find.text('Riwayat Alergi'), findsOneWidget);

    // The street is edited on its own; the region comes from the code.
    final street = tester.widget<TextFormField>(
      find.descendant(
        of: find.ancestor(of: find.text('Detail Jalan / RT / RW'), matching: find.byType(Column)).first,
        matching: find.byType(TextFormField),
      ),
    );
    expect(street.controller!.text, 'Jl. Pelabuhan Semayang No. 12');

    await tester.tap(find.text('Simpan Perubahan'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(saved, isTrue);
    expect(api.medicalRecordsCreated, 0, reason: 'editing must not create a visit');
    expect(api.updates, hasLength(1));
    final body = api.updates.single;
    expect(body['kode_kelurahan'], '61.07.04.2006');
    expect(
      body['address'],
      'Jl. Pelabuhan Semayang No. 12, Kel. Bani Amas, Kec. Bengkayang, '
      'Kabupaten Bengkayang, Kalimantan Barat, 79211',
    );
  });

  testWidgets('a patient without an identity photo cannot be saved, even with a NIK', (tester) async {
    tester.view.physicalSize = const Size(640, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final api = _RecordingPatientApi();
    var saved = false;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          patientApiProvider.overrideWithValue(api),
          wilayahApiProvider.overrideWithValue(_FakeWilayahApi()),
          doctorsProvider.overrideWith((ref) async => []),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: PatientForm(
              initialPatient: _patient.copyWith(photoUrl: null),
              onBack: () {},
              onSaved: () => saved = true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // NIK and photo are both shown; there is no identity type to pick.
    expect(find.text('Nomor NIK (Nomor Induk Kependudukan)'), findsOneWidget);
    expect(find.text('Jenis Identitas'), findsNothing);

    await tester.tap(find.text('Simpan Perubahan'));
    await tester.pump();

    expect(saved, isFalse);
    expect(api.updates, isEmpty);
  });

  testWidgets('"Edit Pasien" from the patient detail opens a working page', (tester) async {
    tester.view.physicalSize = const Size(640, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          patientApiProvider.overrideWithValue(_RecordingPatientApi()),
          wilayahApiProvider.overrideWithValue(_FakeWilayahApi()),
          doctorsProvider.overrideWith((ref) async => []),
          patientDetailProvider('patient-1').overrideWith(
            (ref) async => <String, dynamic>{
              'id': 'patient-1',
              'name': 'Syafruddin',
              'gender': 'Laki-laki',
              'dob': '1995-04-23T00:00:00Z',
              'address': _patient.alamat,
              'kode_kelurahan': '61.07.04.2006',
              'service_ship_code': 'RSK-001',
              'medical_records': <Map<String, dynamic>>[],
            },
          ),
        ],
        child: const MaterialApp(home: PatientDetailScreen(patientId: 'patient-1')),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Edit Pasien'));
    await tester.pumpAndSettle();

    // Pushed as its own page: needs a Scaffold for fields and ink.
    expect(tester.takeException(), isNull);
    expect(find.text('Edit Data Pasien'), findsOneWidget);
    expect(find.text('Simpan Perubahan'), findsOneWidget);
  });

  testWidgets('new patient: Riwayat Alergi comes right after Lokasi Keluhan', (tester) async {
    tester.view.physicalSize = const Size(640, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          patientApiProvider.overrideWithValue(_RecordingPatientApi()),
          wilayahApiProvider.overrideWithValue(_FakeWilayahApi()),
          doctorsProvider.overrideWith((ref) async => []),
        ],
        child: MaterialApp(
          home: Scaffold(body: PatientForm(onBack: () {}, onSaved: () {})),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Starts empty: no sample patient, complaint or vitals.
    for (final sample in ['Budi Santoso', '3171012304950001', 'Demam dan sakit kepala sejak kemarin', '120/80']) {
      expect(find.text(sample), findsNothing, reason: sample);
    }
    // No region picked for the nurse.
    expect(find.text('Kalimantan Barat'), findsNothing);
    expect(find.text('Kalimantan Timur'), findsNothing);

    expect(find.text('Riwayat Alergi'), findsOneWidget);
    final lokasi = tester.getTopLeft(find.text('Lokasi Keluhan')).dy;
    final alergi = tester.getTopLeft(find.text('Riwayat Alergi')).dy;
    final tandaVital = tester.getTopLeft(find.text('TANDA VITAL')).dy;
    expect(alergi, greaterThan(lokasi));
    expect(alergi, lessThan(tandaVital));
  });

  testWidgets('new patient: no doctor is preselected', (tester) async {
    tester.view.physicalSize = const Size(640, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          patientApiProvider.overrideWithValue(_RecordingPatientApi()),
          wilayahApiProvider.overrideWithValue(_FakeWilayahApi()),
          doctorsProvider.overrideWith(
            (ref) async => const [
              Doctor(id: 'doc-1', nama: 'dr. Putri Maulina', spesialisasi: 'Umum', online: true),
            ],
          ),
        ],
        child: MaterialApp(
          home: Scaffold(body: PatientForm(onBack: () {}, onSaved: () {})),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('dr. Putri Maulina'), findsNothing);
  });
}
