import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Port of the prototype's `EmptyDetail` — shown in the detail pane before a
/// list item is selected.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.subtitle});

  final IconData icon;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: AppColors.blueLt, borderRadius: BorderRadius.circular(18)),
            child: Icon(icon, size: 28, color: AppColors.blue),
          ),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.text)),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            SizedBox(
              width: 260,
              child: Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: AppColors.sub),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
