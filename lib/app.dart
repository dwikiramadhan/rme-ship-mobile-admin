import 'package:flutter/material.dart';

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
      home: const AuthGate(),
    );
  }
}
