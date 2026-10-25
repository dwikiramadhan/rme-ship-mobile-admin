import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_badge.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/screen_header.dart';
import '../../doctor/domain/medicine_item.dart';
import '../../doctor/presentation/widgets/medicine_search_modal.dart';
import '../../schedule/domain/trip_schedule.dart';
import '../data/stock_adjustment_api.dart';
import '../domain/stock_adjustment.dart';

/// Picks a medicine from the ship's stock; null when cancelled.
typedef MedicinePicker =
    Future<MedicineItem?> Function(BuildContext context, String shipCode);

Future<MedicineItem?> _pickFromShipStock(
  BuildContext context,
  String shipCode,
) {
  return showModalBottomSheet<MedicineItem>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => MedicineSearchModal(
      shipCode: shipCode,
      selectedName: null,
      onSelect: (_) {},
      onSelectMedicine: (med) => Navigator.of(ctx).pop(med),
    ),
  );
}

/// A medicine on the form with its inputs.
class _LineForm {
  _LineForm(this.medicine);

  final MedicineItem medicine;
  final stockAfter = TextEditingController();
  final reason = TextEditingController();

  AdjustmentLine get line => AdjustmentLine(
    sku: medicine.sku,
    name: medicine.name,
    unit: medicine.unitOfMeasurement,
    currentStock: medicine.stock,
    stockAfter: int.tryParse(stockAfter.text.trim()),
    reason: reason.text,
  );

  void dispose() {
    stockAfter.dispose();
    reason.dispose();
  }
}

/// "Adjustment Stok": the Koordinator picks medicines, sees their stock,
/// enters the counted stock and a reason each, and saves them as one
/// adjustment at the harbor the ship is at. Only on the ongoing trip they're
/// assigned to: its ship is the one adjusted.
class StockAdjustmentForm extends ConsumerStatefulWidget {
  const StockAdjustmentForm({super.key, this.pickMedicine});

  final MedicinePicker? pickMedicine;

  @override
  ConsumerState<StockAdjustmentForm> createState() =>
      _StockAdjustmentFormState();
}

class _StockAdjustmentFormState extends ConsumerState<StockAdjustmentForm> {
  final List<_LineForm> _lines = [];
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  Future<void> _addMedicine(String shipCode) async {
    final med = await (widget.pickMedicine ?? _pickFromShipStock)(
      context,
      shipCode,
    );
    if (med == null || !mounted) return;
    if (_lines.any((l) => l.medicine.sku == med.sku)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${med.name} sudah ada di daftar.')),
      );
      return;
    }
    setState(() {
      _lines.add(_LineForm(med));
      _error = null;
    });
  }

  void _remove(_LineForm line) {
    setState(() => _lines.remove(line));
    line.dispose();
  }

  Future<void> _save(String shipCode, ScheduleStop? port) async {
    final lines = [for (final l in _lines) l.line];
    final error = adjustmentError(lines);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    setState(() {
      _error = null;
      _saving = true;
    });
    final messenger = ScaffoldMessenger.of(context);
    try {
      final body = adjustmentRequestJson(
        shipCode: shipCode,
        portId: port?.portId,
        lines: lines,
        createdAt: DateTime.now(),
      );
      final queued = await ref
          .read(stockAdjustmentApiProvider)
          .create(body, label: 'Adjustment stok: ${lines.length} obat');
      if (!mounted) return;
      for (final l in _lines) {
        l.dispose();
      }
      setState(() => _lines.clear());
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            queued
                ? 'Adjustment stok tersimpan di perangkat dan akan dikirim '
                      'otomatis saat koneksi kembali.'
                : 'Adjustment stok berhasil disimpan.',
          ),
          backgroundColor: queued ? AppColors.orange : AppColors.green,
        ),
      );
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = 'Gagal menyimpan adjustment: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final trip = ref.watch(ongoingTripProvider);
    final port = ref.watch(currentPortProvider);
    final stop = port.valueOrNull;
    final shipCode = trip.valueOrNull?.shipCode ?? '';
    // Not on an ongoing trip: nothing to adjust.
    final blocked = trip.isLoading || port.isLoading || shipCode.isEmpty;
    final lines = [for (final l in _lines) l.line];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ScreenHeader(
          title: 'Adjustment Stok',
          subtitle: 'Sesuaikan stok obat dengan hitungan fisik',
          trailing: _PortChip(
            text: port.isLoading
                ? 'Memuat pelabuhan...'
                : stop?.portName ?? '-',
          ),
        ),
        Expanded(
          child: DefaultTextStyle.merge(
            style: const TextStyle(letterSpacing: 0),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (!trip.isLoading && shipCode.isEmpty) ...[
                  const _Notice(
                    text: notOnOngoingTripMessage,
                    icon: LucideIcons.alertCircle,
                  ),
                  const SizedBox(height: 12),
                ],
                AppCard(
                  padding: EdgeInsets.zero,
                  child: _LinesTable(
                    lines: _lines,
                    onChanged: () => setState(() {}),
                    onRemove: _remove,
                    onAdd: _saving || blocked
                        ? null
                        : () => _addMedicine(shipCode),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  _Notice(text: _error!, icon: LucideIcons.alertCircle),
                ],
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: _SummaryBar(
            lines: lines,
            saving: _saving,
            onSave: blocked ? null : () => _save(shipCode, stop),
          ),
        ),
      ],
    );
  }
}

