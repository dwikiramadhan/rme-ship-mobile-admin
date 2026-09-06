import 'package:bayan_rme/core/utils/diagnosis_helper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DiagnosisHelper.formatDiagnoses', () {
    test('formats list of maps with code and display into a single sentence', () {
      final input = [
        {'code': 'A00.0', 'display': 'Cholera due to Vibrio cholerae 01'},
        {'code': 'A01.0', 'display': 'Typhoid fever'},
      ];
      final result = formatDiagnoses(input);
      expect(result, 'Cholera due to Vibrio cholerae 01 (A00.0), Typhoid fever (A01.0)');
    });

    test('avoids duplicating code if display already contains the code', () {
      final input = [
        {'code': 'A00.0', 'display': 'Cholera due to Vibrio cholerae 01 (A00.0)'},
        {'code': 'J06.9', 'display': 'ISPA'},
      ];
      final result = formatDiagnoses(input);
      expect(result, 'Cholera due to Vibrio cholerae 01 (A00.0), ISPA (J06.9)');
    });

    test('handles variations in key names (nama, icd_code, description, etc.)', () {
      final input = [
        {'icd_code': 'I10', 'name': 'Hipertensi Primer'},
        {'kode': 'E11', 'diagnosa': 'Diabetes Mellitus Tipe 2'},
      ];
      final result = formatDiagnoses(input);
      expect(result, 'Hipertensi Primer (I10), Diabetes Mellitus Tipe 2 (E11)');
    });

    test('formats list of plain strings into a single sentence', () {
      final input = ['Demam Berdarah (A90)', 'ISPA (J06.9)'];
      final result = formatDiagnoses(input);
      expect(result, 'Demam Berdarah (A90), ISPA (J06.9)');
    });

    test('falls back to fallbackDiagnosis when diagnoses is empty or null', () {
      expect(formatDiagnoses(null, fallback: 'Pemeriksaan Rutin'), 'Pemeriksaan Rutin');
      expect(formatDiagnoses([], fallback: 'Pemeriksaan Rutin'), 'Pemeriksaan Rutin');
      expect(formatDiagnoses(null, fallback: '—'), '—');
      expect(formatDiagnoses([], fallback: null), '—');
    });

    test('handles single string input', () {
      expect(formatDiagnoses('Hipertensi'), 'Hipertensi');
    });
  });
}
