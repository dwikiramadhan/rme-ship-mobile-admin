import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'icd_catalog.dart';
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

/// ICD-9-CM procedure codes, searched on the device from the list bundled in the app
/// ([IcdCatalog]) — no connection needed. Same matching and order as
/// GET /api/v1/icd9cm?search=...
class Icd9Api {
  Icd9Api({IcdCatalog? catalog})
    : _catalog = catalog ?? IcdCatalog(IcdCatalog.icd9cmAsset);

  final IcdCatalog _catalog;

  static PaginatedIcd9? _initial;

  /// The first unfiltered page, once loaded, so pickers open instantly.
  static PaginatedIcd9? getCachedInitial() => _initial;

  static void clearCache() => _initial = null;

  /// Loads the list in the background so the picker opens instantly.
  Future<void> prefetchInitial({int limit = 25}) async {
    try {
      _initial ??= await fetchIcd9Paginated(limit: limit);
    } catch (_) {}
  }

  Future<PaginatedIcd9> fetchIcd9Paginated({
    String query = '',
    int page = 1,
    int limit = 20,
  }) async {
    final result = await _catalog.search(query, page: page, limit: limit);
    final totalPages = result.total == 0 ? 1 : (result.total / limit).ceil();
    final paginated = PaginatedIcd9(
      data: [
        for (final (code, display) in result.items)
          Icd9Item(code: code, display: display, version: 'ICD9CM_2010'),
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
