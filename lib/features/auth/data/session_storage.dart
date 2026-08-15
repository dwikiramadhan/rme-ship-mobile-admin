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

  final FlutterSecureStorage _storage;

  Future<void> save(AuthSession session) {
    return _storage.write(key: _sessionKey, value: jsonEncode(session.toJson()));
  }

  Future<AuthSession?> read() async {
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

  Future<void> clear() {
    return _storage.delete(key: _sessionKey);
  }
}
