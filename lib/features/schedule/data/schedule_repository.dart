import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/ship_code_helper.dart';
import '../domain/trip_schedule.dart';
import 'schedule_api.dart';

class ScheduleRepository {
  ScheduleRepository(this._api);

  final ScheduleApi _api;

  /// Fetches schedules directly from API
  Future<List<JadwalPerjalanan>> fetchSchedules({
    String? shipCode,
    String? shipId,
    int page = 1,
    int limit = 10,
    String? search,
    String? status,
  }) async {
    final pageResult = await fetchPaginatedSchedules(
      shipCode: shipCode,
      shipId: shipId,
      page: page,
      limit: limit,
      search: search,
      status: status,
    );
    return pageResult.items;
  }

  /// Fetches paginated schedules with search and status filter
  Future<SchedulePageResult> fetchPaginatedSchedules({
    String? shipCode,
    String? shipId,
    int page = 1,
    int limit = 10,
    String? search,
    String? status,
  }) async {
    try {
      final effectiveCode = (shipCode != null && shipCode.isNotEmpty)
          ? shipCode
          : shipId;
      if (effectiveCode != null && effectiveCode.isNotEmpty) {
        return await _api.getPaginatedSchedulesByShipCode(
          shipCode: effectiveCode,
          page: page,
          limit: limit,
          search: search,
          status: status,
        );
      }
      final items = await _api.getSchedules();
      return SchedulePageResult(
        items: items,
        total: items.length,
        page: page,
        limit: limit,
        hasMore: false,
      );
    } catch (e) {
      debugPrint('ScheduleRepository fetchPaginatedSchedules error: $e');
      rethrow;
    }
  }

  /// Fetches schedule by ID directly from API
  Future<JadwalPerjalanan> fetchScheduleById(String id) async {
    try {
      return await _api.getScheduleById(id);
    } catch (e) {
      debugPrint('ScheduleRepository fetchScheduleById error: $e');
      rethrow;
    }
  }
}

final scheduleApiProvider = Provider<ScheduleApi>((ref) => ScheduleApi());

final scheduleRepositoryProvider = Provider<ScheduleRepository>((ref) {
  final api = ref.watch(scheduleApiProvider);
  return ScheduleRepository(api);
});

class SchedulesNotifier
    extends StateNotifier<AsyncValue<List<JadwalPerjalanan>>> {
  SchedulesNotifier(this._repository, this._ref)
      : super(const AsyncValue.loading()) {
    load();
  }

  final ScheduleRepository _repository;
  final Ref _ref;

  int _currentPage = 1;
  static const int _limit = 10;
  bool _hasMore = false;
  bool _isLoadingMore = false;
  String? _resolvedShipCode;
  String _searchQuery = '';
  String _statusFilter = 'Semua';
  int _totalCount = 0;

  bool get hasMore => _hasMore;
  bool get isLoadingMore => _isLoadingMore;
  int get currentPage => _currentPage;
  String get searchQuery => _searchQuery;
  String get statusFilter => _statusFilter;
  int get totalCount => _totalCount;

  Future<String> _getShipCode() async {
    final code = await resolveLocalStorageShipCode(_ref);
    _resolvedShipCode = code;
    return code;
  }

  Future<void> load({
    String? search,
    String? status,
  }) async {
    state = const AsyncValue.loading();
    _currentPage = 1;
    if (search != null) _searchQuery = search;
    if (status != null) _statusFilter = status;
    try {
      final shipCode = await _getShipCode();
      final result = await _repository.fetchPaginatedSchedules(
        shipCode: shipCode,
        page: 1,
        limit: _limit,
        search: _searchQuery,
        status: _statusFilter,
      );
      _hasMore = result.hasMore;
      _totalCount = result.total;
      state = AsyncValue.data(result.items);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh() async {
    _currentPage = 1;
    try {
      final shipCode = await _getShipCode();
      final result = await _repository.fetchPaginatedSchedules(
        shipCode: shipCode,
        page: 1,
        limit: _limit,
        search: _searchQuery,
        status: _statusFilter,
      );
      _hasMore = result.hasMore;
      _totalCount = result.total;
      state = AsyncValue.data(result.items);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> setSearch(String query) async {
    final trimmed = query.trim();
    if (_searchQuery == trimmed) return;
    _searchQuery = trimmed;
    await load(search: _searchQuery);
  }

  Future<void> setStatusFilter(String status) async {
    if (_statusFilter == status) return;
    _statusFilter = status;
    await load(status: _statusFilter);
  }

  Future<void> resetFilters() async {
    _searchQuery = '';
    _statusFilter = 'Semua';
    await load(search: '', status: 'Semua');
  }

  Future<void> loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    final currentList = state.valueOrNull ?? [];
    _isLoadingMore = true;
    try {
      final nextPage = _currentPage + 1;
      final shipCode = _resolvedShipCode ?? await _getShipCode();
      final result = await _repository.fetchPaginatedSchedules(
        shipCode: shipCode,
        page: nextPage,
        limit: _limit,
        search: _searchQuery,
        status: _statusFilter,
      );
      if (result.items.isEmpty) {
        _hasMore = false;
      } else {
        _currentPage = nextPage;
        _hasMore = result.hasMore;
        _totalCount = result.total > 0 ? result.total : _totalCount + result.items.length;
        state = AsyncValue.data([...currentList, ...result.items]);
      }
    } catch (e) {
      debugPrint('SchedulesNotifier loadMore error: $e');
    } finally {
      _isLoadingMore = false;
      if (mounted) {
        state = AsyncValue.data(state.valueOrNull ?? currentList);
      }
    }
  }
}

final schedulesNotifierProvider = StateNotifierProvider<SchedulesNotifier,
    AsyncValue<List<JadwalPerjalanan>>>((ref) {
  final repository = ref.watch(scheduleRepositoryProvider);
  return SchedulesNotifier(repository, ref);
});

/// Backwards compatible provider providing the list directly
final jadwalPerjalananProvider = Provider<List<JadwalPerjalanan>>((ref) {
  final asyncValue = ref.watch(schedulesNotifierProvider);
  return asyncValue.maybeWhen(
    data: (data) => data,
    orElse: () => const [],
  );
});
