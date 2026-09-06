import 'package:bayan_rme/core/theme/app_colors.dart';
import 'package:bayan_rme/core/widgets/responsive_master_detail.dart';
import 'package:bayan_rme/features/patients/data/patient_repository.dart';
import 'package:bayan_rme/features/patients/domain/patient.dart';
import 'package:bayan_rme/features/patients/domain/vitals.dart';
import 'package:bayan_rme/features/patients/presentation/patient_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakePatientsNotifier extends PatientsNotifier {
  _FakePatientsNotifier(List<Patient> initial) : super(autoFetch: false) {
    state = initial;
  }
}

void main() {
  testWidgets(
    'PatientListScreen displays master patient info without Menunggu Dokter status',
    (tester) async {
      final testPatient = Patient(
        id: 'p-100',
        nama: 'Pierre Gasly',
        nik: '3173051208950007',
        jk: Gender.l,
        umur: 30,
        alamat: 'Jl. Pelabuhan No. 12',
        keluhanUtama: 'Pemeriksaan umum',
        durasiKeluhan: '-',
        lokasiKeluhan: '-',
        vitals: const Vitals(tekananDarah: '120/80'),
        assignedDokterId: '',
        waktuMasuk: '05/09/2026 22:39',
        updatedAt: DateTime.now(),
        status: PatientStatus.menungguDokter,
        registerNo: 'RJ30082026-00001',
        phone: '081234567890',
        poliName: 'Poli Umum',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            patientsProvider.overrideWith(
              (ref) => _FakePatientsNotifier([testPatient]),
            ),
          ],
          child: const MaterialApp(home: Scaffold(body: PatientListScreen())),
        ),
      );

      await tester.pumpAndSettle();

      // Verify patient master info is displayed
      expect(find.text('Pierre Gasly'), findsOneWidget);
      expect(find.text('RJ30082026-00001'), findsOneWidget);
      expect(find.text('3173051208950007'), findsOneWidget);
      expect(find.text('081234567890'), findsOneWidget);
      expect(find.text('Poli Umum'), findsOneWidget);

      // Verify 'Menunggu Dokter' does NOT exist in the widget tree
      expect(find.text('Menunggu Dokter'), findsNothing);
    },
  );

  testWidgets(
    'PatientListScreen renders solid HeaderActionButton when onAddPatient is provided',
    (tester) async {
      bool added = false;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            patientsProvider.overrideWith(
              (ref) => _FakePatientsNotifier([]),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: PatientListScreen(onAddPatient: () => added = true),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final plusFinder = find.byType(HeaderActionButton);
      expect(plusFinder, findsOneWidget);

      final button = tester.widget<HeaderActionButton>(plusFinder);
      expect(button.background, AppColors.blue);
      expect(button.foreground, Colors.white);

      await tester.tap(plusFinder);
      expect(added, isTrue);
    },
  );
}
