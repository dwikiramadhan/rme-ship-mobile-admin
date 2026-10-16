import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

/// The on-device SQLite database behind offline mode: the last GET responses
/// (`http_cache`), the writes waiting to be sent (`outbox`) and the server
/// values that replace local placeholders once sent (`outbox_tokens`).
///
/// It holds patient data, so it is encrypted with SQLCipher; the key is
/// generated on first use and kept in the keystore/keychain.
class OfflineDatabase {
  OfflineDatabase._();

  static const _fileName = 'bayan_rme_offline.db';
  static const _keyStorageKey = 'bayan_rme.offline_db_key';

  static Future<Database>? _db;

  static Future<Database> get instance => _db ??= _open();

  static Future<Database> _open() async {
    final path = '${await getDatabasesPath()}/$_fileName';
    final password = await _readOrCreateKey();
    try {
      return await _openWith(path, password);
    } on DatabaseException catch (e) {
      // The key no longer matches the file (e.g. the keychain was wiped);
      // its contents can't be read anymore, so start over.
      debugPrint('⚠️ [OfflineDatabase] Cannot open, recreating: $e');
      await deleteDatabase(path);
      return _openWith(path, password);
    }
  }

  static Future<Database> _openWith(String path, String password) {
    return openDatabase(
      path,
      password: password,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE http_cache (
            key TEXT PRIMARY KEY,
            body TEXT NOT NULL,
            stored_at INTEGER NOT NULL
          )''');
        await db.execute('''
          CREATE TABLE outbox (
            id TEXT PRIMARY KEY,
            user_id TEXT NOT NULL,
            method TEXT NOT NULL,
            path TEXT NOT NULL,
            body TEXT,
            files TEXT,
            produces TEXT,
            label TEXT NOT NULL,
            status TEXT NOT NULL,
            attempts INTEGER NOT NULL DEFAULT 0,
            last_error TEXT,
            created_at INTEGER NOT NULL
          )''');
        await db.execute('''
          CREATE TABLE outbox_tokens (
            token TEXT PRIMARY KEY,
            value TEXT NOT NULL
          )''');
      },
    );
  }

  static Future<String> _readOrCreateKey() async {
    const storage = FlutterSecureStorage();
    final saved = await storage.read(key: _keyStorageKey);
    if (saved != null && saved.isNotEmpty) return saved;

    final random = Random.secure();
    final key = base64Url.encode(
      List<int>.generate(32, (_) => random.nextInt(256)),
    );
    await storage.write(key: _keyStorageKey, value: key);
    return key;
  }
}
