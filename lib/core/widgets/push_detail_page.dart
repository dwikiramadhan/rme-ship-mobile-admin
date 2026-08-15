import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Pushes a full-screen detail page — used when a notification is tapped
/// (on any layout, this always opens the patient directly rather than
/// switching tabs first).
void pushDetailPage(BuildContext context, {required String title, required Widget child}) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (context) => Scaffold(
        appBar: AppBar(title: Text(title)),
        backgroundColor: AppColors.bg,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ),
      ),
    ),
  );
}
