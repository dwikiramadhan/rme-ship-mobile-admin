/// The doctor's "Hasil Pemeriksaan" (formerly "Catatan Tambahan") inside a
/// visit's notes. The backend keeps one entry per role:
/// "[Doctor - 2026-10-22 07:24]: text".
library;

// Any "[tag]" starts an entry; its role is the part before " - ".
final _roleNote = RegExp(r'^\[([^\]]*)\]:?\s?(.*)$');

bool _isDoctorRole(String role) =>
    RegExp(r'^(doctor|dokter)$', caseSensitive: false).hasMatch(role.trim());

/// The doctor's entries of [notes], one per line. Untagged text (old notes,
/// triage vitals) isn't the doctor's exam result and is left out.
String doctorExamResult(String? notes) {
  final text = notes?.trim() ?? '';
  if (text.isEmpty) return '';
  final entries = <({String role, String text})>[];
  for (final line in text.split('\n')) {
    final m = _roleNote.firstMatch(line);
    if (m != null) {
      final role = m.group(1)!.split(' - ').first;
      entries.add((role: role, text: m.group(2)!.trim()));
    } else if (entries.isNotEmpty) {
      final last = entries.removeLast();
      entries.add((role: last.role, text: '${last.text}\n$line'));
    } else {
      entries.add((role: '', text: line));
    }
  }
  return entries
      .where((e) => _isDoctorRole(e.role) && e.text.trim().isNotEmpty)
      .map((e) => e.text.trim())
      .join('\n');
}
