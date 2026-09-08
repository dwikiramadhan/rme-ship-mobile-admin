import 'package:flutter/material.dart';

import '../../../core/responsive/breakpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../environment/presentation/ship_environment_ribbon.dart';
import 'nav_item.dart';
import 'side_nav_rail.dart';

/// Role-aware app shell: tablet gets the prototype's side nav rail, phone
/// gets a bottom nav bar. [child] is the currently active tab's content.
class RoleShell extends StatefulWidget {
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
  State<RoleShell> createState() => _RoleShellState();
}

class _RoleShellState extends State<RoleShell> {
  int _previousIndex = 0;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = _getIndex(widget.activeKey);
    _previousIndex = _currentIndex;
  }

  @override
  void didUpdateWidget(covariant RoleShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activeKey != widget.activeKey) {
      _previousIndex = _getIndex(oldWidget.activeKey);
      _currentIndex = _getIndex(widget.activeKey);
    }
  }

  int _getIndex(String key) {
    final idx = widget.items.indexWhere((item) => item.key == key);
    return idx >= 0 ? idx : 0;
  }

  @override
  Widget build(BuildContext context) {
    final isForward = _currentIndex >= _previousIndex;

    final animatedContent = ClipRect(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          final isCurrent =
              child.key == ValueKey<String>(widget.activeKey);

          final inOffset = isForward
              ? const Offset(0.20, 0.0)
              : const Offset(-0.20, 0.0);
          final outOffset = isForward
              ? const Offset(-0.20, 0.0)
              : const Offset(0.20, 0.0);

          final offsetTween = Tween<Offset>(
            begin: isCurrent ? inOffset : outOffset,
            end: Offset.zero,
          );

          return SlideTransition(
            position: offsetTween.animate(
              CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              ),
            ),
            child: FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: Curves.easeOut,
              ),
              child: child,
            ),
          );
        },
        child: KeyedSubtree(
          key: ValueKey(widget.activeKey),
          child: widget.child,
        ),
      ),
    );

    if (isTabletLayout(context)) {
      return Scaffold(
        resizeToAvoidBottomInset: false,
        body: SafeArea(
          child: Column(
            children: [
              const ShipEnvironmentRibbon(),
              Expanded(
                child: Row(
                  children: [
                    SideNavRail(
                      items: widget.items,
                      activeKey: widget.activeKey,
                      onChange: widget.onChange,
                    ),
                    Expanded(child: animatedContent),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    final activeIndex = widget.items
        .indexWhere((i) => i.key == widget.activeKey)
        .clamp(0, widget.items.length - 1);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const ShipEnvironmentRibbon(),
            Expanded(child: animatedContent),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: activeIndex,
        onDestinationSelected: (index) =>
            widget.onChange(widget.items[index].key),
        backgroundColor: AppColors.card,
        indicatorColor: AppColors.blueLt,
        destinations: [
          for (final item in widget.items)
            NavigationDestination(
              icon: item.badgeCount > 0
                  ? Badge(
                      label: Text('${item.badgeCount}'),
                      backgroundColor: AppColors.red,
                      child: Icon(item.icon),
                    )
                  : Icon(item.icon),
              label: item.label,
            ),
        ],
      ),
    );
  }
}
