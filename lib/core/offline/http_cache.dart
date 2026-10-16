import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'offline_database.dart';

/// Where [OfflineCacheInterceptor] keeps the last response of each GET.
abstract class HttpCacheStore {
  Future<String?> read(String key);
  Future<void> write(String key, String body);
  Future<void> clear();
}

class SqliteHttpCache implements HttpCacheStore {
  const SqliteHttpCache();

  @override
  Future<String?> read(String key) async {
    final db = await OfflineDatabase.instance;
    final rows = await db.query(
      'http_cache',
      columns: ['body'],
      where: 'key = ?',
      whereArgs: [key],
    );
    return rows.isEmpty ? null : rows.first['body'] as String;
  }

  @override
  Future<void> write(String key, String body) async {
    final db = await OfflineDatabase.instance;
    await db.rawInsert(
      'INSERT OR REPLACE INTO http_cache (key, body, stored_at) VALUES (?, ?, ?)',
      [key, body, DateTime.now().millisecondsSinceEpoch],
    );
  }

  @override
  Future<void> clear() async {
    final db = await OfflineDatabase.instance;
    await db.delete('http_cache');
  }
}

/// Keeps the last successful JSON response of every GET, and answers a GET
/// from it when the server can't be reached, so screens still show the last
/// known data offline. Such responses carry `extra['fromCache'] = true`.
///
/// Caching is best-effort: a storage failure never fails the request.
class OfflineCacheInterceptor extends Interceptor {
  OfflineCacheInterceptor([this._store = const SqliteHttpCache()]);

  final HttpCacheStore _store;

  static const _fallbackStatuses = {502, 503, 504};

  @override
  Future<void> onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) async {
    final options = response.requestOptions;
    final data = response.data;
    if (_isCacheable(options) &&
        response.statusCode == 200 &&
        (data is Map || data is List)) {
      try {
        await _store.write(_key(options), jsonEncode(data));
      } catch (e) {
        debugPrint('⚠️ [OfflineCache] write failed: $e');
      }
    }
    handler.next(response);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    if (!_isCacheable(options) || !_serverUnreachable(err)) {
      return handler.next(err);
    }
    try {
      final cached = await _store.read(_key(options));
      if (cached != null) {
        return handler.resolve(
          Response<dynamic>(
            requestOptions: options,
            data: jsonDecode(cached),
            statusCode: 200,
            extra: {'fromCache': true},
          ),
        );
      }
    } catch (e) {
      debugPrint('⚠️ [OfflineCache] read failed: $e');
    }
    handler.next(err);
  }

  static bool _isCacheable(RequestOptions options) =>
      options.method.toUpperCase() == 'GET' &&
      options.responseType == ResponseType.json;

  static bool _serverUnreachable(DioException err) => switch (err.type) {
        DioExceptionType.connectionError ||
        DioExceptionType.connectionTimeout ||
        DioExceptionType.sendTimeout ||
        DioExceptionType.receiveTimeout =>
          true,
        DioExceptionType.badResponse =>
          _fallbackStatuses.contains(err.response?.statusCode),
        _ => false,
      };

  /// The full URL including the query, so each page / search / filter is
  /// cached on its own. Host is left out so it survives a base URL change.
  static String _key(RequestOptions options) {
    final uri = options.uri;
    return uri.hasQuery ? '${uri.path}?${uri.query}' : uri.path;
  }
}
