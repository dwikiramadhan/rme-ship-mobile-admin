import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'icd_catalog.dart';
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

/// ICD-10 diagnosis codes, searched on the device from the list bundled in the app
/// ([IcdCatalog]) — no connection needed. Same matching and order as
/// GET /api/v1/icd10?search=...
class Icd10Api {
  Icd10Api({IcdCatalog? catalog})
    : _catalog = catalog ?? IcdCatalog(IcdCatalog.icd10Asset);

  final IcdCatalog _catalog;

  static PaginatedIcd10? _initial;

  /// The first unfiltered page, once loaded, so pickers open instantly.
  static PaginatedIcd10? getCachedInitial() => _initial;

  static void clearCache() => _initial = null;

  /// Loads the list in the background so the picker opens instantly.
  Future<void> prefetchInitial({int limit = 25}) async {
    try {
      _initial ??= await fetchIcd10Paginated(limit: limit);
    } catch (_) {}
  }

  Future<PaginatedIcd10> fetchIcd10Paginated({
    String query = '',
    int page = 1,
    int limit = 20,
  }) async {
    final result = await _catalog.search(query, page: page, limit: limit);
    final totalPages = result.total == 0 ? 1 : (result.total / limit).ceil();
    final paginated = PaginatedIcd10(
      data: [
        for (final (code, display) in result.items)
          Icd10Item(code: code, display: display),
      ],
      total: result.total,
      page: page,
      limit: limit,
      totalPages: totalPages,
      hasMore: page < totalPages,
    );
    if (query.trim().isEmpty && page == 1) _initial ??= paginated;
    return paginated;
  }

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
