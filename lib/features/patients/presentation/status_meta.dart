import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../domain/lab_order.dart';
import '../domain/patient.dart';
import '../domain/prescription_item.dart';

class StatusMeta {
  const StatusMeta({required this.label, required this.color, required this.background});
  final String label;
  final Color color;
  final Color background;
}

/// Returns a single badge summarising patient clinical workflow status.
StatusMeta statusMeta(Patient p) {
  // 1. Direct mapping from backend status_penanganan if available
  if (p.statusPenanganan != null && p.statusPenanganan!.trim().isNotEmpty) {
    final sp = p.statusPenanganan!.trim();
    switch (sp) {
      case 'Menunggu Dokter':
        return const StatusMeta(label: 'Menunggu Dokter', color: AppColors.orange, background: AppColors.orangeLt);
      case 'Diperiksa':
        return const StatusMeta(label: 'Diperiksa', color: AppColors.blue, background: AppColors.blueLt);
      case 'Menunggu Obat':
        return const StatusMeta(label: 'Menunggu Obat', color: AppColors.yellow, background: AppColors.yellowLt);
      case 'Menunggu Lab':
        return const StatusMeta(label: 'Menunggu Lab', color: AppColors.purple, background: AppColors.purpleLt);
      case 'Selesai':
        return const StatusMeta(label: 'Selesai', color: AppColors.green, background: AppColors.greenLt);
      default:
        return StatusMeta(label: sp, color: AppColors.blue, background: AppColors.blueLt);
    }
  }

  // 2. Lab order status fallback
  if (p.labOrder != null) {
    if (p.labOrder!.status == LabOrderStatus.selesai) {
      return const StatusMeta(label: 'Hasil Lab Ada', color: AppColors.purple, background: AppColors.purpleLt);
    }
    return const StatusMeta(label: 'Tunggu Lab', color: AppColors.purple, background: AppColors.purpleLt);
  }

  // 3. Prescription / Pharmacy workflow status fallback
  if (p.resepStatus == ResepStatus.diproses) {
    return const StatusMeta(label: 'Resep Diproses', color: AppColors.yellow, background: AppColors.yellowLt);
  }
  if (p.resepStatus == ResepStatus.selesai) {
    return const StatusMeta(label: 'Selesai', color: AppColors.green, background: AppColors.greenLt);
  }
  if (p.resepStatus == ResepStatus.baru) {
    return const StatusMeta(label: 'Resep Baru', color: AppColors.yellow, background: AppColors.yellowLt);
  }

  // 4. Doctor examination status fallback
  if (p.status == PatientStatus.diperiksa || (p.diagnosa != null && p.diagnosa!.isNotEmpty)) {
    return const StatusMeta(label: 'Diperiksa', color: AppColors.blue, background: AppColors.blueLt);
  }

  // 5. Default: Menunggu Dokter
  return const StatusMeta(label: 'Menunggu Dokter', color: AppColors.orange, background: AppColors.orangeLt);
}
