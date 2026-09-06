/// Helper formatting diagnosa/diagnoses untuk aplikasi Bayan RME.
/// Memanipulasi array/list `diagnoses` dari backend response menjadi satu kalimat/string yang rapi.
class DiagnosisHelper {
  DiagnosisHelper._();

  /// Format diagnoses response (array/list of object atau string) menjadi satu kalimat string terpadu.
  ///
  /// Contoh input:
  /// - `[{'code': 'A00.0', 'display': 'Cholera'}, {'code': 'A01.0', 'display': 'Typhoid fever'}]`
  ///   -> `"Cholera (A00.0), Typhoid fever (A01.0)"`
  /// - `['Demam Berdarah (A90)', 'ISPA (J06.9)']`
  ///   -> `"Demam Berdarah (A90), ISPA (J06.9)"`
  /// - `[{'name': 'Hipertensi', 'icd_code': 'I10'}]`
  ///   -> `"Hipertensi (I10)"`
  /// - Jika array kosong / null:
  ///   -> Menggunakan [fallback] (default: `'—'`)
  static String formatDiagnoses(
    dynamic rawDiagnoses, {
    dynamic fallback = '—',
  }) {
    if (rawDiagnoses is List && rawDiagnoses.isNotEmpty) {
      final parts = <String>[];
      for (final item in rawDiagnoses) {
        if (item is Map) {
          final code = (item['code'] ?? item['icd_code'] ?? item['icd10'] ?? item['kode'])
              ?.toString()
              .trim();
          final display = (item['display'] ??
                  item['name'] ??
                  item['nama'] ??
                  item['description'] ??
                  item['diagnosa'] ??
                  item['diagnosis'])
              ?.toString()
              .trim();

          if (display != null && display.isNotEmpty && code != null && code.isNotEmpty) {
            // Hindari pengulangan jika display sudah memuat code dalam kurung atau dash
            if (display.contains(code)) {
              parts.add(display);
            } else {
              parts.add('$display ($code)');
            }
          } else if (display != null && display.isNotEmpty) {
            parts.add(display);
          } else if (code != null && code.isNotEmpty) {
            parts.add(code);
          }
        } else if (item != null) {
          final str = item.toString().trim();
          if (str.isNotEmpty) {
            parts.add(str);
          }
        }
      }
      if (parts.isNotEmpty) {
        return parts.join(', ');
      }
    } else if (rawDiagnoses is String && rawDiagnoses.trim().isNotEmpty) {
      final trimmed = rawDiagnoses.trim();
      if (trimmed != '—' && trimmed != '-') {
        return trimmed;
      }
    }

    if (fallback != null) {
      final fb = fallback.toString().trim();
      if (fb.isNotEmpty && fb != '-' && fb != '—') {
        return fb;
      }
    }

    return '—';
  }
}

/// Top-level convenience wrapper: `formatDiagnoses(rawDiagnoses, fallback: ...)`
String formatDiagnoses(
  dynamic rawDiagnoses, {
  dynamic fallback = '—',
}) =>
    DiagnosisHelper.formatDiagnoses(rawDiagnoses, fallback: fallback);
