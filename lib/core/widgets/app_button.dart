import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

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
    final scheme = Theme.of(context).colorScheme;
    final semantic = Theme.of(context).extension<AppSemanticColors>() ?? AppSemanticColors.light;
    final disabled = onPressed == null || loading;
    final Color bg = switch (variant) {
      AppButtonVariant.primary => scheme.primary,
      AppButtonVariant.danger => scheme.error,
      AppButtonVariant.success => semantic.success,
      AppButtonVariant.ghost => AppColors.card2,
    };
    final Color fg = variant == AppButtonVariant.ghost ? scheme.onSurface : scheme.onPrimary;

    final button = ElevatedButton(
      onPressed: disabled ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: disabled ? scheme.onSurfaceVariant : bg,
        disabledBackgroundColor: scheme.onSurfaceVariant.withValues(alpha: 0.6),
        foregroundColor: fg,
        elevation: 0,
        side: variant == AppButtonVariant.ghost
            ? BorderSide(color: scheme.outline, width: 1.5)
            : BorderSide.none,
        padding: EdgeInsets.symmetric(horizontal: small ? 14 : 20, vertical: small ? 9 : 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        minimumSize: full ? const Size.fromHeight(0) : null,
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
              fontSize: small ? 13 : 14.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );

    return full ? SizedBox(width: double.infinity, child: button) : button;
  }
}
