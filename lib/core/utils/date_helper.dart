/// Helper formatting tanggal dan waktu untuk aplikasi Bayan RME
class DateHelper {
  DateHelper._();

  static const List<String> monthNames = [
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember',
  ];

  static const List<String> monthNamesShort = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'Mei',
    'Jun',
    'Jul',
    'Agu',
    'Sep',
    'Okt',
    'Nov',
    'Des',
  ];

  static DateTime? _parse(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    if (raw is String) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) return null;
      final parsed = DateTime.tryParse(trimmed);
      if (parsed != null) return parsed;
      // Handle dd/MM/yyyy or dd/MM/yyyy HH:mm
      final parts = trimmed.split(' ');
      final dateParts = parts[0].split(RegExp(r'[/.-]'));
      if (dateParts.length == 3) {
        final d = int.tryParse(dateParts[0]);
        final m = int.tryParse(dateParts[1]);
        final y = int.tryParse(dateParts[2]);
        if (d != null && m != null && y != null) {
          int h = 0, min = 0;
          if (parts.length > 1) {
            final timeParts = parts[1].split(':');
            if (timeParts.length >= 2) {
              h = int.tryParse(timeParts[0]) ?? 0;
              min = int.tryParse(timeParts[1]) ?? 0;
            }
          }
          return DateTime(y, m, d, h, min);
        }
      }
    }
    return null;
  }

  /// Format string ISO / timestamp / DateTime menjadi format tanggal: `05 Sep 2026`
  /// Menerima tipe `String?` atau `DateTime?`.
  static String formatDate(
    dynamic raw, {
    bool shortMonth = true,
    String fallback = '-',
  }) {
    if (raw == null) return fallback;
    if (raw is String && raw.trim().isEmpty) return fallback;
    final dt = _parse(raw);
    if (dt == null) return raw.toString();

    final local = dt.toLocal();
    final months = shortMonth ? monthNamesShort : monthNames;
    final day = local.day.toString().padLeft(2, '0');
    final month = months[local.month - 1];
    return '$day $month ${local.year}';
  }

  /// Format string ISO / timestamp / DateTime menjadi format tanggal & jam
  /// beserta zona waktu perangkat: `05 Sep 2026 14:30 WIB`
  static String formatDateTime(
    dynamic raw, {
    bool shortMonth = true,
    String fallback = '-',
  }) {
    if (raw == null) return fallback;
    if (raw is String && raw.trim().isEmpty) return fallback;
    final dt = _parse(raw);
    if (dt == null) return raw.toString();

    final local = dt.toLocal();
    final date = formatDate(local, shortMonth: shortMonth, fallback: fallback);
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$date $hour:$minute ${zoneOf(local)}';
  }

  /// Nama zona waktu Indonesia untuk sebuah offset UTC: WIB (+7), WITA (+8),
  /// WIT (+9). Offset lain ditulis apa adanya, mis. `UTC+5:30` atau `UTC`.
  static String zoneLabel(Duration offset) {
    switch (offset.inMinutes) {
      case 420: // +7
        return 'WIB';
      case 480: // +8
        return 'WITA';
      case 540: // +9
        return 'WIT';
      case 0:
        return 'UTC';
    }
    final sign = offset.isNegative ? '-' : '+';
    final hours = offset.inHours.abs();
    final minutes = offset.inMinutes.abs() % 60;
    return minutes == 0
        ? 'UTC$sign$hours'
        : 'UTC$sign$hours:${minutes.toString().padLeft(2, '0')}';
  }

  /// Zona waktu perangkat pada saat [dt] (ikut aturan zona perangkat).
  static String zoneOf(DateTime dt) => zoneLabel(dt.toLocal().timeZoneOffset);

  /// Offset UTC untuk label zona Indonesia (`WIB`/`WITA`/`WIT`), atau null
  /// jika labelnya tidak dikenali.
  static Duration? offsetOfZone(String zone) {
    switch (zone.trim().toUpperCase()) {
      case 'WIB':
        return const Duration(hours: 7);
      case 'WITA':
        return const Duration(hours: 8);
      case 'WIT':
        return const Duration(hours: 9);
    }
    return null;
  }

  /// Jam dinding [dt] di zona [zone] (mis. jadwal kapal yang dicatat dalam
  /// WITA), sebagai DateTime lokal biasa yang hanya dipakai untuk tampilan
  /// atau form. Zona tak dikenal: jam perangkat.
  static DateTime wallClockIn(DateTime dt, String zone) {
    final offset = offsetOfZone(zone);
    if (offset == null) return dt.toLocal();
    final z = dt.toUtc().add(offset);
    return DateTime(z.year, z.month, z.day, z.hour, z.minute, z.second);
  }
}

/// Top-level convenience wrapper: `formatDate(raw)`
String formatDate(
  dynamic raw, {
  bool shortMonth = true,
  String fallback = '-',
}) =>
    DateHelper.formatDate(raw, shortMonth: shortMonth, fallback: fallback);

/// Top-level convenience wrapper: `formatDateTime(raw)`
String formatDateTime(
  dynamic raw, {
  bool shortMonth = true,
  String fallback = '-',
}) =>
    DateHelper.formatDateTime(raw, shortMonth: shortMonth, fallback: fallback);
