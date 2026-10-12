import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bayan_rme/features/patients/domain/dispensed_medicine.dart';
import 'package:bayan_rme/features/patients/domain/medical_history.dart';
import 'package:bayan_rme/features/patients/presentation/medical_history_detail_view.dart';

/// A finished visit as GET /medical-history returns it: the doctor
/// prescribed Amoxicillin, the pharmacy gave Cefadroxil instead.
MedicalHistory _finishedVisit({String status = 'Selesai'}) =>
    MedicalHistory.fromApiJson({
      'id': 'mr-1',
      'code': 'RJ12102026-00002',
      'patient_id': 'p-1',
      'patient': {'id': 'p-1', 'name': 'Budi Santoso'},
      'status_penanganan': status,
      'created_at': '2026-10-12T08:00:00Z',
      'prescriptions': [
        {
          'sku': 'AMX-500',
          'medicine': {
            'name': 'Amoxicillin 500mg',
            'unit_of_measurement': 'Kapsul',
          },
          'dosage': '3x1',
          'quantity': 10,
          'instructions': 'Sesudah makan',
          'dispenses': [
            {
              'dispensed_sku': 'CFX-500',
              'dispensed_medicine': {
                'name': 'Cefadroxil 500mg',
                'unit_of_measurement': 'Kapsul',
              },
              'dispensed_quantity': 10,
              'is_substituted': true,
              'substitution_reason': 'Stok Habis',
              'dispensed_by': {'name': 'apt. Aditya'},
              'dispensed_at': '2026-10-12T09:00:00Z',
            },
          ],
        },
        {
          'sku': 'PCM-500',
          'medicine': {
            'name': 'Paracetamol 500mg',
            'unit_of_measurement': 'Tablet',
          },
          'dosage': '3x1',
          'quantity': 6,
          'instructions': 'Bila demam',
          'dispenses': [
            {
              'dispensed_sku': 'PCM-500',
              'dispensed_medicine': {
                'name': 'Paracetamol 500mg',
                'unit_of_measurement': 'Tablet',
              },
              'dispensed_quantity': 6,
              'is_substituted': false,
              'dispensed_by': {'name': 'apt. Aditya'},
            },
          ],
        },
      ],
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
  test('reads what the pharmacy handed over, including substitutions', () {
    final items = _finishedVisit().dispensedMedicines;

    expect(items, hasLength(2));
    final first = items.first;
    expect(first.name, 'Cefadroxil 500mg');
    expect(first.quantity, 10);
    expect(first.unit, 'Kapsul');
    expect(first.dosage, '3x1');
    expect(first.instructions, 'Sesudah makan');
    expect(first.isSubstituted, isTrue);
    expect(first.substitutedFor, 'Amoxicillin 500mg');
    expect(first.substitutionReason, 'Stok Habis');
    expect(first.dispensedBy, 'apt. Aditya');
    expect(items.last.isSubstituted, isFalse);
  });

  test('reads the patient detail record shape too', () {
    // GET /patients/:id records: name/instruction, dispenses in the same keys.
    final items = DispensedMedicine.listFromPrescriptions([
      {
        'name': 'Amoxicillin 500mg',
        'unit_of_measurement': 'Kapsul',
        'dosage': '3x1',
        'quantity': 10,
        'instruction': 'Sesudah makan',
        'dispenses': [
          {
            'dispensed_medicine': {
              'name': 'Cefadroxil 500mg',
              'unit_of_measurement': 'Kapsul',
            },
            'dispensed_quantity': 10,
            'is_substituted': true,
            'substitution_reason': 'Stok Habis',
          },
        ],
      },
      // Not dispensed (older data): the prescription itself.
      {'name': 'Vitamin C', 'quantity': 5, 'instruction': 'Pagi'},
    ]);

    expect(items.first.name, 'Cefadroxil 500mg');
    expect(items.first.instructions, 'Sesudah makan');
    expect(items.first.substitutedFor, 'Amoxicillin 500mg');
    expect(items.last.name, 'Vitamin C');
    expect(items.last.quantity, 5);
    expect(items.last.isSubstituted, isFalse);
  });

  testWidgets('finished visit lists the medicines given', (tester) async {
    await _pumpDetail(tester, _finishedVisit());

    expect(find.text('Obat yang Diberikan'), findsOneWidget);
    expect(find.text('Cefadroxil 500mg'), findsOneWidget);
    expect(find.text('10 Kapsul'), findsOneWidget);
    expect(find.text('3x1 · Sesudah makan'), findsOneWidget);
    expect(
      find.text('Pengganti Amoxicillin 500mg · Stok Habis'),
      findsOneWidget,
    );
    expect(find.text('Paracetamol 500mg'), findsOneWidget);
    expect(find.textContaining('Diserahkan oleh apt. Aditya'), findsOneWidget);
  });

  testWidgets('not shown before the visit is finished', (tester) async {
    await _pumpDetail(tester, _finishedVisit(status: 'Menunggu Obat'));

    expect(find.text('Obat yang Diberikan'), findsNothing);
  });
}
