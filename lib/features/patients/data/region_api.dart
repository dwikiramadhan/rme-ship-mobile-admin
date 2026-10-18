import 'dart:convert';
import 'dart:io' show gzip;
import 'dart:isolate';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class WilayahProvinsi {
  const WilayahProvinsi({
    required this.kodeProvinsi,
    required this.namaProvinsi,
  });

  final int kodeProvinsi;
  final String namaProvinsi;
}

class WilayahKabupatenKota {
  const WilayahKabupatenKota({
    required this.kodeKabkota,
    required this.namaKabkota,
    required this.kodeProvinsi,
  });

  final double kodeKabkota;
  final String namaKabkota;
  final int kodeProvinsi;
}

class WilayahKecamatan {
  const WilayahKecamatan({
    required this.kodeKecamatan,
    required this.namaKecamatan,
    required this.kodeKabkota,
  });

  final String kodeKecamatan;
  final String namaKecamatan;
  final double kodeKabkota;
}

class WilayahKelurahan {
  const WilayahKelurahan({
    required this.kodeKelurahan,
    required this.namaKelurahan,
    required this.kodeKecamatan,
    required this.kodePos,
  });

  final String kodeKelurahan;
  final String namaKelurahan;
  final String kodeKecamatan;
  final int kodePos;
}

/// Region reference data (provinsi → kabupaten/kota → kecamatan →
/// kelurahan/desa) for the address dropdowns.
///
/// Read from the app asset [assetPath], not the API, so the dropdowns work
/// with no connection. The asset is exported from the backend's region
/// tables by `tool/export_wilayah.sh`; the patient keeps only the
/// kelurahan code, which the backend resolves against the same tables.
class WilayahApi {
  WilayahApi({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  static const assetPath = 'assets/data/wilayah.json.gz';

  final AssetBundle _bundle;

  // Parsed once per app run (about 83k villages); shared by every instance.
  static Future<Map<String, dynamic>>? _data;

  Future<Map<String, dynamic>> get _regions => _data ??= _load().catchError(
    (Object e, StackTrace st) {
      _data = null; // let the next call try again
      Error.throwWithStackTrace(e, st);
    },
  );

  Future<Map<String, dynamic>> _load() async {
    final bytes = await _bundle.load(assetPath);
    final compressed = bytes.buffer.asUint8List(
      bytes.offsetInBytes,
      bytes.lengthInBytes,
    );
    // Off the UI thread: decoding takes a few hundred ms on a slow phone.
    return Isolate.run(
      () => jsonDecode(utf8.decode(gzip.decode(compressed)))
          as Map<String, dynamic>,
    );
  }

  /// When the bundled data was exported from the backend (`YYYY-MM-DD`).
  Future<DateTime?> exportedAt() async =>
      DateTime.tryParse((await _regions)['exported_at'] as String? ?? '');

  /// The rows under [parent] in [level], e.g. the districts of "64.02".
  Future<List<List<dynamic>>> _rows(String level, String parent) async {
    final byParent = (await _regions)[level] as Map<String, dynamic>;
    return [
      for (final row in (byParent[parent] as List?) ?? const [])
        row as List<dynamic>,
    ];
  }

  Future<List<WilayahProvinsi>> getProvinsi() async => [
    for (final row in (await _regions)['provinsi'] as List)
      WilayahProvinsi(
        kodeProvinsi: row[0] as int,
        namaProvinsi: row[1] as String,
      ),
  ];

  Future<List<WilayahKabupatenKota>> getKabupatenKota(int kodeProvinsi) async => [
    for (final row in await _rows('kabkota', '$kodeProvinsi'))
      WilayahKabupatenKota(
        kodeKabkota: double.parse(row[0] as String),
        namaKabkota: row[1] as String,
        kodeProvinsi: kodeProvinsi,
      ),
  ];

  Future<List<WilayahKecamatan>> getKecamatan(double kodeKabkota) async => [
    for (final row in await _rows('kecamatan', kodeKabkota.toStringAsFixed(2)))
      WilayahKecamatan(
        kodeKecamatan: row[0] as String,
        namaKecamatan: row[1] as String,
        kodeKabkota: kodeKabkota,
      ),
  ];

  Future<List<WilayahKelurahan>> getKelurahan(String kodeKecamatan) async => [
    for (final row in await _rows('kelurahan', kodeKecamatan))
      WilayahKelurahan(
        kodeKelurahan: row[0] as String,
        namaKelurahan: row[1] as String,
        kodeKecamatan: kodeKecamatan,
        kodePos: row[2] as int,
      ),
  ];
}

final wilayahApiProvider = Provider<WilayahApi>((ref) => WilayahApi());
