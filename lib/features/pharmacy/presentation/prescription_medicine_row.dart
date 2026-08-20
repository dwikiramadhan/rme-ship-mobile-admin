import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_select.dart';
import '../../patients/domain/doctor.dart';
import '../../patients/domain/prescription_item.dart';

/// Port of the prototype's `PrescriptionMedicineRow` — one prescription line with an
/// inline "Ganti Obat" (substitute drug) action for out-of-stock cases.
class PrescriptionMedicineRow extends StatefulWidget {
  const PrescriptionMedicineRow({
    super.key,
    required this.item,
    required this.onGanti,
    required this.disabled,
    this.index = 0,
  });

  final ResepItem item;
  final void Function(String obatBaru, String alasan) onGanti;
  final bool disabled;
  final int index;

  @override
  State<PrescriptionMedicineRow> createState() =>
      _PrescriptionMedicineRowState();
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.card2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            r.obat,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                              color: AppColors.text,
                            ),
                          ),
                        ),
                        if (r.dosis.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.card,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Text(
                              r.dosis,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.orange,
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (r.instruksi.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(
                            LucideIcons.clock,
                            size: 12,
                            color: AppColors.sub,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              r.instruksi,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.sub,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (r.penggantian != null) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.yellowLt,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              LucideIcons.arrowLeftRight,
                              size: 11,
                              color: AppColors.yellow,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                'Diganti dari ${r.penggantian!.dari} (${r.penggantian!.alasan})',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.yellow,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (!widget.disabled && !_editing) ...[
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: () => setState(() => _editing = true),
                  icon: const Icon(LucideIcons.arrowLeftRight, size: 11),
                  label: const Text(
                    'Ganti',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.border, width: 1.2),
                    foregroundColor: AppColors.sub,
                    backgroundColor: AppColors.card,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (_editing) ...[
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Form Penggantian / Substitusi Obat',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 8),
                  AppSelect<String>(
                    label: 'Obat Pengganti',
                    value: _obatBaru,
                    options: [
                      for (final o in kObatList)
                        if (o != r.obat) AppSelectOption(value: o, label: o),
                    ],
                    onChanged: (v) => setState(() => _obatBaru = v),
                  ),
                  const SizedBox(height: 8),
                  AppSelect<String>(
                    label: 'Alasan Penggantian',
                    value: _alasan,
                    options: [
                      for (final a in kAlasanGantiObat)
                        AppSelectOption(value: a, label: a),
                    ],
                    onChanged: (v) => setState(() => _alasan = v),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: AppButton(
                          label: 'Simpan Penggantian',
                          small: true,
                          full: true,
                          onPressed: (_obatBaru != null && _alasan != null)
                              ? _save
                              : null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: AppButton(
                          label: 'Batal',
                          small: true,
                          full: true,
                          variant: AppButtonVariant.ghost,
                          onPressed: () => setState(() => _editing = false),
                        ),
                      ),
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
