import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_config.dart';
import '../../../core/network/dio_client.dart';
import '../domain/icd10_item.dart';

class PaginatedIcd10 {
  const PaginatedIcd10({
    required this.data,
    required this.total,
    required this.page,
    required this.limit,
    required this.totalPages,
    required this.hasMore,
  });

  final List<Icd10Item> data;
  final int total;
  final int page;
  final int limit;
  final int totalPages;
  final bool hasMore;
}

class Icd10Api {
  Icd10Api({Dio? dio}) : _dio = dio ?? DioClient.instance;

  final Dio _dio;

  static final Map<String, PaginatedIcd10> _cache = {};

  /// Retrieves cached initial page (unfiltered) if available.
  static PaginatedIcd10? getCachedInitial() => _cache[''];

  /// Clears in-memory cache.
  static void clearCache() => _cache.clear();

  /// Prefetches the initial page in background so pickers open instantly.
  Future<void> prefetchInitial({int limit = 25}) async {
    if (_cache.containsKey('')) return;
    try {
      final res = await fetchIcd10Paginated(
        query: '',
        page: 1,
        limit: limit,
        useCache: false,
      );
      _cache[''] = res;
    } catch (_) {}
  }

  /// Fetches paginated ICD-10 diagnosis codes via GET /api/v1/icd10?page=1&limit=20&search=...
  Future<PaginatedIcd10> fetchIcd10Paginated({
    String query = '',
    int page = 1,
    int limit = 20,
    bool useCache = true,
  }) async {
    final cacheKey = '${query.trim().toLowerCase()}_${page}_$limit';
    if (useCache && _cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

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
        return const PaginatedIcd10(
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
          .map((j) => Icd10Item.fromJson(j))
          .toList();

      final paginated = PaginatedIcd10(
        data: list,
        total: total,
        page: currentPage,
        limit: limit,
        totalPages: totalPages,
        hasMore: hasMore,
      );

      _cache[cacheKey] = paginated;
      if (query.trim().isEmpty && page == 1) {
        _cache[''] = paginated;
      }

      return paginated;
    } on DioException catch (e) {
      debugPrint('Icd10Api fetchIcd10Paginated DioException: $e');
      return const PaginatedIcd10(
        data: [],
        total: 0,
        page: 1,
        limit: 20,
        totalPages: 1,
        hasMore: false,
      );
    } catch (e) {
      debugPrint('Icd10Api fetchIcd10Paginated error: $e');
      return const PaginatedIcd10(
        data: [],
        total: 0,
        page: 1,
        limit: 20,
        totalPages: 1,
        hasMore: false,
      );
    }
  }

  /// Fetches ICD-10 diagnosis codes via GET /api/v1/icd10?page=1&limit=20&search=...
  Future<List<Icd10Item>> searchIcd10({
    String query = '',
    int page = 1,
    int limit = 20,
  }) async {
    final paginated = await fetchIcd10Paginated(
      query: query,
      page: page,
      limit: limit,
    );
    return paginated.data;
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
