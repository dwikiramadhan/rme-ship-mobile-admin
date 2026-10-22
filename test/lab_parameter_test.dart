import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bayan_rme/features/lab/presentation/widgets/lab_result_table.dart';
import 'package:bayan_rme/features/patients/domain/lab_order.dart';
import 'package:bayan_rme/features/patients/domain/lab_parameter.dart';
import 'package:bayan_rme/features/patients/domain/lab_test_type.dart';
import 'package:bayan_rme/features/patients/presentation/widgets/prescription_pdf_dialog.dart';

// The lab result form (master GET /lab-parameters): rows of the requested
// tests, the patient's reference range, and what is sent back.

const _tests = [
  LabTestType(id: 't-hema', category: 'Hematologi', name: 'Hematologi Rutin'),
  LabTestType(id: 't-elek', category: 'Elektrolit', name: 'Na, K, Cl'),
  LabTestType(id: 't-prot', category: 'Urinalisa', name: 'Protein'),
  LabTestType(id: 't-glu', category: 'Gula Darah', name: 'Glukosa Puasa'),
];

final _hb = LabParameter.fromJson(const {
  'id': 'hb',
  'section': 'Hematologi',
  'group': '',
  'name': 'Hemoglobin',
  'unit': 'g/dL',
  'input_type': 'text',
  'options': <String>[],
  'normal_options': <String>[],
  'reference_range': 'L : 13,5 – 17,5\nP : 11,7 – 15,5\nAnak : 10,5 – 14,5',
  'references': [
    {'who': 'L', 'range': '13,5 – 17,5'},
    {'who': 'P', 'range': '11,7 – 15,5'},
    {'who': 'Anak', 'range': '10,5 – 14,5'},
  ],
  'sort_order': 1,
  'lab_test_ids': ['t-hema'],
});

const _trombosit = LabParameter(
  id: 'trom',
  section: 'Hematologi',
  name: 'Trombosit',
  referenceRange: 'Dewasa : 150 – 400\nBayi baru lahir : 84 – 487',
  references: [
    LabReference(who: 'Dewasa', range: '150 – 400'),
    LabReference(who: 'Bayi', range: '84 – 487'),
  ],
  sortOrder: 5,
  labTestIds: ['t-hema'],
);

const _glukosa = LabParameter(
  id: 'glu',
  section: 'Kimia Klinik',
  group: 'Gula Darah',
  name: 'Glukosa Puasa',
  unit: 'mg/dL',
  referenceRange: '70 – 110',
  references: [LabReference(who: '', range: '70 – 110')],
  sortOrder: 25,
  labTestIds: ['t-glu'],
);

const _hiv = LabParameter(
  id: 'hiv',
  section: 'Imunoserologi',
  name: 'Anti HIV',
  inputType: kLabInputSelect,
  options: ['Non-Reaktif', 'Reaktif'],
  normalOptions: ['Non-Reaktif'],
  referenceRange: 'Non-Reaktif',
  sortOrder: 19,
);

