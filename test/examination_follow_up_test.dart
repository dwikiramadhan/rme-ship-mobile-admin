import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bayan_rme/features/doctor/presentation/widgets/examination_input_modal.dart';
import 'package:bayan_rme/features/patients/domain/medical_history.dart';
import 'package:bayan_rme/features/patients/presentation/medical_history_detail_view.dart';

/// A visit the doctor referred to the lab, now back with results.
MedicalHistory _backFromLab() => MedicalHistory.fromApiJson({
  'id': 'mr-1',
  'code': 'RJ12102026-00001',
  'patient_id': 'p-1',
  'patient': {'id': 'p-1', 'name': 'Siti Aminah', 'register_no': 'RJ-1'},
  'status': 'Monitoring',
  'status_penanganan': 'Menunggu Dokter',
  'diagnosis': 'J06.9',
  'diagnoses': [
    {'code': 'J06.9', 'display': 'Acute upper respiratory infection'},
  ],
  'procedures': [
    {'code': '89.07', 'display': 'Konsultasi'},
  ],
  'lab_examination': {
    'id': 'lab-1',
    'requested_test': 'Darah Lengkap',
    'doctor_notes': 'Cek Hb',
    'attachment_url': '/uploads/lab-eximination/hasil.pdf',
    'items': [
      {
        'test_name': 'Hemoglobin',
        'result_value': '10.1',
        'unit': 'g/dL',
        'reference_range': '13.0-17.0',
        'status': 'Low',
      },
    ],
  },
});

void main() {
  test('a visit back from the lab is a follow-up', () {
    final h = _backFromLab();
    expect(h.hasOwnLabResults, isTrue);
    expect(h.isLabFollowUp, isTrue);
  });

  testWidgets('follow-up modal shows lab results and the earlier exam', (tester) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final history = _backFromLab();
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: ExaminationInputModal(patient: history.toPatient(), history: history),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Lanjutan Pemeriksaan (Setelah Lab)'), findsOneWidget);

    // Lab results the doctor continues from.
    expect(find.text('Hasil Pemeriksaan Lab'), findsOneWidget);
    expect(find.text('Darah Lengkap'), findsOneWidget);
    expect(find.text('Hemoglobin'), findsOneWidget);
    expect(find.text('10.1 g/dL'), findsOneWidget);
    expect(find.text('Low'), findsOneWidget);
    expect(find.text('Lihat Dokumen'), findsOneWidget);

    // Earlier diagnosis and procedure are filled in, not empty.
    expect(find.textContaining('J06.9'), findsWidgets);
    expect(find.textContaining('89.07'), findsWidgets);

    expect(find.text('Simpan & Kirim ke Farmasi'), findsOneWidget);

    // Status kondisi dropdown is compact (Material's default is 48px).
    final statusBox = find
        .ancestor(
          of: find.byType(DropdownButton<String>),
          matching: find.byType(Container),
        )
        .first;
    final statusHeight = tester.getSize(statusBox).height;
    expect(statusHeight, lessThanOrEqualTo(40));

    // Let the ICD cache warm-up the modal starts finish.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 30));
  });

  testWidgets('detail button says the doctor continues after the lab', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MedicalHistoryDetailView(history: _backFromLab(), canExamine: true),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Tinjau Hasil Lab & Lanjutkan Pemeriksaan'), findsOneWidget);
    expect(find.text('Periksa Pasien / Input Rekam Medis'), findsNothing);
  });
}
