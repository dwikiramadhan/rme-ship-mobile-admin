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

  /// Format string ISO / timestamp / DateTime menjadi format tanggal & jam: `05 Sep 2026 14:30`
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
    return '$date $hour:$minute';
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
