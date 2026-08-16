import 'package:flutter/material.dart';

import 'core/responsive/breakpoints.dart';
import 'core/routing/auth_gate.dart';
import 'core/theme/app_theme.dart';

class BayanRmeApp extends StatelessWidget {
  const BayanRmeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bayan RME',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      builder: (context, child) {
        final scale = getAdaptiveTextScale(context);
        final mediaQuery = MediaQuery.of(context);
        return MediaQuery(
          data: mediaQuery.copyWith(
            textScaler: TextScaler.linear(scale),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const AuthGate(),
    );
  }
}
