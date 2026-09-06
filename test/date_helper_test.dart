import 'package:bayan_rme/core/utils/date_helper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DateHelper', () {
    test('formats ISO string correctly with short month', () {
      expect(formatDate('2026-09-05T00:00:00Z'), equals('05 Sep 2026'));
      expect(formatDate('1995-08-17T00:00:00Z'), equals('17 Agu 1995'));
      expect(formatDate('2026-01-01T10:30:00Z'), equals('01 Jan 2026'));
    });

    test('formats ISO string correctly with full month name', () {
      expect(formatDate('2026-09-05T00:00:00Z', shortMonth: false), equals('05 September 2026'));
    });

    test('formats DateTime object directly', () {
      final dt = DateTime(2026, 12, 25);
      expect(formatDate(dt), equals('25 Des 2026'));
    });

    test('handles null and empty values gracefully', () {
      expect(formatDate(null), equals('-'));
      expect(formatDate(''), equals('-'));
      expect(formatDate('   '), equals('-'));
      expect(formatDate(null, fallback: 'N/A'), equals('N/A'));
    });

    test('formats date and time', () {
      final dt = DateTime(2026, 9, 5, 14, 30);
      expect(formatDateTime(dt), equals('05 Sep 2026 14:30'));
    });
  });
}
