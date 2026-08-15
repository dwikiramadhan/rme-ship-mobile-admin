import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../domain/lab_order.dart';
import '../domain/patient.dart';
import '../domain/resep_item.dart';

class StatusMeta {
  const StatusMeta({required this.label, required this.color, required this.background});
  final String label;
  final Color color;
  final Color background;
}

/// Port of the prototype's `statusMeta(p)` — a single badge summarising
/// where a patient currently sits in the Perawat -> Dokter -> Apotek/Lab flow.
StatusMeta statusMeta(Patient p) {
  final labOrder = p.labOrder;
  if (labOrder != null && labOrder.status == LabOrderStatus.selesai && !p.dilihatDokterLab) {
    return const StatusMeta(label: 'Hasil Lab Siap', color: AppColors.green, background: AppColors.greenLt);
  }
  if (labOrder != null && labOrder.status != LabOrderStatus.selesai) {
    return const StatusMeta(label: 'Menunggu Lab', color: AppColors.purple, background: AppColors.purpleLt);
  }
  if (p.resepStatus == ResepStatus.selesai) {
    return const StatusMeta(label: 'Selesai', color: AppColors.sub, background: AppColors.card2);
  }
  if (p.resepStatus == ResepStatus.diproses) {
    return const StatusMeta(label: 'Resep Diproses', color: AppColors.blue, background: AppColors.blueLt);
  }
  if (p.resepStatus == ResepStatus.baru) {
    return const StatusMeta(label: 'Resep Baru', color: AppColors.yellow, background: AppColors.yellowLt);
  }
  if (p.status == PatientStatus.diperiksa) {
    return const StatusMeta(label: 'Sedang Diperiksa', color: AppColors.blue, background: AppColors.blueLt);
  }
  return const StatusMeta(label: 'Menunggu Dokter', color: AppColors.yellow, background: AppColors.yellowLt);
}
