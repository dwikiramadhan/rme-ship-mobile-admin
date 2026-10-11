import 'dart:typed_data';

import 'package:bayan_rme/core/network/dio_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Adapter that replays a scripted sequence of outcomes and counts calls.
class _ScriptedAdapter implements HttpClientAdapter {
  _ScriptedAdapter(this._outcomes);

  final List<Object> _outcomes; // int status code, or DioExceptionType
  int calls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final outcome = _outcomes[calls.clamp(0, _outcomes.length - 1)];
    calls++;
    if (outcome is DioExceptionType) {
      throw DioException(requestOptions: options, type: outcome);
    }
    return ResponseBody.fromString(
      '{}',
      outcome as int,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Dio _dioWith(_ScriptedAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'http://test'))..httpClientAdapter = adapter;
  dio.interceptors.add(RetryInterceptor(dio, baseDelay: Duration.zero));
  return dio;
}

void main() {
  test('retries GET on connection error then succeeds', () async {
    final adapter = _ScriptedAdapter([DioExceptionType.connectionError, 200]);
    final res = await _dioWith(adapter).get('/x');
    expect(res.statusCode, 200);
    expect(adapter.calls, 2);
  });

  test('retries GET on 503 at most twice', () async {
    final adapter = _ScriptedAdapter([503]);
    await expectLater(_dioWith(adapter).get('/x'), throwsA(isA<DioException>()));
    expect(adapter.calls, 3);
  });

  test('does not retry 4xx', () async {
    final adapter = _ScriptedAdapter([404]);
    await expectLater(_dioWith(adapter).get('/x'), throwsA(isA<DioException>()));
    expect(adapter.calls, 1);
  });

  test('does not retry non-GET requests', () async {
    final adapter = _ScriptedAdapter([DioExceptionType.connectionError, 200]);
    await expectLater(_dioWith(adapter).post('/x'), throwsA(isA<DioException>()));
    expect(adapter.calls, 1);
  });

  test('does not retry timeouts', () async {
    final adapter = _ScriptedAdapter([DioExceptionType.receiveTimeout, 200]);
    await expectLater(_dioWith(adapter).get('/x'), throwsA(isA<DioException>()));
    expect(adapter.calls, 1);
  });
}