/// Shown when the Koordinator isn't on an ongoing trip.
const notOnOngoingTripMessage =
    'Anda belum ditugaskan di jadwal perjalanan Ongoing, sehingga stok obat '
    'belum dapat disesuaikan.';

// One type scale for the whole form: 13 card title, 12.5 body, 11 meta,
// 10.5 column labels (all before the tablet text scale).
const _kBody = TextStyle(
  fontSize: 12.5,
  color: AppColors.text,
  letterSpacing: 0,
);
const _kMeta = TextStyle(fontSize: 11, color: AppColors.sub, letterSpacing: 0);
const _kColumnLabel = TextStyle(
  fontSize: 10.5,
  fontWeight: FontWeight.w600,
  letterSpacing: 0.3,
  color: AppColors.sub,
);

// Fixed column widths of the wide (tablet) table; the medicine name takes
// the rest.
const double _kSystemCol = 92;
const double _kCountCol = 112;
const double _kDiffCol = 84;
const double _kReasonCol = 220;
const double _kRemoveCol = 32;
const double _kColGap = 12;

/// Below this width the rows stack instead of forming a table.
const double _kTableMinWidth = 640;

/// The harbor the ship is at, shown in the header.
class _PortChip extends StatelessWidget {
  const _PortChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.card2,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(LucideIcons.anchor, size: 13, color: AppColors.sub),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.text,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

/// A red notice: not on an ongoing trip, or what is missing before saving.
class _Notice extends StatelessWidget {
  const _Notice({required this.text, required this.icon});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.redLt,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.red.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 15, color: AppColors.red),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.red,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Daftar Obat": a table on tablet (one row per medicine), stacked rows on
/// narrow screens.
class _LinesTable extends StatelessWidget {
  const _LinesTable({
    required this.lines,
    required this.onChanged,
    required this.onRemove,
    required this.onAdd,
  });