void main() {
  test('a form row reads its options, references and lab tests', () {
    expect(_hb.name, 'Hemoglobin');
    expect(_hb.isSelect, isFalse);
    expect(_hb.references, hasLength(3));
    expect(_hb.labTestIds, ['t-hema']);
    expect(_glukosa.heading, 'Kimia Klinik / Gula Darah');
    expect(_hb.heading, 'Hematologi');
  });

  test("the doctor's request names the lab tests, commas in names too", () {
    expect(
      requestedLabTestIds(
        'Hematologi: Hematologi Rutin; Elektrolit: Na, K, Cl; '
        'Urinalisa: Protein; Lain-lain: Rontgen Thorax',
        _tests,
      ),
      {'t-hema', 't-elek', 't-prot'},
    );
    // A name in another category doesn't count.
    expect(requestedLabTestIds('Hematologi: Protein', _tests), isEmpty);
    expect(requestedLabTestIds('', _tests), isEmpty);
  });

  test('the requested rows come in form order, grouped by heading', () {
    final rows = requestedParameters(
      [_glukosa, _hiv, _trombosit, _hb],
      {'t-hema', 't-glu'},
    );
    expect(rows.map((p) => p.id), ['hb', 'trom', 'glu']);
    final groups = groupLabParameters(rows);
    expect(groups.map((g) => g.$1), [
      'Hematologi',
      'Kimia Klinik / Gula Darah',
    ]);
    expect(groups.first.$2.map((p) => p.id), ['hb', 'trom']);
    expect(
      filterLabParameters([_hb, _glukosa, _hiv], 'gula').map((p) => p.id),
      ['glu'],
    );
  });

  test("the reference range follows the patient's sex and age", () {
    final at = DateTime(2026, 10, 22);
    String ref(LabParameter p, String gender, DateTime? dob) =>
        patientReference(p, gender: gender, dob: dob, at: at);

    expect(ref(_hb, 'Laki-laki', DateTime(1986)), '13,5 – 17,5');
    expect(ref(_hb, 'Perempuan', DateTime(1996)), '11,7 – 15,5');
    expect(ref(_hb, 'Perempuan', DateTime(2020)), '10,5 – 14,5');
    expect(ref(_trombosit, 'Laki-laki', DateTime(2026, 10, 12)), '84 – 487');
    // A child without a child range: the adult one.
    expect(ref(_trombosit, 'Perempuan', DateTime(2020)), '150 – 400');
    expect(ref(_glukosa, '', null), '70 – 110');
    // Unknown sex, only L/P lines: all of them.
    expect(
      ref(_hb, '', null),
      'L : 13,5 – 17,5; P : 11,7 – 15,5; Anak : 10,5 – 14,5',
    );
    // A choice row shows its reference as is.
    expect(ref(_hiv, 'Laki-laki', null), 'Non-Reaktif');
  });

  test('only rows with a result are sent, by their form row', () {
    final items = labParameterItems(
      [_hb, _glukosa, _hiv],
      {'hb': ' 14,2 ', 'glu': '  ', 'hiv': 'Reaktif'},
      reference: (p) => p.id == 'hb' ? '13,5 – 17,5' : p.referenceRange,
    );
    expect(items, hasLength(2));
    expect(items.first, {
      'lab_parameter_id': 'hb',
      'test_name': 'Hemoglobin',
      'test_category': 'Hematologi',
      'unit': 'g/dL',
      'reference_range': '13,5 – 17,5',
      'result_value': '14,2',
    });
    expect(items.last['lab_parameter_id'], 'hiv');
  });

  test('results are marked like the printed form', () {
    expect(labFlagMark('Tinggi'), ' (H)');
    expect(labFlagMark('Rendah'), ' (L)');
    expect(labFlagMark('Abnormal'), ' *');
    expect(labFlagMark('Normal'), '');
    final item = LabExaminationItem.fromJson(const {
      'lab_parameter_id': 'hb',
      'test_name': 'Hemoglobin',
      'test_category': 'Hematologi',
      'result_value': '10,9',
      'unit': 'g/dL',
      'reference_range': '11,7 – 15,5',
      'status': 'Rendah',
    });
    expect(item.labParameterId, 'hb');
    expect(item.flagged, isTrue);
    final groups = groupLabResults([
      item,
      const LabExaminationItem(
        testName: 'Glukosa Puasa',
        testCategory: 'Gula Darah',
        unit: 'mg/dL',
        referenceRange: '70 – 110',
      ),
    ]);
    expect(groups.map((g) => g.$1), ['Hematologi', 'Gula Darah']);
  });

  testWidgets('the result table highlights values outside the range', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LabResultTable(
            items: [
              LabExaminationItem.fromJson(const {
                'test_name': 'Hemoglobin',
                'test_category': 'Hematologi',
                'result_value': '10,9',
                'unit': 'g/dL',
                'reference_range': '11,7 – 15,5',
                'status': 'Rendah',
              }),
            ],
          ),
        ),
      ),
    );
    expect(find.text('HEMATOLOGI'), findsOneWidget);
    expect(find.text('10,9 (L) g/dL'), findsOneWidget);
    expect(find.text('Rujukan: 11,7 – 15,5'), findsOneWidget);
  });

  testWidgets('the lab result PDF downloads by lab examination', (
    tester,
  ) async {
    final pdf = Uint8List.fromList(utf8.encode('%PDF-1.4 test'));
    String? requested;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showLabResultPdfDialog(
              context,
              labExaminationId: 'lab-1',
              loader: (id) async {
                requested = id;
                return (bytes: pdf, fileName: 'hasil-lab-siti-22102026.pdf');
              },
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump();
    expect(requested, 'lab-1');
    expect(find.text('Hasil Pemeriksaan Lab'), findsOneWidget);
  });
}
