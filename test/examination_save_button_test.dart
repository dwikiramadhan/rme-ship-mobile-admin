import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bayan_rme/core/notifications/in_app_notification_overlay.dart';
import 'package:bayan_rme/features/doctor/presentation/widgets/examination_input_modal.dart';
import 'package:bayan_rme/features/patients/domain/medical_history.dart';

// "Simpan Rekam Medis" stays disabled until the required fields are filled
// in, and its errors show above the sheet rather than behind it.

MedicalHistory _visit({String id = 'mr-1', String patientId = 'p-1'}) =>
    MedicalHistory.fromApiJson({
      'id': id,
      'code': 'RJ30102026-00001',
      'patient_id': patientId,
      'patient': {'id': patientId, 'name': 'Siti Aminah'},
      'status': 'Stable',
      'status_penanganan': 'Menunggu Dokter',
      'diagnoses': [
        {'code': 'J06.9', 'display': 'Acute upper respiratory infection'},
      ],
    });

ElevatedButton _saveButton(WidgetTester tester, String label) => tester.widget(
  find.ancestor(of: find.text(label), matching: find.byType(ElevatedButton)),
);

/// Lets the ICD cache warm-up and the banner timer finish.
Future<void> _finish(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 30));
}

void main() {
  testWidgets('disabled until the required fields are filled in', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // A new exam: nothing recorded yet.
    final history = MedicalHistory.fromApiJson({
      'id': 'mr-1',
      'patient_id': 'p-1',
      'patient': {'id': 'p-1', 'name': 'Siti Aminah'},
      'status_penanganan': 'Menunggu Dokter',
    });
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: ExaminationInputModal(
              patient: history.toPatient(),
              history: history,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(_saveButton(tester, 'Simpan Rekam Medis').onPressed, isNull);
    expect(
      find.text(
        'Lengkapi dulu: Hasil Pemeriksaan, Diagnosa Klinis (ICD-10), '
        'Obat (atau pilih Tidak Perlu Obat)',
      ),
      findsOneWidget,
    );

    await tester.enterText(
      find.widgetWithText(
        TextField,
        'Tuliskan hasil pemeriksaan fisik / temuan klinis pasien...',
      ),
      'Faring hiperemis',
    );
    await tester.tap(find.text('Tidak Perlu Obat'));
    await tester.pump();

    // Only the diagnosis is left.
    expect(
      find.text('Lengkapi dulu: Diagnosa Klinis (ICD-10)'),
      findsOneWidget,
    );
    expect(_saveButton(tester, 'Simpan Rekam Medis').onPressed, isNull);

    await _finish(tester);
  });

  testWidgets('enabled once everything required is there', (tester) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final history = _visit();
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: ExaminationInputModal(
              patient: history.toPatient(),
              history: history,
              editing: true,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Tidak Perlu Obat'));
    await tester.pump();

    expect(find.textContaining('Lengkapi dulu'), findsNothing);
    expect(_saveButton(tester, 'Simpan Perubahan').onPressed, isNotNull);

    await _finish(tester);
  });

  testWidgets('a save error shows above the sheet', (tester) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // No record id: saving stops with an error.
    final history = _visit(id: '', patientId: '');
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          // The test font is far wider than the app's: the sheet gets the
          // same width as the modal in the other tests.
          theme: ThemeData(
            bottomSheetTheme: const BottomSheetThemeData(
              constraints: BoxConstraints(maxWidth: 900),
            ),
          ),
          builder: (context, child) => InAppNotificationOverlay(child: child!),
          home: const Scaffold(body: SizedBox.expand()),
        ),
      ),
    );
    unawaited(
      showExaminationInputModal(
        tester.element(find.byType(Scaffold)),
        patient: history.toPatient(),
        history: history,
        editing: true,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tidak Perlu Obat'));
    await tester.pump();
    await tester.tap(find.text('Simpan Perubahan'));
    await tester.pumpAndSettle();

    // On top of the sheet: it can be seen and tapped.
    expect(
      find.text('Gagal Menyimpan Rekam Medis').hitTestable(),
      findsOneWidget,
    );
    // The sheet stays open to fix it.
    expect(find.text('Simpan Perubahan'), findsOneWidget);

    await _finish(tester);
  });
}
