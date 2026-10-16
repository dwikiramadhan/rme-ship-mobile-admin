import 'dart:convert';
import 'dart:typed_data';

import 'package:bayan_rme/core/offline/http_cache.dart';
import 'package:bayan_rme/core/offline/outbox_entry.dart';
import 'package:bayan_rme/core/offline/outbox_store.dart';
import 'package:dio/dio.dart';

class InMemoryOutboxStore implements OutboxStore {
  final List<OutboxEntry> rows = [];
  final Map<String, String> savedTokens = {};

  @override
  Future<void> add(OutboxEntry entry) async => rows.add(entry);

  @override
  Future<List<OutboxEntry>> entries(String userId) async =>
      rows.where((e) => e.userId == userId).toList();

  @override
  Future<void> update(OutboxEntry entry) async {
    final i = rows.indexWhere((e) => e.id == entry.id);
    if (i >= 0) rows[i] = entry;
  }

  @override
  Future<void> remove(String id) async => rows.removeWhere((e) => e.id == id);

  @override
  Future<Map<String, String>> tokens() async => {...savedTokens};

  @override
  Future<void> saveToken(String token, String value) async =>
      savedTokens[token] = value;

  @override
  Future<void> clearTokens() async => savedTokens.clear();
}

class InMemoryHttpCache implements HttpCacheStore {
  final Map<String, String> bodies = {};

  @override
  Future<String?> read(String key) async => bodies[key];

  @override
  Future<void> write(String key, String body) async => bodies[key] = body;

  @override
  Future<void> clear() async => bodies.clear();
}

/// A request as the fake server saw it.
class SeenRequest {
  SeenRequest(this.options);

  final RequestOptions options;
  String get method => options.method;
  String get path => options.path;
  Object? get data => options.data;
}

/// Answers each request with [handler]; returning null means the server is
/// unreachable (a connection error).
class FakeServerAdapter implements HttpClientAdapter {
  FakeServerAdapter(this.handler);

  ({int status, Object? body})? Function(SeenRequest request) handler;
  final List<SeenRequest> seen = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final request = SeenRequest(options);
    seen.add(request);
    final reply = handler(request);
    if (reply == null) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'offline',
      );
    }
    return ResponseBody.fromString(
      jsonEncode(reply.body),
      reply.status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Dio fakeDio(FakeServerAdapter adapter) =>
    Dio(BaseOptions(baseUrl: 'https://example.test'))..httpClientAdapter = adapter;
