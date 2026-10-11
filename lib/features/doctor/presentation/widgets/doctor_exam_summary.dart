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
        _ExamSection(
          label: 'DIAGNOSA KLINIS',
          child: _DiagnosaDisplay(diagnosa: p.diagnosa),
        ),
        const SizedBox(height: 10),
        _ExamSection(
          label: 'TINDAKAN / PROSEDUR (ICD-9-CM)',
          child: _TindakanDisplay(tindakan: p.tindakan),
        ),
        const SizedBox(height: 14),
      ],
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

  List<String> _parseItems(String text) {
    if (text.isEmpty || text == '—' || text == '-') return [];
    if (text.contains('\n')) {
      return text
          .split('\n')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }
    if (text.contains(';')) {
      return text
          .split(';')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }
    if (text.contains(',')) {
      return text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }
    return [text.trim()];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = diagnosa?.trim() ?? '';
    final items = _parseItems(text);

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

  List<String> _parseItems(String text) {
    if (text.isEmpty || text == '—' || text == '-') return [];
    if (text.contains('\n')) {
      return text
          .split('\n')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }
    if (text.contains(';')) {
      return text
          .split(';')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }
    if (text.contains(',')) {
      return text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }
    return [text.trim()];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = tindakan?.trim() ?? '';
    final items = _parseItems(text);

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
/// and procedure lists.
class _ExamSection extends StatelessWidget {
  const _ExamSection({required this.label, required this.child});

  final String label;
  final Widget child;

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
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.sub,
              letterSpacing: 0.4,
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
                fontSize: 12.5,
                height: 1.3,
                color: AppColors.text,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
