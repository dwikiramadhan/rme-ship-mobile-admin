import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_badge.dart';
import '../../../patients/domain/patient.dart';
import '../../../patients/presentation/status_meta.dart';
import '../../data/icd10_api.dart';
import '../../data/icd9_api.dart';

/// Read-only summary of the doctor's examination: status, ICD-10 diagnoses,
/// ICD-9-CM procedures, prescription and lab order. Shared by the doctor's
/// patient detail and the lab order detail.
class DoctorExamSummary extends StatelessWidget {
  const DoctorExamSummary({
    super.key,
    required this.patient,
    this.headerAction,
    this.beforeDiagnosis,
    this.onViewLabDocument,
  });

  final Patient patient;

  /// Optional widget next to the status badge (e.g. the doctor's "Ubah").
  final Widget? headerAction;

  /// Optional content shown between the header and "Diagnosa Klinis"
  /// (e.g. the doctor's special note on the lab screen).
  final Widget? beforeDiagnosis;

  /// Opens the lab result document; the "Lihat Dokumen" button is hidden
  /// when null.
  final void Function(String url)? onViewLabDocument;

  @override
  Widget build(BuildContext context) {
    final p = patient;
    final meta = statusMeta(p);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.orangeLt,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    LucideIcons.stethoscope,
                    size: 15,
                    color: AppColors.orange,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Hasil Pemeriksaan Dokter',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.orange,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                AppBadge(
                  label: meta.label,
                  color: meta.color,
                  background: meta.background,
                ),
                if (headerAction != null) ...[
                  const SizedBox(width: 8),
                  headerAction!,
                ],
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (beforeDiagnosis != null) ...[
          beforeDiagnosis!,
          const SizedBox(height: 10),
        ],
        ExamDiagnosisDetail(diagnosa: p.diagnosa, tindakan: p.tindakan),
        const SizedBox(height: 14),
      ],
    );
  }
}

/// The diagnosis (ICD-10) and procedure (ICD-9-CM) blocks of an examination.
/// Part of [DoctorExamSummary]; also shown on the pharmacy prescription card.
class ExamDiagnosisDetail extends StatelessWidget {
  const ExamDiagnosisDetail({
    super.key,
    this.diagnosa,
    this.tindakan,
    this.inline = false,
    this.labelLetterSpacing = 0.4,
  });

  final String? diagnosa;
  final String? tindakan;

  /// Letter spacing of the small caps block labels.
  final double labelLetterSpacing;

  /// One sentence per block ("Name (CODE), Name (CODE)") instead of a list.
  final bool inline;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExamSection(
          label: 'Diagnosa Klinis',
          labelLetterSpacing: labelLetterSpacing,
          child: inline
              ? _InlineIcdText(text: diagnosa, procedure: false)
              : _DiagnosaDisplay(diagnosa: diagnosa),
        ),
        const SizedBox(height: 10),
        ExamSection(
          label: 'Tindakan / Prosedur (ICD-9-CM)',
          labelLetterSpacing: labelLetterSpacing,
          child: inline
              ? _InlineIcdText(text: tindakan, procedure: true)
              : _TindakanDisplay(tindakan: tindakan),
        ),
      ],
    );
  }
}

/// Splits a stored diagnosis/procedure text into entries (one per line,
/// or separated by ";" or ",").
List<String> _splitIcdItems(String text) {
  if (text.isEmpty || text == '—' || text == '-') return [];
  for (final separator in ['\n', ';', ',']) {
    if (text.contains(separator)) {
      return text
          .split(separator)
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }
  }
  return [text.trim()];
}

/// All entries in one sentence: "Name (CODE), Name (CODE)". Bare codes are
/// looked up to get their names.
class _InlineIcdText extends ConsumerWidget {
  const _InlineIcdText({required this.text, required this.procedure});

  final String? text;

  /// ICD-9-CM procedures instead of ICD-10 diagnoses.
  final bool procedure;

  String _label(WidgetRef ref, String raw) {
    if (raw.contains(' - ')) {
      final parts = raw.split(' - ');
      return '${parts.sublist(1).join(' - ').trim()} (${parts.first.trim()})';
    }
    if (_parseNameWithCode(raw) != null) return raw;
    final ({String display, String code})? item;
    if (procedure) {
      final found = ref.watch(icd9LookupProvider(raw)).valueOrNull;
      item = found == null ? null : (display: found.display, code: found.code);
    } else {
      final found = ref.watch(icd10LookupProvider(raw)).valueOrNull;
      item = found == null ? null : (display: found.display, code: found.code);
    }
    if (item == null || item.display.isEmpty) return raw;
    return item.display.contains(item.code)
        ? item.display
        : '${item.display} (${item.code})';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = _splitIcdItems(text?.trim() ?? '');
    if (items.isEmpty) return const Text('—', style: _emptyStyle);
    return Text(
      items.map((raw) => _label(ref, raw)).join(', '),
      style: const TextStyle(fontSize: 12, height: 1.4, color: AppColors.text),
    );
  }
}

/// Splits "Acute pharyngitis (J02.9)" into name and code; null if the text
/// isn't in that form (it then falls back to an ICD lookup).
final _nameWithCodePattern = RegExp(r'^(.+?)\s*\(([A-Za-z]?\d[\w.\-]*)\)$');

