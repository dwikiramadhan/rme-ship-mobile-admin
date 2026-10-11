import 'package:bayan_rme/core/network/ttl_cache.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('serves cached value within TTL and shares in-flight requests', () async {
    final cache = TtlCache<int>(const Duration(minutes: 5));
    var calls = 0;
    Future<int> fetch() async => ++calls;

    final results = await Future.wait([
      cache.getOrFetch('k', fetch),
      cache.getOrFetch('k', fetch),
    ]);
    expect(results, [1, 1]);
    expect(await cache.getOrFetch('k', fetch), 1);
    expect(calls, 1);
  });

  test('refetches after TTL expires', () async {
    final cache = TtlCache<int>(Duration.zero);
    var calls = 0;
    await cache.getOrFetch('k', () async => ++calls);
    await cache.getOrFetch('k', () async => ++calls);
    expect(calls, 2);
  });

  test('does not cache failures or vetoed values', () async {
    final cache = TtlCache<List<int>>(
      const Duration(minutes: 5),
      shouldCache: (v) => v.isNotEmpty,
    );
    await expectLater(
      cache.getOrFetch('k', () async => throw Exception('offline')),
      throwsException,
    );
    expect(await cache.getOrFetch('k', () async => <int>[]), isEmpty);
    expect(await cache.getOrFetch('k', () async => [7]), [7]);
    expect(await cache.getOrFetch('k', () async => [8]), [7]);
  });
}
