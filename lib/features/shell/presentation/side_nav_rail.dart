import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import 'nav_item.dart';

/// Port of the prototype's `SideNavRail` — a 96px vertical rail with the
/// Bayan logo and icon+label buttons, used on tablet layouts.
class SideNavRail extends StatelessWidget {
  const SideNavRail({super.key, required this.items, required this.activeKey, required this.onChange});

  final List<ShellNavItem> items;
  final String activeKey;
  final ValueChanged<String> onChange;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      decoration: const BoxDecoration(color: AppColors.card, border: Border(right: BorderSide(color: AppColors.border))),
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            margin: const EdgeInsets.only(bottom: 22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: AppColors.border),
              boxShadow: [BoxShadow(color: AppColors.text.withValues(alpha: 0.06), blurRadius: 6, offset: const Offset(0, 2))],
            ),
            child: Image.asset('assets/images/bayan_logo.png', width: 30, height: 30, fit: BoxFit.contain),
          ),
          for (final item in items) _RailButton(item: item, active: item.key == activeKey, onTap: () => onChange(item.key)),
        ],
      ),
    );
  }
}

class _RailButton extends StatelessWidget {
  const _RailButton({required this.item, required this.active, required this.onTap});

  final ShellNavItem item;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: SizedBox(
            width: 84,
            child: Column(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 46,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: active ? AppColors.blueLt : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(item.icon, size: 20, color: active ? AppColors.blue : AppColors.sub),
                    ),
                    if (item.badgeCount > 0)
                      Positioned(
                        top: -2,
                        right: 6,
                        child: Container(
                          constraints: const BoxConstraints(minWidth: 16),
                          height: 16,
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: AppColors.red, borderRadius: BorderRadius.circular(8)),
                          child: Text(
                            '${item.badgeCount}',
                            style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  item.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11.5, fontWeight: active ? FontWeight.w700 : FontWeight.w500, color: active ? AppColors.blue : AppColors.sub),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
