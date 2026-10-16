import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_controller.dart';
import '../../patients/data/patient_repository.dart';
import '../data/device_api.dart';

/// Push notifications (FCM) for the signed-in user:
/// - after login: asks for permission and registers the device token with
///   the backend (again whenever FCM rotates it);
/// - on logout: deletes the token, so the next user on this device doesn't
///   get the previous one's notifications;
/// - a push received or tapped while the app runs refreshes the role's
///   notification list and shows its banner, like a WebSocket event.
///
/// Background pushes are shown by the system from their `notification`
/// payload; no Dart code runs for them.
class PushController {
  PushController(this._ref, this._deviceApi);

  final Ref _ref;
  final DeviceApi _deviceApi;
  final List<StreamSubscription<Object?>> _subscriptions = [];

  FirebaseMessaging get _messaging => FirebaseMessaging.instance;

  Future<void> onLogin() async {
    try {
      await _messaging.requestPermission();
      final token = await _messaging.getToken();
      // For "Send test message" in the Firebase console.
      if (kDebugMode) debugPrint('🔔 [Push] FCM token: $token');
      if (token != null) await _register(token);

      _cancelSubscriptions();
      _subscriptions
        ..add(_messaging.onTokenRefresh.listen(_register))
        ..add(FirebaseMessaging.onMessage.listen(_onPush))
        ..add(FirebaseMessaging.onMessageOpenedApp.listen(_onPush));
      final opening = await _messaging.getInitialMessage();
      if (opening != null) _onPush(opening);
    } catch (e) {
      debugPrint('⚠️ [Push] setup failed: $e');
    }
  }

  Future<void> onLogout() async {
    _cancelSubscriptions();
    try {
      await _messaging.deleteToken();
    } catch (e) {
      debugPrint('⚠️ [Push] deleteToken failed: $e');
    }
  }

  Future<void> _register(String token) async {
    try {
      await _deviceApi.register(
        fcmToken: token,
        platform: Platform.isIOS ? 'ios' : 'android',
      );
    } catch (e) {
      // Not fatal: offline, or the backend doesn't have the endpoint yet.
      // Registered again on the next login or token refresh.
      debugPrint('⚠️ [Push] device registration failed: $e');
    }
  }

  void _onPush(RemoteMessage message) {
    _ref
        .read(notificationsProvider.notifier)
        .fetchRecentNotifications(
          triggerBannerForPatientId: message.data['patient_id']?.toString(),
        );
  }

  void _cancelSubscriptions() {
    for (final s in _subscriptions) {
      s.cancel();
    }
    _subscriptions.clear();
  }
}

/// Watched by the app root. Null when Firebase isn't set up (under
/// `flutter test`, or a platform without its Firebase config file).
final pushControllerProvider = Provider<PushController?>((ref) {
  if (!_firebaseReady()) return null;

  final controller = PushController(ref, DeviceApi());
  ref.onDispose(controller._cancelSubscriptions);
  ref.listen<String?>(
    authControllerProvider.select((s) => s.session?.user.id),
    (previous, userId) {
      if (userId != null) {
        controller.onLogin();
      } else if (previous != null) {
        controller.onLogout();
      }
    },
    fireImmediately: true,
  );
  return controller;
});

bool _firebaseReady() {
  try {
    return Firebase.apps.isNotEmpty;
  } catch (_) {
    return false;
  }
}
