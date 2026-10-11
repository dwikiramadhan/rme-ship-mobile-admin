import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bayan_rme/core/utils/capitalize_first_formatter.dart';
import 'package:bayan_rme/core/widgets/app_text_field.dart';

String _format(String text) {
  const formatter = CapitalizeFirstFormatter();
  return formatter
      .formatEditUpdate(
        TextEditingValue.empty,
        TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
        ),
      )
      .text;
}

void main() {
  group('CapitalizeFirstFormatter', () {
    test('uppercases only the first letter', () {
      expect(_format('demam sejak 2 hari'), 'Demam sejak 2 hari');
      expect(_format('d'), 'D');
    });

    test('skips leading whitespace', () {
      expect(_format('  pusing'), '  Pusing');
    });

    test('leaves the rest of the text untouched', () {
      expect(_format('Sudah Besar'), 'Sudah Besar');
      expect(_format('nyeri DADA kiri'), 'Nyeri DADA kiri');
    });

    test('ignores empty, whitespace and number-first text', () {
      expect(_format(''), '');
      expect(_format('   '), '   ');
      expect(_format('2 hari'), '2 hari');
    });

    test('keeps the cursor position', () {
      const formatter = CapitalizeFirstFormatter();
      final result = formatter.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(
          text: 'abc',
          selection: TextSelection.collapsed(offset: 2),
        ),
      );
      expect(result.selection, const TextSelection.collapsed(offset: 2));
    });
  });

  group('AppTextField', () {
    Future<void> pumpField(WidgetTester tester, AppTextField field) {
      return tester.pumpWidget(
        MaterialApp(home: Scaffold(body: field)),
      );
    }

    testWidgets('capitalizes the first letter of free text', (tester) async {
      final ctrl = TextEditingController();
      await pumpField(tester, AppTextField(label: 'Keluhan', controller: ctrl));

      await tester.enterText(find.byType(TextFormField), 'batuk');
      expect(ctrl.text, 'Batuk');
    });

    testWidgets('leaves opt-out and password fields unchanged', (tester) async {
      final unit = TextEditingController();
      await pumpField(
        tester,
        AppTextField(label: 'Satuan', controller: unit, capitalizeFirst: false),
      );
      await tester.enterText(find.byType(TextFormField), 'g/dL');
      expect(unit.text, 'g/dL');

      final password = TextEditingController();
      await pumpField(
        tester,
        AppTextField(label: 'Sandi', controller: password, obscureText: true),
      );
      await tester.enterText(find.byType(TextFormField), 'rahasia');
      expect(password.text, 'rahasia');
    });
  });
}
