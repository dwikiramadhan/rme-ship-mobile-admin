import 'package:bayan_rme/core/theme/app_colors.dart';
import 'package:bayan_rme/features/patients/data/patient_repository.dart';
import 'package:bayan_rme/features/patients/presentation/medical_history_detail_view.dart';
import 'package:bayan_rme/features/patients/presentation/patient_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

void main() {
  testWidgets('PatientDetailScreen displays web-inspired patient details, stat boxes, and tabs', (tester) async {
    const testPatientId = '03872b15-c38d-4aa5-a007-e6a59b9b2241';
    final fakeDetailData = <String, dynamic>{
      'id': testPatientId,
      'name': 'Kimi Antonelli',
      'nik': '3173051208950005',
      'dob': '1995-08-17T00:00:00Z',
      'gender': 'Laki-laki',
      'blood_type': 'O+',
      'phone': '081234567890',
      'last_visit': '2026-08-30',
      'address': 'Jl. Pelabuhan No. 12',
      'kode_pos': 23652,
      'nama_wali': 'Siti Rahma',
      'hubungan_wali': 'Istri',
      'keterangan': 'Alergi penisilin',
      'medical_records': [
        {
          'id': 'mr-002',
          'visit_date': '2026-08-30T07:00:00Z',
          'service_ship': {
            'name': 'RSK dr. Lie Dharmawan Bayan Peduli I',
            'location': 'Pelabuhan Tanjung Priok',
          },
          'status': 'Menunggu Dokter',
          'doctor': {
            'name': 'dr. Andika Pratama',
            'sip': '7/B.15a/31.73.08.1002.19.BJ/4/TM.09.74/e/2025',
          },
          'complaint': 'Demam dan sakit kepala',
          'diagnosis': '—',
        },
        {
          'id': 'mr-001',
          'created_at': '2026-08-30T07:00:00Z',
          'service_ship': {
            'name': 'RSK dr. Lie Dharmawan Bayan Peduli I',
            'location': 'Pelabuhan Makassar',
          },
          'status': 'Selesai',
          'doctor': {
            'name': 'dr. Andika Pratama',
            'sip': '7/B.15a/31.73.08.1002.19.BJ/4/TM.09.74/e/2025',
          },
          'complaint': 'Demam dan sakit kepala',
          'diagnosis': '—',
          'diagnoses': [
            {'code': 'A00.0', 'display': 'Cholera due to Vibrio cholerae 01'},
            {'code': 'A01.0', 'display': 'Demam Tifoid'},
          ],
          'prescriptions': [
            {'name': 'Paracetamol 500mg', 'qty': 10, 'dosage': '3x1 sesudah makan'},
          ],
        },
      ],
    };

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          patientDetailProvider(testPatientId).overrideWith((ref) async => fakeDetailData),
        ],
        child: const MaterialApp(
          home: PatientDetailScreen(patientId: testPatientId),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify header buttons
    expect(find.text('Kembali ke Data Pasien'), findsOneWidget);
    expect(find.text('Edit Pasien'), findsOneWidget);

    // Verify patient profile & initials
    expect(find.text('Kimi Antonelli'), findsOneWidget);
    expect(find.textContaining('3173051208950005'), findsOneWidget);
    // Full address in the header summary.
    expect(find.text('Jl. Pelabuhan No. 12'), findsOneWidget);
    expect(find.text('KA'), findsOneWidget);

    // Verify 4 stat boxes
    expect(find.text('GOLONGAN DARAH'), findsOneWidget);
    expect(find.text('O+'), findsOneWidget);
    expect(find.text('NO. TELEPON'), findsOneWidget);
    expect(find.text('081234567890'), findsOneWidget);
    expect(find.text('TOTAL KUNJUNGAN'), findsOneWidget);
    expect(find.text('2 Kali'), findsOneWidget);
    expect(find.text('KUNJUNGAN TERAKHIR'), findsOneWidget);

    // Verify tabs
    expect(find.text('Riwayat Rekam Medis (2)'), findsOneWidget);
    expect(find.text('Profil & Identitas Lengkap'), findsOneWidget);

    // Verify medical record cards
    expect(find.text('#2'), findsOneWidget);
    expect(find.text('#1'), findsOneWidget);
    // Odd/even visits are told apart by background colour only.
    Color? cardColor(String number) {
      final ink = tester.widget<Ink>(
        find.ancestor(of: find.text(number), matching: find.byType(Ink)).first,
      );
      return (ink.decoration as BoxDecoration?)?.color;
    }
    expect(cardColor('#1'), AppColors.card);
    expect(cardColor('#2'), AppColors.orangeLt);

    // Card header items (number, status, arrow) sit on one centre line.
    final card1 = find.ancestor(of: find.text('#1'), matching: find.byType(Ink)).first;
    double centreY(Finder inCard) =>
        tester.getCenter(find.descendant(of: card1, matching: inCard)).dy;
    final badgeY = centreY(find.text('#1'));
    expect(centreY(find.text('Menunggu Dokter')), moreOrLessEquals(badgeY, epsilon: 1));
    expect(centreY(find.byIcon(LucideIcons.chevronRight)), moreOrLessEquals(badgeY, epsilon: 1));
    expect(find.text('Menunggu Dokter'), findsOneWidget);
    expect(find.text('Selesai'), findsOneWidget);
    expect(find.text('Detail Resep'), findsOneWidget);
    expect(find.text('Unduh Resep'), findsOneWidget);
    expect(find.textContaining('dr. Andika Pratama'), findsWidgets);
    expect(find.text('Demam dan sakit kepala'), findsWidgets);
    expect(find.textContaining('30-08-2026'), findsWidgets);
    expect(
      find.text('Cholera due to Vibrio cholerae 01 (A00.0), Demam Tifoid (A01.0)'),
      findsOneWidget,
    );

    // Switch to tab 2: Profil & Identitas Lengkap
    await tester.tap(find.text('Profil & Identitas Lengkap'));
    await tester.pumpAndSettle();

    expect(find.text('Identitas Diri & Informasi Pribadi'), findsOneWidget);
    expect(find.text('Alamat Tempat Tinggal'), findsOneWidget);
    expect(find.text('Kontak Darurat & Wali'), findsOneWidget);
    expect(find.text('Siti Rahma'), findsOneWidget);
    expect(find.text('Istri'), findsOneWidget);
  });

  testWidgets('record and profile tabs fit a phone screen and never invent data', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    const testPatientId = 'patient-phone';
    final fakeDetailData = <String, dynamic>{
      'id': testPatientId,
      'name': 'Pasien Dengan Nama Yang Cukup Panjang Sekali',
      'gender': 'Perempuan',
      'address': 'Jl. Pelabuhan No. 12, RT 03 / RW 05, Kelurahan Koja, Jakarta Utara',
      'keterangan': 'Alergi penisilin',
      'medical_records': [
        // No doctor, complaint, ship or diagnosis recorded yet.
        {'id': 'mr-1', 'created_at': '2026-08-30T07:00:00Z', 'status': 'Selesai'},
      ],
    };

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          patientDetailProvider(testPatientId).overrideWith((ref) async => fakeDetailData),
        ],
        child: const MaterialApp(home: PatientDetailScreen(patientId: testPatientId)),
      ),
    );
    await tester.pumpAndSettle();

    // Missing data is shown as missing, not replaced by sample values.
    expect(find.textContaining('dr. Andika Pratama'), findsNothing);
    expect(find.text('Demam dan sakit kepala'), findsNothing);
    expect(find.textContaining('Tanjung Priok'), findsNothing);
    expect(find.text('Belum ada diagnosis'), findsOneWidget);
    expect(find.text('Detail Resep'), findsOneWidget);
    expect(find.text('Unduh Resep'), findsOneWidget);

    // Tapping a visit card opens its read-only detail in a modal.
    await tester.ensureVisible(find.text('Belum ada diagnosis'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Belum ada diagnosis'));
    await tester.pumpAndSettle();
    expect(find.text('Detail Rekam Medis'), findsOneWidget);
    expect(find.byType(MedicalHistoryDetailView), findsOneWidget);
    // No actions that would lead back to this same page.
    expect(find.text('Buka Rekam Medis Lengkap Pasien'), findsNothing);

    await tester.tap(find.byIcon(LucideIcons.x).last);
    await tester.pumpAndSettle();
    expect(find.text('Detail Rekam Medis'), findsNothing);

    await tester.ensureVisible(find.text('Profil & Identitas Lengkap'));
    await tester.tap(find.text('Profil & Identitas Lengkap'));
    await tester.pumpAndSettle();

    // Allergy note gets its own highlighted box.
    expect(find.text('CATATAN MEDIS / RIWAYAT ALERGI'), findsOneWidget);
    expect(find.text('Alergi penisilin'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('visit without a timestamp shows its date only, not a made-up time', (tester) async {
    const testPatientId = 'patient-date-only';
    final fakeDetailData = <String, dynamic>{
      'id': testPatientId,
      'name': 'Pasien Tanpa Jam',
      'medical_records': [
        {'id': 'mr-1', 'date': '2026-10-11T00:00:00Z', 'status': 'Menunggu Dokter'},
      ],
    };

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          patientDetailProvider(testPatientId).overrideWith((ref) async => fakeDetailData),
        ],
        child: const MaterialApp(home: PatientDetailScreen(patientId: testPatientId)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Minggu, 11-10-2026'), findsOneWidget);
    expect(find.textContaining('11-10-2026 '), findsNothing);
  });
}