({String name, String code})? _parseNameWithCode(String text) {
  final match = _nameWithCodePattern.firstMatch(text.trim());
  if (match == null) return null;
  return (name: match.group(1)!.trim(), code: match.group(2)!.trim());
}

class _DiagnosaDisplay extends ConsumerWidget {
  const _DiagnosaDisplay({this.diagnosa});

  final String? diagnosa;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = diagnosa?.trim() ?? '';
    final items = _splitIcdItems(text);

    if (items.isEmpty) {
      return const Text('—', style: _emptyStyle);
    }

    if (items.length == 1) {
      return _DiagnosaSingleItem(rawText: items.first);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(height: 7),
          _DiagnosaSingleItem(
            rawText: items[i],
            tag: i == 0 ? 'Utama' : 'Sekunder',
          ),
        ],
      ],
    );
  }
}

class _DiagnosaSingleItem extends ConsumerWidget {
  const _DiagnosaSingleItem({required this.rawText, this.tag});

  final String rawText;
  final String? tag;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (rawText.contains(' - ')) {
      final parts = rawText.split(' - ');
      final code = parts.first.trim();
      final name = parts.sublist(1).join(' - ').trim();
      return _buildRow(code, name);
    }
    // "Name (CODE)" — the backend's diagnosis_detail / tindakan_detail format.
    final named = _parseNameWithCode(rawText);
    if (named != null) return _buildRow(named.code, named.name);

    final asyncLookup = ref.watch(icd10LookupProvider(rawText));

    return asyncLookup.when(
      data: (item) {
        if (item != null) {
          return _buildRow(item.code, item.display);
        }
        return _buildRow('', rawText);
      },
      loading: () => _buildRow(
        rawText.contains(' ') ? '' : rawText,
        rawText.contains(' ') ? rawText : 'Memuat diagnosa ($rawText)...',
      ),
      error: (_, _) => _buildRow(rawText.contains(' ') ? '' : rawText, rawText),
    );
  }

  Widget _buildRow(String code, String name) => _IcdRow(
    code: code,
    name: name,
    leading: tag == null
        ? null
        : Text(
            tag!,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: tag == 'Utama' ? AppColors.orange : AppColors.sub,
            ),
          ),
  );
}

class _TindakanDisplay extends ConsumerWidget {
  const _TindakanDisplay({this.tindakan});

  final String? tindakan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = tindakan?.trim() ?? '';
    final items = _splitIcdItems(text);

    if (items.isEmpty) {
      return const Text('—', style: _emptyStyle);
    }

    if (items.length == 1) {
      return _TindakanSingleItem(rawText: items.first);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(height: 7),
          _TindakanSingleItem(rawText: items[i], indexStr: '${i + 1}.'),
        ],
      ],
    );
  }
}

class _TindakanSingleItem extends ConsumerWidget {
  const _TindakanSingleItem({required this.rawText, this.indexStr});

  final String rawText;
  final String? indexStr;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (rawText.contains(' - ')) {
      final parts = rawText.split(' - ');
      final code = parts.first.trim();
      final name = parts.sublist(1).join(' - ').trim();
      return _buildRow(code, name);
    }
    // "Name (CODE)" — the backend's diagnosis_detail / tindakan_detail format.
    final named = _parseNameWithCode(rawText);
    if (named != null) return _buildRow(named.code, named.name);

    final asyncLookup = ref.watch(icd9LookupProvider(rawText));

    return asyncLookup.when(
      data: (item) {
        if (item != null) {
          return _buildRow(item.code, item.display);
        }
        return _buildRow('', rawText);
      },
      loading: () => _buildRow(
        rawText.contains(' ') ? '' : rawText,
        rawText.contains(' ') ? rawText : 'Memuat tindakan ($rawText)...',
      ),
      error: (_, _) => _buildRow(rawText.contains(' ') ? '' : rawText, rawText),
    );
  }

  Widget _buildRow(String code, String name) => _IcdRow(
    code: code,
    name: name,
    leading: indexStr == null
        ? null
        : Text(
            indexStr!,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppColors.sub,
            ),
          ),
  );
}

const _emptyStyle = TextStyle(fontSize: 12.5, color: AppColors.sub);

/// A plain bordered block with a small caps label, used for the diagnosis
/// and procedure lists (and the people on the pharmacy prescription card).
class ExamSection extends StatelessWidget {
  const ExamSection({
    super.key,
    required this.label,
    required this.child,
    this.labelLetterSpacing = 0.4,
  });

  final String label;
  final Widget child;
  final double labelLetterSpacing;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 11),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.sub,
              letterSpacing: labelLetterSpacing,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

/// One ICD entry: optional leading marker, the code in a neutral chip and
/// the name in regular weight.
class _IcdRow extends StatelessWidget {
  const _IcdRow({required this.code, required this.name, this.leading});

  final String code;
  final String name;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (leading != null) ...[
          Padding(padding: const EdgeInsets.only(top: 2), child: leading),
          const SizedBox(width: 8),
        ],
        if (code.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
            decoration: BoxDecoration(
              color: AppColors.bg,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              code,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.text,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Text(
              name,
              style: const TextStyle(
                fontSize: 12,
                height: 1,
                color: AppColors.text,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
