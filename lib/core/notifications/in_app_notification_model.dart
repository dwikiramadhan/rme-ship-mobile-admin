import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_colors.dart';

enum InAppNotificationType {
  doctor,
  pharmacy,
  lab,
  schedule,
  warning,
  info,
}

class InAppNotificationItem {
  const InAppNotificationItem({
    required this.id,
    required this.title,
    required this.message,
    this.type = InAppNotificationType.info,
    this.patientId,
    this.actionLabel,
    this.onTap,
    this.timestamp,
  });

  final String id;
  final String title;
  final String message;
  final InAppNotificationType type;
  final String? patientId;
  final String? actionLabel;
  final VoidCallback? onTap;
  final DateTime? timestamp;

  IconData get icon {
    switch (type) {
      case InAppNotificationType.doctor:
        return LucideIcons.stethoscope;
      case InAppNotificationType.pharmacy:
        return LucideIcons.pill;
      case InAppNotificationType.lab:
        return LucideIcons.flaskConical;
      case InAppNotificationType.schedule:
        return LucideIcons.calendarDays;
      case InAppNotificationType.warning:
        return LucideIcons.triangleAlert;
      case InAppNotificationType.info:
        return LucideIcons.bell;
    }
  }

  Color get color {
    switch (type) {
      case InAppNotificationType.doctor:
        return AppColors.blue;
      case InAppNotificationType.pharmacy:
        return AppColors.green;
      case InAppNotificationType.lab:
        return const Color(0xFF8B5CF6); // Ungu Lab
      case InAppNotificationType.schedule:
        return AppColors.orange;
      case InAppNotificationType.warning:
        return AppColors.red;
      case InAppNotificationType.info:
        return AppColors.blue;
    }
  }

  Color get backgroundColor {
    switch (type) {
      case InAppNotificationType.doctor:
        return AppColors.blueLt;
      case InAppNotificationType.pharmacy:
        return AppColors.greenLt;
      case InAppNotificationType.lab:
        return const Color(0xFFF3E8FF);
      case InAppNotificationType.schedule:
        return const Color(0xFFFFEDD5);
      case InAppNotificationType.warning:
        return AppColors.redLt;
      case InAppNotificationType.info:
        return AppColors.blueLt;
    }
  }

  String get categoryLabel {
    switch (type) {
      case InAppNotificationType.doctor:
        return 'DOKTER';
      case InAppNotificationType.pharmacy:
        return 'FARMASI';
      case InAppNotificationType.lab:
        return 'LABORATORIUM';
      case InAppNotificationType.schedule:
        return 'JADWAL';
      case InAppNotificationType.warning:
        return 'PERINGATAN';
      case InAppNotificationType.info:
        return 'NOTIFIKASI';
    }
  }
}
