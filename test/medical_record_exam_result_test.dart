import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bayan_rme/features/patients/domain/medical_history.dart';
import 'package:bayan_rme/features/patients/presentation/medical_history_detail_view.dart';

// The doctor's free-text "Hasil Pemeriksaan" shows in the visit detail, under
// "Hasil Pemeriksaan & Catatan Medis".

MedicalHistory _visit({String? notes}) => MedicalHistory.fromApiJson({
  'id': 'mr-1',
  'code': 'RJ12102026-00002',
  'patient_id': 'p-1',
  'patient': {'id': 'p-1', 'name': 'Budi Santoso'},
  'status_penanganan': 'Menunggu Obat',
  'created_at': '2026-10-12T08:00:00Z',
  'complaint': 'Batuk 3 hari',
  'notes': ?notes,
});

Future<void> _pumpDetail(WidgetTester tester, MedicalHistory history) async {
  tester.view.physicalSize = const Size(900, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: MedicalHistoryDetailView(history: history, embedded: true),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets("shows the doctor's exam result, not the other notes", (
    tester,
  ) async {
    await _pumpDetail(
      tester,
      _visit(
        notes:
            '[Perawat - 2026-10-12 08:00]: Pasien datang sendiri\n'
            '[Doctor - 2026-10-12 08:30]: Ronki basah di paru kanan\n'
            'Tidak ada wheezing',
      ),
    );

    expect(find.text('Hasil Pemeriksaan'), findsOneWidget);
    expect(
      find.text('Ronki basah di paru kanan\nTidak ada wheezing'),
      findsOneWidget,
    );
    expect(find.textContaining('Pasien datang sendiri'), findsNothing);
  });

  testWidgets('says so when the doctor has not examined yet', (tester) async {
    await _pumpDetail(tester, _visit());

    expect(find.text('Hasil Pemeriksaan'), findsOneWidget);
    expect(find.text('Belum ada hasil pemeriksaan dokter'), findsOneWidget);
  });
}
