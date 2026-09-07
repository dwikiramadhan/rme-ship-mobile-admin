import 'dart:convert';

/// Helper utility to clean and extract human-readable text from dynamic values,
/// maps, or stringified objects (e.g. `"{name: ..., code: ...}"`).
class CleanTextHelper {
  CleanTextHelper._();

  /// Extracts clean name or title from a string, Map, or stringified Map.
  static String cleanName(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;

    if (value is Map) {
      final name = value['name'] ??
          value['nama'] ??
          value['patient_name'] ??
          value['medicine_name'] ??
          value['nama_pasien'] ??
          value['nama_obat'] ??
          value['full_name'] ??
          value['nama_lengkap'] ??
          value['title'] ??
          value['display'] ??
          value['label'];
      if (name != null) {
        final str = cleanName(name);
        if (str.isNotEmpty && str != fallback) return str;
      }

      // Check nested objects
      for (final subKey in ['patient', 'medicine', 'obat', 'drug', 'doctor']) {
        if (value[subKey] is Map || (value[subKey] is String && (value[subKey] as String).startsWith('{'))) {
          final str = cleanName(value[subKey]);
          if (str.isNotEmpty && str != fallback) return str;
        }
      }
      return fallback;
    }

    final str = value.toString().trim();
    if (str.isEmpty || str == '—' || str == '-') return fallback;
    if (str.startsWith('Instance of ')) return fallback;

    // Check if string is a JSON or stringified Map, e.g. "{id: ..., name: Foo Bar, code: 123}"
    if (str.startsWith('{') && str.endsWith('}')) {
      // 1. Try standard JSON decode
      try {
        final decoded = jsonDecode(str);
        if (decoded is Map) {
          final res = cleanName(decoded, fallback: fallback);
          if (res.isNotEmpty && res != fallback) return res;
        }
      } catch (_) {}

      // 2. Regex match for name keys (supporting quoted or unquoted values)
      final match = RegExp(
        r'''(?:^|[{,\s])["']?(?:name|nama|patient_name|nama_pasien|medicine_name|nama_obat|full_name|nama_lengkap|title|display|label)["']?\s*[:=]\s*(?:"([^"]*)"|'([^']*)'|([^,}]+))''',
        caseSensitive: false,
      ).firstMatch(str);
      if (match != null) {
        final extracted = (match.group(1) ?? match.group(2) ?? match.group(3))?.trim() ?? '';
        if (extracted.isNotEmpty && !extracted.startsWith('{')) {
          return extracted;
        }
      }

      // 3. Regex match for nested sub-objects
      final subMatch = RegExp(
        r'''(?:^|[{,\s])["']?(?:patient|medicine|obat|drug|doctor)["']?\s*[:=]\s*(\{.*?\})''',
        caseSensitive: false,
      ).firstMatch(str);
      if (subMatch != null) {
        final subStr = subMatch.group(1);
        if (subStr != null && subStr != str) {
          final res = cleanName(subStr, fallback: fallback);
          if (res.isNotEmpty && res != fallback) return res;
        }
      }

      // Never leak raw object string "{...}" as a name!
      return fallback;
    }

    return str;
  }

  /// Extracts clean code or SKU from a string, Map, or stringified Map.
  static String cleanCode(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;

    if (value is Map) {
      final code = value['code'] ??
          value['kode'] ??
          value['sku'] ??
          value['medicine_sku'] ??
          value['register_no'] ??
          value['patient_code'] ??
          value['registration_code'] ??
          value['no_registrasi'] ??
          value['reg_no'] ??
          value['norm'] ??
          value['no_rm'] ??
          value['nik'] ??
          value['icd10'];
      if (code != null) {
        final str = cleanCode(code);
        if (str.isNotEmpty && str != fallback) return str;
      }

      // Check nested objects
      for (final subKey in ['patient', 'medicine', 'obat', 'drug', 'doctor']) {
        if (value[subKey] is Map || (value[subKey] is String && (value[subKey] as String).startsWith('{'))) {
          final str = cleanCode(value[subKey]);
          if (str.isNotEmpty && str != fallback) return str;
        }
      }
      return fallback;
    }

    final str = value.toString().trim();
    if (str.isEmpty || str == '—' || str == '-') return fallback;
    if (str.startsWith('Instance of ')) return fallback;

    // Check if string is a JSON or stringified Map, e.g. "{id: ..., code: GT-C009}"
    if (str.startsWith('{') && str.endsWith('}')) {
      // 1. Try standard JSON decode
      try {
        final decoded = jsonDecode(str);
        if (decoded is Map) {
          final res = cleanCode(decoded, fallback: fallback);
          if (res.isNotEmpty && res != fallback) return res;
        }
      } catch (_) {}

      // 2. Regex match for code keys (supporting quoted or unquoted values)
      final match = RegExp(
        r'''(?:^|[{,\s])["']?(?:code|kode|sku|medicine_sku|register_no|patient_code|registration_code|no_registrasi|reg_no|norm|no_rm|nik|icd10)["']?\s*[:=]\s*(?:"([^"]*)"|'([^']*)'|([^,}]+))''',
        caseSensitive: false,
      ).firstMatch(str);
      if (match != null) {
        final extracted = (match.group(1) ?? match.group(2) ?? match.group(3))?.trim() ?? '';
        if (extracted.isNotEmpty && !extracted.startsWith('{')) {
          return extracted;
        }
      }

      // 3. Regex match for nested sub-objects
      final subMatch = RegExp(
        r'''(?:^|[{,\s])["']?(?:patient|medicine|obat|drug|doctor)["']?\s*[:=]\s*(\{.*?\})''',
        caseSensitive: false,
      ).firstMatch(str);
      if (subMatch != null) {
        final subStr = subMatch.group(1);
        if (subStr != null && subStr != str) {
          final res = cleanCode(subStr, fallback: fallback);
          if (res.isNotEmpty && res != fallback) return res;
        }
      }

      // Never leak raw object string "{...}" as a code!
      return fallback;
    }

    return str;
  }
}
