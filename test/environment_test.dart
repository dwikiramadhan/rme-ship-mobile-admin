import 'package:bayan_rme/features/environment/data/environment_api.dart';
import 'package:bayan_rme/features/environment/data/environment_storage.dart';
import 'package:bayan_rme/features/environment/domain/environment_item.dart';
import 'package:bayan_rme/features/environment/presentation/environment_controller.dart';
import 'package:bayan_rme/features/environment/presentation/server_connection_controller.dart';
import 'package:bayan_rme/features/environment/presentation/ship_environment_ribbon.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EnvironmentItem Domain Model', () {
    test('parses from standard backend API JSON correctly', () {
      final json = {
        'id': 'env-uuid-12345',
        'code': 'KAPAL-01',
        'name': 'KM Bayan Express 01',
        'ship_id': 'ship-uuid-999',
        'created_at': '2026-09-06T06:00:00Z',
        'updated_at': '2026-09-06T06:00:00Z',
      };

      final item = EnvironmentItem.fromJson(json);

      expect(item.id, equals('env-uuid-12345'));
      expect(item.code, equals('KAPAL-01'));
      expect(item.name, equals('KM Bayan Express 01'));
      expect(item.shipId, equals('ship-uuid-999'));
      expect(item.createdAt, equals('2026-09-06T06:00:00Z'));
      expect(item.updatedAt, equals('2026-09-06T06:00:00Z'));
    });

    test('serializes to JSON correctly', () {
      const item = EnvironmentItem(
        id: 'env-99',
        code: 'KAPAL-99',
        name: 'KM Nusantara',
        shipId: 'ship-uuid-888',
      );

      final map = item.toJson();
      expect(map['id'], equals('env-99'));
      expect(map['code'], equals('KAPAL-99'));
      expect(map['name'], equals('KM Nusantara'));
      expect(map['ship_id'], equals('ship-uuid-888'));
    });
  });

  group('EnvironmentApi', () {
    const shipA = EnvironmentItem(
      id: 'env-a',
      code: 'KAPAL-A',
      name: 'KM Alpha',
      shipId: 'ship-a',
    );

    test("asks only for the logged-in user's ship", () async {
      final queries = <Map<String, dynamic>>[];
      final dio = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              queries.add(options.queryParameters);
              handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    'result': [
                      {
                        'id': 'env-b',
                        'code': 'KAPAL-B',
                        'name': 'KM Beta',
                        'ship_id': 'ship-b',
                      },
                    ],
                  },
                ),
              );
            },
          ),
        );
      final storage = _MemoryEnvironmentStorage();
      final env = await EnvironmentApi(
        dio: dio,
        storage: storage,
      ).fetchFirstEnvironment(shipId: 'ship-b');

      expect(queries.single['ship_id'], 'ship-b');
      expect(env?.code, 'KAPAL-B');
      expect(storage.saved?.code, 'KAPAL-B');
    });

    test("offline, another ship's saved environment is not shown", () async {
      final dio = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) => handler.reject(
              DioException.connectionError(
                requestOptions: options,
                reason: 'offline',
              ),
            ),
          ),
        );
      final api = EnvironmentApi(
        dio: dio,
        storage: _MemoryEnvironmentStorage()..saved = shipA,
      );

      expect(await api.fetchFirstEnvironment(shipId: 'ship-b'), isNull);
      expect(await api.fetchFirstEnvironment(shipId: 'ship-a'), shipA);
    });
  });

  test('a user set to no ship sees no ship, not the last one saved', () async {
    var requests = 0;
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(onRequest: (options, handler) => requests++),
      );
    final storage = _MemoryEnvironmentStorage()
      ..saved = const EnvironmentItem(
        id: 'env-a',
        code: 'KAPAL-A',
        name: 'KM Alpha',
        shipId: 'ship-a',
      );
    final controller = EnvironmentController(
      EnvironmentApi(dio: dio, storage: storage),
      storage,
      withoutShip: true,
    );
    await controller.refresh();

    expect(controller.state, const AsyncValue<EnvironmentItem?>.data(null));
    expect(storage.saved, isNull);
    expect(requests, 0);
  });

  group('ShipEnvironmentRibbon Widget', () {
    testWidgets('renders active ship name and code badge when loaded', (
      tester,
    ) async {
      const testEnv = EnvironmentItem(
        id: 'env-1',
        code: 'KAPAL-01',
        name: 'KM Bayan 01',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeEnvironmentProvider.overrideWith(
              (ref) =>
                  _FakeEnvironmentController(const AsyncValue.data(testEnv)),
            ),
            serverConnectionProvider.overrideWith(
              (ref) => _FakeServerConnectionNotifier(true),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(body: ShipEnvironmentRibbon()),
          ),
        ),
      );

      expect(find.text('KAPAL:'), findsOneWidget);
      expect(find.text('KM Bayan 01'), findsOneWidget);
      expect(find.text('KAPAL-01'), findsOneWidget);
      expect(find.text('Terhubung'), findsOneWidget);
    });

    testWidgets('renders loading state when environment is being fetched', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeEnvironmentProvider.overrideWith(
              (ref) => _FakeEnvironmentController(const AsyncValue.loading()),
            ),
            serverConnectionProvider.overrideWith(
              (ref) => _FakeServerConnectionNotifier(true),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(body: ShipEnvironmentRibbon()),
          ),
        ),
      );

      expect(find.text('Memuat data kapal...'), findsOneWidget);
    });

    testWidgets('renders Disconnected status when server connection is false', (
      tester,
    ) async {
      const testEnv = EnvironmentItem(
        id: 'env-1',
        code: 'KAPAL-01',
        name: 'KM Bayan 01',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeEnvironmentProvider.overrideWith(
              (ref) =>
                  _FakeEnvironmentController(const AsyncValue.data(testEnv)),
            ),
            serverConnectionProvider.overrideWith(
              (ref) => _FakeServerConnectionNotifier(false),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(body: ShipEnvironmentRibbon()),
          ),
        ),
      );

      expect(find.text('Disconnected'), findsOneWidget);
      expect(find.text('Terhubung'), findsNothing);
    });

    testWidgets('renders Terhubung status when server connection is true', (
      tester,
    ) async {
      const testEnv = EnvironmentItem(
        id: 'env-1',
        code: 'KAPAL-01',
        name: 'KM Bayan 01',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeEnvironmentProvider.overrideWith(
              (ref) =>
                  _FakeEnvironmentController(const AsyncValue.data(testEnv)),
            ),
            serverConnectionProvider.overrideWith(
              (ref) => _FakeServerConnectionNotifier(true),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(body: ShipEnvironmentRibbon()),
          ),
        ),
      );

      expect(find.text('Terhubung'), findsOneWidget);
      expect(find.text('Disconnected'), findsNothing);
    });
  });
}

class _FakeServerConnectionNotifier extends StateNotifier<bool>
    implements ServerConnectionNotifier {
  _FakeServerConnectionNotifier(super.state);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeEnvironmentController
    extends StateNotifier<AsyncValue<EnvironmentItem?>>
    implements EnvironmentController {
  _FakeEnvironmentController(super.state);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MemoryEnvironmentStorage extends EnvironmentStorage {
  EnvironmentItem? saved;

  @override
  Future<void> save(EnvironmentItem env) async => saved = env;

  @override
  Future<EnvironmentItem?> read() async => saved;

  @override
  Future<void> clear() async => saved = null;
}
