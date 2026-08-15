import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Small round action button (used for the header "+", "x", back, etc.).
class CircleIconButton extends StatelessWidget {
  const CircleIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.background = AppColors.card2,
    this.foreground = AppColors.text,
    this.size = 38,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final Color background;
  final Color foreground;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, size: size * 0.5, color: foreground),
        ),
      ),
    );
  }
}
