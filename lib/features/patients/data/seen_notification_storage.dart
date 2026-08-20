import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists seen notification IDs so that viewed notifications do not reappear
/// when the user logs out, logs in again, or restarts the app.
class SeenNotificationStorage {
  SeenNotificationStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _kDoctorKey = 'bayan_rme.seen_notifs_doctor';
  static const _kDoctorLabKey = 'bayan_rme.seen_notifs_doctor_lab';
  static const _kPharmacyKey = 'bayan_rme.seen_notifs_pharmacy';
  static const _kLabKey = 'bayan_rme.seen_notifs_lab';

  final Set<String> _doctorSeen = {};
  final Set<String> _doctorLabSeen = {};
  final Set<String> _pharmacySeen = {};
  final Set<String> _labSeen = {};
  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;
    try {
      final docRaw = await _storage.read(key: _kDoctorKey);
      if (docRaw != null) {
        _doctorSeen.addAll(List<String>.from(jsonDecode(docRaw) as List));
      }

      final docLabRaw = await _storage.read(key: _kDoctorLabKey);
      if (docLabRaw != null) {
        _doctorLabSeen.addAll(List<String>.from(jsonDecode(docLabRaw) as List));
      }

      final pharmRaw = await _storage.read(key: _kPharmacyKey);
      if (pharmRaw != null) {
        _pharmacySeen.addAll(List<String>.from(jsonDecode(pharmRaw) as List));
      }

      final labRaw = await _storage.read(key: _kLabKey);
      if (labRaw != null) {
        _labSeen.addAll(List<String>.from(jsonDecode(labRaw) as List));
      }
    } catch (_) {}
    _loaded = true;
  }

  bool isDoctorSeen(String id) => _doctorSeen.contains(id);
  bool isDoctorLabSeen(String id) => _doctorLabSeen.contains(id);
  bool isPharmacySeen(String id) => _pharmacySeen.contains(id);
  bool isLabSeen(String id) => _labSeen.contains(id);

  Future<void> markDoctorSeen(String id) async {
    _doctorSeen.add(id);
    await _storage.write(key: _kDoctorKey, value: jsonEncode(_doctorSeen.toList()));
  }

  Future<void> markDoctorLabSeen(String id) async {
    _doctorLabSeen.add(id);
    await _storage.write(key: _kDoctorLabKey, value: jsonEncode(_doctorLabSeen.toList()));
  }

  Future<void> markPharmacySeen(String id) async {
    _pharmacySeen.add(id);
    await _storage.write(key: _kPharmacyKey, value: jsonEncode(_pharmacySeen.toList()));
  }

  Future<void> markLabSeen(String id) async {
    _labSeen.add(id);
    await _storage.write(key: _kLabKey, value: jsonEncode(_labSeen.toList()));
  }
}
