import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../domain/environment_item.dart';

/// Persists active ship environment metadata in local storage (FlutterSecureStorage).
/// Allows global access to the active ship `code` across the application.
class EnvironmentStorage {
  EnvironmentStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _envItemKey = 'bayan_rme.active_environment';
  static const _envCodeKey = 'bayan_rme.active_environment_code';
  static const _envNameKey = 'bayan_rme.active_environment_name';
  static const _envShipIdKey = 'bayan_rme.active_environment_ship_id';
  static const _shipIdKey = 'bayan_rme.ship_id';

  /// Saves the active environment item and specifically persists `code`, `name`, and `ship_id`.
  Future<void> save(EnvironmentItem env) async {
    final futures = <Future<void>>[
      _storage.write(key: _envItemKey, value: jsonEncode(env.toJson())),
      _storage.write(key: _envCodeKey, value: env.code),
      _storage.write(key: _envNameKey, value: env.name),
    ];
    if (env.shipId != null && env.shipId!.isNotEmpty) {
      futures.add(_storage.write(key: _envShipIdKey, value: env.shipId!));
      futures.add(_storage.write(key: _shipIdKey, value: env.shipId!));
    }
    await Future.wait(futures);
  }

  /// Directly reads the persisted environment code string.
  Future<String?> getCode() async {
    return _storage.read(key: _envCodeKey);
  }

  /// Directly reads the persisted environment name string.
  Future<String?> getName() async {
    return _storage.read(key: _envNameKey);
  }

  /// Directly reads the persisted environment ship_id string.
  Future<String?> getShipId() async {
    final direct = await _storage.read(key: _envShipIdKey);
    if (direct != null && direct.isNotEmpty) return direct;
    return _storage.read(key: _shipIdKey);
  }

  /// Saves just the environment code string.
  Future<void> saveCode(String code) async {
    await _storage.write(key: _envCodeKey, value: code);
  }

  /// Saves just the environment ship_id string.
  Future<void> saveShipId(String shipId) async {
    await Future.wait([
      _storage.write(key: _envShipIdKey, value: shipId),
      _storage.write(key: _shipIdKey, value: shipId),
    ]);
  }

  /// Reads the full cached [EnvironmentItem].
  Future<EnvironmentItem?> read() async {
    final raw = await _storage.read(key: _envItemKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return EnvironmentItem.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  /// Clears stored environment data.
  Future<void> clear() async {
    await Future.wait([
      _storage.delete(key: _envItemKey),
      _storage.delete(key: _envCodeKey),
      _storage.delete(key: _envNameKey),
      _storage.delete(key: _envShipIdKey),
      _storage.delete(key: _shipIdKey),
    ]);
  }
}
