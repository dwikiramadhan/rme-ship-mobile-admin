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
  int _reconnectAttempts = 0;

  final _eventController = StreamController<Map<String, dynamic>>.broadcast();
  final _connectionController = StreamController<bool>.broadcast();

  Stream<Map<String, dynamic>> get onEvent => _eventController.stream;
  Stream<bool> get onConnectionChanged => _connectionController.stream;
  bool get isConnected => _isConnected;

  void connect() {
    if (_isDisposed || _isConnected) return;

    try {
      final uri = Uri.parse(_url);
      debugPrint('🔌 [WebSocket] Connecting to $uri...');
      _channel = WebSocketChannel.connect(uri);

      _subscription = _channel!.stream.listen(
        (data) {
          _updateConnection(true);
          _reconnectAttempts = 0;
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

      _updateConnection(true);
      _reconnectAttempts = 0;
      _startHeartbeat();
      debugPrint('✅ [WebSocket] Connected successfully.');
    } catch (e) {
      debugPrint('⚠️ [WebSocket] Failed to connect: $e');
      _scheduleReconnect();
    }
  }

  void _updateConnection(bool connected) {
    if (_isConnected != connected) {
      _isConnected = connected;
      if (!_connectionController.isClosed) {
        _connectionController.add(connected);
      }
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
    _updateConnection(false);
    _subscription?.cancel();
    _subscription = null;
    _pingTimer?.cancel();

    if (_isDisposed) return;

    _reconnectTimer?.cancel();
    // Exponential backoff: 2s, 4s, 8s, up to max 15s to keep ship Wi-Fi healthy
    final delaySeconds = (_reconnectAttempts < 3)
        ? (2 * (1 << _reconnectAttempts))
        : 15;
    _reconnectAttempts++;

    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () {
      if (!_isDisposed && !_isConnected) {
        debugPrint('🔄 [WebSocket] Attempting reconnect (attempt $_reconnectAttempts)...');
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
    _updateConnection(false);
    _reconnectTimer?.cancel();
    _pingTimer?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();
    _eventController.close();
    _connectionController.close();
  }
}
