import 'package:bayan_rme/core/network/api_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('defaults to the cloud backend host, without /api/v1', () {
    expect(ApiConfig.defaultBaseUrl, 'https://rme-ship.wikibaggins.com');
    expect(ApiConfig.patientsPath, startsWith('/api/v1/'));
  });

  test('health check uses the cloud health endpoint', () {
    expect(ApiConfig.healthPath, '/api/v1/health');
  });

  test('a URL without a scheme is treated as https', () {
    expect(ApiConfig.sanitizeUrl('example.com/'), 'https://example.com');
    expect(
      ApiConfig.sanitizeUrl('http://192.168.1.26:8080'),
      'http://192.168.1.26:8080',
    );
  });

  test('websocket follows the base URL scheme', () {
    ApiConfig.setCustomBaseUrl(null);
    expect(ApiConfig.wsUrl, 'wss://rme-ship.wikibaggins.com/api/v1/ws');
  });
}
