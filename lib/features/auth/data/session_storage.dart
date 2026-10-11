import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../domain/app_user.dart';

/// Persists the logged-in session on-device (encrypted keystore/keychain via
/// flutter_secure_storage) so a role's session survives app restarts and
/// works without a live connection — the "session login tersimpan
/// (offline-enabled)" requirement from the original spec.
class SessionStorage {
  SessionStorage({FlutterSecureStorage? storage}) : _storage = storage ?? const FlutterSecureStorage();

  static const _sessionKey = 'bayan_rme.auth_session';

  static const _rememberEmailKey = 'bayan_rme.remember_email';

  final FlutterSecureStorage _storage;

  // In-memory mirror of the persisted session, shared by every instance so
  // the Dio interceptor doesn't hit the keystore/keychain on each request.
  // All writes to [_sessionKey] go through this class, so it stays in sync.
  static AuthSession? _cachedSession;
  static bool _cacheLoaded = false;

  Future<void> save(AuthSession session) async {
    await _storage.write(key: _sessionKey, value: jsonEncode(session.toJson()));
    _cachedSession = session;
    _cacheLoaded = true;
  }

  Future<AuthSession?> read() async {
    if (_cacheLoaded) return _cachedSession;
    final session = await _readFromStorage();
    // A save()/clear() that finished while we were reading is newer — keep it.
    if (!_cacheLoaded) {
      _cachedSession = session;
      _cacheLoaded = true;
    }
    return _cachedSession;
  }

  Future<AuthSession?> _readFromStorage() async {
    final raw = await _storage.read(key: _sessionKey);
    if (raw == null) return null;
    try {
      return AuthSession.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      // Corrupt/old-format entry — treat as no session rather than crashing.
      await clear();
      return null;
    }
  }

  Future<void> clear() async {
    await _storage.delete(key: _sessionKey);
    _cachedSession = null;
    _cacheLoaded = true;
  }

  Future<void> saveRememberEmail(String email) {
    return _storage.write(key: _rememberEmailKey, value: email);
  }

  Future<String?> readRememberEmail() {
    return _storage.read(key: _rememberEmailKey);
  }

  Future<void> clearRememberEmail() {
    return _storage.delete(key: _rememberEmailKey);
  }
}
