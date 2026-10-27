import 'package:bayan_rme/core/network/api_exception.dart';
import 'package:bayan_rme/features/nurse/data/today_stats_api.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/offline_fakes.dart';

void main() {
  test(
    'asks for the device day and ship, and reads the three counts',
    () async {
      final server = FakeServerAdapter(
        (_) => (
          status: 200,
          body: {
            'result': {'patients': 4, 'waiting': 2, 'visits': 5},
          },
        ),
      );
      final now = DateTime(2026, 10, 27, 14, 30);

      final stats = await TodayStatsApi(
        dio: fakeDio(server),
      ).fetch(now: now, shipId: 'ship-1');

      final request = server.seen.single.options;
      expect(
        '${request.method} ${request.path}',
        'GET /api/v1/dashboard/today-stats',
      );
      expect(request.queryParameters, {
        'from': DateTime(2026, 10, 27).toUtc().toIso8601String(),
        'to': DateTime(2026, 10, 28).toUtc().toIso8601String(),
        'ship_id': 'ship-1',
      });
      expect([stats.patients, stats.waiting, stats.visits], [4, 2, 5]);
    },
  );

  test('leaves out ship_id when the account has no ship', () async {
    final server = FakeServerAdapter(
      (_) => (status: 200, body: {'result': {}}),
    );

    final stats = await TodayStatsApi(
      dio: fakeDio(server),
    ).fetch(now: DateTime(2026, 10, 27));

    expect(
      server.seen.single.options.queryParameters.containsKey('ship_id'),
      isFalse,
    );
    expect([stats.patients, stats.waiting, stats.visits], [0, 0, 0]);
  });

  test('a failure surfaces as an ApiException', () async {
    final server = FakeServerAdapter((_) => null);

    expect(
      () => TodayStatsApi(
        dio: fakeDio(server),
      ).fetch(now: DateTime(2026, 10, 27)),
      throwsA(isA<ApiException>()),
    );
  });
}
