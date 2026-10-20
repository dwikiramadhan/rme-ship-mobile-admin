import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_colors.dart';

/// Marks a patient or visit whose change is still on the device, waiting to
/// be sent to the server.
class UnsyncedBadge extends StatelessWidget {
  const UnsyncedBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.yellowLt,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.yellow.withValues(alpha: 0.4)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.cloudOff, size: 11, color: AppColors.yellow),
          SizedBox(width: 4),
          Text(
            'Belum sync',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.yellow,
            ),
          ),
        ],
      ),
    );
  }
}
