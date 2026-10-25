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

/// Simulates a "load more" request in flight.
class _LoadingMorePatientsNotifier extends _FakePatientsNotifier {
  _LoadingMorePatientsNotifier(super.initial);

  @override
  bool get isLoadingMore => true;
}

Patient _patient(String id) => Patient(
  id: id,
  nama: 'Pasien $id',
  nik: '',
  jk: Gender.l,
  umur: 30,
  alamat: '-',
  keluhanUtama: '-',
  durasiKeluhan: '-',
  lokasiKeluhan: '-',
  vitals: const Vitals(),
  assignedDokterId: '',
  waktuMasuk: '05/09/2026 22:39',
  updatedAt: DateTime(2026, 9, 5),
);

void main() {
  for (final count in [2, 3]) {
    testWidgets(
      'wide layout shows one centered load-more spinner ($count patients)',
      (tester) async {
        tester.view.physicalSize = const Size(1600, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              patientsProvider.overrideWith(
                (ref) => _LoadingMorePatientsNotifier([
                  for (var i = 1; i <= count; i++) _patient('$i'),
                ]),
              ),
            ],
            child: const MaterialApp(home: Scaffold(body: PatientListScreen())),
          ),
        );
        // The spinner animates forever, so pump frames instead of settling.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        final spinner = find.byType(CircularProgressIndicator);
        expect(spinner, findsOneWidget);
        // Centered across the list (same horizontal center as the list).
        final listCenterX = tester.getCenter(find.byType(ListView)).dx;
        expect(
          tester.getCenter(spinner).dx,
          moreOrLessEquals(listCenterX, epsilon: 1),
        );
      },
    );
  }

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
        registerNo: 'RJ30082026-00001',
        phone: '081234567890',
        poliName: 'Poli Umum',
        createdByName: 'Suster Siti',
        createdPortName: 'Pelabuhan Maloy',
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
      expect(find.text('Pelabuhan Maloy'), findsOneWidget);
      expect(find.text('Suster Siti'), findsOneWidget);
      // Phone, poli and the Edit Pasien button are no longer on the card.
      expect(find.text('081234567890'), findsNothing);
      expect(find.text('Poli Umum'), findsNothing);
      expect(find.text('Edit Pasien'), findsNothing);

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
            patientsProvider.overrideWith((ref) => _FakePatientsNotifier([])),
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
