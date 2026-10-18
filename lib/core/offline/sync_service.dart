import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../features/auth/data/session_storage.dart';
import '../network/dio_client.dart';
import 'outbox_entry.dart';
import 'outbox_store.dart';

/// Outbox counts for the current user, shown in the ship ribbon.
class SyncStatus {
  const SyncStatus({this.pending = 0, this.failed = 0, this.syncing = false});

  final int pending;
  final int failed;
  final bool syncing;
}

enum _SendResult { sent, retryLater, rejected, unauthorized }

/// Queues writes made while offline and sends them, oldest first, once the
/// server is reachable again.
///
/// Rules:
/// - Entries are sent one at a time, in order; the first one that can't be
///   sent yet (offline, timeout, 5xx) stops the round so order is kept.
/// - An entry the server rejects (4xx) is marked failed and kept for the user
///   to retry or discard; later entries carry on.
/// - A 401 stops the round; the entries wait for the same user to log in.
/// - Each entry's id is sent as `Idempotency-Key`.
class SyncService {
  SyncService({
    // Callers pass it as `store:` (private named parameter).
    this._store = const SqliteOutboxStore(),
    Dio? dio,
    Future<String?> Function()? currentUserId,
    Future<Directory> Function()? filesDir,
    Duration? retryInterval = const Duration(seconds: 30),
  })  : _dio = dio ?? DioClient.instance,
        _currentUserId = currentUserId ?? _sessionUserId,
        _filesDir = filesDir ?? _defaultFilesDir {
    if (retryInterval != null) {
      _retryTimer = Timer.periodic(retryInterval, (_) {
        if (_status.pending > 0) syncNow();
      });
    }
  }

  final OutboxStore _store;
  final Dio _dio;
  final Future<String?> Function() _currentUserId;
  final Future<Directory> Function() _filesDir;
  Timer? _retryTimer;

  final _statusController = StreamController<SyncStatus>.broadcast();
  final _syncedController = StreamController<void>.broadcast();
  SyncStatus _status = const SyncStatus();

  Future<void>? _running;
  bool _runAgain = false;

  Stream<SyncStatus> get statusStream => _statusController.stream;
  SyncStatus get status => _status;

  /// Fires after a round that sent at least one entry, so screens can reload
  /// the server's version of what was queued.
  Stream<void> get onSynced => _syncedController.stream;

  static String newId() => const Uuid().v4();

  static Future<String?> _sessionUserId() async =>
      (await SessionStorage().read())?.user.id;

  static Future<Directory> _defaultFilesDir() async {
    final docs = await getApplicationDocumentsDirectory();
    return Directory('${docs.path}/outbox_files').create(recursive: true);
  }

  /// Whether the current user still has writes waiting to be sent. New
  /// writes must then be queued too, behind them, to keep the order (a visit
  /// can't reach the server before the patient it belongs to).
  Future<bool> hasPending() async {
    final userId = await _currentUserId();
    if (userId == null) return false;
    final entries = await _store.entries(userId);
    return entries.any((e) => e.status == OutboxStatus.pending);
  }

  /// Queues a write and tries to send the queue right away.
  Future<OutboxEntry> enqueue({
    required String method,
    required String path,
    required String label,
    Map<String, dynamic>? body,
    Map<String, String> files = const {},
    Map<String, String> produces = const {},
    String? id,
  }) async {
    final userId = await _currentUserId();
    if (userId == null) {
      throw StateError('Tidak ada sesi login untuk menyimpan data offline.');
    }
    final entry = OutboxEntry(
      id: id ?? newId(),
      userId: userId,
      method: method,
      path: path,
      label: label,
      body: body,
      files: files,
      produces: produces,
      createdAt: DateTime.now(),
    );
    await _store.add(entry);
    await refreshStatus();
    unawaited(syncNow());
    return entry;
  }

  /// Copies [file] into app storage so it is still there when the queue is
  /// sent (picker / camera files can be temporary). Returns the copy's path.
  /// The copy keeps the file's [name] (default: its own), which is the name
  /// the server receives.
  Future<String> keepFile(File file, {String? name}) async {
    final dir = await _newFileDir();
    final fileName = name ?? file.path.split(Platform.pathSeparator).last;
    final copy = await file.copy('${dir.path}/$fileName');
    return copy.path;
  }

  /// Like [keepFile], for a file only held in memory.
  Future<String> keepBytes(List<int> bytes, String name) async {
    final dir = await _newFileDir();
    final copy = await File('${dir.path}/$name').writeAsBytes(bytes);
    return copy.path;
  }

  /// A folder of its own per kept file, so files with the same name don't
  /// overwrite each other.
  Future<Directory> _newFileDir() async {
    final dir = await _filesDir();
    return Directory('${dir.path}/${newId()}').create();
  }

  Future<List<OutboxEntry>> entries() async {
    final userId = await _currentUserId();
    if (userId == null) return const [];
    return _store.entries(userId);
  }

  /// Puts a failed entry back in the queue and sends it.
  Future<void> retry(String id) async {
    final entry = (await entries()).where((e) => e.id == id).firstOrNull;
    if (entry == null) return;
    await _store.update(entry.copyWith(status: OutboxStatus.pending));
    await refreshStatus();
    unawaited(syncNow());
  }

  /// Drops an entry for good, with its kept files.
  Future<void> discard(String id) async {
    final entry = (await entries()).where((e) => e.id == id).firstOrNull;
    if (entry == null) return;
    await _store.remove(id);
    await _deleteFiles(entry);
    await refreshStatus();
  }

