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

  /// Format string ISO / timestamp / DateTime menjadi format tanggal: `05 Sep 2026`
  /// Menerima tipe `String?` atau `DateTime?`.
  static String formatDate(
    dynamic raw, {
    bool shortMonth = true,
    String fallback = '-',
  }) {
    if (raw == null) return fallback;
    DateTime? dt;
    if (raw is DateTime) {
      dt = raw;
    } else if (raw is String) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) return fallback;
      dt = DateTime.tryParse(trimmed);
    }
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
    DateTime? dt;
    if (raw is DateTime) {
      dt = raw;
    } else if (raw is String) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) return fallback;
      dt = DateTime.tryParse(trimmed);
    }
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
