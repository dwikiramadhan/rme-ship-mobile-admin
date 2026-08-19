import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../domain/patient.dart';

class StatusMeta {
  const StatusMeta({required this.label, required this.color, required this.background});
  final String label;
  final Color color;
  final Color background;
}

/// Returns a single badge summarising patient status directly from database (`patients.status`).
StatusMeta statusMeta(Patient p) {
  final status = p.dbStatus.trim();
  final lower = status.toLowerCase();

  if (lower == 'stable' || lower == 'stabil') {
    return const StatusMeta(label: 'Stabil', color: AppColors.green, background: AppColors.greenLt);
  }
  if (lower == 'kritis' || lower == 'critical') {
    return const StatusMeta(label: 'Kritis', color: AppColors.red, background: AppColors.redLt);
  }
  if (lower == 'discharged' || lower == 'pulang' || lower == 'selesai') {
    return const StatusMeta(label: 'Pulang', color: AppColors.sub, background: AppColors.card2);
  }
  if (lower == 'monitoring' || lower == 'observasi') {
    return const StatusMeta(label: 'Monitoring', color: AppColors.blue, background: AppColors.blueLt);
  }
  if (status.isNotEmpty) {
    return StatusMeta(label: status, color: AppColors.blue, background: AppColors.blueLt);
  }

  return const StatusMeta(label: 'Monitoring', color: AppColors.blue, background: AppColors.blueLt);
}
