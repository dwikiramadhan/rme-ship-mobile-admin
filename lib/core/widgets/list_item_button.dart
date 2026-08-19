import 'package:flutter/material.dart';

/// Port of the prototype's `ListButton` — an avatar + title/subtitle row
/// used in every master list (antrian, pasien, daftar resep, order lab).
/// Selected state swaps the shadow for a thin blue border.
class ListItemButton extends StatelessWidget {
  const ListItemButton({
    super.key,
    required this.active,
    required this.onTap,
    required this.avatarColor,
    required this.avatarBg,
    required this.initial,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final bool active;
  final VoidCallback onTap;
  final Color avatarColor;
  final Color avatarBg;
  final String initial;
  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: active ? scheme.primaryContainer : scheme.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: active ? Border.all(color: scheme.primary, width: 1.5) : null,
            boxShadow: active
                ? null
                : [
                    BoxShadow(
                      color: scheme.onSurface.withValues(alpha: 0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: avatarBg, borderRadius: BorderRadius.circular(11)),
                child: Text(initial, style: TextStyle(color: avatarColor, fontWeight: FontWeight.w800, fontSize: 15)),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: scheme.onSurface)),
                    const SizedBox(height: 1),
                    Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 8), trailing!],
            ],
          ),
        ),
      ),
    );
  }
}
