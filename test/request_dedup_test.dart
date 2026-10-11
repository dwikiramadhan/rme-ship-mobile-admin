import 'dart:async';
import 'dart:typed_data';

import 'package:bayan_rme/features/doctor/data/icd10_api.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Counts requests and holds each response until [release] is called, so
/// concurrent callers really overlap.
class _GatedAdapter implements HttpClientAdapter {
  int calls = 0;
  final _gate = Completer<void>();

  void release() => _gate.complete();

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls++;
    await _gate.future;
    return ResponseBody.fromString(
      '{"result":{"data":[{"code":"A00","display":"Cholera"}],"total":1,"total_pages":1,"page":1}}',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  setUp(Icd10Api.clearCache);

  test('concurrent identical ICD-10 requests share one network call', () async {
    final adapter = _GatedAdapter();
    final api = Icd10Api(dio: Dio(BaseOptions(baseUrl: 'http://test'))..httpClientAdapter = adapter);

    // Mirrors the exam modal + picker both prefetching, plus the picker's
    // own page-1 fetch, all at the same time.
    final futures = [
      api.prefetchInitial(),
      api.prefetchInitial(),
      api.fetchIcd10Paginated(limit: 25),
    ];
    await Future<void>.delayed(Duration.zero);
    adapter.release();

    // Must complete (regression: a self-awaiting whenComplete deadlocked).
    await Future.wait(futures).timeout(const Duration(seconds: 2));
    expect(adapter.calls, 1);
    expect(Icd10Api.getCachedInitial()?.data.single.code, 'A00');

    // Afterwards the result is served from cache.
    await api.fetchIcd10Paginated(limit: 25);
    expect(adapter.calls, 1);
  });
}
