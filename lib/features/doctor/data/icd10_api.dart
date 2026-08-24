import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_config.dart';
import '../../../core/network/dio_client.dart';
import '../domain/icd10_item.dart';

class Icd10Api {
  Icd10Api({Dio? dio}) : _dio = dio ?? DioClient.instance;

  final Dio _dio;

  /// Fetches ICD-10 diagnosis codes via GET /api/v1/icd10?page=1&limit=20&search=...
  Future<List<Icd10Item>> searchIcd10({
    String query = '',
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final response = await _dio.get(
        ApiConfig.icd10Path,
        queryParameters: {
          'page': page,
          'limit': limit,
          if (query.trim().isNotEmpty) 'search': query.trim(),
        },
      );

      final data = response.data;
      if (data is! Map<String, dynamic>) {
        return [];
      }

      final result = data['result'] ?? data['data'];
      final List rawList;
      if (result is List) {
        rawList = result;
      } else if (result is Map<String, dynamic> && result['data'] is List) {
        rawList = result['data'] as List;
      } else {
        rawList = [];
      }

      return rawList
          .whereType<Map<String, dynamic>>()
          .map((j) => Icd10Item.fromJson(j))
          .toList();
    } on DioException catch (e) {
      debugPrint('Icd10Api searchIcd10 error: $e');
      return [];
    } catch (e) {
      debugPrint('Icd10Api searchIcd10 error: $e');
      return [];
    }
  }
}

final icd10ApiProvider = Provider<Icd10Api>((ref) => Icd10Api());

/// Resolves an ICD-10 code (or formatted string) to full Icd10Item (code + display)
final icd10LookupProvider =
    FutureProvider.family<Icd10Item?, String>((ref, code) async {
  final cleanCode = code.trim();
  if (cleanCode.isEmpty || cleanCode == '—' || cleanCode == '-') return null;

  // If code already contains " - ", parse directly
  if (cleanCode.contains(' - ')) {
    final parts = cleanCode.split(' - ');
    return Icd10Item(
      code: parts.first.trim(),
      display: parts.sublist(1).join(' - ').trim(),
    );
  }

  final api = ref.read(icd10ApiProvider);
  final results = await api.searchIcd10(query: cleanCode, limit: 10);
  return results
          .where((i) => i.code.toLowerCase() == cleanCode.toLowerCase())
          .firstOrNull ??
      results
          .where(
            (i) => i.display.toLowerCase().contains(cleanCode.toLowerCase()),
          )
          .firstOrNull ??
      (results.isNotEmpty ? results.first : null);
});
