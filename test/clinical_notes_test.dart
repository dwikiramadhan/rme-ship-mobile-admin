import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bayan_rme/features/doctor/presentation/widgets/doctor_exam_summary.dart';
import 'package:bayan_rme/features/patients/domain/clinical_notes.dart';
import 'package:bayan_rme/features/patients/domain/medical_history.dart';

void main() {
  test("the exam result is the doctor's note, without the other roles", () {
    const notes = '[Perawat - 2026-10-22 07:00]: Tensi diulang\n'
        '[Doctor - 2026-10-22 07:24]: Faring hiperemis\n'
        'tonsil T1-T1\n'
        '[Lab - 2026-10-22 08:00]: Sampel diterima\n'
        '[Dokter - 2026-10-22 09:00]: Setelah lab: Hb rendah';
    expect(
      doctorExamResult(notes),
      'Faring hiperemis\ntonsil T1-T1\nSetelah lab: Hb rendah',
    );
    expect(doctorExamResult('[Perawat - 2026-10-22 07:00]: Tensi'), isEmpty);
    // Triage vitals after the doctor's entry aren't part of it.
    expect(
      doctorExamResult('[Doctor - 2026-10-22 07:24]: Faring hiperemis\n[Triage] TD: 120/80'),
      'Faring hiperemis',
    );
  });

  test('untagged notes are not the exam result', () {
    expect(doctorExamResult(' Istirahat cukup '), isEmpty);
    expect(doctorExamResult('[Triage] TD: 120/80 | Nadi: 88'), isEmpty);
    expect(doctorExamResult(null), isEmpty);
  });

  testWidgets('the lab sees the doctor\'s exam result above the diagnosis', (tester) async {
    final visit = MedicalHistory.fromApiJson({
      'id': 'mr-1',
      'patient_id': 'p-1',
      'status_penanganan': 'Menunggu Lab',
      'diagnosis': 'J06.9',
    });
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: DoctorExamSummary(
              patient: visit.toPatient(),
              examResult: doctorExamResult('[Doctor - 2026-10-22 07:24]: Faring hiperemis'),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Hasil Pemeriksaan'), findsOneWidget);
    expect(find.text('Faring hiperemis'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Faring hiperemis')).dy,
      lessThan(tester.getTopLeft(find.text('Diagnosa Klinis')).dy),
    );
  });
}
