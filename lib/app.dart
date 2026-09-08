import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/notifications/in_app_notification_overlay.dart';
import 'core/responsive/breakpoints.dart';
import 'core/routing/app_navigator.dart';
import 'core/routing/auth_gate.dart';
import 'core/theme/app_theme.dart';
import 'features/patients/data/patient_repository.dart';

class BayanRmeApp extends ConsumerStatefulWidget {
  const BayanRmeApp({super.key});

  @override
  ConsumerState<BayanRmeApp> createState() => _BayanRmeAppState();
}

class _BayanRmeAppState extends ConsumerState<BayanRmeApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      debugPrint(
        '📱 [AppLifecycle] App resumed on ship tablet. Triggering catch-up sync...',
      );
      ref.read(notificationsProvider.notifier).catchUpSync();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: rootNavigatorKey,
      title: 'RME Bayan',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      builder: (context, child) {
        final scale = getAdaptiveTextScale(context);
        final mediaQuery = MediaQuery.of(context);
        return MediaQuery(
          data: mediaQuery.copyWith(
            textScaler: TextScaler.linear(scale),
          ),
          child: InAppNotificationOverlay(
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
      home: const AuthGate(),
    );
  }
}
