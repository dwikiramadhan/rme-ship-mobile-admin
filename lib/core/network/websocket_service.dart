import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'api_config.dart';

/// Manages real-time WebSocket connection to the backend server.
/// Dispatches incoming real-time events to listeners and automatically
/// handles reconnection if the connection drops.
class WebSocketService {
  WebSocketService({String? url}) : _url = url ?? ApiConfig.wsUrl;

  final String _url;
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _reconnectTimer;
  Timer? _pingTimer;

  bool _isConnected = false;
  bool _isDisposed = false;

  final _eventController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get onEvent => _eventController.stream;
  bool get isConnected => _isConnected;

  void connect() {
    if (_isDisposed || _isConnected) return;

    try {
      final uri = Uri.parse(_url);
      debugPrint('🔌 [WebSocket] Connecting to $uri...');
      _channel = WebSocketChannel.connect(uri);

      _subscription = _channel!.stream.listen(
        (data) {
          _isConnected = true;
          _handleMessage(data);
        },
        onError: (error) {
          debugPrint('⚠️ [WebSocket] Error: $error');
          _scheduleReconnect();
        },
        onDone: () {
          debugPrint('🔌 [WebSocket] Connection closed.');
          _scheduleReconnect();
        },
        cancelOnError: true,
      );

      _isConnected = true;
      _startHeartbeat();
      debugPrint('✅ [WebSocket] Connected successfully.');
    } catch (e) {
      debugPrint('⚠️ [WebSocket] Failed to connect: $e');
      _scheduleReconnect();
    }
  }

  void _handleMessage(dynamic data) {
    try {
      final text = data.toString().trim();
      if (text == 'pong' || text == 'PONG' || text == 'ping' || text == 'PING') return;

      final json = jsonDecode(text);
      if (json is Map<String, dynamic>) {
        final type = json['type'] ?? json['event'];
        if (type == 'ping' || type == 'pong') return;

        debugPrint('📩 [WebSocket] Event received: $type');
        _eventController.add(json);
      }
    } catch (e) {
      debugPrint('⚠️ [WebSocket] Parse message error: $e ($data)');
    }
  }

  void _startHeartbeat() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      if (_isConnected && _channel != null) {
        try {
          _channel!.sink.add(jsonEncode({'type': 'ping'}));
        } catch (_) {}
      }
    });
  }

  void _scheduleReconnect() {
    _isConnected = false;
    _subscription?.cancel();
    _subscription = null;
    _pingTimer?.cancel();

    if (_isDisposed) return;

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      if (!_isDisposed && !_isConnected) {
        debugPrint('🔄 [WebSocket] Attempting reconnect...');
        connect();
      }
    });
  }

  void send(Map<String, dynamic> message) {
    if (_isConnected && _channel != null) {
      try {
        _channel!.sink.add(jsonEncode(message));
      } catch (e) {
        debugPrint('⚠️ [WebSocket] Failed to send message: $e');
      }
    }
  }

  void dispose() {
    _isDisposed = true;
    _isConnected = false;
    _reconnectTimer?.cancel();
    _pingTimer?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();
    _eventController.close();
  }
}
