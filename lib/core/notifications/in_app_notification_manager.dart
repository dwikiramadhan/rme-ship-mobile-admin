import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'in_app_notification_model.dart';

class InAppNotificationNotifier extends StateNotifier<InAppNotificationItem?> {
  InAppNotificationNotifier() : super(null);

  Timer? _dismissTimer;
  final List<InAppNotificationItem> _queue = [];

  void showNotification(InAppNotificationItem item) {
    if (state != null) {
      // Don't duplicate the same notification in queue
      if (state!.id != item.id && !_queue.any((q) => q.id == item.id)) {
        _queue.add(item);
      }
      return;
    }

    _display(item);
  }

  void _display(InAppNotificationItem item) {
    _dismissTimer?.cancel();

    // Trigger audio & haptic feedback for real-time awareness
    try {
      HapticFeedback.mediumImpact();
      SystemSound.play(SystemSoundType.alert);
    } catch (_) {}

    state = item;

    _dismissTimer = Timer(const Duration(seconds: 6), () {
      dismiss();
    });
  }

  void dismiss() {
    _dismissTimer?.cancel();
    state = null;

    if (_queue.isNotEmpty) {
      final next = _queue.removeAt(0);
      // Small pause before displaying next notification
      Future.delayed(const Duration(milliseconds: 300), () {
        _display(next);
      });
    }
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    super.dispose();
  }
}

final inAppNotificationProvider =
    StateNotifierProvider<InAppNotificationNotifier, InAppNotificationItem?>((ref) {
  return InAppNotificationNotifier();
});
