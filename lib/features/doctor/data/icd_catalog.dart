import 'dart:convert';
import 'dart:io' show gzip;
import 'dart:isolate';

import 'package:flutter/services.dart';

/// An ICD code list shipped inside the app (exported from the backend by
/// `tool/export_icd.sh`), searched on the device so the doctor's ICD
/// pickers work with no connection.
class IcdCatalog {
  IcdCatalog(this.assetPath, {AssetBundle? bundle})
    : _bundle = bundle ?? rootBundle;

  static const icd10Asset = 'assets/data/icd10.json.gz';
  static const icd9cmAsset = 'assets/data/icd9cm.json.gz';

  final String assetPath;
  final AssetBundle _bundle;

  // Parsed once per app run per list; shared by every instance.
  static final Map<String, Future<_IcdData>> _loaded = {};

  Future<_IcdData> get _data => _loaded[assetPath] ??= _load().catchError(
    (Object e, StackTrace st) {
      _loaded.remove(assetPath); // let the next call try again
      Error.throwWithStackTrace(e, st);
    },
  );

  Future<_IcdData> _load() async {
    final bytes = await _bundle.load(assetPath);
    final compressed = bytes.buffer.asUint8List(
      bytes.offsetInBytes,
      bytes.lengthInBytes,
    );
    // Off the UI thread; lower-cased copies are made once for searching.
    return Isolate.run(() {
      final json =
          jsonDecode(utf8.decode(gzip.decode(compressed)))
              as Map<String, dynamic>;
      final items = [
        for (final row in json['items'] as List)
          _IcdRow(row[0] as String, row[1] as String),
      ];
      return _IcdData(
        DateTime.tryParse(json['exported_at'] as String? ?? ''),
        items,
      );
    });
  }

  /// When the list was exported from the backend.
  Future<DateTime?> exportedAt() async => (await _data).exportedAt;

  /// Page [page] of the codes matching [query] the way the backend does:
  /// the text anywhere in the code or the description, ignoring case, in
  /// code order. An empty query matches everything.
  Future<({List<(String code, String display)> items, int total})> search(
    String query, {
    int page = 1,
    int limit = 20,
  }) async {
    final data = await _data;
    final q = query.trim().toLowerCase();
    final matches = q.isEmpty
        ? data.items
        : [
            for (final row in data.items)
              if (row.codeLower.contains(q) || row.displayLower.contains(q))
                row,
          ];
    final start = (page - 1) * limit;
    return (
      items: [
        for (final row in matches.skip(start).take(limit))
          (row.code, row.display),
      ],
      total: matches.length,
    );
  }
}

class _IcdRow {
  _IcdRow(this.code, this.display)
    : codeLower = code.toLowerCase(),
      displayLower = display.toLowerCase();

  final String code;
  final String display;
  final String codeLower;
  final String displayLower;
}

class _IcdData {
  const _IcdData(this.exportedAt, this.items);

  final DateTime? exportedAt;
  final List<_IcdRow> items;
}