  /// Sends the queue. Calls while a round is running make it run once more
  /// afterwards, so an entry queued mid-round isn't left behind.
  Future<void> syncNow() {
    if (_running != null) {
      _runAgain = true;
      return _running!;
    }
    return _running = _runRounds().whenComplete(() => _running = null);
  }

  Future<void> _runRounds() async {
    do {
      _runAgain = false;
      try {
        await _round();
      } catch (e) {
        debugPrint('⚠️ [Sync] round failed: $e');
      }
    } while (_runAgain);
  }

  Future<void> _round() async {
    final userId = await _currentUserId();
    if (userId == null) return;
    final pending = (await _store.entries(userId))
        .where((e) => e.status == OutboxStatus.pending)
        .toList();
    if (pending.isEmpty) return;

    _setStatus(syncing: true);
    final tokens = await _store.tokens();
    var sent = 0;
    try {
      for (final entry in pending) {
        // Logged out / switched user mid-round: the auth header would now
        // carry someone else's token.
        if (await _currentUserId() != userId) break;
        final (result, response, error) = await _send(entry, tokens);
        if (result == _SendResult.sent) {
          sent++;
          for (final MapEntry(key: token, value: path) in entry.produces.entries) {
            final value = _valueAt(response?.data, path);
            if (value != null) {
              tokens[token] = value;
              await _store.saveToken(token, value);
            }
          }
          await _store.remove(entry.id);
          await _deleteFiles(entry);
          continue;
        }
        if (result == _SendResult.rejected) {
          await _store.update(
            entry.copyWith(
              status: OutboxStatus.failed,
              attempts: entry.attempts + 1,
              lastError: error,
            ),
          );
          continue;
        }
        if (result == _SendResult.retryLater) {
          await _store.update(
            entry.copyWith(attempts: entry.attempts + 1, lastError: error),
          );
        }
        // retryLater / unauthorized: keep the order, stop here.
        break;
      }
      if ((await _store.entries(userId)).isEmpty) {
        await _store.clearTokens();
      }
    } finally {
      await refreshStatus();
      if (sent > 0) _syncedController.add(null);
    }
  }

  Future<(_SendResult, Response<dynamic>?, String?)> _send(
    OutboxEntry entry,
    Map<String, String> tokens,
  ) async {
    try {
      final path = _resolve(entry.path, tokens) as String;
      final body = _resolve(entry.body, tokens) as Map<String, dynamic>?;
      final Object? data;
      if (entry.files.isEmpty) {
        data = body;
      } else {
        data = FormData.fromMap({
          ...?body,
          for (final MapEntry(key: field, value: filePath) in entry.files.entries)
            field: await MultipartFile.fromFile(
              filePath,
              filename: filePath.split(Platform.pathSeparator).last,
            ),
        });
      }
      final response = await _dio.request<dynamic>(
        path,
        data: data,
        options: Options(
          method: entry.method,
          headers: {'Idempotency-Key': entry.id},
        ),
      );
      return (_SendResult.sent, response, null);
    } on DioException catch (e) {
      final message = DioClient.mapError(e).message;
      final status = e.response?.statusCode;
      if (status == 401) return (_SendResult.unauthorized, null, message);
      if (status != null &&
          status >= 400 &&
          status < 500 &&
          status != 408 &&
          status != 429) {
        return (_SendResult.rejected, null, message);
      }
      return (_SendResult.retryLater, null, message);
    } on FileSystemException catch (e) {
      return (_SendResult.rejected, null, 'File tidak ditemukan: ${e.path}');
    }
  }

  /// [value] with every placeholder token in its strings replaced by the
  /// server value it stands for.
  static Object? _resolve(Object? value, Map<String, String> tokens) {
    if (tokens.isEmpty) return value;
    return switch (value) {
      final String s => tokens.entries.fold<String>(
          s,
          (acc, t) => acc.replaceAll(t.key, t.value),
        ),
      final Map<String, dynamic> m => {
          for (final e in m.entries) e.key: _resolve(e.value, tokens),
        },
      final List<dynamic> l => [for (final v in l) _resolve(v, tokens)],
      _ => value,
    };
  }

  /// The value at dotted [path] (e.g. `result.id`) in a JSON response.
  static String? _valueAt(Object? data, String path) {
    Object? current = data;
    for (final key in path.split('.')) {
      if (current is! Map) return null;
      current = current[key];
    }
    return current?.toString();
  }

  Future<void> _deleteFiles(OutboxEntry entry) async {
    if (entry.files.isEmpty) return;
    final filesDir = (await _filesDir()).path;
    for (final path in entry.files.values) {
      try {
        final file = File(path);
        // The kept file's own folder (see [_newFileDir]), with the file.
        final folder = file.parent;
        if (folder.parent.path == filesDir) {
          await folder.delete(recursive: true);
        } else {
          await file.delete();
        }
      } catch (_) {}
    }
  }

  /// Recounts the current user's outbox (e.g. after logging in or out).
  Future<void> refreshStatus() async {
    final all = await entries();
    _setStatus(
      pending: all.where((e) => e.status == OutboxStatus.pending).length,
      failed: all.where((e) => e.status == OutboxStatus.failed).length,
      syncing: false,
    );
  }

  void _setStatus({int? pending, int? failed, bool? syncing}) {
    _status = SyncStatus(
      pending: pending ?? _status.pending,
      failed: failed ?? _status.failed,
      syncing: syncing ?? _status.syncing,
    );
    if (!_statusController.isClosed) _statusController.add(_status);
  }

  void dispose() {
    _retryTimer?.cancel();
    _statusController.close();
    _syncedController.close();
  }
}
