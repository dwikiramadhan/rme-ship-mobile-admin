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

/// Returns StatusMeta directly from backend status_penanganan string.
StatusMeta statusMetaFromPenanganan(String? statusPenanganan) {
  if (statusPenanganan != null && statusPenanganan.trim().isNotEmpty) {
    final sp = statusPenanganan.trim();
    final lower = sp.toLowerCase();
    if (lower.contains('menunggu dokter') || lower == 'antrian' || lower == 'waiting') {
      return StatusMeta(label: sp, color: AppColors.orange, background: AppColors.orangeLt);
    } else if (lower.contains('periksa') || lower == 'diperiksa' || lower == 'sedang diperiksa' || lower == 'examining') {
      return StatusMeta(label: sp, color: AppColors.blue, background: AppColors.blueLt);
    } else if (lower.contains('obat') || lower == 'farmasi' || lower.contains('resep')) {
      return StatusMeta(label: sp, color: AppColors.yellow, background: AppColors.yellowLt);
    } else if (lower.contains('lab')) {
      return StatusMeta(label: sp, color: const Color(0xFF0284C7), background: const Color(0xFFF0F9FF));
    } else if (lower.contains('selesai') || lower == 'completed' || lower == 'done') {
      return StatusMeta(label: sp, color: AppColors.green, background: AppColors.greenLt);
    } else if (lower.contains('batal') || lower.contains('cancel')) {
      return StatusMeta(label: sp, color: AppColors.red, background: AppColors.redLt);
    } else {
      return StatusMeta(label: sp, color: AppColors.blue, background: AppColors.blueLt);
    }
  }
  return const StatusMeta(label: 'Menunggu Dokter', color: AppColors.orange, background: AppColors.orangeLt);
}

/// Returns a single badge summarising patient clinical workflow status.
StatusMeta statusMeta(Patient p) {
  // 1. Direct mapping from backend status_penanganan if available
  if (p.statusPenanganan != null && p.statusPenanganan!.trim().isNotEmpty) {
    return statusMetaFromPenanganan(p.statusPenanganan);
  }

  // 2. Lab order status fallback
  if (p.labOrder != null) {
    if (p.labOrder!.status == LabOrderStatus.selesai) {
      return const StatusMeta(label: 'Hasil Lab Ada', color: Color(0xFF0284C7), background: Color(0xFFF0F9FF));
    }
    return const StatusMeta(label: 'Tunggu Lab', color: Color(0xFF0284C7), background: Color(0xFFF0F9FF));
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

