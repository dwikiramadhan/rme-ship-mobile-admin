import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

enum AppButtonVariant { primary, danger, success, ghost }

/// Port of the prototype's `Btn` component: filled by default, ghost variant
/// for secondary actions, small variant for inline row actions.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.full = false,
    this.small = false,
    this.loading = false,
    this.loadingLabel = 'Menyimpan...',
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final IconData? icon;
  final bool full;
  final bool small;
  final bool loading;
  final String loadingLabel;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null || loading;

    final (gradient, flatBg, shadows, border) = switch ((disabled, variant)) {
      (true, _) => (
          null,
          const Color(0xFFE2E8F0),
          null,
          null,
        ),
      (false, AppButtonVariant.primary) => (
          const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFB923C), Color(0xFFEA580C)],
          ),
          null,
          [
            BoxShadow(
              color: const Color(0xFFEA580C).withValues(alpha: 0.28),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
          null,
        ),
      (false, AppButtonVariant.success) => (
          const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF34D399), Color(0xFF059669)],
          ),
          null,
          [
            BoxShadow(
              color: const Color(0xFF059669).withValues(alpha: 0.25),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
          null,
        ),
      (false, AppButtonVariant.danger) => (
          const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF87171), Color(0xFFDC2626)],
          ),
          null,
          [
            BoxShadow(
              color: const Color(0xFFDC2626).withValues(alpha: 0.25),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
          null,
        ),
      (false, AppButtonVariant.ghost) => (
          null,
          Colors.white.withValues(alpha: 0.85),
          [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
          Border.all(color: const Color(0xFFCBD5E1), width: 1.0),
        ),
    };

    final Color fg = switch ((disabled, variant)) {
      (true, _) => const Color(0xFF94A3B8),
      (false, AppButtonVariant.ghost) => AppColors.text,
      (false, _) => Colors.white,
    };

    final content = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: disabled ? null : onPressed,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: small ? 14 : 20,
            vertical: small ? 9 : 12,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (loading) ...[
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: fg),
                ),
                const SizedBox(width: 8),
              ] else if (icon != null) ...[
                Icon(icon, size: small ? 14 : 16, color: fg),
                const SizedBox(width: 6),
              ],
              Text(
                loading ? loadingLabel : label,
                style: TextStyle(
                  fontSize: small ? 11 : 12,
                  fontWeight: FontWeight.w700,
                  color: fg,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final decorated = Container(
      decoration: BoxDecoration(
        color: flatBg,
        gradient: gradient,
        borderRadius: BorderRadius.circular(20),
        border: border,
        boxShadow: shadows,
      ),
      child: content,
    );

    return full
        ? SizedBox(width: double.infinity, child: decorated)
        : decorated;
  }
}
