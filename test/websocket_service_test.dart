import 'package:bayan_rme/core/network/websocket_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('not signed in: does not connect', () async {
    var tokenReads = 0;
    final ws = WebSocketService(
      url: 'ws://127.0.0.1:9/api/v1/ws',
      accessToken: () async {
        tokenReads++;
        return null;
      },
    );
    addTearDown(ws.dispose);

    await ws.connect();

    expect(tokenReads, 1);
    expect(ws.isConnected, isFalse);
  });

  test('after logout (disconnect) it stays closed until connect', () async {
    var tokenReads = 0;
    final ws = WebSocketService(
      url: 'ws://127.0.0.1:9/api/v1/ws',
      accessToken: () async {
        tokenReads++;
        return null;
      },
    );
    addTearDown(ws.dispose);

    ws.disconnect();
    ws.reconnect(); // e.g. the server address changed
    await pumpEventQueue();
    expect(tokenReads, 0);

    await ws.connect(); // logged in again
    expect(tokenReads, 1);
  });
}
