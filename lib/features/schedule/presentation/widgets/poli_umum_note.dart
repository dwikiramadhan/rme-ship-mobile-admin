import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';

/// Shown when the ongoing trip has no doctor to assign a visit to.
const String noTripDoctorsMessage =
    'Belum ada dokter di jadwal perjalanan Ongoing.';

/// Shown instead of the doctor picker for Poli Umum, which needs no assigned
/// doctor: every doctor on the ongoing trip is told about the patient.
class PoliUmumDoctorsNote extends StatelessWidget {
  const PoliUmumDoctorsNote({
    super.key,
    required this.doctorCount,
    this.loading = false,
  });

  final int doctorCount;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final String text;
    if (loading) {
      text = 'Memuat dokter di jadwal perjalanan...';
    } else if (doctorCount > 0) {
      text =
          'Poli Umum tidak perlu Assign Dokter. Semua dokter di jadwal '
          'perjalanan Ongoing ($doctorCount dokter) akan menerima notifikasi, '
          'dan dokter pertama yang memeriksa tercatat sebagai dokter pasien ini.';
    } else {
      text =
          'Poli Umum tidak perlu Assign Dokter. $noTripDoctorsMessage '
          'Belum ada yang menerima notifikasi.';
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.blueLt,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.blue.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(LucideIcons.users, size: 16, color: AppColors.blue),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 10.5, color: AppColors.text),
            ),
          ),
        ],
      ),
    );
  }
}
