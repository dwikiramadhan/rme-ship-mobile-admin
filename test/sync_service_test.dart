import 'package:bayan_rme/core/offline/outbox_entry.dart';
import 'package:bayan_rme/core/offline/sync_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/offline_fakes.dart';

void main() {
  late InMemoryOutboxStore store;
  late FakeServerAdapter server;
  late SyncService sync;
  String? userId;

  setUp(() {
    store = InMemoryOutboxStore();
    server = FakeServerAdapter((_) => null); // offline until a test says so
    userId = 'nurse-1';
    sync = SyncService(
      store: store,
      dio: fakeDio(server),
      currentUserId: () async => userId,
      retryInterval: null,
    );
  });

  tearDown(() => sync.dispose());

  test('offline: writes stay queued, in order', () async {
    await sync.enqueue(method: 'POST', path: '/a', label: 'A');
    await sync.enqueue(method: 'POST', path: '/b', label: 'B');
    await sync.syncNow();

    expect(store.rows.map((e) => e.path), ['/a', '/b']);
    expect(await sync.hasPending(), isTrue);
    expect(sync.status.pending, 2);
  });

  test('online: sends oldest first with an Idempotency-Key, then empties', () async {
    final first = await sync.enqueue(method: 'POST', path: '/a', label: 'A');
    await sync.enqueue(method: 'PUT', path: '/b', label: 'B', body: {'x': 1});

    server.handler = (_) => (status: 200, body: {'status': 'success'});
    server.seen.clear();
    await sync.syncNow();

    expect(server.seen.map((r) => '${r.method} ${r.path}'), ['POST /a', 'PUT /b']);
    expect(server.seen.first.options.headers['Idempotency-Key'], first.id);
    expect(store.rows, isEmpty);
    expect(sync.status.pending, 0);
  });

  test('a local id is replaced by the server id in later entries', () async {
    await sync.enqueue(
      method: 'POST',
      path: '/api/v1/patients',
      label: 'Pasien baru',
      body: {'id': 'local-123', 'nama': 'Budi'},
      produces: {'local-123': 'result.id'},
    );
    await sync.enqueue(
      method: 'POST',
      path: '/api/v1/patients/local-123/medical-records',
      label: 'Kunjungan',
      body: {'patient_ref': 'local-123'},
    );

    server.handler = (r) => r.path == '/api/v1/patients'
        ? (status: 201, body: {'result': {'id': 'srv-9'}})
        : (status: 201, body: {});
    server.seen.clear();
    await sync.syncNow();

    expect(server.seen.last.path, '/api/v1/patients/srv-9/medical-records');
    expect(server.seen.last.data, {'patient_ref': 'srv-9'});
    expect(store.rows, isEmpty);
  });

  test('a rejected entry is kept as failed and the rest still sync', () async {
    await sync.enqueue(method: 'POST', path: '/bad', label: 'Bad');
    await sync.enqueue(method: 'POST', path: '/good', label: 'Good');

    server.handler = (r) => r.path == '/bad'
        ? (status: 422, body: {'message': 'NIK sudah terdaftar'})
        : (status: 200, body: {});
    await sync.syncNow();

    expect(store.rows, hasLength(1));
    expect(store.rows.single.status, OutboxStatus.failed);
    expect(store.rows.single.lastError, 'NIK sudah terdaftar');
    expect(sync.status.failed, 1);
    // A failed entry doesn't force new writes into the queue.
    expect(await sync.hasPending(), isFalse);
  });

  test('a server error stops the round and keeps the order', () async {
    await sync.enqueue(method: 'POST', path: '/a', label: 'A');
    await sync.enqueue(method: 'POST', path: '/b', label: 'B');
    await sync.syncNow(); // let the offline rounds started by enqueue finish

    server.handler = (_) => (status: 503, body: {});
    server.seen.clear();
    await sync.syncNow();

    expect(server.seen.map((r) => r.path), ['/a']);
    expect(store.rows.map((e) => e.status), everyElement(OutboxStatus.pending));
  });

  test('only the user who queued an entry sends it', () async {
    await sync.enqueue(method: 'POST', path: '/a', label: 'A');
    await sync.syncNow(); // let the offline round started by enqueue finish
    userId = 'doctor-2';
    server.handler = (_) => (status: 200, body: {});
    server.seen.clear();
    await sync.syncNow();

    expect(server.seen, isEmpty);
    expect(store.rows, hasLength(1));
  });

  test('a failed entry can be retried or discarded', () async {
    final entry = await sync.enqueue(method: 'POST', path: '/a', label: 'A');
    server.handler = (_) => (status: 400, body: {'message': 'invalid'});
    await sync.syncNow();
    expect(store.rows.single.status, OutboxStatus.failed);

    server.handler = (_) => (status: 200, body: {});
    await sync.retry(entry.id);
    await sync.syncNow();
    expect(store.rows, isEmpty);

    final other = await sync.enqueue(method: 'POST', path: '/b', label: 'B');
    await sync.discard(other.id);
    expect(store.rows, isEmpty);
  });
}
