import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bayan_rme/features/doctor/presentation/widgets/examination_input_modal.dart';
import 'package:bayan_rme/features/patients/data/patient_repository.dart';
import 'package:bayan_rme/features/patients/domain/lab_order.dart';
import 'package:bayan_rme/features/patients/domain/lab_test_type.dart';
import 'package:bayan_rme/features/patients/domain/medical_history.dart';

const _tests = [
  LabTestType(id: '1', category: 'Hematologi', name: 'Hematologi Rutin'),
  LabTestType(id: '2', category: 'Hematologi', name: 'Golongan Darah ABO & Rh'),
  LabTestType(id: '3', category: 'Urinalisa', name: 'Protein'),
  LabTestType(id: '4', category: 'Gula Darah', name: 'Glukosa Puasa', requiresFasting: true),
];

void main() {
  test('a lab test reads the master JSON', () {
    final t = LabTestType.fromJson(const {
      'id': '4',
      'category': 'Gula Darah',
      'name': 'Glukosa Puasa',
      'requires_fasting': true,
    });
    expect(t, _tests[3]);
  });

  test('the request names each category, then "Lain-lain"', () {
    expect(groupLabTests(_tests).map((g) => g.$1), ['Hematologi', 'Urinalisa', 'Gula Darah']);
    expect(
      buildRequestedTest([_tests[0], _tests[3], _tests[2], _tests[1]], ' Rontgen Thorax '),
      'Hematologi: Hematologi Rutin, Golongan Darah ABO & Rh; Gula Darah: Glukosa Puasa; '
      'Urinalisa: Protein; Lain-lain: Rontgen Thorax',
    );
    expect(buildRequestedTest(const [], '  '), isEmpty);
  });

  test('searching lab tests matches the name or the category', () {
    expect(filterLabTests(_tests, 'glukosa').map((t) => t.id), ['4']);
    expect(filterLabTests(_tests, ' HEMATO ').map((t) => t.id), ['1', '2']);
    expect(filterLabTests(_tests, 'urinalisa').map((t) => t.id), ['3']);
    expect(filterLabTests(_tests, ''), hasLength(4));
  });

  test('the fasting flag goes to the server and comes back', () {
    const order = LabOrder(id: 'L1', jenis: 'Gula Darah: Glukosa Puasa', requiresFasting: true);
    expect(labOrderRequestJson(order)['requires_fasting'], isTrue);

    final visit = MedicalHistory.fromApiJson({
      'id': 'mr-1',
      'patient_id': 'p-1',
      'status_penanganan': 'Menunggu Lab',
      'lab_examination': {
        'id': 'lab-1',
        'requested_test': 'Gula Darah: Glukosa Puasa',
        'requires_fasting': true,
      },
    });
    expect(visit.requestedLabOrder?.requiresFasting, isTrue);
  });

  testWidgets('the doctor ticks lab tests per category and sees the fasting note', (tester) async {
    tester.view.physicalSize = const Size(900, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final history = MedicalHistory.fromApiJson({
      'id': 'mr-1',
      'patient_id': 'p-1',
      'patient': {'id': 'p-1', 'name': 'Siti Aminah'},
      'status_penanganan': 'Menunggu Dokter',
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [labTestsProvider.overrideWith((ref) async => _tests)],
        child: MaterialApp(
          home: Scaffold(
            body: ExaminationInputModal(patient: history.toPatient(), history: history),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Ya, Perlu Rujukan Lab'));
    await tester.pump();
    await tester.pump(); // the lab tests arrive
    expect(find.text('Hematologi'), findsOneWidget);
    expect(find.text('Gula Darah'), findsOneWidget);
    expect(find.text('Lain-lain'), findsOneWidget);
    expect(find.textContaining('perlu puasa'), findsNothing);

    await tester.tap(find.text('Glukosa Puasa'));
    await tester.pump();
    expect(
      find.text('Pasien perlu puasa sebelum pengambilan sampel (Glukosa Puasa).'),
      findsOneWidget,
    );

    // Let the ICD cache warm-up the modal starts finish.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 30));
  });
}
