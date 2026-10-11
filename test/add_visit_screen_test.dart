import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bayan_rme/features/history/presentation/add_visit_screen.dart';
import 'package:bayan_rme/features/patients/data/patient_repository.dart';
import 'package:bayan_rme/features/patients/domain/patient.dart';
import 'package:bayan_rme/features/patients/domain/vitals.dart';

void main() {
  testWidgets('TambahKunjunganScreen renders correctly with patient selection, vitals, and form fields', (tester) async {
    final samplePatient = Patient(
      id: 'patient-123',
      nama: 'Pierre Gasly',
      nik: '3173051208950007',
      jk: Gender.l,
      umur: 30,
      alamat: 'Jl. Pelabuhan No. 12',
      keluhanUtama: '',
      durasiKeluhan: '',
      lokasiKeluhan: '',
      vitals: const Vitals(tekananDarah: '120/80', nadi: '78', suhu: '36.8', frekuensiNapas: '18', spo2: '98'),
      assignedDokterId: '',
      waktuMasuk: '10:00',
      updatedAt: DateTime(2026, 9, 6),
      registerNo: 'RJ05092026-00001',
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: TambahKunjunganScreen(
              initialPatient: samplePatient,
              onBack: () {},
              onSaved: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Title & Subtitle
    expect(find.text('Input Kunjungan Baru'), findsOneWidget);

    // Verify Selected Patient is rendered in selector & summary
    expect(find.text('Pierre Gasly'), findsWidgets);
    expect(find.text('RJ05092026-00001'), findsOneWidget);
    expect(find.text('Ganti Pasien'), findsOneWidget);

    // Verify Form Sections without numbers
    expect(find.text('Pilih Pasien'), findsOneWidget);
    expect(find.text('Poliklinik & Dokter Pemeriksa'), findsOneWidget);
    expect(find.text('Keluhan Pasien'), findsOneWidget);
    expect(find.text('Tanda-Tanda Vital (Triage)'), findsOneWidget);

    // Verify Save Button
    expect(find.text('Simpan Kunjungan'), findsOneWidget);

    // Test Ganti Pasien button opens popup modal
    await tester.tap(find.text('Ganti Pasien'));
    await tester.pumpAndSettle();

    // Now popup modal should appear with search field and 'Pilih Pasien' title
    expect(find.byType(PatientSearchModal), findsOneWidget);
    expect(find.text('Cari nama pasien, NIK, atau No. RM...'), findsOneWidget);
  });

  testWidgets('Pilih Pasien list shows short patient facts and hides missing ones', (tester) async {
    Patient patient({required String id, required String nama, String nik = '', String registerNo = '', String? dob, String? lastVisit}) {
      return Patient(
        id: id,
        nama: nama,
        nik: nik,
        jk: Gender.p,
        umur: dob == null ? 0 : 28,
        alamat: '',
        keluhanUtama: '',
        durasiKeluhan: '',
        lokasiKeluhan: '',
        vitals: const Vitals(),
        assignedDokterId: '',
        waktuMasuk: '',
        updatedAt: DateTime(2026, 9, 6),
        registerNo: registerNo,
        dob: dob,
        lastVisit: lastVisit,
      );
    }

    final complete = patient(
      id: 'p-1',
      nama: 'Siti Aminah',
      nik: '3173051208950007',
      registerNo: 'RJ05092026-00001',
      dob: '1998-01-01',
      lastVisit: '2026-09-05T10:00:00Z',
    );
    final sparse = patient(id: 'p-2', nama: 'Tanpa Data');
    Patient? picked;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          patientsProvider.overrideWith(
            (ref) => PatientsNotifier(autoFetch: false)..state = [complete, sparse],
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: PatientSearchModal(selectedId: 'p-1', onSelect: (p) => picked = p),
          ),
        ),
      ),
    );

    expect(find.text('Siti Aminah'), findsOneWidget);
    expect(find.text('RJ05092026-00001'), findsOneWidget);
    expect(find.text('Perempuan · 28 thn'), findsOneWidget);
    expect(find.text('3173051208950007'), findsOneWidget);
    expect(find.text('Terakhir 05 Sep 2026'), findsOneWidget);

    // No date of birth / NIK / RM: only gender, no "0 thn", "NIK:" or "RM: -".
    expect(find.text('Perempuan'), findsOneWidget);
    expect(find.textContaining('0 thn'), findsNothing);
    expect(find.textContaining('NIK:'), findsNothing);
    expect(find.text('RM: -'), findsNothing);

    await tester.tap(find.text('Tanpa Data'));
    expect(picked?.id, 'p-2');
  });
}
