import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bayan_rme/features/doctor/presentation/widgets/doctor_exam_summary.dart';
import 'package:bayan_rme/features/patients/domain/patient.dart';
import 'package:bayan_rme/features/patients/domain/vitals.dart';

void main() {
  testWidgets('diagnoses and procedures show code + name, names not bold', (tester) async {
    final patient = Patient(
      id: 'p-1',
      nama: 'Pasien',
      nik: '',
      jk: Gender.p,
      umur: 30,
      alamat: '',
      keluhanUtama: '',
      durasiKeluhan: '',
      lokasiKeluhan: '',
      vitals: const Vitals(),
      assignedDokterId: '',
      waktuMasuk: '',
      updatedAt: DateTime(2026, 10, 12),
      diagnosa: 'J02.9 - Acute pharyngitis; A09 - Gastroenteritis',
      tindakan: '89.07 - Konsultasi',
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(body: SingleChildScrollView(child: DoctorExamSummary(patient: patient))),
        ),
      ),
    );

    expect(find.text('DIAGNOSA KLINIS'), findsOneWidget);
    expect(find.text('J02.9'), findsOneWidget);
    expect(find.text('Utama'), findsOneWidget);
    expect(find.text('Sekunder'), findsOneWidget);
    expect(find.text('89.07'), findsOneWidget);

    for (final name in ['Acute pharyngitis', 'Gastroenteritis', 'Konsultasi']) {
      final weight = tester.widget<Text>(find.text(name)).style?.fontWeight;
      expect(weight == null || weight == FontWeight.w400, isTrue, reason: '$name should not be bold');
    }
  });
}
