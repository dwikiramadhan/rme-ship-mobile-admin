import 'package:bayan_rme/core/utils/clean_text_helper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CleanTextHelper', () {
    test('extracts clean name and code from Map', () {
      final map = {
        'name': 'Cairan D 40% 25 Ml',
        'sku': 'GT-C009',
      };
      expect(CleanTextHelper.cleanName(map), equals('Cairan D 40% 25 Ml'));
      expect(CleanTextHelper.cleanCode(map), equals('GT-C009'));
    });

    test('extracts clean name and code from stringified Map', () {
      const str = '{id: 123, name: Cairan D 40% 25 Ml, code: GT-C009}';
      expect(CleanTextHelper.cleanName(str), equals('Cairan D 40% 25 Ml'));
      expect(CleanTextHelper.cleanCode(str), equals('GT-C009'));
    });

    test('extracts clean name and code with quotes in stringified Map', () {
      const str = '{"patient_name": "Pierre Gasly", "register_no": "RJ05092026-00001"}';
      expect(CleanTextHelper.cleanName(str), equals('Pierre Gasly'));
      expect(CleanTextHelper.cleanCode(str), equals('RJ05092026-00001'));
    });

    test('extracts clean name and code from nested Map', () {
      final map = {
        'id': 'abc',
        'medicine': {
          'name': 'Diazepam Supp',
          'code': 'GP-D002',
        },
      };
      expect(CleanTextHelper.cleanName(map), equals('Diazepam Supp'));
      expect(CleanTextHelper.cleanCode(map), equals('GP-D002'));
    });

    test('never leaks raw object string when keys are unknown', () {
      const str = '{id: 123, foo: bar}';
      expect(CleanTextHelper.cleanName(str, fallback: 'Obat'), equals('Obat'));
      expect(CleanTextHelper.cleanCode(str, fallback: '—'), equals('—'));
    });

    test('handles Instance of and brackets gracefully', () {
      expect(CleanTextHelper.cleanName("Instance of 'SomeClass'", fallback: 'Fallback'), equals('Fallback'));
    });

    test('handles plain strings normally', () {
      expect(CleanTextHelper.cleanName('Paracetamol'), equals('Paracetamol'));
      expect(CleanTextHelper.cleanCode('MED-001'), equals('MED-001'));
    });

    test('handles empty and null values gracefully', () {
      expect(CleanTextHelper.cleanName(null, fallback: 'Pasien'), equals('Pasien'));
      expect(CleanTextHelper.cleanCode(null, fallback: '—'), equals('—'));
      expect(CleanTextHelper.cleanName(''), equals(''));
    });
  });
}
