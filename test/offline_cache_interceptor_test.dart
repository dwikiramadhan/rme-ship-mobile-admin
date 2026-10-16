import 'package:bayan_rme/core/offline/http_cache.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/offline_fakes.dart';

void main() {
  late InMemoryHttpCache cache;
  late FakeServerAdapter server;
  late Dio dio;

  setUp(() {
    cache = InMemoryHttpCache();
    server = FakeServerAdapter((_) => (status: 200, body: {'result': ['Budi']}));
    dio = fakeDio(server)..interceptors.add(OfflineCacheInterceptor(cache));
  });

  test('offline, a GET returns the last response it got online', () async {
    await dio.get<dynamic>('/api/v1/patients', queryParameters: {'page': 1});

    server.handler = (_) => null;
    final res = await dio.get<dynamic>(
      '/api/v1/patients',
      queryParameters: {'page': 1},
    );

    expect(res.data, {'result': ['Budi']});
    expect(res.extra['fromCache'], isTrue);
  });

  test('each query is cached on its own', () async {
    await dio.get<dynamic>('/api/v1/patients', queryParameters: {'page': 1});
    server.handler = (_) => null;

    expect(
      () => dio.get<dynamic>('/api/v1/patients', queryParameters: {'page': 2}),
      throwsA(isA<DioException>()),
    );
  });

  test('writes are never cached nor answered from the cache', () async {
    await dio.post<dynamic>('/api/v1/patients', data: {'nama': 'Budi'});
    expect(cache.bodies, isEmpty);

    server.handler = (_) => null;
    expect(
      () => dio.post<dynamic>('/api/v1/patients', data: {}),
      throwsA(isA<DioException>()),
    );
  });

  test('a client error is not hidden behind the cache', () async {
    await dio.get<dynamic>('/api/v1/patients');
    server.handler = (_) => (status: 404, body: {'message': 'not found'});

    expect(
      () => dio.get<dynamic>('/api/v1/patients'),
      throwsA(isA<DioException>()),
    );
  });
}
