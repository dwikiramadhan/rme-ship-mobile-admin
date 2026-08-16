/// The API base URL is compiled in via `--dart-define=API_BASE_URL=...` so it
/// can point at a real deployment without touching code. Defaults to the
/// backend spec's dev address.
///
/// This session's sandbox cannot reach a server on the developer's own
/// machine, so `flutter run` here won't complete a real login — build/run on
/// a device or emulator that can route to this host instead.
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
}
