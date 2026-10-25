import 'package:bayan_rme/core/network/api_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('uses the local backend outside release builds, host only', () {
    // Tests don't run in release mode.
    expect(ApiConfig.baseUrl, ApiConfig.developmentBaseUrl);
    expect(ApiConfig.developmentBaseUrl, 'http://localhost:8080');
    expect(ApiConfig.productionBaseUrl, 'https://api.rmebayanpeduli.com');
    expect(ApiConfig.patientsPath, startsWith('/api/v1/'));
  });

  test('health check uses the backend health endpoint', () {
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
    expect(ApiConfig.wsUrl, 'ws://localhost:8080/api/v1/ws');
  });
}
