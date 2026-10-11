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

    test('formats date and time with the device time zone', () {
      final dt = DateTime(2026, 9, 5, 14, 30);
      expect(
        formatDateTime(dt),
        equals('05 Sep 2026 14:30 ${DateHelper.zoneOf(dt)}'),
      );
    });

    test('names Indonesian time zones by UTC offset', () {
      expect(DateHelper.zoneLabel(const Duration(hours: 7)), 'WIB');
      expect(DateHelper.zoneLabel(const Duration(hours: 8)), 'WITA');
      expect(DateHelper.zoneLabel(const Duration(hours: 9)), 'WIT');
      expect(DateHelper.zoneLabel(Duration.zero), 'UTC');
      expect(DateHelper.zoneLabel(const Duration(hours: 5, minutes: 30)), 'UTC+5:30');
      expect(DateHelper.zoneLabel(const Duration(hours: -4)), 'UTC-4');
    });

    test('shows a moment as the clock reads in a given zone', () {
      // 02:00 UTC is 09:00 WIB, 10:00 WITA, 11:00 WIT.
      final moment = DateTime.utc(2026, 9, 5, 2);
      expect(DateHelper.wallClockIn(moment, 'WIB').hour, 9);
      expect(DateHelper.wallClockIn(moment, 'wita').hour, 10);
      expect(DateHelper.wallClockIn(moment, 'WIT').hour, 11);
      // Unknown zone label: device time.
      expect(DateHelper.wallClockIn(moment, 'XYZ'), moment.toLocal());
    });
  });
}
