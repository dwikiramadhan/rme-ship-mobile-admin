import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/clean_text_helper.dart';
import '../../../core/widgets/app_button.dart';
import '../../doctor/domain/medicine_item.dart';
import '../../doctor/presentation/widgets/medicine_search_modal.dart';
import '../../patients/domain/prescription_item.dart';

/// Port of the prototype's `PrescriptionMedicineRow` — one prescription line with an
/// inline "Ganti Obat" (substitute drug) action for out-of-stock cases.
typedef OnGantiObatCallback = void Function(
  String obatBaru,
  String alasan, {
  String? newSku,
  dynamic newJumlah,
  String? notes,
});

class PrescriptionMedicineRow extends StatefulWidget {
  const PrescriptionMedicineRow({
    super.key,
    required this.item,
    required this.onGanti,
    required this.disabled,
    this.index = 0,
    this.shipCode,
  });

  final ResepItem item;
  final Function onGanti;
  final bool disabled;
  final int index;
  final String? shipCode;

  @override
  State<PrescriptionMedicineRow> createState() =>
      _PrescriptionMedicineRowState();
}

typedef ResepObatRow = PrescriptionMedicineRow;

const List<String> _kDosisList = [
  '1x1',
  '2x1',
  '3x1',
  '4x1',
  '1x2',
  '2x2',
  '1x0.5',
  'Sesuai kebutuhan (PRN)',
];

const List<String> _kAturanPakaiList = [
  'Sesudah makan',
  'Sebelum makan',
  'Bersama makan',
  'Sebelum tidur',
  'Input manual',
];

// ignore: constant_identifier_names
const SUBSTITUTION_REASONS = [
  {'value': 'OUT_OF_STOCK', 'label': 'Stok Habis / Kosong (OUT_OF_STOCK)'},
  {
    'value': 'CLINICAL_ADJUSTMENT',
    'label': 'Penyesuaian Klinis / Medis (CLINICAL_ADJUSTMENT)',
  },
  {
    'value': 'PATIENT_PREFERENCE',
    'label': 'Permintaan Pasien (PATIENT_PREFERENCE)',
  },
  {'value': 'OTHER', 'label': 'Alasan Lainnya (OTHER)'},
];

String formatSubstitutionReason(String? reason) {
  if (reason == null || reason.trim().isEmpty) return '-';
  final found = SUBSTITUTION_REASONS.firstWhere(
    (e) => e['value'] == reason,
    orElse: () => {'label': reason},
  );
  return found['label'] ?? reason;
}

class _PrescriptionMedicineRowState extends State<PrescriptionMedicineRow> {
  bool _editing = false;
  String? _obatBaru;
  String? _alasan;
  MedicineItem? _selectedMedicine;
  late TextEditingController _jumlahCtrl;
  late TextEditingController _customInstruksiCtrl;
  final TextEditingController _notesCtrl = TextEditingController();
  late String _dosis;
  late String _aturanPakai;
  late String _satuan;

  @override
  void initState() {
    super.initState();
    _initFields();
  }

  void _initFields() {
    final j = widget.item.jumlah?.toString().trim() ?? '';
    _jumlahCtrl = TextEditingController(text: j.isNotEmpty ? j : '1');
    _customInstruksiCtrl = TextEditingController();
    _dosis = _kDosisList.contains(widget.item.dosis)
        ? widget.item.dosis
        : '1x1';
    _aturanPakai = _kAturanPakaiList.contains(widget.item.instruksi)
        ? widget.item.instruksi
        : (_kAturanPakaiList.contains(widget.item.instruksi.trim())
              ? widget.item.instruksi.trim()
              : 'Sesudah makan');
    _satuan = (widget.item.unitOfMeasurement?.trim().isNotEmpty == true)
        ? widget.item.unitOfMeasurement!.trim()
        : (widget.item.satuan?.trim().isNotEmpty == true
              ? widget.item.satuan!.trim()
              : 'Pcs');
  }

