import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bayan_rme/features/history/presentation/tambah_kunjungan_screen.dart';
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
}
