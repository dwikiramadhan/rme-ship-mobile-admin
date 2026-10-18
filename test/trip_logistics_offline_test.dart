import 'dart:io';

import 'package:bayan_rme/core/offline/http_cache.dart';
import 'package:bayan_rme/core/offline/sync_service.dart';
import 'package:bayan_rme/features/schedule/data/schedule_api.dart';
import 'package:bayan_rme/features/schedule/domain/trip_schedule.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/offline_fakes.dart';

final _trip = JadwalPerjalanan.fromApiJson(const {
  'id': 'sch-1',
  'code': 'SCH-1',
});

/// The trip's server data: one provision record and one trip issue.
({int status, Object? body})? _online(SeenRequest r) => switch ((
  r.method,
  r.path,
)) {
  ('GET', '/api/v1/schedules/sch-1') => (
    status: 200,
    body: {
      'result': {'id': 'sch-1', 'code': 'SCH-1'},
    },
  ),
  ('GET', '/api/v1/ship-provisions-history/schedule/SCH-1') => (
    status: 200,
    body: {
      'result': [
        {
          'id': 'prov-1',
          'schedule_code': 'SCH-1',
          'fuel_oil': 900,
          'water': 400,
        },
      ],
    },
  ),
  ('GET', '/api/v1/trip-issues') => (
    status: 200,
    body: {
      'result': [
        {'id': 'iss-1', 'schedule_id': 'sch-1', 'description': 'Mesin panas'},
      ],
    },
  ),
  ('POST', _) => (
    status: 201,
    body: {
      'result': {'id': 'srv-new'},
    },
  ),
  _ => (status: 200, body: {'result': {}}),
};

void main() {
  late FakeServerAdapter server;
  late ScheduleRepository repository;
  late InMemoryOutboxStore store;
  late SyncService sync;
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('trip_test');
    server = FakeServerAdapter(_online);
    final dio = fakeDio(server)
      ..interceptors.add(OfflineCacheInterceptor(InMemoryHttpCache()));
    repository = ScheduleRepository(ScheduleApi(dio: dio));
    store = InMemoryOutboxStore();
    sync = SyncService(
      store: store,
      dio: fakeDio(server),
      currentUserId: () async => 'admin-1',
      filesDir: () async => tempDir,
      retryInterval: null,
    );
  });

  tearDown(() async {
    sync.dispose();
    await tempDir.delete(recursive: true);
  });

  /// The trip detail, loaded once online, then the connection drops.
  Future<TripDetailNotifier> openedThenOffline() async {
    final trip = TripDetailNotifier(repository, _trip, sync);
    addTearDown(trip.dispose);
    await trip.load();
    server.handler = (_) => null;
    return trip;
  }

  /// What the trip detail shows now.
  JadwalPerjalanan shown(TripDetailNotifier trip) {
    late JadwalPerjalanan value;
    trip.addListener((s) => value = s.value!)(); // fires right away
    return value;
  }

  List<ProvisionHistoryItem> provisionsOf(TripDetailNotifier trip) =>
      shown(trip).provisions;

  test('offline: a new provision record is queued and shown on top', () async {
    final trip = await openedThenOffline();

    final savedOffline = await trip.addProvision(fuelOil: 850, water: 380);

    expect(savedOffline, isTrue);
    expect(store.rows.single.path, '/api/v1/ship-provisions-history');
    expect(store.rows.single.label, 'Sisa BBM & air');
    expect(provisionsOf(trip).map((p) => p.fuelOil), [850, 900]);
  });

  test(
    'offline: a new record can be edited; sent under the server id later',
    () async {
      final trip = await openedThenOffline();
      await trip.addProvision(fuelOil: 850, water: 380);
      final localId = provisionsOf(trip).first.id;

      await trip.updateProvision(id: localId, fuelOil: 800, water: 380);
      expect(provisionsOf(trip).map((p) => p.fuelOil), [800, 900]);

      server.handler = _online;
      server.seen.clear();
      await sync.syncNow();
      expect(
        server.seen
            .where((r) => r.method != 'GET')
            .map((r) => '${r.method} ${r.path}'),
        [
          'POST /api/v1/ship-provisions-history',
          'PUT /api/v1/ship-provisions-history/srv-new',
        ],
      );
      expect(store.rows, isEmpty);
    },
  );

  test('offline: trip issues added and deleted show right away', () async {
    final trip = await openedThenOffline();

    await trip.addTripIssue(
      description: 'Badai',
      occurredAt: DateTime(2026, 10, 18, 9),
    );
    await trip.deleteTripIssue('iss-1');

    final issues = shown(trip).tripIssues;
    expect(issues.map((i) => i.description), ['Badai']);
    expect(store.rows.map((e) => e.method), ['POST', 'DELETE']);
  });

  test('reopened offline: the queued changes are still shown', () async {
    final first = await openedThenOffline();
    await first.addProvision(fuelOil: 850, water: 380);

    final reopened = TripDetailNotifier(repository, _trip, sync);
    addTearDown(reopened.dispose);
    await reopened.load();

    expect(provisionsOf(reopened).map((p) => p.fuelOil), [850, 900]);
  });

  test('online: written straight to the server', () async {
    final trip = TripDetailNotifier(repository, _trip, sync);
    addTearDown(trip.dispose);
    await trip.load();

    final savedOffline = await trip.addProvision(fuelOil: 850, water: 380);

    expect(savedOffline, isFalse);
    expect(store.rows, isEmpty);
  });
}
