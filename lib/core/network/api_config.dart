import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// API paths and base URL: the production backend in release builds, a
/// local backend while developing. Either can be overridden at build time
/// via `--dart-define=API_BASE_URL=...` (e.g. the Android emulator's
/// `http://10.0.2.2:8080`, or a LAN address on a phone).
class ApiConfig {
  ApiConfig._();

  static const String productionBaseUrl = 'https://api.rmebayanpeduli.com';
  static const String developmentBaseUrl = 'http://localhost:8080';

  /// Where the removed server settings dialog kept a custom address.
  static const String _serverUrlStorageKey = 'bayan_rme.server_url';

  /// Host only, without `/api/v1`: every path below already carries it.
  static String get baseUrl {
    const raw = String.fromEnvironment('API_BASE_URL');
    if (raw.isNotEmpty) {
      return sanitizeUrl(raw);
    }
    return kReleaseMode ? productionBaseUrl : developmentBaseUrl;
  }

  static String sanitizeUrl(String input) {
    var trimmed = input.trim();
    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
      trimmed = 'https://$trimmed';
    }
    if (trimmed.endsWith('/')) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }

  /// Drops a server address saved by the old server settings dialog.
  static Future<void> init({FlutterSecureStorage? storage}) async {
    try {
      await (storage ?? const FlutterSecureStorage()).delete(
        key: _serverUrlStorageKey,
      );
    } catch (_) {}
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

  static const String healthPath = '/api/v1/health';
  static const String loginPath = '/api/v1/auth/login';
  static const String mePath = '/api/v1/auth/me';
  static const String changePasswordPath = '/api/v1/auth/me/password';
  static const String patientsPath = '/api/v1/patients';
  static const String medicalPersonnelPath = '/api/v1/medical-personnel';
  static const String doctorsPath = medicalPersonnelPath;
  static const String medicalHistoryPath = '/api/v1/medical-history';
  static const String schedulesPath = '/api/v1/schedules';
  static const String assignedSchedulesPath = '/api/v1/schedules/assigned';
  static String schedulesByShipPath(String shipCode) =>
      '/api/v1/schedules/ship/${Uri.encodeComponent(shipCode)}';
  static String scheduleCounterPath(String shipCode) =>
      '/api/v1/schedules/ship/${Uri.encodeComponent(shipCode)}/counter';
  static const String icd10Path = '/api/v1/icd10';
  static const String icd9Path = '/api/v1/icd9cm';
  static const String medicinesPath = '/api/v1/medicines';
  static const String shipMedicineStocksPathPrefix =
      '/api/v1/ship-medicines/stocks/';
  static String shipMedicineStocksPath(String shipCode) =>
      '$shipMedicineStocksPathPrefix${Uri.encodeComponent(shipCode)}';
  static const String shipMedicineHistoryPath = '/api/v1/ship-medicines/history';
  static const String shipMedicinesPath = '/api/v1/ship-medicines';
  static const String environmentsPath = '/api/v1/environments';
  static String medicalRecordDispensePath(String medRecId) =>
      '/api/v1/medical-records/$medRecId/dispense';
  static String medicalRecordPrescriptionPdfPath(String medRecId) =>
      '/api/v1/medical-records/$medRecId/prescription/pdf';
  static String medicalRecordLabExaminationsPath(String medRecId) =>
      '/api/v1/medical-records/$medRecId/lab-examinations';
  static String labExaminationPdfPath(String labExamId) =>
      '/api/v1/lab-examinations/$labExamId/pdf';
  static String labExaminationViewDocumentPath(String fileName) =>
      '/api/v1/lab-examinations/view-document/${Uri.encodeComponent(fileName)}';
  static String labExaminationViewDocumentUrl(String fileName) =>
      '$baseUrl${labExaminationViewDocumentPath(fileName)}';
  static const String shipProvisionsHistoryPath = '/api/v1/ship-provisions-history';
  static const String tripIssuesPath = '/api/v1/trip-issues';
  static const String portsPath = '/api/v1/ports';
  static const String crewsPath = '/api/v1/crews';
  static const String poliklinikPath = '/api/v1/poliklinik';
  static const String labTestsPath = '/api/v1/lab-tests';
  static const String stockAdjustmentsPath = '/api/v1/stock-adjustments';
  static const String stockAdjustmentReportPath =
      '/api/v1/stock-adjustments/report';
  static const String stockAdjustmentReportDownloadPath =
      '/api/v1/stock-adjustments/report/download';
  static const String labParametersPath = '/api/v1/lab-parameters';
  static const String devicesPath = '/api/v1/devices';
  static const String todayStatsPath = '/api/v1/dashboard/today-stats';
}



