/// API paths and base URL. The base is compiled in via `--dart-define=API_BASE_URL=...`.
///
/// Example:
///   flutter run --dart-define=API_BASE_URL=https://rme-api.bayan.id
class ApiConfig {
  ApiConfig._();

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8080',
  );

  static const String loginPath = '/api/v1/auth/login';
  static const String changePasswordPath = '/api/v1/auth/change-password';
}
