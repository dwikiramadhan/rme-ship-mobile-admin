import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Port of the prototype's `ScreenHeader` — plain card header by default, or
/// a blue gradient header when [gradient] is true (used on phone dashboards).
class ScreenHeader extends StatelessWidget implements PreferredSizeWidget {
  const ScreenHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.gradient = false,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final bool gradient;

  @override
  Size get preferredSize => const Size.fromHeight(72);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = gradient ? Colors.white : scheme.onSurface;
    final sfg = gradient ? Colors.white.withValues(alpha: 0.7) : scheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: gradient
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.blue, Color(0xFF1E40AF)],
              )
            : null,
        color: gradient ? null : scheme.surface,
        border: gradient ? null : Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: fg)),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: TextStyle(fontSize: 13, color: sfg)),
                ],
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
