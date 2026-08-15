import 'package:flutter/material.dart';

import '../../../core/responsive/breakpoints.dart';
import '../../../core/theme/app_colors.dart';
import 'nav_item.dart';
import 'side_nav_rail.dart';

/// Role-aware app shell: tablet gets the prototype's side nav rail, phone
/// gets a bottom nav bar. [child] is the currently active tab's content.
class RoleShell extends StatelessWidget {
  const RoleShell({
    super.key,
    required this.items,
    required this.activeKey,
    required this.onChange,
    required this.child,
  });

  final List<ShellNavItem> items;
  final String activeKey;
  final ValueChanged<String> onChange;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (isTabletLayout(context)) {
      return Scaffold(
        body: Row(
          children: [
            SideNavRail(items: items, activeKey: activeKey, onChange: onChange),
            Expanded(child: child),
          ],
        ),
      );
    }

    final activeIndex = items.indexWhere((i) => i.key == activeKey).clamp(0, items.length - 1);
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: activeIndex,
        onDestinationSelected: (index) => onChange(items[index].key),
        backgroundColor: AppColors.card,
        indicatorColor: AppColors.blueLt,
        destinations: [
          for (final item in items)
            NavigationDestination(
              icon: item.badgeCount > 0
                  ? Badge(label: Text('${item.badgeCount}'), backgroundColor: AppColors.red, child: Icon(item.icon))
                  : Icon(item.icon),
              label: item.label,
            ),
        ],
      ),
    );
  }
}
