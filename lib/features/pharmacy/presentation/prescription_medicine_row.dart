import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_select.dart';
import '../../patients/domain/doctor.dart';
import '../../patients/domain/prescription_item.dart';

/// Port of the prototype's `PrescriptionMedicineRow` — one prescription line with an
/// inline "Ganti Obat" (substitute drug) action for out-of-stock cases.
class PrescriptionMedicineRow extends StatefulWidget {
  const PrescriptionMedicineRow({super.key, required this.item, required this.onGanti, required this.disabled});

  final ResepItem item;
  final void Function(String obatBaru, String alasan) onGanti;
  final bool disabled;

  @override
  State<PrescriptionMedicineRow> createState() => _PrescriptionMedicineRowState();
}

typedef ResepObatRow = PrescriptionMedicineRow;

class _PrescriptionMedicineRowState extends State<PrescriptionMedicineRow> {
  bool _editing = false;
  String? _obatBaru;
  String? _alasan;

  void _save() {
    if (_obatBaru == null || _alasan == null) return;
    widget.onGanti(_obatBaru!, _alasan!);
    setState(() {
      _editing = false;
      _obatBaru = null;
      _alasan = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.item;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: AppColors.card2, borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text.rich(
                      TextSpan(
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.text),
                        children: [TextSpan(text: r.obat), TextSpan(text: ' · ${r.dosis}', style: const TextStyle(fontWeight: FontWeight.w500, color: AppColors.sub, fontSize: 12.5))],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(r.instruksi, style: const TextStyle(fontSize: 12, color: AppColors.sub)),
                    if (r.penggantian != null) ...[
                      const SizedBox(height: 5),
                      Text(
                        '🔄 Diganti dari ${r.penggantian!.dari} · Alasan: ${r.penggantian!.alasan}',
                        style: const TextStyle(fontSize: 11.5, color: AppColors.yellow, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ],
                ),
              ),
              if (!widget.disabled && !_editing)
                OutlinedButton(
                  onPressed: () => setState(() => _editing = true),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.border, width: 1.5),
                    foregroundColor: AppColors.sub,
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Ganti Obat', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                ),
            ],
          ),
          if (_editing) ...[
            Container(
              margin: const EdgeInsets.only(top: 10),
              padding: const EdgeInsets.only(top: 10),
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppSelect<String>(
                    label: 'Obat Pengganti',
                    value: _obatBaru,
                    options: [for (final o in kObatList) if (o != r.obat) AppSelectOption(value: o, label: o)],
                    onChanged: (v) => setState(() => _obatBaru = v),
                  ),
                  const SizedBox(height: 8),
                  AppSelect<String>(
                    label: 'Alasan Penggantian',
                    value: _alasan,
                    options: [for (final a in kAlasanGantiObat) AppSelectOption(value: a, label: a)],
                    onChanged: (v) => setState(() => _alasan = v),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: AppButton(label: 'Simpan', small: true, full: true, onPressed: (_obatBaru != null && _alasan != null) ? _save : null)),
                      const SizedBox(width: 7),
                      Expanded(child: AppButton(label: 'Batal', small: true, full: true, variant: AppButtonVariant.ghost, onPressed: () => setState(() => _editing = false))),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
