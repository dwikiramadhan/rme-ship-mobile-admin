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
  if (statusPenanganan == null || statusPenanganan.trim().isEmpty) {
    return const StatusMeta(label: 'Menunggu Dokter', color: AppColors.orange, background: AppColors.orangeLt);
  }
  final sp = statusPenanganan.trim();
  final lower = sp.toLowerCase();
  return switch (lower) {
    _ when lower.contains('menunggu dokter') || lower == 'antrian' || lower == 'waiting' =>
      StatusMeta(label: sp, color: AppColors.orange, background: AppColors.orangeLt),
    _ when lower.contains('periksa') || lower == 'diperiksa' || lower == 'sedang diperiksa' || lower == 'examining' =>
      StatusMeta(label: sp, color: AppColors.blue, background: AppColors.blueLt),
    _ when lower.contains('obat') || lower == 'farmasi' || lower.contains('resep') =>
      StatusMeta(label: sp, color: AppColors.yellow, background: AppColors.yellowLt),
    _ when lower.contains('lab') =>
      StatusMeta(label: sp, color: const Color(0xFF0284C7), background: const Color(0xFFF0F9FF)),
    _ when lower.contains('selesai') || lower == 'completed' || lower == 'done' =>
      StatusMeta(label: sp, color: AppColors.green, background: AppColors.greenLt),
    _ when lower.contains('batal') || lower.contains('cancel') =>
      StatusMeta(label: sp, color: AppColors.red, background: AppColors.redLt),
    _ =>
      StatusMeta(label: sp, color: AppColors.blue, background: AppColors.blueLt),
  };
}

/// Returns a single badge summarising patient clinical workflow status.
StatusMeta statusMeta(Patient p) {
  // 1. Direct mapping from backend status_penanganan if available
  if (p.statusPenanganan case final sp? when sp.trim().isNotEmpty) {
    return statusMetaFromPenanganan(sp);
  }

  // 2. Lab order status fallback
  if (p.labOrder case final labOrder?) {
    return switch (labOrder.status) {
      LabOrderStatus.selesai => const StatusMeta(label: 'Hasil Lab Ada', color: Color(0xFF0284C7), background: Color(0xFFF0F9FF)),
      _ => const StatusMeta(label: 'Tunggu Lab', color: Color(0xFF0284C7), background: Color(0xFFF0F9FF)),
    };
  }

  // 3. Prescription & doctor examination workflow fallback
  return switch (p.resepStatus) {
    ResepStatus.diproses => const StatusMeta(label: 'Resep Diproses', color: AppColors.yellow, background: AppColors.yellowLt),
    ResepStatus.selesai => const StatusMeta(label: 'Selesai', color: AppColors.green, background: AppColors.greenLt),
    ResepStatus.baru => const StatusMeta(label: 'Resep Baru', color: AppColors.yellow, background: AppColors.yellowLt),
    _ when p.status == PatientStatus.diperiksa || (p.diagnosa?.isNotEmpty ?? false) =>
      const StatusMeta(label: 'Diperiksa', color: AppColors.blue, background: AppColors.blueLt),
    _ => const StatusMeta(label: 'Menunggu Dokter', color: AppColors.orange, background: AppColors.orangeLt),
  };
}