  final List<_LineForm> lines;
  final VoidCallback onChanged;
  final ValueChanged<_LineForm> onRemove;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= _kTableMinWidth;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Row(
                children: [
                  const Text(
                    'Daftar Obat',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.card2,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(
                      '${lines.length} obat',
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.sub,
                      ),
                    ),
                  ),
                  if (wide) ...[
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Text(
                        'Isi stok fisik hasil hitung, selisih dihitung '
                        'otomatis',
                        textAlign: TextAlign.right,
                        overflow: TextOverflow.ellipsis,
                        style: _kMeta,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (lines.isEmpty)
              Container(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: const Text(
                  'Belum ada obat. Tambahkan obat yang stoknya akan '
                  'disesuaikan.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: AppColors.sub),
                ),
              )
            else ...[
              if (wide) const _TableHeader(),
              for (final line in lines)
                wide
                    ? _WideRow(
                        form: line,
                        onChanged: onChanged,
                        onRemove: () => onRemove(line),
                      )
                    : _NarrowRow(
                        form: line,
                        onChanged: onChanged,
                        onRemove: () => onRemove(line),
                      ),
            ],
            Align(
              alignment: lines.isEmpty
                  ? Alignment.center
                  : Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 2, 4, 4),
                child: TextButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(LucideIcons.plus, size: 15),
                  label: const Text(
                    'Tambah Obat',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.orange,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader();

  @override
  Widget build(BuildContext context) {
    Widget label(String text, {double? width}) => width == null
        ? Expanded(child: Text(text, style: _kColumnLabel))
        : SizedBox(
            width: width,
            child: Text(text, style: _kColumnLabel),
          );
    const gap = SizedBox(width: _kColGap);

    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: AppColors.card2,
        border: Border.symmetric(
          horizontal: BorderSide(color: AppColors.border),
        ),
      ),
      child: Row(
        children: [
          label('OBAT'),
          gap,
          label('STOK SISTEM', width: _kSystemCol),
          gap,
          label('STOK FISIK', width: _kCountCol),
          gap,
          label('SELISIH', width: _kDiffCol),
          gap,
          label('ALASAN', width: _kReasonCol),
          gap,
          const SizedBox(width: _kRemoveCol),
        ],
      ),
    );
  }
}

/// Name and "SKU · unit" of a medicine.
class _MedicineName extends StatelessWidget {
  const _MedicineName({required this.form});

  final _LineForm form;

  @override
  Widget build(BuildContext context) {
    final med = form.medicine;
    final meta = [
      med.sku,
      med.unitOfMeasurement,
    ].where((s) => s.isNotEmpty).join(' · ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          med.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: AppColors.text,
          ),
        ),
        if (meta.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(meta, style: _kMeta),
        ],
      ],
    );
  }
}

/// "124 strip": the ship's stock when the medicine was picked.
class _SystemStock extends StatelessWidget {
  const _SystemStock({required this.form});

  final _LineForm form;

  @override
  Widget build(BuildContext context) {
    final med = form.medicine;
    return Text.rich(
      TextSpan(
        style: _kBody,
        children: [
          TextSpan(text: '${med.stock}'),
          if (med.unitOfMeasurement.isNotEmpty)
            TextSpan(text: ' ${med.unitOfMeasurement}', style: _kMeta),
        ],
      ),
    );
  }
}

/// Stok akhir − sisa stok as a coloured badge; "—" until counted.
class _DiffBadge extends StatelessWidget {
  const _DiffBadge({required this.diff});

  final int? diff;

  @override
  Widget build(BuildContext context) {
    final d = diff;
    final (color, background) = d == null || d == 0
        ? (AppColors.sub, AppColors.card2)
        : d < 0
        ? (AppColors.red, AppColors.redLt)
        : (AppColors.green, AppColors.greenLt);
    return AppBadge(
      label: d == null ? '—' : signedDifference(d),
      color: color,
      background: background,
      fontSize: 10.5,
      fontWeight: FontWeight.w600,
    );
  }
}

/// Compact filled input used for the counted stock and the reason.
class _CompactField extends StatelessWidget {
  const _CompactField({
    required this.controller,
    required this.hint,
    required this.onChanged,
    this.numbersOnly = false,
  });

  final TextEditingController controller;
  final String hint;
  final VoidCallback onChanged;
  final bool numbersOnly;

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: color, width: width),
        );
    return TextField(
      controller: controller,
      keyboardType: numbersOnly ? TextInputType.number : null,
      inputFormatters: numbersOnly
          ? [FilteringTextInputFormatter.digitsOnly]
          : [LengthLimitingTextInputFormatter(500)],
      style: _kBody,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
          fontSize: 12.5,
          color: Color(0xFF94A3B8),
          letterSpacing: 0,
        ),
        isDense: true,
        filled: true,
        fillColor: AppColors.inputBg,
        // The padding gives the box its height (it grows with the tablet
        // text scale): a fixed height leaves the drawn box short.
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 9,
        ),
        border: border(AppColors.border),
        enabledBorder: border(AppColors.border),
        focusedBorder: border(AppColors.orange, 1.5),
      ),
      onChanged: (_) => onChanged(),
    );
  }
}

