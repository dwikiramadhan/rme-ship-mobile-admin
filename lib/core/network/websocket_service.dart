import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../features/auth/data/session_storage.dart';
import 'api_config.dart';

/// Manages real-time WebSocket connection to the backend server.
/// Dispatches incoming real-time events to listeners and automatically
/// handles reconnection if the connection drops.
///
/// The backend only accepts a signed-in user (access token in the
/// `Authorization` header) and sends them their own ship's events. Events
/// come from the backend after it saved a change; the app never sends any.
class WebSocketService {
  WebSocketService({String? url, Future<String?> Function()? accessToken})
    : _customUrl = url,
      _accessToken = accessToken ?? _sessionToken {
    _baseUrlSub = ApiConfig.onBaseUrlChanged.listen((_) {
      if (!_isDisposed) {
        debugPrint(
          '🔄 [WebSocket] Base URL changed. Reconnecting to ${ApiConfig.wsUrl}...',
        );
        reconnect();
      }
    });
  }

  final String? _customUrl;
  String get _url => _customUrl ?? ApiConfig.wsUrl;
  final Future<String?> Function() _accessToken;

  static Future<String?> _sessionToken() async =>
      (await SessionStorage().read())?.token;

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  StreamSubscription? _baseUrlSub;
  Timer? _reconnectTimer;
  Timer? _pingTimer;

  bool _isConnected = false;
  bool _isConnecting = false;
  bool _isDisposed = false;
  // Off after [disconnect] (logged out): no reconnecting until [connect].
  bool _wanted = false;
  int _reconnectAttempts = 0;

  final _eventController = StreamController<Map<String, dynamic>>.broadcast();
  final _connectionController = StreamController<bool>.broadcast();

  Stream<Map<String, dynamic>> get onEvent => _eventController.stream;
  Stream<bool> get onConnectionChanged => _connectionController.stream;
  bool get isConnected => _isConnected;

  Future<void> connect() async {
    _wanted = true;
    if (_isDisposed || _isConnected || _isConnecting) return;
    _isConnecting = true;

    final targetUrl = _url;
    try {
      // Read on every attempt: a refreshed token is used on reconnect.
      final token = await _accessToken();
      if (token == null || token.isEmpty || !_wanted) {
        // Not signed in: connected again after login.
        _isConnecting = false;
        return;
      }
      final uri = Uri.parse(targetUrl);
      debugPrint('🔌 [WebSocket] Connecting to $uri...');
      final channel = IOWebSocketChannel.connect(
        uri,
        headers: {'Authorization': 'Bearer $token'},
      );
      _channel = channel;

      _subscription = channel.stream.listen(
        (data) {
          _handleMessage(data);
        },
        onError: (error) {
          debugPrint('⚠️ [WebSocket] Stream error: $error');
          _isConnecting = false;
          _scheduleReconnect();
        },
        onDone: () {
          debugPrint('🔌 [WebSocket] Connection closed.');
          _isConnecting = false;
          _scheduleReconnect();
        },
        cancelOnError: true,
      );

      // Verify connection establishment before declaring connected
      await channel.ready;
      if (_channel != channel || _isDisposed) return;

      _isConnecting = false;
      _updateConnection(true);
      _reconnectAttempts = 0;
      _startHeartbeat();
      debugPrint('✅ [WebSocket] Connected successfully to $uri.');
    } catch (e) {
      _isConnecting = false;
      debugPrint('⚠️ [WebSocket] Failed to connect: $e');
      _scheduleReconnect();
    }
  }

  void reconnect({bool resetAttempts = true}) {
    if (!_wanted) return;
    if (resetAttempts) _reconnectAttempts = 0;
    _close();
    connect();
  }

  /// Closes the connection and stops reconnecting (e.g. on logout), until
  /// [connect] is called again.
  void disconnect() {
    _wanted = false;
    _reconnectAttempts = 0;
    _close();
  }

  void _close() {
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    _subscription = null;
    _pingTimer?.cancel();
    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;
    _isConnecting = false;
    _updateConnection(false);
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

  /// Keeps idle connections open through proxies; the backend ignores it.
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

    if (_isDisposed || !_wanted) return;

    _reconnectTimer?.cancel();
    // Exponential backoff: 2s, 4s, 8s, up to max 15s to keep ship Wi-Fi healthy
    final delaySeconds = (_reconnectAttempts < 3)
        ? (2 * (1 << _reconnectAttempts))
        : 15;
    _reconnectAttempts++;

    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () {
      if (!_isDisposed && _wanted && !_isConnected) {
        debugPrint('🔄 [WebSocket] Attempting reconnect (attempt $_reconnectAttempts)...');
        connect();
      }
    });
  }

  void dispose() {
    _isDisposed = true;
    _updateConnection(false);
    _reconnectTimer?.cancel();
    _pingTimer?.cancel();
    _subscription?.cancel();
    _baseUrlSub?.cancel();
    _channel?.sink.close();
    _eventController.close();
    _connectionController.close();
  }
}
