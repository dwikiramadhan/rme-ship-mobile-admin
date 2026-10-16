import 'package:bayan_rme/core/network/api_exception.dart';
import 'package:bayan_rme/features/notifications/data/device_api.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/offline_fakes.dart';

void main() {
  test('registers the FCM token and platform with the backend', () async {
    final server = FakeServerAdapter((_) => (status: 200, body: {}));
    await DeviceApi(dio: fakeDio(server)).register(
      fcmToken: 'tok-123',
      platform: 'android',
    );

    final request = server.seen.single;
    expect('${request.method} ${request.path}', 'POST /api/v1/devices');
    expect(request.data, {'fcm_token': 'tok-123', 'platform': 'android'});
  });

  test('a failure surfaces as an ApiException', () async {
    final server = FakeServerAdapter((_) => (status: 404, body: {}));

    expect(
      () => DeviceApi(dio: fakeDio(server)).register(
        fcmToken: 'tok-123',
        platform: 'android',
      ),
      throwsA(isA<ApiException>()),
    );
  });
}
