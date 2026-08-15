import 'package:flutter/widgets.dart';

class ShellNavItem {
  const ShellNavItem({required this.key, required this.label, required this.icon, this.badgeCount = 0});

  final String key;
  final String label;
  final IconData icon;
  final int badgeCount;
}
