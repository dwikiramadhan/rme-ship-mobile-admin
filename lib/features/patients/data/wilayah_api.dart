import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';

class WilayahProvinsi {
  const WilayahProvinsi({
    required this.kodeProvinsi,
    required this.namaProvinsi,
  });

  final int kodeProvinsi;
  final String namaProvinsi;

  factory WilayahProvinsi.fromJson(Map<String, dynamic> json) {
    return WilayahProvinsi(
      kodeProvinsi: (json['kode_provinsi'] as num?)?.toInt() ?? 0,
      namaProvinsi: json['nama_provinsi']?.toString() ?? '',
    );
  }
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

  factory WilayahKabupatenKota.fromJson(Map<String, dynamic> json) {
    return WilayahKabupatenKota(
      kodeKabkota: (json['kode_kabkota'] as num?)?.toDouble() ?? 0.0,
      namaKabkota: json['nama_kabkota']?.toString() ?? '',
      kodeProvinsi: (json['kode_provinsi'] as num?)?.toInt() ?? 0,
    );
  }
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

  factory WilayahKecamatan.fromJson(Map<String, dynamic> json) {
    return WilayahKecamatan(
      kodeKecamatan: json['kode_kecamatan']?.toString() ?? '',
      namaKecamatan: json['nama_kecamatan']?.toString() ?? '',
      kodeKabkota: (json['kode_kabkota'] as num?)?.toDouble() ?? 0.0,
    );
  }
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

  factory WilayahKelurahan.fromJson(Map<String, dynamic> json) {
    return WilayahKelurahan(
      kodeKelurahan: json['kode_kelurahan']?.toString() ?? '',
      namaKelurahan: json['nama_kelurahan']?.toString() ?? '',
      kodeKecamatan: json['kode_kecamatan']?.toString() ?? '',
      kodePos: (json['kode_pos'] as num?)?.toInt() ?? 0,
    );
  }
}

class WilayahApi {
  WilayahApi({Dio? dio}) : _dio = dio ?? DioClient.instance;

  final Dio _dio;

  Future<List<WilayahProvinsi>> getProvinsi() async {
    try {
      final res = await _dio.get('/api/v1/wilayah/provinsi');
      final data = res.data;
      if (data is Map<String, dynamic> && data['result'] is List) {
        return (data['result'] as List)
            .map((e) => WilayahProvinsi.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return const [];
    } catch (_) {
      return const [];
    }
  }

  Future<List<WilayahKabupatenKota>> getKabupatenKota(int kodeProvinsi) async {
    try {
      final res = await _dio.get(
        '/api/v1/wilayah/kabupaten-kota',
        queryParameters: {'kode_provinsi': kodeProvinsi},
      );
      final data = res.data;
      if (data is Map<String, dynamic> && data['result'] is List) {
        return (data['result'] as List)
            .map((e) => WilayahKabupatenKota.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return const [];
    } catch (_) {
      return const [];
    }
  }

  Future<List<WilayahKecamatan>> getKecamatan(double kodeKabkota) async {
    try {
      final res = await _dio.get(
        '/api/v1/wilayah/kecamatan',
        queryParameters: {'kode_kabkota': kodeKabkota},
      );
      final data = res.data;
      if (data is Map<String, dynamic> && data['result'] is List) {
        return (data['result'] as List)
            .map((e) => WilayahKecamatan.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return const [];
    } catch (_) {
      return const [];
    }
  }

  Future<List<WilayahKelurahan>> getKelurahan(String kodeKecamatan) async {
    try {
      final res = await _dio.get(
        '/api/v1/wilayah/kelurahan',
        queryParameters: {'kode_kecamatan': kodeKecamatan},
      );
      final data = res.data;
      if (data is Map<String, dynamic> && data['result'] is List) {
        return (data['result'] as List)
            .map((e) => WilayahKelurahan.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return const [];
    } catch (_) {
      return const [];
    }
  }
}

final wilayahApiProvider = Provider<WilayahApi>((ref) => WilayahApi());
