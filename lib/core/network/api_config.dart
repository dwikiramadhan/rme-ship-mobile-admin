import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// API paths and base URL. Can be dynamically configured via local storage or
/// compiled in via `--dart-define=API_BASE_URL=...`.
class ApiConfig {
  ApiConfig._();

  static const String serverUrlStorageKey = 'bayan_rme.server_url';
  static String? _customBaseUrl;

  static String get defaultBaseUrl {
    const raw = String.fromEnvironment('API_BASE_URL');
    if (raw.isNotEmpty) {
      return sanitizeUrl(raw);
    }
    return 'http://localhost:8080';
  }

  static String sanitizeUrl(String input) {
    var trimmed = input.trim();
    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
      trimmed = 'http://$trimmed';
    }
    if (trimmed.endsWith('/')) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }

  static Future<void> init({FlutterSecureStorage? storage}) async {
    try {
      final s = storage ?? const FlutterSecureStorage();
      final saved = await s.read(key: serverUrlStorageKey);
      if (saved != null && saved.trim().isNotEmpty) {
        _customBaseUrl = sanitizeUrl(saved);
      }
    } catch (_) {}
  }

  static void setCustomBaseUrl(String? url) {
    if (url == null || url.trim().isEmpty) {
      _customBaseUrl = null;
    } else {
      _customBaseUrl = sanitizeUrl(url);
    }
  }

  static Future<void> saveCustomBaseUrl(
    String? url, {
    FlutterSecureStorage? storage,
  }) async {
    setCustomBaseUrl(url);
    try {
      final s = storage ?? const FlutterSecureStorage();
      if (_customBaseUrl != null) {
        await s.write(key: serverUrlStorageKey, value: _customBaseUrl!);
      } else {
        await s.delete(key: serverUrlStorageKey);
      }
    } catch (_) {}
  }

  static String get baseUrl => _customBaseUrl ?? defaultBaseUrl;

  static String get wsUrl {
    final httpUrl = baseUrl;
    if (httpUrl.startsWith('https://')) {
      return 'wss://${httpUrl.substring(8)}/api/v1/ws';
    } else if (httpUrl.startsWith('http://')) {
      return 'ws://${httpUrl.substring(7)}/api/v1/ws';
    }
    return 'ws://$httpUrl/api/v1/ws';
  }

  static Future<bool> testConnection(String targetUrl) async {
    try {
      final sanitized = sanitizeUrl(targetUrl);
      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 4),
          receiveTimeout: const Duration(seconds: 4),
        ),
      );
      final res = await dio.get('$sanitized$healthPath');
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static const String healthPath = '/health';
  static const String loginPath = '/api/v1/auth/login';
  static const String changePasswordPath = '/api/v1/auth/change-password';
  static const String patientsPath = '/api/v1/patients';
  static const String medicalPersonnelPath = '/api/v1/medical-personnel';
  static const String doctorsPath = medicalPersonnelPath;
  static const String medicalHistoryPath = '/api/v1/medical-history';
  static const String schedulesPath = '/api/v1/schedules';
  static String schedulesByShipPath(String shipCode) =>
      '/api/v1/schedules/ship/${Uri.encodeComponent(shipCode)}';
  static String scheduleCounterPath(String shipCode) =>
      '/api/v1/schedules/ship/${Uri.encodeComponent(shipCode)}/counter';
  static const String icd10Path = '/api/v1/icd10';
  static const String icd9Path = '/api/v1/icd9cm';
  static const String medicinesPath = '/api/v1/medicines';
  static String shipMedicineStocksPath(String shipCode) =>
      '/api/v1/ship-medicines/stocks/${Uri.encodeComponent(shipCode)}';
  static const String shipMedicineHistoryPath = '/api/v1/ship-medicines/history';
  static const String environmentsPath = '/api/v1/environments';
  static String medicalRecordDispensePath(String medRecId) =>
      '/api/v1/medical-records/$medRecId/dispense';
  static String medicalRecordLabExaminationsPath(String medRecId) =>
      '/api/v1/medical-records/$medRecId/lab-examinations';
  static const String shipProvisionsHistoryPath = '/api/v1/ship-provisions-history';
  static const String tripIssuesPath = '/api/v1/trip-issues';
  static const String portsPath = '/api/v1/ports';
  static const String crewsPath = '/api/v1/crews';
  static const String poliklinikPath = '/api/v1/poliklinik';
}



