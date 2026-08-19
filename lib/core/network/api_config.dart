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

  static const String loginPath = '/api/v1/auth/login';
  static const String changePasswordPath = '/api/v1/auth/change-password';
  static const String patientsPath = '/api/v1/patients';
  static const String doctorsPath = '/api/v1/doctors';
  static const String medicalHistoryPath = '/api/v1/medical-history';
}