  @override
  void didUpdateWidget(PrescriptionMedicineRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item != widget.item && !_editing) {
      final j = widget.item.jumlah?.toString().trim() ?? '';
      _jumlahCtrl.text = j.isNotEmpty ? j : '1';
      _dosis = _kDosisList.contains(widget.item.dosis)
          ? widget.item.dosis
          : '1x1';
      _aturanPakai = _kAturanPakaiList.contains(widget.item.instruksi)
          ? widget.item.instruksi
          : 'Sesudah makan';
      _satuan = (widget.item.unitOfMeasurement?.trim().isNotEmpty == true)
          ? widget.item.unitOfMeasurement!.trim()
          : (widget.item.satuan?.trim().isNotEmpty == true
                ? widget.item.satuan!.trim()
                : 'Pcs');
    }
  }

  @override
  void dispose() {
    _jumlahCtrl.dispose();
    _customInstruksiCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _showMedicineSearch() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => MedicineSearchModal(
        shipCode: widget.shipCode,
        selectedName: _obatBaru,
        onSelect: (medName) {
          setState(() {
            _obatBaru = medName;
          });
          Navigator.of(ctx).pop();
        },
        onSelectMedicine: (med) {
          setState(() {
            _obatBaru = med.name;
            _selectedMedicine = med;
            if (med.unitOfMeasurement.isNotEmpty) {
              _satuan = med.unitOfMeasurement;
            }
          });
          Navigator.of(ctx).pop();
        },
      ),
    );
  }

  void _save() {
    if (_obatBaru == null || _alasan == null) return;
    try {
      (widget.onGanti as dynamic)(
        _obatBaru!,
        _alasan!,
        newSku: _selectedMedicine?.sku,
        newJumlah: int.tryParse(_jumlahCtrl.text.trim()) ?? widget.item.jumlah,
        notes: _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : null,
      );
    } catch (_) {
      (widget.onGanti as dynamic)(_obatBaru!, _alasan!);
    }
    setState(() {
      _editing = false;
      _obatBaru = null;
      _alasan = null;
      _selectedMedicine = null;
      _notesCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.item;

    String displayName = CleanTextHelper.cleanName(r.obat);
    String? displaySku = CleanTextHelper.cleanCode(r.sku);

    if (displaySku.isEmpty) {
      final codeFromObat = CleanTextHelper.cleanCode(r.obat);
      if (codeFromObat.isNotEmpty && codeFromObat != displayName) {
        displaySku = codeFromObat;
      }
    }

    if (displaySku.isEmpty) {
      final match = RegExp(
        r'^(.*?)\s*\(([^)]+)\)$',
      ).firstMatch(displayName.trim());
      if (match != null) {
        displayName = match.group(1)?.trim() ?? displayName;
        displaySku = match.group(2)?.trim();
      }
    }

    final formattedDosis = r.dosis.trim().isNotEmpty
        ? r.dosis.replaceAll('x', '×')
        : '-';
    final formattedAturan = r.instruksi.trim().isNotEmpty
        ? r.instruksi.trim()
        : '-';

    final String qtyText;
    final unitOfMeasurement = r.unitOfMeasurement?.trim().isNotEmpty == true
        ? r.unitOfMeasurement!.trim()
        : r.satuan?.trim();

    if (r.jumlah != null && r.jumlah.toString().trim().isNotEmpty) {
      final jStr = r.jumlah.toString().trim();
      if (jStr.contains(' ')) {
        qtyText = jStr;
      } else {
        qtyText = (unitOfMeasurement != null && unitOfMeasurement.isNotEmpty)
            ? '$jStr $unitOfMeasurement'
            : jStr;
      }
    } else if (unitOfMeasurement != null && unitOfMeasurement.isNotEmpty) {
      qtyText = unitOfMeasurement;
    } else {
      qtyText = '-';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Left Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Line 1: Badge + Name + SKU
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2.5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '#${widget.index + 1}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: displayName,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.text,
                                  ),
                                ),
                                if (displaySku != null &&
                                    displaySku.isNotEmpty) ...[
                                  const TextSpan(text: ' '),
                                  TextSpan(
                                    text: '($displaySku)',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: Color.fromARGB(255, 112, 139, 176),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Line 2: Dosis & Aturan
                    Text.rich(
                      TextSpan(
                        children: [
                          const TextSpan(
                            text: 'Dosis: ',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          TextSpan(
                            text: formattedDosis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.text,
                            ),
                          ),
                          const TextSpan(
                            text: ' • ',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                          const TextSpan(
                            text: 'Aturan: ',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          TextSpan(
                            text: formattedAturan,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.text,
                            ),
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Right Content: Qty Badge & Edit Button
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 5.5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF9C3).withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFFFDE047),
                        width: 1.2,
                      ),
                    ),
                    child: Text(
                      qtyText,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF92400E),
                      ),
                    ),
                  ),
                  if (!widget.disabled) ...[
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () => setState(() => _editing = !_editing),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 5.5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFDF5),
                          borderRadius: BorderRadius.circular(20),
                          // border: Border.all(
                          //   color: const Color(0xFFFDE047),
                          //   width: 1.2,
                          // ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(
                              LucideIcons.pencil,
                              size: 11,
                              color: Color(0xFFB45309),
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Ubah',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFB45309),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          if (r.penggantian != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                      'Diganti dari ${r.penggantian!.dari} (${formatSubstitutionReason(r.penggantian!.alasan)})',
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
          if (_editing) ...[
            Builder(
              builder: (context) {
                final hasMedicine =
                    _selectedMedicine != null ||
                    (_obatBaru != null && _obatBaru!.isNotEmpty);

                return Container(
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.card2,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: hasMedicine
                          ? AppColors.orange.withValues(alpha: 0.4)
                          : AppColors.border,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Field 1: Nama Obat
                      const Row(
                        children: [
                          Text(
                            'Nama Obat',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.text,
                            ),
                          ),
                          Text(
                            ' *',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.red,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      GestureDetector(
                        onTap: _showMedicineSearch,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: hasMedicine
                                  ? AppColors.orange.withValues(alpha: 0.5)
                                  : AppColors.border,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                LucideIcons.pill,
                                size: 13,
                                color: hasMedicine
                                    ? AppColors.orange
                                    : AppColors.sub,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _selectedMedicine?.name ??
                                      _obatBaru ??
                                      'Cari & pilih obat dari stok kapal...',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: hasMedicine
                                        ? AppColors.text
                                        : AppColors.sub,
                                    fontWeight: hasMedicine
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const Icon(
                                LucideIcons.chevronDown,
                                size: 13,
                                color: AppColors.sub,
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (hasMedicine &&
                          (_selectedMedicine?.stock != null ||
                              (_selectedMedicine?.category != null &&
                                  _selectedMedicine!.category.isNotEmpty))) ...[
                        const SizedBox(height: 5),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            if (_selectedMedicine?.stock != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: (_selectedMedicine!.stock > 0)
                                      ? const Color(0xFFECFDF5)
                                      : const Color(0xFFFEF2F2),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: (_selectedMedicine!.stock > 0)
                                        ? const Color(0xFFA7F3D0)
                                        : const Color(0xFFFECACA),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      LucideIcons.package,
                                      size: 10,
                                      color: (_selectedMedicine!.stock > 0)
                                          ? const Color(0xFF059669)
                                          : AppColors.red,
                                    ),
                                    const SizedBox(width: 3.5),
                                    Text(
                                      'Stok: ${_selectedMedicine!.stock} ${_selectedMedicine!.unitOfMeasurement}',
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w600,
                                        color: (_selectedMedicine!.stock > 0)
                                            ? const Color(0xFF059669)
                                            : AppColors.red,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (_selectedMedicine?.category != null &&
                                _selectedMedicine!.category.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF3F4F6),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: const Color(0xFFE5E7EB),
                                  ),
                                ),
                                child: Text(
                                  _selectedMedicine!.category,
                                  style: const TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.sub,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 10),

                      // Fields 2, 3, 4: Qty, Dosis, Aturan Pakai in one row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Kolom 1: Qty
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Qty (${_satuan.isNotEmpty ? _satuan : 'Pcs'})',
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.text,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 5),
                                SizedBox(
                                  height: 36,
                                  child: Row(
                                    children: [
                                      // Minus button (-)
                                      InkWell(
                                        borderRadius: BorderRadius.circular(4),
                                        onTap: () {
                                          final cur =
                                              int.tryParse(
                                                _jumlahCtrl.text.trim(),
                                              ) ??
                                              1;
                                          if (cur > 1) {
                                            _jumlahCtrl.text = (cur - 1)
                                                .toString();
                                            setState(() {});
                                          }
                                        },
                                        child: const Padding(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 3,
                                            vertical: 6,
                                          ),
                                          child: Icon(
                                            LucideIcons.minus,
                                            size: 12,
                                            color: AppColors.sub,
                                          ),
                                        ),
                                      ),
                                      // Input Angka
                                      Expanded(
                                        child: TextField(
                                          controller: _jumlahCtrl,
                                          keyboardType: TextInputType.number,
                                          inputFormatters: [
                                            FilteringTextInputFormatter
                                                .digitsOnly,
                                          ],
                                          textAlign: TextAlign.center,
                                          cursorColor: AppColors.orange,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.text,
                                          ),
                                          decoration: const InputDecoration(
                                            isDense: true,
                                            contentPadding:
                                                EdgeInsets.symmetric(
                                                  vertical: 8,
                                                ),
                                            border: InputBorder.none,
                                            enabledBorder: InputBorder.none,
                                            focusedBorder: InputBorder.none,
                                            hintText: '1',
                                            hintStyle: TextStyle(
                                              fontSize: 13,
                                              color: AppColors.sub,
                                              fontWeight: FontWeight.normal,
                                            ),
                                          ),
                                        ),
                                      ),
                                      // Plus button (+)
                                      InkWell(
                                        borderRadius: BorderRadius.circular(4),
                                        onTap: () {
                                          final cur =
                                              int.tryParse(
                                                _jumlahCtrl.text.trim(),
                                              ) ??
                                              1;
                                          _jumlahCtrl.text = (cur + 1)
                                              .toString();
                                          setState(() {});
                                        },
                                        child: const Padding(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 3,
                                            vertical: 6,
                                          ),
                                          child: Icon(
                                            LucideIcons.plus,
                                            size: 12,
                                            color: AppColors.orange,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Kolom 2: Dosis
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Dosis',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.text,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Container(
                                  height: 36,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      isExpanded: true,
                                      value: _dosis,
                                      dropdownColor: Colors.white,
                                      icon: const Icon(
                                        LucideIcons.chevronDown,
                                        size: 12,
                                        color: AppColors.sub,
                                      ),
                                      items: [
                                        for (final d in _kDosisList)
                                          DropdownMenuItem(
                                            value: d,
                                            child: Text(
                                              d,
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: AppColors.text,
                                                fontWeight: FontWeight.w600,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                      ],
                                      onChanged: (v) {
                                        if (v != null) {
                                          setState(() => _dosis = v);
                                        }
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Kolom 3: Aturan Pakai
                          Expanded(
                            flex: 4,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Aturan Pakai',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.text,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Container(
                                  height: 36,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      isExpanded: true,
                                      value: _aturanPakai,
                                      dropdownColor: Colors.white,
                                      icon: const Icon(
                                        LucideIcons.chevronDown,
                                        size: 12,
                                        color: AppColors.sub,
                                      ),
                                      items: [
                                        for (final a in _kAturanPakaiList)
                                          DropdownMenuItem(
                                            value: a,
                                            child: Text(
                                              a,
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: AppColors.text,
                                                fontWeight: FontWeight.w500,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                      ],
                                      onChanged: (v) {
                                        if (v != null) {
                                          setState(() => _aturanPakai = v);
                                        }
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (_aturanPakai == 'Input manual') ...[
                        const SizedBox(height: 8),
                        const Text(
                          'Aturan Pakai Khusus',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.text,
                          ),
                        ),
                        const SizedBox(height: 4),
                        TextField(
                          controller: _customInstruksiCtrl,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.text,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Tuliskan aturan pakai khusus obat...',
                            hintStyle: const TextStyle(
                              fontSize: 10,
                              color: AppColors.sub,
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: AppColors.border,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: AppColors.orange,
                              ),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),

                      // Alasan Penggantian
                      const Row(
                        children: [
                          Text(
                            'Alasan Penggantian',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.text,
                            ),
                          ),
                          Text(
                            ' *',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.red,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Container(
                        height: 36,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: _alasan,
                            hint: const Text(
                              'Pilih alasan penggantian...',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: AppColors.sub,
                              ),
                            ),
                            dropdownColor: Colors.white,
                            icon: const Icon(
                              LucideIcons.chevronDown,
                              size: 13,
                              color: AppColors.sub,
                            ),
                            items: [
                              for (final reason in SUBSTITUTION_REASONS)
                                DropdownMenuItem(
                                  value: reason['value'],
                                  child: Text(
                                    reason['label']!,
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      color: AppColors.text,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                            onChanged: (v) => setState(() => _alasan = v),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Catatan Substitusi (Opsional)
                      const Text(
                        'Catatan Substitusi',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.text,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: TextField(
                          controller: _notesCtrl,
                          maxLines: 2,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.text,
                          ),
                          decoration: const InputDecoration(
                            isDense: true,
                            hintText: 'Catatan tambahan substitusi (opsional)...',
                            hintStyle: TextStyle(
                              fontSize: 11.5,
                              color: AppColors.sub,
                            ),
                            contentPadding: EdgeInsets.all(8),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: AppButton(
                              label: 'Simpan',
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
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}
