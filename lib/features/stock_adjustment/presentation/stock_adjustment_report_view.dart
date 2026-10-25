import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_helper.dart';
import '../../../core/widgets/app_card.dart';
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
  final _search = TextEditingController();
  // Lower-cased medicine search; filters the loaded rows on the device.
  String _filter = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

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
    final noShip = _shipCode.isEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ScreenHeader(
          title: 'Laporan Adjustment',
          subtitle: 'Riwayat adjustment stok obat kapal',
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _BadgeButton(
                label: 'Unduh PDF',
                icon: LucideIcons.fileText,
                color: AppColors.red,
                background: AppColors.redLt,
                onPressed: noShip ? null : _downloadPdf,
              ),
              const SizedBox(width: 8),
              _BadgeButton(
                label: 'Unduh Excel',
                icon: LucideIcons.fileSpreadsheet,
                color: AppColors.green,
                background: AppColors.greenLt,
                onPressed: noShip || _downloading ? null : _downloadExcel,
              ),
            ],
          ),
        ),
        Expanded(
          child: DefaultTextStyle.merge(
            style: const TextStyle(letterSpacing: 0),
            child: FutureBuilder<List<AdjustmentReportRow>>(
              future: _rows,
              builder: (context, snap) {
                final all = snap.data ?? const <AdjustmentReportRow>[];
                final rows = _filter.isEmpty
                    ? all
                    : [
                        for (final r in all)
                          if (r.product.toLowerCase().contains(_filter)) r,
                      ];

                final Widget content;
                if (_shipKnown && noShip) {
                  content = const _Message(
                    'Anda belum ditugaskan di jadwal perjalanan mana pun.',
                  );
                } else if (snap.connectionState != ConnectionState.done) {
                  content = const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(
                      child: CircularProgressIndicator(color: AppColors.orange),
                    ),
                  );
                } else if (snap.hasError) {
                  content = _Message('Gagal memuat laporan: ${snap.error}');
                } else if (all.isEmpty) {
                  content = const _Message(
                    'Tidak ada adjustment stok pada periode ini.',
                  );
                } else if (rows.isEmpty) {
                  content = _Message(
                    'Tidak ada obat yang cocok dengan "${_search.text.trim()}".',
                  );
                } else {
                  content = _ReportTable(rows: rows);
                }

                return RefreshIndicator(
                  color: AppColors.orange,
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      AppCard(
                        padding: EdgeInsets.zero,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _Toolbar(
                              count: rows.length,
                              search: _search,
                              onSearch: (v) => setState(
                                () => _filter = v.trim().toLowerCase(),
                              ),
                              from: _from,
                              to: _to,
                              onPickFrom: () => _pickDate(from: true),
                              onPickTo: () => _pickDate(from: false),
                            ),
                            content,
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

// Same type scale as the adjustment form: 13 card title, 12.5 body, 11 meta,
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

// Fixed column widths of the wide (tablet) table; the medicine takes the rest.
const double _kDateCol = 128;
const double _kStockCol = 118;
const double _kDiffCol = 52;
const double _kReasonCol = 150;
const double _kPortCol = 136;
const double _kUserCol = 128;
const double _kColGap = 12;

/// Below this width each row is stacked instead of a table row.
const double _kTableMinWidth = 940;

/// "Unduh PDF" / "Unduh Excel" in the header, drawn like a badge.
class _BadgeButton extends StatelessWidget {
  const _BadgeButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.background,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final Color color;
  final Color background;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onPressed == null ? 0.5 : 1,
      child: Material(
        color: background.withValues(alpha: 0.9),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: color.withValues(alpha: 0.22), width: 0.8),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Card header: title + row count, medicine search and the date range.
class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.count,
    required this.search,
    required this.onSearch,
    required this.from,
    required this.to,
    required this.onPickFrom,
    required this.onPickTo,
  });

  final int count;
  final TextEditingController search;
  final ValueChanged<String> onSearch;
  final DateTime from;
  final DateTime to;
  final VoidCallback onPickFrom;
  final VoidCallback onPickTo;

  @override
  Widget build(BuildContext context) {
    final title = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Riwayat',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.text,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
          decoration: BoxDecoration(
            color: AppColors.card2,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Text(
            '$count baris',
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: AppColors.sub,
            ),
          ),
        ),
      ],
    );
    final searchField = _SearchField(controller: search, onChanged: onSearch);
    final range = _DateRange(
      from: from,
      to: to,
      onPickFrom: onPickFrom,
      onPickTo: onPickTo,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 820) {
            return Row(
              children: [
                title,
                const Spacer(),
                SizedBox(width: 240, child: searchField),
                const SizedBox(width: 8),
                range,
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(alignment: Alignment.centerLeft, child: title),
              const SizedBox(height: 10),
              searchField,
              const SizedBox(height: 8),
              Align(alignment: Alignment.centerLeft, child: range),
            ],
          );
        },
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: color, width: width),
        );
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: _kBody,
      decoration: InputDecoration(
        hintText: 'Cari nama obat',
        hintStyle: const TextStyle(
          fontSize: 12.5,
          color: Color(0xFF94A3B8),
          letterSpacing: 0,
        ),
        prefixIcon: const Icon(
          LucideIcons.search,
          size: 14,
          color: AppColors.sub,
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 34),
        isDense: true,
        filled: true,
        fillColor: AppColors.inputBg,
        // The padding gives the box its height (it grows with the tablet
        // text scale), like the fields on the adjustment form.
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        border: border(AppColors.border),
        enabledBorder: border(AppColors.border),
        focusedBorder: border(AppColors.orange, 1.5),
      ),
    );
  }
}

