import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_config.dart';
import '../../../core/network/dio_client.dart';
import '../domain/icd9_item.dart';

class PaginatedIcd9 {
  const PaginatedIcd9({
    required this.data,
    required this.total,
    required this.page,
    required this.limit,
    required this.totalPages,
    required this.hasMore,
  });

  final List<Icd9Item> data;
  final int total;
  final int page;
  final int limit;
  final int totalPages;
  final bool hasMore;
}

class Icd9Api {
  Icd9Api({Dio? dio}) : _dio = dio ?? DioClient.instance;

  final Dio _dio;

  /// Fetches paginated ICD-9-CM procedure codes via GET /api/v1/icd9?page=1&limit=20&search=...
  Future<PaginatedIcd9> fetchIcd9Paginated({
    String query = '',
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final response = await _dio.get(
        ApiConfig.icd9Path,
        queryParameters: {
          'page': page,
          'limit': limit,
          if (query.trim().isNotEmpty) 'search': query.trim(),
        },
      );

      final data = response.data;
      if (data is! Map<String, dynamic>) {
        return const PaginatedIcd9(
          data: [],
          total: 0,
          page: 1,
          limit: 20,
          totalPages: 1,
          hasMore: false,
        );
      }

      final result = data['result'] ?? data['data'];
      final List rawList;
      int total = 0;
      int totalPages = 1;
      int currentPage = page;
      bool hasMore = false;

      if (result is Map<String, dynamic>) {
        rawList = result['data'] is List ? (result['data'] as List) : [];
        total = (result['total'] as num?)?.toInt() ??
            (result['total_items'] as num?)?.toInt() ??
            rawList.length;
        totalPages = (result['total_pages'] as num?)?.toInt() ??
            (result['totalPages'] as num?)?.toInt() ??
            1;
        currentPage = (result['page'] as num?)?.toInt() ?? page;
        hasMore = currentPage < totalPages;
      } else if (result is List) {
        rawList = result;
        total = (data['total'] as num?)?.toInt() ?? rawList.length;
        totalPages = (data['total_pages'] as num?)?.toInt() ??
            (rawList.length >= limit ? currentPage + 1 : currentPage);
        currentPage = page;
        hasMore = rawList.length >= limit;
      } else {
        rawList = [];
      }

      final list = rawList
          .whereType<Map<String, dynamic>>()
          .map((j) => Icd9Item.fromJson(j))
          .toList();

      return PaginatedIcd9(
        data: list,
        total: total,
        page: currentPage,
        limit: limit,
        totalPages: totalPages,
        hasMore: hasMore,
      );
    } on DioException catch (e) {
      debugPrint('Icd9Api fetchIcd9Paginated DioException: $e');
      return const PaginatedIcd9(
        data: [],
        total: 0,
        page: 1,
        limit: 20,
        totalPages: 1,
        hasMore: false,
      );
    } catch (e) {
      debugPrint('Icd9Api fetchIcd9Paginated error: $e');
      return const PaginatedIcd9(
        data: [],
        total: 0,
        page: 1,
        limit: 20,
        totalPages: 1,
        hasMore: false,
      );
    }
  }

  /// Fetches ICD-9-CM procedure codes via GET /api/v1/icd9?page=1&limit=20&search=...
  Future<List<Icd9Item>> searchIcd9({
    String query = '',
    int page = 1,
    int limit = 20,
  }) async {
    final paginated = await fetchIcd9Paginated(
      query: query,
      page: page,
      limit: limit,
    );
    return paginated.data;
  }
}

final icd9ApiProvider = Provider<Icd9Api>((ref) => Icd9Api());

/// Resolves an ICD-9 code (or formatted string) to full Icd9Item (code + display)
final icd9LookupProvider =
    FutureProvider.family<Icd9Item?, String>((ref, code) async {
  final cleanCode = code.trim();
  if (cleanCode.isEmpty || cleanCode == '—' || cleanCode == '-') return null;

  // If code already contains " - ", parse directly
  if (cleanCode.contains(' - ')) {
    final parts = cleanCode.split(' - ');
    return Icd9Item(
      code: parts.first.trim(),
      display: parts.sublist(1).join(' - ').trim(),
    );
  }

  final api = ref.read(icd9ApiProvider);
  final results = await api.searchIcd9(query: cleanCode, limit: 10);
  final lowerCode = cleanCode.toLowerCase();
  final strippedCode = lowerCode.replaceAll('.', '').replaceAll(' ', '');

  return results
          .where((i) => i.code.toLowerCase().trim() == lowerCode)
          .firstOrNull ??
      results
          .where((i) =>
              i.code.toLowerCase().replaceAll('.', '').trim() == strippedCode)
          .firstOrNull ??
      results
          .where((i) => i.display.toLowerCase().trim() == lowerCode)
          .firstOrNull ??
      (results.isNotEmpty && !cleanCode.contains(' ') ? results.first : null);
});
