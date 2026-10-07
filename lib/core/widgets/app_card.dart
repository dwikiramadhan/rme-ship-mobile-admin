import 'package:flutter/material.dart';

/// Borderless, shadow-only card — matches the prototype's "border removed,
/// shadow kept" styling pass.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.color,
    this.border,
    this.clipBehavior = Clip.antiAlias,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? color;
  final BoxBorder? border;
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    final isCustomColor = color != null;
    return Container(
      clipBehavior: clipBehavior,
      padding: padding ?? const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isCustomColor ? color : Colors.white.withValues(alpha: 0.95),
        gradient: isCustomColor
            ? null
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white,
                  Color(0xFFFBFDFF),
                ],
              ),
        borderRadius: BorderRadius.circular(14),
        border: border ??
            Border.all(
              color: const Color(0xFFE2E8F0).withValues(alpha: 0.8),
              width: 0.9,
            ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: child,
    );
  }
}
