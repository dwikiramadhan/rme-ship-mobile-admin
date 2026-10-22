/// Stock adjustment by the Koordinator: the ship's stock of some medicines is
/// replaced by what was counted on board, each with a reason, and recorded
/// with the harbor the ship is at (POST /api/v1/stock-adjustments).
library;

/// One medicine on the adjustment form, before it is sent.
class AdjustmentLine {
  const AdjustmentLine({
    required this.sku,
    required this.name,
    this.unit = '',
    required this.currentStock,
    this.stockAfter,
    this.reason = '',
  });

  final String sku;
  final String name;
  final String unit;

  /// The ship's stock when the medicine was picked ("Sisa stok"). The backend
  /// reads it again when saving.
  final int currentStock;

  /// The counted stock ("Stok Akhir"); null until filled in.
  final int? stockAfter;
  final String reason;

  /// Stok akhir − sisa stok; null until the counted stock is filled in.
  int? get difference => stockAfter == null ? null : stockAfter! - currentStock;

  AdjustmentLine copyWith({int? Function()? stockAfter, String? reason}) =>
      AdjustmentLine(
        sku: sku,
        name: name,
        unit: unit,
        currentStock: currentStock,
        stockAfter: stockAfter == null ? this.stockAfter : stockAfter(),
        reason: reason ?? this.reason,
      );
}

/// What is missing before [lines] can be saved, or null when complete.
String? adjustmentError(List<AdjustmentLine> lines) {
  if (lines.isEmpty) return 'Pilih minimal 1 obat.';
  for (final l in lines) {
    final after = l.stockAfter;
    if (after == null) return 'Isi stok akhir ${l.name}.';
    if (after < 0) return 'Stok akhir ${l.name} tidak boleh negatif.';
    if (l.reason.trim().isEmpty) {
      return 'Alasan adjustment ${l.name} wajib diisi.';
    }
  }
  return null;
}

/// Body of POST /api/v1/stock-adjustments. [portId] = the harbor of the
/// ongoing trip; left out when the ship isn't on a trip.
Map<String, dynamic> adjustmentRequestJson({
  required String shipCode,
  String? portId,
  required List<AdjustmentLine> lines,
  DateTime? createdAt,
}) => {
  'ship_code': shipCode.trim(),
  if (portId != null && portId.isNotEmpty) 'port_id': portId,
  if (createdAt != null)
    'client_created_at': createdAt.toUtc().toIso8601String(),
  'items': [
    for (final l in lines)
      {
        'medicine_sku': l.sku,
        'stock_after': l.stockAfter,
        'reason': l.reason.trim(),
      },
  ],
};

/// "+4", "-80", "0".
String signedDifference(int value) => value > 0 ? '+$value' : '$value';

/// One row of the adjustment report (GET /api/v1/stock-adjustments/report):
/// one medicine of one adjustment.
class AdjustmentReportRow {
  const AdjustmentReportRow({
    required this.no,
    required this.code,
    required this.date,
    required this.product,
    required this.uom,
    required this.stockBefore,
    required this.stockAfter,
    required this.difference,
    required this.reason,
    required this.port,
    required this.user,
  });

  final int no;
  final String code;
  final DateTime? date;

  /// "[SKU] Nama".
  final String product;
  final String uom;
  final int stockBefore;
  final int stockAfter;
  final int difference;
  final String reason;
  final String port;
  final String user;

  factory AdjustmentReportRow.fromJson(Map<String, dynamic> json) {
    int toInt(Object? v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
    String text(Object? v) => v == null ? '' : '$v'.trim();
    final before = toInt(json['stock_before']);
    final after = toInt(json['stock_after']);
    return AdjustmentReportRow(
      no: toInt(json['no']),
      code: text(json['code']),
      date: DateTime.tryParse(text(json['date']))?.toLocal(),
      product: text(json['product']),
      uom: text(json['uom']),
      stockBefore: before,
      stockAfter: after,
      difference: json['difference'] == null
          ? after - before
          : toInt(json['difference']),
      reason: text(json['reason']),
      port: text(json['port']),
      user: text(json['user']),
    );
  }
}

/// Report filter as query parameters; dates are YYYY-MM-DD.
Map<String, String> adjustmentReportQuery({
  required String shipCode,
  DateTime? from,
  DateTime? to,
}) {
  String day(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
  return {
    if (shipCode.trim().isNotEmpty) 'ship_code': shipCode.trim(),
    if (from != null) 'date_from': day(from),
    if (to != null) 'date_to': day(to),
  };
}