class _RemoveButton extends StatelessWidget {
  const _RemoveButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _kRemoveCol,
      height: _kRemoveCol,
      child: IconButton(
        tooltip: 'Hapus',
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        style: IconButton.styleFrom(
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        iconSize: 15,
        icon: const Icon(LucideIcons.trash2, color: Color(0xFF94A3B8)),
        onPressed: onPressed,
      ),
    );
  }
}

/// One medicine as a table row (tablet).
class _WideRow extends StatelessWidget {
  const _WideRow({
    required this.form,
    required this.onChanged,
    required this.onRemove,
  });

  final _LineForm form;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(width: _kColGap);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(child: _MedicineName(form: form)),
          gap,
          SizedBox(
            width: _kSystemCol,
            child: _SystemStock(form: form),
          ),
          gap,
          SizedBox(
            width: _kCountCol,
            child: _CompactField(
              controller: form.stockAfter,
              hint: 'Jumlah',
              numbersOnly: true,
              onChanged: onChanged,
            ),
          ),
          gap,
          SizedBox(
            width: _kDiffCol,
            child: Align(
              alignment: Alignment.centerLeft,
              child: _DiffBadge(diff: form.line.difference),
            ),
          ),
          gap,
          SizedBox(
            width: _kReasonCol,
            child: _CompactField(
              controller: form.reason,
              hint: 'Tulis alasan',
              onChanged: onChanged,
            ),
          ),
          gap,
          _RemoveButton(onPressed: onRemove),
        ],
      ),
    );
  }
}

/// One medicine as stacked rows (phone).
class _NarrowRow extends StatelessWidget {
  const _NarrowRow({
    required this.form,
    required this.onChanged,
    required this.onRemove,
  });

  final _LineForm form;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _MedicineName(form: form)),
              _RemoveButton(onPressed: onRemove),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(
              children: [
                Expanded(child: _SystemStock(form: form)),
                const SizedBox(width: _kColGap),
                SizedBox(
                  width: _kCountCol,
                  child: _CompactField(
                    controller: form.stockAfter,
                    hint: 'Jumlah',
                    numbersOnly: true,
                    onChanged: onChanged,
                  ),
                ),
                const SizedBox(width: _kColGap),
                _DiffBadge(diff: form.line.difference),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _CompactField(
              controller: form.reason,
              hint: 'Tulis alasan',
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom bar: how many medicines are counted, how many go down / up, and
/// the save button.
class _SummaryBar extends StatelessWidget {
  const _SummaryBar({
    required this.lines,
    required this.saving,
    required this.onSave,
  });

  final List<AdjustmentLine> lines;
  final bool saving;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    final counted = lines.where((l) => l.difference != null).length;
    final down = lines.where((l) => (l.difference ?? 0) < 0).length;
    final up = lines.where((l) => (l.difference ?? 0) > 0).length;

    Widget stat(String label, String value, Color color) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: _kMeta),
        const SizedBox(height: 1),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
    Widget divider() => Container(
      width: 1,
      height: 28,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      color: AppColors.border,
    );

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  stat(
                    'Obat disesuaikan',
                    '$counted dari ${lines.length}',
                    AppColors.text,
                  ),
                  divider(),
                  stat('Stok berkurang', '$down obat', AppColors.red),
                  divider(),
                  stat('Stok bertambah', '$up obat', AppColors.green),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          AppButton(
            label: 'Simpan Adjustment',
            icon: LucideIcons.check,
            loading: saving,
            onPressed: onSave,
          ),
        ],
      ),
    );
  }
}