/// "Dari 01 Okt 2026 | Sampai 25 Okt 2026": each half opens a date picker.
class _DateRange extends StatelessWidget {
  const _DateRange({
    required this.from,
    required this.to,
    required this.onPickFrom,
    required this.onPickTo,
  });

  final DateTime from;
  final DateTime to;
  final VoidCallback onPickFrom;
  final VoidCallback onPickTo;

  @override
  Widget build(BuildContext context) {
    Widget half(
      String label,
      DateTime date,
      VoidCallback onTap, {
      bool icon = false,
    }) => InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon) ...[
              const Icon(LucideIcons.calendar, size: 14, color: AppColors.sub),
              const SizedBox(width: 8),
            ],
            Text(label, style: _kMeta),
            const SizedBox(width: 8),
            Text(
              DateHelper.formatDate(date.toIso8601String()),
              style: _kBody.copyWith(fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );

    return Material(
      color: AppColors.inputBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            half('Dari', from, onPickFrom, icon: true),
            const VerticalDivider(width: 1, color: AppColors.border),
            half('Sampai', to, onPickTo),
          ],
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 12.5, color: AppColors.sub),
      ),
    );
  }
}

/// "[SKU] Name" from the report, split for display; the SKU is empty when the
/// product has no "[...]" prefix.
(String sku, String name) _splitProduct(String product) {
  final match = RegExp(r'^\[([^\]]+)\]\s*(.*)$').firstMatch(product.trim());
  if (match == null) return ('', product.trim());
  return (match.group(1)!.trim(), match.group(2)!.trim());
}

String _dateTime(DateTime? date) {
  if (date == null) return '-';
  final hh = date.hour.toString().padLeft(2, '0');
  final mm = date.minute.toString().padLeft(2, '0');
  return '${DateHelper.formatDate(date.toIso8601String())} $hh:$mm';
}

Color _diffColor(int diff) => diff == 0
    ? AppColors.sub
    : diff < 0
    ? AppColors.red
    : AppColors.green;

String _orDash(String s) => s.isEmpty ? '-' : s;

/// The rows as a table on tablet, stacked on narrow screens.
class _ReportTable extends StatelessWidget {
  const _ReportTable({required this.rows});

  final List<AdjustmentReportRow> rows;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= _kTableMinWidth;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (wide) const _TableHeader(),
            for (var i = 0; i < rows.length; i++)
              wide
                  ? _WideRow(row: rows[i], last: i == rows.length - 1)
                  : _NarrowRow(row: rows[i]),
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
          label('TANGGAL', width: _kDateCol),
          gap,
          label('OBAT'),
          gap,
          label('STOK', width: _kStockCol),
          gap,
          label('SELISIH', width: _kDiffCol),
          gap,
          label('ALASAN', width: _kReasonCol),
          gap,
          label('PELABUHAN', width: _kPortCol),
          gap,
          label('PETUGAS', width: _kUserCol),
        ],
      ),
    );
  }
}

/// A value with a smaller grey line under it.
class _TwoLine extends StatelessWidget {
  const _TwoLine(this.value, this.meta, {this.bold = false});

  final String value;
  final String meta;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: bold ? _kBody.copyWith(fontWeight: FontWeight.w600) : _kBody,
        ),
        if (meta.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            meta,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _kMeta,
          ),
        ],
      ],
    );
  }
}

/// "120 → 112 Kapsul".
class _StockChange extends StatelessWidget {
  const _StockChange({required this.row});

  final AdjustmentReportRow row;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        style: _kBody,
        children: [
          TextSpan(text: '${row.stockBefore} → ${row.stockAfter}'),
          if (row.uom.isNotEmpty) TextSpan(text: ' ${row.uom}', style: _kMeta),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _DiffText extends StatelessWidget {
  const _DiffText({required this.diff});

  final int diff;

  @override
  Widget build(BuildContext context) {
    return Text(
      signedDifference(diff),
      style: TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
        color: _diffColor(diff),
      ),
    );
  }
}

class _WideRow extends StatelessWidget {
  const _WideRow({required this.row, required this.last});

  final AdjustmentReportRow row;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final (sku, name) = _splitProduct(row.product);
    Widget cell(double width, Widget child) =>
        SizedBox(width: width, child: child);
    Widget plain(String text) =>
        Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: _kBody);
    const gap = SizedBox(width: _kColGap);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      decoration: BoxDecoration(
        border: last
            ? null
            : const Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          cell(_kDateCol, _TwoLine(_dateTime(row.date), row.code)),
          gap,
          Expanded(child: _TwoLine(name, sku, bold: true)),
          gap,
          cell(_kStockCol, _StockChange(row: row)),
          gap,
          cell(_kDiffCol, _DiffText(diff: row.difference)),
          gap,
          cell(_kReasonCol, plain(_orDash(row.reason))),
          gap,
          cell(_kPortCol, plain(_orDash(row.port))),
          gap,
          cell(_kUserCol, plain(_orDash(row.user))),
        ],
      ),
    );
  }
}

class _NarrowRow extends StatelessWidget {
  const _NarrowRow({required this.row});

  final AdjustmentReportRow row;

  @override
  Widget build(BuildContext context) {
    final (sku, name) = _splitProduct(row.product);
    final meta = [
      if (sku.isNotEmpty) sku,
      _dateTime(row.date),
      if (row.code.isNotEmpty) row.code,
    ].join(' · ');

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _TwoLine(name, meta, bold: true)),
              const SizedBox(width: 12),
              _DiffText(diff: row.difference),
            ],
          ),
          const SizedBox(height: 6),
          _StockChange(row: row),
          const SizedBox(height: 4),
          Text(_orDash(row.reason), style: _kBody),
          const SizedBox(height: 2),
          Text('${_orDash(row.port)} · ${_orDash(row.user)}', style: _kMeta),
        ],
      ),
    );
  }
}
