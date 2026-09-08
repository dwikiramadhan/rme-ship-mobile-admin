import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/health_api.dart';

final healthApiProvider = Provider<HealthApi>((ref) {
  return HealthApi();
});

/// Controls and periodically checks backend connectivity via `/health`.
/// Emits `true` when the server responds OK, or `false` (Disconnected) when unreachable.
class ServerConnectionNotifier extends StateNotifier<bool> {
  ServerConnectionNotifier(
    this._healthApi, {
    Duration checkInterval = const Duration(seconds: 10),
    bool autoStart = true,
  })  : _interval = checkInterval,
        super(true) {
    if (autoStart) {
      // Immediate initial check
      check();
      // Regular background poll
      _startPeriodicCheck();
    }
  }

  final HealthApi _healthApi;
  final Duration _interval;
  Timer? _timer;

  void _startPeriodicCheck() {
    _timer?.cancel();
    _timer = Timer.periodic(_interval, (_) {
      check();
    });
  }

  /// Manually checks backend health and updates state.
  Future<bool> check() async {
    final isHealthy = await _healthApi.checkHealth();
    if (mounted && state != isHealthy) {
      state = isHealthy;
    }
    return isHealthy;
  }

  /// Manually sets the connection status (e.g. from network interceptor).
  void setConnected(bool value) {
    if (mounted && state != value) {
      state = value;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final serverConnectionProvider =
    StateNotifierProvider.autoDispose<ServerConnectionNotifier, bool>((ref) {
  final healthApi = ref.watch(healthApiProvider);
  final isTest = !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');
  return ServerConnectionNotifier(
    healthApi,
    autoStart: !isTest,
  );
});
