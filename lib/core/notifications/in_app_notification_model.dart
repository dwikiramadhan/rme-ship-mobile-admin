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

  IconData get icon => switch (type) {
        InAppNotificationType.doctor => LucideIcons.stethoscope,
        InAppNotificationType.pharmacy => LucideIcons.pill,
        InAppNotificationType.lab => LucideIcons.flaskConical,
        InAppNotificationType.schedule => LucideIcons.calendarDays,
        InAppNotificationType.warning => LucideIcons.triangleAlert,
        InAppNotificationType.info => LucideIcons.bell,
      };

  Color get color => switch (type) {
        InAppNotificationType.doctor => AppColors.blue,
        InAppNotificationType.pharmacy => AppColors.green,
        InAppNotificationType.lab => const Color(0xFF8B5CF6), // Ungu Lab
        InAppNotificationType.schedule => AppColors.orange,
        InAppNotificationType.warning => AppColors.red,
        InAppNotificationType.info => AppColors.blue,
      };

  Color get backgroundColor => switch (type) {
        InAppNotificationType.doctor => AppColors.blueLt,
        InAppNotificationType.pharmacy => AppColors.greenLt,
        InAppNotificationType.lab => const Color(0xFFF3E8FF),
        InAppNotificationType.schedule => const Color(0xFFFFEDD5),
        InAppNotificationType.warning => AppColors.redLt,
        InAppNotificationType.info => AppColors.blueLt,
      };

  String get categoryLabel => switch (type) {
        InAppNotificationType.doctor => 'DOKTER',
        InAppNotificationType.pharmacy => 'FARMASI',
        InAppNotificationType.lab => 'LABORATORIUM',
        InAppNotificationType.schedule => 'JADWAL',
        InAppNotificationType.warning => 'PERINGATAN',
        InAppNotificationType.info => 'NOTIFIKASI',
      };
}
