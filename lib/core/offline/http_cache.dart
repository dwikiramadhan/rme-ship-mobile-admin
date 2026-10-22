import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../network/api_config.dart';
import 'offline_database.dart';

/// Reference data the forms need offline: the ship's doctors, the harbors
/// and the ship's medicine stock list. Not patient data, so it stays cached
/// across logouts (the next user on the ship needs it too). Regions and ICD
/// codes come from app assets.
const List<String> masterDataPaths = [
  ApiConfig.medicalPersonnelPath,
  ApiConfig.portsPath,
  ApiConfig.shipMedicineStocksPathPrefix,
  ApiConfig.labTestsPath,
];

/// Whether cache [key] (a path + query) is master data: it starts with one
/// of [masterDataPaths].
bool isMasterDataKey(String key) => masterDataPaths.any(key.startsWith);

/// Where [OfflineCacheInterceptor] keeps the last response of each GET.
abstract class HttpCacheStore {
  Future<String?> read(String key);
  Future<void> write(String key, String body);

  /// Drops every cached response except master data ([masterDataPaths]).
  Future<void> clearUserData();

  /// When a response under [pathPrefix] (any rest of path or query) was last
  /// stored; null if never.
  Future<DateTime?> lastStoredAt(String pathPrefix);
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
  Future<void> clearUserData() async {
    final db = await OfflineDatabase.instance;
    final keys = await db.query('http_cache', columns: ['key']);
    final batch = db.batch();
    for (final row in keys) {
      final key = row['key'] as String;
      if (!isMasterDataKey(key)) {
        batch.delete('http_cache', where: 'key = ?', whereArgs: [key]);
      }
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<DateTime?> lastStoredAt(String pathPrefix) async {
    final db = await OfflineDatabase.instance;
    // substr, not LIKE: paths contain "_", a LIKE wildcard.
    final rows = await db.rawQuery(
      'SELECT MAX(stored_at) AS t FROM http_cache WHERE substr(key, 1, ?) = ?',
      [pathPrefix.length, pathPrefix],
    );
    final t = rows.first['t'] as int?;
    return t == null ? null : DateTime.fromMillisecondsSinceEpoch(t);
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
