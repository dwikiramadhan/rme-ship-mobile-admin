import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_helper.dart';
import '../../../core/widgets/screen_header.dart';
import '../../patients/presentation/widgets/prescription_pdf_dialog.dart';
import '../../schedule/domain/trip_schedule.dart';
import '../data/stock_adjustment_api.dart';
import '../domain/stock_adjustment.dart';

/// Saves an Excel file; returns false when the user cancels.
typedef ExcelSaver = Future<bool> Function(String fileName, Uint8List bytes);

Future<bool> _saveExcel(String fileName, Uint8List bytes) async {
  final uri = await FilePicker.saveFile(
    dialogTitle: 'Simpan Excel',
    fileName: fileName,
    bytes: bytes,
    mimeType:
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    type: FileType.custom,
    allowedExtensions: const ['xlsx'],
  );
  return uri != null;
}

/// "Laporan Adjustment": the adjustments of the ship of the Koordinator's
/// trip in a date range, one row per medicine, downloadable as PDF or Excel.
class StockAdjustmentReportView extends ConsumerStatefulWidget {
  const StockAdjustmentReportView({
    super.key,
    this.shipCode,
    this.saveExcel,
    this.today,
  });

  /// The ship's code; the assigned trip's ship when null (tests set it).
  final String? shipCode;
  final ExcelSaver? saveExcel;

  /// "Today" for the default range (tests set it).
  final DateTime? today;

  @override
  ConsumerState<StockAdjustmentReportView> createState() =>
      _StockAdjustmentReportViewState();
}

class _StockAdjustmentReportViewState
    extends ConsumerState<StockAdjustmentReportView> {
  late DateTime _from;
  late DateTime _to;
  String _shipCode = '';
  // False until the assigned trip (and so the ship) is known.
  bool _shipKnown = false;
  Future<List<AdjustmentReportRow>>? _rows;
  bool _downloading = false;

  @override
  void initState() {
    super.initState();
    final today = widget.today ?? DateTime.now();
    _to = DateTime(today.year, today.month, today.day);
    _from = DateTime(today.year, today.month);
    if (widget.shipCode != null) {
      _setShip(widget.shipCode!);
      return;
    }
    ref.listenManual(assignedTripProvider, (_, next) {
      if (next.hasValue) _setShip(next.value?.shipCode ?? '');
    }, fireImmediately: true);
  }

  void _setShip(String shipCode) {
    setState(() {
      _shipCode = shipCode;
      _shipKnown = true;
    });
    _load();
  }

  Map<String, String> get _query =>
      adjustmentReportQuery(shipCode: _shipCode, from: _from, to: _to);

  Future<void> _load() async {
    if (!mounted || _shipCode.isEmpty) return;
    setState(() {
      _rows = ref.read(stockAdjustmentApiProvider).fetchReport(_query);
    });
  }

  Future<void> _pickDate({required bool from}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: from ? _from : _to,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (from) {
        _from = picked;
        if (_to.isBefore(_from)) _to = _from;
      } else {
        _to = picked;
        if (_from.isAfter(_to)) _from = _to;
      }
    });
    await _load();
  }

  void _downloadPdf() {
    showDialog<void>(
      context: context,
      builder: (_) => PrescriptionPdfDialog(
        medicalRecordId: _shipCode,
        path: StockAdjustmentApi.reportDownloadPath(
          AdjustmentReportFormat.pdf,
          _query,
        ),
        title: 'Laporan Adjustment Stok',
        noun: 'laporan',
        fileStem: 'laporan-adjustment-stok',
        icon: LucideIcons.fileText,
      ),
    );
  }

  Future<void> _downloadExcel() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _downloading = true);
    try {
      final file = await ref
          .read(stockAdjustmentApiProvider)
          .download(AdjustmentReportFormat.xlsx, _query);
      final saved = await (widget.saveExcel ?? _saveExcel)(
        file.fileName,
        file.bytes,
      );
      if (saved) {
        messenger.showSnackBar(
          SnackBar(content: Text('Laporan tersimpan: ${file.fileName}')),
        );
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Gagal mengunduh laporan: $e')),
      );
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ScreenHeader(
          title: 'Laporan Adjustment',
          subtitle: 'Riwayat adjustment stok obat kapal',
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _DateButton(
                      label: 'Dari',
                      date: _from,
                      onTap: () => _pickDate(from: true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _DateButton(
                      label: 'Sampai',
                      date: _to,
                      onTap: () => _pickDate(from: false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _shipCode.isEmpty ? null : _downloadPdf,
                      icon: const Icon(LucideIcons.fileText, size: 15),
                      label: const Text('Unduh PDF'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _shipCode.isEmpty || _downloading
                          ? null
                          : _downloadExcel,
                      icon: const Icon(LucideIcons.fileSpreadsheet, size: 15),
                      label: const Text('Unduh Excel'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<AdjustmentReportRow>>(
            future: _rows,
            builder: (context, snap) {
              if (_shipKnown && _shipCode.isEmpty) {
                return const _Message(
                  'Anda belum ditugaskan di jadwal perjalanan mana pun.',
                );
              }
              if (snap.connectionState != ConnectionState.done) {
                return const Center(
                  child: CircularProgressIndicator(color: AppColors.orange),
                );
              }
              if (snap.hasError) {
                return _Message('Gagal memuat laporan: ${snap.error}');
              }
              final rows = snap.data ?? const [];
              if (rows.isEmpty) {
                return const _Message(
                  'Tidak ada adjustment stok pada periode ini.',
                );
              }
              return RefreshIndicator(
                onRefresh: _load,
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  itemCount: rows.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _ReportRowCard(row: rows[i]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _DateButton extends StatelessWidget {
  const _DateButton({
    required this.label,
    required this.date,
    required this.onTap,
  });

  final String label;
  final DateTime date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: const Icon(LucideIcons.calendar, size: 15),
      label: Text('$label: ${DateHelper.formatDate(date.toIso8601String())}'),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, color: AppColors.sub),
        ),
      ),
    );
  }
}

class _ReportRowCard extends StatelessWidget {
  const _ReportRowCard({required this.row});

  final AdjustmentReportRow row;

  @override
  Widget build(BuildContext context) {
    final diffColor = row.difference == 0
        ? AppColors.sub
        : row.difference < 0
        ? AppColors.red
        : AppColors.green;
    const sub = TextStyle(fontSize: 11.5, color: AppColors.sub);
    final date = row.date;

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
          Text(
            row.product,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            [
              row.code,
              if (date != null)
                DateHelper.formatDateTime(date.toIso8601String()),
            ].join(' • '),
            style: sub,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                'Stok Awal ${row.stockBefore} → Stok Akhir ${row.stockAfter}'
                '${row.uom.isEmpty ? '' : ' ${row.uom}'}',
                style: const TextStyle(fontSize: 12.5, color: AppColors.text),
              ),
              const Spacer(),
              Text(
                signedDifference(row.difference),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: diffColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text('Alasan: ${row.reason}', style: sub),
          Text(
            'Pelabuhan: ${row.port.isEmpty ? '-' : row.port}'
            ' • Petugas: ${row.user.isEmpty ? '-' : row.user}',
            style: sub,
          ),
        ],
      ),
    );
  }
}
