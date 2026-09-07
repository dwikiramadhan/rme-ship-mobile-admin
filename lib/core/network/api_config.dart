import 'dart:io';
import 'package:flutter/foundation.dart';

/// API paths and base URL. The base is compiled in via `--dart-define=API_BASE_URL=...`.
///
/// Example:
///   flutter run --dart-define=API_BASE_URL=https://rme-api.bayan.id
class ApiConfig {
  ApiConfig._();

  static String get baseUrl {
    const raw = String.fromEnvironment('API_BASE_URL');
    if (raw.isNotEmpty) {
      final trimmed = raw.trim();
      var url = trimmed.startsWith('http://') || trimmed.startsWith('https://')
          ? trimmed
          : 'http://$trimmed';
      if (url.endsWith('/')) {
        url = url.substring(0, url.length - 1);
      }
      return url;
    }

    if (!kIsWeb && Platform.isAndroid) {
      return 'http://localhost:8080';
    }
    return 'http://localhost:8080';
  }

  static String get wsUrl {
    final httpUrl = baseUrl;
    if (httpUrl.startsWith('https://')) {
      return 'wss://${httpUrl.substring(8)}/api/v1/ws';
    } else if (httpUrl.startsWith('http://')) {
      return 'ws://${httpUrl.substring(7)}/api/v1/ws';
    }
    return 'ws://$httpUrl/api/v1/ws';
  }

  static const String loginPath = '/api/v1/auth/login';
  static const String changePasswordPath = '/api/v1/auth/change-password';
  static const String patientsPath = '/api/v1/patients';
  static const String medicalPersonnelPath = '/api/v1/medical-personnel';
  static const String doctorsPath = medicalPersonnelPath;
  static const String medicalHistoryPath = '/api/v1/medical-history';
  static const String schedulesPath = '/api/v1/schedules';
  static String schedulesByShipPath(String shipCode) =>
      '/api/v1/schedules/ship/${Uri.encodeComponent(shipCode)}';
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



