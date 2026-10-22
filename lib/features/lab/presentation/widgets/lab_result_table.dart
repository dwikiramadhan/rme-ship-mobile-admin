import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../patients/domain/lab_order.dart';
import '../../../patients/presentation/widgets/prescription_pdf_dialog.dart';

/// Mark after a result outside its reference range, as on the printed form:
/// (H) above, (L) below, * otherwise abnormal.
String labFlagMark(String status) => switch (status.toLowerCase()) {
  'tinggi' || 'high' => ' (H)',
  'rendah' || 'low' => ' (L)',
  'abnormal' => ' *',
  _ => '',
};

/// [items] by their category (form part, e.g. "Hematologi", "Gula Darah"),
/// in the order they came.
List<(String, List<LabExaminationItem>)> groupLabResults(
  Iterable<LabExaminationItem> items,
) {
  final groups = <(String, List<LabExaminationItem>)>[];
  for (final it in items) {
    final i = groups.indexWhere((g) => g.$1 == it.testCategory);
    if (i < 0) {
      groups.add((it.testCategory, [it]));
    } else {
      groups[i].$2.add(it);
    }
  }
  return groups;
}

/// The lab results by form part: name, value and unit, reference range;
/// values outside the range in red with their mark.
class LabResultTable extends StatelessWidget {
  const LabResultTable({super.key, required this.items});

  final List<LabExaminationItem> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (category, rows) in groupLabResults(items)) ...[
          if (category.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 4),
              child: Text(
                category.toUpperCase(),
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.skyBlue,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          for (final it in rows) _LabResultTile(item: it),
        ],
        const SizedBox(height: 2),
        const Text(
          '(H) di atas nilai rujukan · (L) di bawah nilai rujukan · * tidak normal',
          style: TextStyle(fontSize: 9.5, color: AppColors.sub),
        ),
      ],
    );
  }
}

class _LabResultTile extends StatelessWidget {
  const _LabResultTile({required this.item});

  final LabExaminationItem item;

  @override
  Widget build(BuildContext context) {
    final result = item.resultValue.isNotEmpty ? item.resultValue : item.notes;
    final value = [
      if (result.isNotEmpty) '$result${labFlagMark(item.status)}',
      if (item.unit.isNotEmpty) item.unit,
    ].join(' ');
    return Container(
      margin: const EdgeInsets.only(bottom: 5),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: item.flagged ? AppColors.redLt : AppColors.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.testName,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text,
                  ),
                ),
                if (item.referenceRange.isNotEmpty)
                  Text(
                    'Rujukan: ${item.referenceRange}',
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: AppColors.sub,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value.isNotEmpty ? value : '—',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: item.flagged ? AppColors.red : AppColors.text,
            ),
          ),
        ],
      ),
    );
  }
}

/// "Unduh Hasil Lab (PDF)": the printable result of [labExaminationId].
class LabResultPdfButton extends StatelessWidget {
  const LabResultPdfButton({super.key, required this.labExaminationId});

  final String labExaminationId;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () =>
          showLabResultPdfDialog(context, labExaminationId: labExaminationId),
      icon: const Icon(LucideIcons.download, size: 13),
      label: const Text(
        'Unduh Hasil Lab (PDF)',
        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.skyBlue,
        side: const BorderSide(color: AppColors.border),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}
