import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ScreenHeader(
          title: 'Adjustment Stok',
          subtitle: 'Sesuaikan stok obat dengan hitungan fisik',
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              _PortCard(
                text: port.isLoading
                    ? 'Memuat pelabuhan...'
                    : stop?.portName ?? '-',
              ),
              if (!trip.isLoading && shipCode.isEmpty) ...[
                const SizedBox(height: 10),
                const Text(
                  notOnOngoingTripMessage,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.red,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              for (final line in _lines) ...[
                _LineCard(
                  form: line,
                  onChanged: () => setState(() {}),
                  onRemove: () => _remove(line),
                ),
                const SizedBox(height: 10),
              ],
              if (_lines.isEmpty)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Text(
                    'Belum ada obat. Tambahkan obat yang stoknya akan '
                    'disesuaikan.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12.5, color: AppColors.sub),
                  ),
                ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _saving || blocked
                    ? null
                    : () => _addMedicine(shipCode),
                icon: const Icon(LucideIcons.plus, size: 16),
                label: const Text('Tambah Obat'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.orange,
                  side: const BorderSide(color: AppColors.orange),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.red,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              FilledButton(
                onPressed: _saving || blocked
                    ? null
                    : () => _save(shipCode, stop),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.orange,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Simpan Adjustment'),
              ),
            ],
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

class _PortCard extends StatelessWidget {
  const _PortCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.card2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.anchor, size: 16, color: AppColors.sub),
          const SizedBox(width: 8),
          const Text(
            'Lokasi Pelabuhan: ',
            style: TextStyle(fontSize: 12.5, color: AppColors.sub),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LineCard extends StatelessWidget {
  const _LineCard({
    required this.form,
    required this.onChanged,
    required this.onRemove,
  });

  final _LineForm form;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final med = form.medicine;
    final diff = form.line.difference;
    final unit = med.unitOfMeasurement.isEmpty
        ? ''
        : ' ${med.unitOfMeasurement}';
    InputDecoration decoration(String label, String hint) => InputDecoration(
      labelText: label,
      hintText: hint,
      isDense: true,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    );

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '[${med.sku}] ${med.name}',
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Hapus',
                icon: const Icon(
                  LucideIcons.trash2,
                  size: 16,
                  color: AppColors.red,
                ),
                onPressed: onRemove,
              ),
            ],
          ),
          Text(
            'Sisa stok: ${med.stock}$unit',
            style: const TextStyle(fontSize: 12, color: AppColors.sub),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: form.stockAfter,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: decoration('Stok Akhir', 'Hasil hitung fisik'),
                  onChanged: (_) => onChanged(),
                ),
              ),
              const SizedBox(width: 10),
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  diff == null
                      ? 'Selisih: -'
                      : 'Selisih: ${signedDifference(diff)}',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: diff == null || diff == 0
                        ? AppColors.sub
                        : diff < 0
                        ? AppColors.red
                        : AppColors.green,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: form.reason,
            maxLength: 500,
            decoration: decoration(
              'Alasan',
              'cth: Kedaluwarsa, rusak, selisih hitung',
            ).copyWith(counterText: ''),
            onChanged: (_) => onChanged(),
          ),
        ],
      ),
    );
  }
}
