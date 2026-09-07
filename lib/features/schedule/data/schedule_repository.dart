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

  /// Updates a schedule by ID
  Future<JadwalPerjalanan> updateSchedule(
    String id,
    Map<String, dynamic> body,
  ) async {
    try {
      return await _api.updateSchedule(id, body);
    } catch (e) {
      debugPrint('ScheduleRepository updateSchedule error: $e');
      rethrow;
    }
  }

  /// Fetches provisions history for a schedule code
  Future<List<ProvisionHistoryItem>> fetchProvisionsHistory(String scheduleCode) async {
    try {
      return await _api.getProvisionsHistory(scheduleCode);
    } catch (e) {
      debugPrint('ScheduleRepository fetchProvisionsHistory error: $e');
      return [];
    }
  }

  /// Adds a new provision entry
  Future<ProvisionHistoryItem> addProvision(Map<String, dynamic> body) async {
    try {
      return await _api.createProvision(body);
    } catch (e) {
      debugPrint('ScheduleRepository addProvision error: $e');
      rethrow;
    }
  }

  /// Deletes a provision entry
  Future<void> deleteProvision(String id) async {
    try {
      await _api.deleteProvision(id);
    } catch (e) {
      debugPrint('ScheduleRepository deleteProvision error: $e');
      rethrow;
    }
  }

  /// Fetches trip issues for a schedule
  Future<List<TripIssueItem>> fetchTripIssues(String scheduleId) async {
    try {
      return await _api.getTripIssues(scheduleId);
    } catch (e) {
      debugPrint('ScheduleRepository fetchTripIssues error: $e');
      return [];
    }
  }

  /// Adds a new trip issue
  Future<TripIssueItem> addTripIssue(Map<String, dynamic> body) async {
    try {
      return await _api.createTripIssue(body);
    } catch (e) {
      debugPrint('ScheduleRepository addTripIssue error: $e');
      rethrow;
    }
  }

  /// Deletes a trip issue
  Future<void> deleteTripIssue(String id) async {
    try {
      await _api.deleteTripIssue(id);
    } catch (e) {
      debugPrint('ScheduleRepository deleteTripIssue error: $e');
      rethrow;
    }
  }

  /// Fetches paginated ports via GET /api/v1/ports?page=1&limit=10
  Future<PaginatedPortResult> fetchPorts({
    int page = 1,
    int limit = 10,
    String? search,
  }) async {
    try {
      return await _api.getPorts(
        page: page,
        limit: limit,
        search: search,
      );
    } catch (e) {
      debugPrint('ScheduleRepository fetchPorts error: $e');
      rethrow;
    }
  }

  /// Fetches paginated medical personnel via GET /api/v1/medical-personnel
  Future<PaginatedPersonnelResult> fetchMedicalPersonnel({
    required String type,
    int page = 1,
    int limit = 10,
    String? search,
  }) async {
    try {
      return await _api.getMedicalPersonnel(
        type: type,
        page: page,
        limit: limit,
        search: search,
      );
    } catch (e) {
      debugPrint('ScheduleRepository fetchMedicalPersonnel error: $e');
      rethrow;
    }
  }

  /// Fetches paginated crews via GET /api/v1/crews
  Future<PaginatedCrewResult> fetchCrews({
    int page = 1,
    int limit = 10,
    String? search,
  }) async {
    try {
      return await _api.getCrews(
        page: page,
        limit: limit,
        search: search,
      );
    } catch (e) {
      debugPrint('ScheduleRepository fetchCrews error: $e');
      rethrow;
    }
  }

  /// Fetches paginated poliklinik via GET /api/v1/poliklinik
  Future<PaginatedPoliklinikResult> fetchPoliklinik({
    int page = 1,
    int limit = 10,
    String? search,
  }) async {
    try {
      return await _api.getPoliklinik(
        page: page,
        limit: limit,
        search: search,
      );
    } catch (e) {
      debugPrint('ScheduleRepository fetchPoliklinik error: $e');
      rethrow;
    }
  }
}

final scheduleApiProvider = Provider<ScheduleApi>((ref) => ScheduleApi());

final scheduleRepositoryProvider = Provider<ScheduleRepository>((ref) {
  final api = ref.watch(scheduleApiProvider);
  return ScheduleRepository(api);
});

class TripDetailNotifier extends StateNotifier<AsyncValue<JadwalPerjalanan>> {
  TripDetailNotifier(this._repository, this._initial)
      : super(AsyncValue.data(_initial)) {
    load();
  }

  final ScheduleRepository _repository;
  final JadwalPerjalanan _initial;

  Future<void> load() async {
    try {
      var schedule = await _repository.fetchScheduleById(_initial.id);
      final schedCode =
          schedule.code.isNotEmpty ? schedule.code : _initial.code;

      List<ProvisionHistoryItem> provisions = [];
      if (schedCode.isNotEmpty) {
        provisions = await _repository.fetchProvisionsHistory(schedCode);
      }

      final issues = await _repository.fetchTripIssues(schedule.id);

      schedule = schedule.copyWith(
        provisions: provisions,
        tripIssues: issues,
      );

      state = AsyncValue.data(schedule);
    } catch (e, st) {
      debugPrint('TripDetailNotifier load error: $e');
      if (!mounted) return;
      if (!state.hasValue) {
        state = AsyncValue.error(e, st);
      }
    }
  }

  Future<void> refresh() async => load();

  Future<void> addProvision({
    required double fuelOil,
    required double water,
    double? lat,
    double? lng,
    String? scheduleCode,
  }) async {
    final current = state.valueOrNull ?? _initial;
    final schedCode = (scheduleCode != null && scheduleCode.isNotEmpty)
        ? scheduleCode
        : (current.scheduleCode.isNotEmpty
            ? current.scheduleCode
            : (current.code.isNotEmpty ? current.code : _initial.code));
    final body = <String, dynamic>{
      'schedule_code': schedCode,
      'fuel_oil': fuelOil % 1 == 0 ? fuelOil.toInt() : fuelOil,
      'water': water % 1 == 0 ? water.toInt() : water,
      'lat': ?lat,
      'lng': ?lng,
    };
    debugPrint('ScheduleRepository [POST /api/v1/ship-provisions-history] body: $body');
    await _repository.addProvision(body);
    await refresh();
  }

  Future<void> deleteProvision(String id) async {
    await _repository.deleteProvision(id);
    await refresh();
  }

  Future<void> addTripIssue({
    required String description,
    required DateTime occurredAt,
    String? occurredAtTz,
    double? lat,
    double? lng,
  }) async {
    final current = state.valueOrNull ?? _initial;
    final body = {
      'schedule_id': current.id,
      'description': description,
      'occurred_at': occurredAt.toIso8601String(),
      'occurred_at_tz': ?occurredAtTz,
      'lat': ?lat,
      'lng': ?lng,
    };
    await _repository.addTripIssue(body);
    await refresh();
  }

  Future<void> deleteTripIssue(String id) async {
    await _repository.deleteTripIssue(id);
    await refresh();
  }

  Future<void> updateSchedule(Map<String, dynamic> body) async {
    final current = state.valueOrNull ?? _initial;
    final updated = await _repository.updateSchedule(current.id, body);
    state = AsyncValue.data(updated);
    await refresh();
  }
}

final tripDetailNotifierProvider = StateNotifierProvider.autoDispose
    .family<TripDetailNotifier, AsyncValue<JadwalPerjalanan>, JadwalPerjalanan>(
  (ref, initial) {
    final repo = ref.watch(scheduleRepositoryProvider);
    return TripDetailNotifier(repo, initial);
  },
);

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
