import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_config.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/offline/outbox_entry.dart';
import '../../../core/offline/sync_service.dart';
import '../../../core/utils/ship_code_helper.dart';
import '../../auth/domain/user_role.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../patients/domain/doctor.dart';
import '../../sync/presentation/sync_providers.dart';
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

  /// Updates a provision entry
  Future<ProvisionHistoryItem> updateProvision(String id, Map<String, dynamic> body) async {
    try {
      return await _api.updateProvision(id, body);
    } catch (e) {
      debugPrint('ScheduleRepository updateProvision error: $e');
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

  /// Updates a trip issue
  Future<TripIssueItem> updateTripIssue(String id, Map<String, dynamic> body) async {
    try {
      return await _api.updateTripIssue(id, body);
    } catch (e) {
      debugPrint('ScheduleRepository updateTripIssue error: $e');
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
  /// Fetches schedule status counters from the dedicated counter API
  Future<ScheduleCounter> fetchScheduleCounter(String shipCode) async {
    try {
      return await _api.getScheduleCounter(shipCode);
    } catch (e) {
      debugPrint('ScheduleRepository fetchScheduleCounter error: $e');
      rethrow;
    }
  }
}

final scheduleApiProvider = Provider<ScheduleApi>((ref) => ScheduleApi());

/// Harbors to pick for a visit ("Pelabuhan"), from GET /api/v1/ports.
final portsProvider = FutureProvider<List<PortItem>>((ref) async {
  final result = await ref.watch(scheduleApiProvider).getPorts(limit: 100);
  return result.items;
});

final scheduleRepositoryProvider = Provider<ScheduleRepository>((ref) {
  final api = ref.watch(scheduleApiProvider);
  return ScheduleRepository(api);
});

/// The trips the logged-in user is assigned to (Koordinator), newest first.
final assignedTripsProvider =
    FutureProvider.autoDispose<List<JadwalPerjalanan>>((ref) {
  return ref.watch(scheduleApiProvider).getAssignedSchedules();
});

/// The assigned trip a Koordinator works on; see [currentAssignedTrip].
final assignedTripProvider =
    FutureProvider.autoDispose<JadwalPerjalanan?>((ref) async {
  return currentAssignedTrip(await ref.watch(assignedTripsProvider.future));
});

/// The ongoing trip of this ship when a visit form opens. Null when no trip
/// is under way. For a Koordinator: the ongoing trip they're assigned to,
/// whichever ship it is.
final ongoingTripProvider =
    FutureProvider.autoDispose<JadwalPerjalanan?>((ref) async {
  final role = ref.watch(authControllerProvider).session?.user.role;
  if (role == UserRole.koordinator) {
    final trips = await ref.watch(assignedTripsProvider.future);
    return trips.where((t) => t.isOngoing).firstOrNull;
  }
  final shipCode = await resolveLocalStorageShipCode(ref);
  if (shipCode.isEmpty) return null;
  // Same request as the schedule list, so it also works offline.
  final result = await ref
      .watch(scheduleRepositoryProvider)
      .fetchPaginatedSchedules(shipCode: shipCode, search: '', status: 'Semua');
  return result.items.where((t) => t.isOngoing).firstOrNull;
});

/// The harbor a new visit is recorded at: where the ongoing trip is when the
/// form opens. Null when no trip is under way.
final currentPortProvider =
    FutureProvider.autoDispose<ScheduleStop?>((ref) async {
  final trip = await ref.watch(ongoingTripProvider.future);
  final stop = trip?.currentStop(DateTime.now());
  return stop == null || stop.portId.isEmpty ? null : stop;
});

/// The doctors on the ongoing trip: the ones a visit outside Poli Umum can
/// be assigned to, and the ones told about a Poli Umum visit.
final tripDoctorsProvider =
    FutureProvider.autoDispose<List<Doctor>>((ref) async {
  final trip = await ref.watch(ongoingTripProvider.future);
  return [
    for (final d in trip?.doctorStaff ?? const <SchedulePersonnelItem>[])
      if (d.id.isNotEmpty)
        Doctor(id: d.id, nama: d.name, spesialisasi: d.specialization, online: true),
  ];
});

/// The clinics open on the ongoing trip: the ones a new patient's first visit
/// can go to. Deactivated or deleted clinics are left out.
final tripClinicsProvider =
    FutureProvider.autoDispose<List<PoliklinikItem>>((ref) async {
  final trip = await ref.watch(ongoingTripProvider.future);
  return [
    for (final c in trip?.clinics ?? const <ScheduleClinicItem>[])
      if (c.poliActive && c.poliCode.isNotEmpty)
        PoliklinikItem(id: c.poliId, code: c.poliCode, name: c.poliName),
  ];
});

/// The clinics a visit can go to, from GET /api/v1/poliklinik; the standard
/// list when the server can't be reached.
final poliklinikOptionsProvider =
    FutureProvider<List<PoliklinikItem>>((ref) async {
  try {
    final result = await ref
        .watch(scheduleRepositoryProvider)
        .fetchPoliklinik(limit: 200);
    final items = result.items.where((p) => p.code.isNotEmpty).toList();
    if (items.isNotEmpty) return items;
  } catch (_) {}
  return defaultPoliklinik;
});

/// Provides stable counter data fetched from GET /api/v1/schedules/ship/:shipCode/counter.
final scheduleCounterProvider = FutureProvider.autoDispose<ScheduleCounter>((ref) async {
  final shipCode = await resolveLocalStorageShipCode(ref);
  // No ship yet: nothing to count.
  if (shipCode.isEmpty) return const ScheduleCounter();
  final repo = ref.watch(scheduleRepositoryProvider);
  return repo.fetchScheduleCounter(shipCode);
});

class TripDetailNotifier extends StateNotifier<AsyncValue<JadwalPerjalanan>> {
  TripDetailNotifier(this._repository, this._initial, [this._sync])
      : super(AsyncValue.data(_initial)) {
    // Queued logistics reached the server: show the server's version.
    _synced = _sync?.onSynced.listen((_) => load());
    load();
  }

  final ScheduleRepository _repository;
  final JadwalPerjalanan _initial;

  /// Keeps the logistics written offline (provisions, trip issues).
  final SyncService? _sync;
  StreamSubscription<void>? _synced;

  /// The trip as last fetched, before the queued changes are applied.
  JadwalPerjalanan? _fetched;

  @override
  void dispose() {
    _synced?.cancel();
    super.dispose();
  }

  Future<void> load() async {
    try {
      // The three requests are independent, so run them in parallel. Provisions
      // are keyed by schedule code, which the list item already carries.
      final scheduleFuture = _repository.fetchScheduleById(_initial.id);
      final provisionsFuture = _initial.code.isNotEmpty
          ? _repository.fetchProvisionsHistory(_initial.code)
          : Future.value(<ProvisionHistoryItem>[]);
      final issuesFuture = _repository.fetchTripIssues(_initial.id);

      // `.wait` handles every future's error, so none goes unobserved.
      var (schedule, provisions, issues) =
          await (scheduleFuture, provisionsFuture, issuesFuture).wait;

      // Fall back to the fetched code if it's missing or differs locally.
      final schedCode =
          schedule.code.isNotEmpty ? schedule.code : _initial.code;
      if (schedCode != _initial.code && schedCode.isNotEmpty) {
        provisions = await _repository.fetchProvisionsHistory(schedCode);
      }

      _fetched = schedule.copyWith(
        provisions: provisions,
        tripIssues: issues,
      );
    } catch (e) {
      debugPrint('TripDetailNotifier load error: $e');
    }
    // Offline the fetched trip is the cached one (or the list item): the
    // changes still in the outbox are shown on top of it.
    final shown = await _withQueued(_fetched ?? _initial);
    if (!mounted) return;
    state = AsyncValue.data(shown);
  }

  /// [trip] with the provisions and trip issues still waiting in the outbox
  /// added, changed or removed.
  Future<JadwalPerjalanan> _withQueued(JadwalPerjalanan trip) async {
    final sync = _sync;
    if (sync == null) return trip;
    final queued = [
      for (final e in await sync.entries())
        if (e.status == OutboxStatus.pending) e,
    ];
    if (queued.isEmpty) return trip;

    final code = trip.code.isNotEmpty ? trip.code : _initial.code;
    final id = trip.id.isNotEmpty ? trip.id : _initial.id;
    final provisions = _applyQueued(
      trip.provisions,
      queued,
      basePath: ApiConfig.shipProvisionsHistoryPath,
      isOfTrip: (body) => body['schedule_code'] == code,
      toJson: (p) => p.toJson(),
      fromJson: ProvisionHistoryItem.fromJson,
      idOf: (p) => p.id,
    );
    final issues = _applyQueued(
      trip.tripIssues,
      queued,
      basePath: ApiConfig.tripIssuesPath,
      isOfTrip: (body) => body['schedule_id'] == id,
      toJson: (i) => i.toJson(),
      fromJson: TripIssueItem.fromJson,
      idOf: (i) => i.id,
    );
    return trip.copyWith(provisions: provisions, tripIssues: issues);
  }

  /// [items] after the queued writes to [basePath], oldest first: a POST
  /// adds an item on top (its entry id stands for the server id until it is
  /// sent), a PUT changes one, a DELETE removes one.
  static List<T> _applyQueued<T>(
    List<T> items,
    List<OutboxEntry> queued, {
    required String basePath,
    required bool Function(Map<String, dynamic> body) isOfTrip,
    required Map<String, dynamic> Function(T item) toJson,
    required T Function(Map<String, dynamic> json) fromJson,
    required String Function(T item) idOf,
  }) {
    var result = [...items];
    for (final entry in queued) {
      final body = entry.body ?? const <String, dynamic>{};
      if (entry.path == basePath) {
        if (entry.method == 'POST' && isOfTrip(body)) {
          result.insert(
            0,
            fromJson({
              ...body,
              'id': entry.id,
              'created_at': entry.createdAt.toUtc().toIso8601String(),
            }),
          );
        }
        continue;
      }
      if (!entry.path.startsWith('$basePath/')) continue;
      final itemId = entry.path.substring(basePath.length + 1);
      if (entry.method == 'DELETE') {
        result = [for (final i in result) if (idOf(i) != itemId) i];
      } else if (entry.method == 'PUT') {
        result = [
          for (final i in result)
            idOf(i) == itemId ? fromJson({...toJson(i), ...body}) : i,
        ];
      }
    }
    return result;
  }

  /// Sends a logistics write, or keeps it in the outbox while the server
  /// can't be reached (or earlier writes still wait there). [localId] names a
  /// new item until the server gives it its id. Returns true when kept.
  Future<bool> _sendOrQueue({
    required String method,
    required String path,
    required String label,
    Map<String, dynamic>? body,
    String? localId,
    required Future<void> Function() send,
  }) async {
    final sync = _sync;
    Future<bool> queue() async {
      await sync!.enqueue(
        method: method,
        path: path,
        label: label,
        body: body,
        id: localId,
        produces: {?localId: 'result.id'},
      );
      return true;
    }

    if (sync != null && await sync.hasPending()) return queue();
    try {
      await send();
      return false;
    } on ApiException catch (e) {
      if (sync == null || !e.isOffline) rethrow;
      return queue();
    }
  }

  Future<void> refresh() async => load();

  /// Returns true when kept offline (see [_sendOrQueue]), as do the other
  /// logistics writes.
  Future<bool> addProvision({
    required double fuelOil,
    required double water,
    String type = 'sisa',
    double? fuelOilAdded,
    double? waterAdded,
    String? notes,
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
      'type': type,
      'fuel_oil': fuelOil % 1 == 0 ? fuelOil.toInt() : fuelOil,
      'water': water % 1 == 0 ? water.toInt() : water,
      if (fuelOilAdded != null)
        'fuel_oil_added': fuelOilAdded % 1 == 0 ? fuelOilAdded.toInt() : fuelOilAdded,
      if (waterAdded != null)
        'water_added': waterAdded % 1 == 0 ? waterAdded.toInt() : waterAdded,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
      'lat': ?lat,
      'lng': ?lng,
    };
    debugPrint('ScheduleRepository [POST /api/v1/ship-provisions-history] body: $body');
    final savedOffline = await _sendOrQueue(
      method: 'POST',
      path: ApiConfig.shipProvisionsHistoryPath,
      label: type == 'tambah' ? 'Pengisian BBM & air' : 'Sisa BBM & air',
      body: body,
      localId: SyncService.newId(),
      send: () => _repository.addProvision(body),
    );
    await refresh();
    return savedOffline;
  }

  Future<bool> deleteProvision(String id) async {
    final savedOffline = await _sendOrQueue(
      method: 'DELETE',
      path: '${ApiConfig.shipProvisionsHistoryPath}/$id',
      label: 'Hapus catatan BBM & air',
      send: () => _repository.deleteProvision(id),
    );
    await refresh();
    return savedOffline;
  }

  Future<bool> updateProvision({
    required String id,
    required double fuelOil,
    required double water,
    double? lat,
    double? lng,
    String? type,
    double? fuelOilAdded,
    double? waterAdded,
    String? notes,
  }) async {
    final body = <String, dynamic>{
      'fuel_oil': fuelOil % 1 == 0 ? fuelOil.toInt() : fuelOil,
      'water': water % 1 == 0 ? water.toInt() : water,
      'type': ?type,
      if (fuelOilAdded != null)
        'fuel_oil_added': fuelOilAdded % 1 == 0 ? fuelOilAdded.toInt() : fuelOilAdded,
      if (waterAdded != null)
        'water_added': waterAdded % 1 == 0 ? waterAdded.toInt() : waterAdded,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
      'lat': ?lat,
      'lng': ?lng,
    };
    debugPrint('ScheduleRepository [PUT /api/v1/ship-provisions-history/$id] body: $body');
    final savedOffline = await _sendOrQueue(
      method: 'PUT',
      path: '${ApiConfig.shipProvisionsHistoryPath}/$id',
      label: 'Ubah catatan BBM & air',
      body: body,
      send: () => _repository.updateProvision(id, body),
    );
    await refresh();
    return savedOffline;
  }

  static String _formatRfc3339(DateTime dt) {
    final offset = dt.timeZoneOffset;
    final hours = offset.inHours.abs().toString().padLeft(2, '0');
    final minutes = (offset.inMinutes.abs() % 60).toString().padLeft(2, '0');
    final sign = offset.isNegative ? '-' : '+';
    final offsetStr = '$sign$hours:$minutes';

    final year = dt.year.toString().padLeft(4, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final day = dt.day.toString().padLeft(2, '0');
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    final second = dt.second.toString().padLeft(2, '0');

    return '$year-$month-${day}T$hour:$minute:$second$offsetStr';
  }

  Future<bool> addTripIssue({
    required String description,
    required DateTime occurredAt,
    String? scheduleId,
    double? lat,
    double? lng,
  }) async {
    final current = state.valueOrNull ?? _initial;
    final schedId = (scheduleId != null && scheduleId.isNotEmpty)
        ? scheduleId
        : (current.id.isNotEmpty ? current.id : _initial.id);
    final body = <String, dynamic>{
      'schedule_id': schedId,
      'description': description,
      'occurred_at': _formatRfc3339(occurredAt),
      'lat': ?lat,
      'lng': ?lng,
    };
    debugPrint('ScheduleRepository [POST /api/v1/trip-issues] body: $body');
    final savedOffline = await _sendOrQueue(
      method: 'POST',
      path: ApiConfig.tripIssuesPath,
      label: 'Kendala perjalanan: $description',
      body: body,
      localId: SyncService.newId(),
      send: () => _repository.addTripIssue(body),
    );
    await refresh();
    return savedOffline;
  }

  Future<bool> updateTripIssue({
    required String id,
    required String description,
    required DateTime occurredAt,
    double? lat,
    double? lng,
  }) async {
    final body = <String, dynamic>{
      'description': description,
      'occurred_at': _formatRfc3339(occurredAt),
      'lat': ?lat,
      'lng': ?lng,
    };
    debugPrint('ScheduleRepository [PUT /api/v1/trip-issues/$id] body: $body');
    final savedOffline = await _sendOrQueue(
      method: 'PUT',
      path: '${ApiConfig.tripIssuesPath}/$id',
      label: 'Ubah kendala perjalanan',
      body: body,
      send: () => _repository.updateTripIssue(id, body),
    );
    await refresh();
    return savedOffline;
  }

  Future<bool> deleteTripIssue(String id) async {
    final savedOffline = await _sendOrQueue(
      method: 'DELETE',
      path: '${ApiConfig.tripIssuesPath}/$id',
      label: 'Hapus kendala perjalanan',
      send: () => _repository.deleteTripIssue(id),
    );
    await refresh();
    return savedOffline;
  }

  Future<void> updateSchedule(Map<String, dynamic> body) async {
    final current = state.valueOrNull ?? _initial;
    final updated = await _repository.updateSchedule(current.id, body);
    // The save succeeded; if the screen closed meanwhile there's nothing to update.
    if (!mounted) return;
    state = AsyncValue.data(updated);
    await refresh();
  }
}

final tripDetailNotifierProvider = StateNotifierProvider.autoDispose
    .family<TripDetailNotifier, AsyncValue<JadwalPerjalanan>, JadwalPerjalanan>(
  (ref, initial) {
    final repo = ref.watch(scheduleRepositoryProvider);
    return TripDetailNotifier(repo, initial, ref.watch(syncServiceProvider));
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
  bool _hasMore = false;
  bool _isLoadingMore = false;
  String? _resolvedShipCode;
  String _searchQuery = '';
  String _statusFilter = 'Semua';
  int _totalCount = 0;
  // Bumped by every page-1 load/refresh. Older responses (including an
  // in-flight loadMore) are dropped so they can't overwrite newer results.
  int _requestSeq = 0;

  bool get hasMore => _hasMore;
  bool get isLoadingMore => _isLoadingMore;
  int get currentPage => _currentPage;
  String get searchQuery => _searchQuery;
  String get statusFilter => _statusFilter;
  int get totalCount => _totalCount;

  Future<String> _getShipCode() async {
    final code = await resolveLocalStorageShipCode(_ref);
    // Shown on the schedule screen's error state.
    if (code.isEmpty) throw Exception(noActiveShipMessage);
    _resolvedShipCode = code;
    return code;
  }

  Future<void> load({
    String? search,
    String? status,
  }) async {
    final seq = ++_requestSeq;
    state = const AsyncValue.loading();
    _currentPage = 1;
    if (search != null) _searchQuery = search;
    if (status != null) _statusFilter = status;
    try {
      final shipCode = await _getShipCode();
      final result = await _repository.fetchPaginatedSchedules(
        shipCode: shipCode,
        search: _searchQuery,
        status: _statusFilter,
      );
      if (seq != _requestSeq || !mounted) return;
      _hasMore = result.hasMore;
      _totalCount = result.total;
      state = AsyncValue.data(result.items);
    } catch (e, st) {
      if (seq != _requestSeq || !mounted) return;
      state = AsyncValue.error(e, st);
    }
  }

  /// Requests the list's first page as it opens (no search, every status),
  /// only so the offline cache has it; the list shown doesn't change.
  Future<List<JadwalPerjalanan>> warmCache() async {
    final result = await _repository.fetchPaginatedSchedules(
      shipCode: await _getShipCode(),
      search: '',
      status: 'Semua',
    );
    return result.items;
  }

  Future<void> refresh() async {
    final seq = ++_requestSeq;
    _currentPage = 1;
    try {
      final shipCode = await _getShipCode();
      final result = await _repository.fetchPaginatedSchedules(
        shipCode: shipCode,
        search: _searchQuery,
        status: _statusFilter,
      );
      if (seq != _requestSeq || !mounted) return;
      _hasMore = result.hasMore;
      _totalCount = result.total;
      state = AsyncValue.data(result.items);
    } catch (e, st) {
      if (seq != _requestSeq || !mounted) return;
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
    final seq = _requestSeq;
    _isLoadingMore = true;
    try {
      final nextPage = _currentPage + 1;
      final shipCode = _resolvedShipCode ?? await _getShipCode();
      final result = await _repository.fetchPaginatedSchedules(
        shipCode: shipCode,
        page: nextPage,
        search: _searchQuery,
        status: _statusFilter,
      );
      // The list was reset (search/filter/refresh) while this page loaded.
      if (seq != _requestSeq || !mounted) return;
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
      // Skip when a newer load owns the state (it may still be loading).
      if (mounted && seq == _requestSeq) {
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
