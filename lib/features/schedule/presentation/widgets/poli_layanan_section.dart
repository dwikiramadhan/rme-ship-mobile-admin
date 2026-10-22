import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/schedule_api.dart';
import '../../domain/trip_schedule.dart';
import 'edit_clinics_modal.dart';

/// Opens the clinic editor of [schedule] and saves it (Koordinator).
void editScheduleClinics(
  BuildContext context,
  WidgetRef ref,
  JadwalPerjalanan schedule,
) {
  EditClinicsModal.show(
    context,
    schedule: schedule,
    onSave: (body) async {
      final api = ScheduleApi();
      await api.updateSchedule(schedule.id, body);
      ref.invalidate(scheduleCounterProvider);
      ref.invalidate(assignedTripsProvider);
      await ref.read(schedulesNotifierProvider.notifier).refresh();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Poli layanan berhasil diperbarui'),
            backgroundColor: AppColors.green,
          ),
        );
      }
    },
  );
}

/// "Daftar Poli Layanan" of the trip under way. With [onEdit] the clinics
/// can be changed (Koordinator); without it the list is read-only.
class PoliLayananSection extends StatelessWidget {
  const PoliLayananSection({
    super.key,
    required this.schedule,
    required this.clinics,
    this.onEdit,
  });

  final JadwalPerjalanan? schedule;
  final List<ScheduleClinicItem> clinics;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final schedule = this.schedule;
    final onEdit = this.onEdit;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              LucideIcons.building2,
              size: 16,
              color: Color(0xFF475569),
            ),
            const SizedBox(width: 8),
            const Text(
              'DAFTAR POLI LAYANAN',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
                color: Color(0xFF475569),
              ),
            ),
            const Spacer(),
            if (schedule != null && onEdit != null)
              InkWell(
                onTap: onEdit,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.orangeLt,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.orange.withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        LucideIcons.pencilLine,
                        size: 13,
                        color: AppColors.orange,
                      ),
                      SizedBox(width: 5),
                      Text(
                        'Atur Poli',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.orange,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (schedule == null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: const Column(
              children: [
                Icon(LucideIcons.calendarX, size: 36, color: Color(0xFF94A3B8)),
                SizedBox(height: 10),
                Text(
                  'Tidak ada jadwal pelayaran aktif',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Poli layanan dapat diatur setelah jadwal pelayaran tersedia.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: AppColors.sub),
                ),
              ],
            ),
          )
        else if (clinics.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                const Icon(
                  LucideIcons.building2,
                  size: 40,
                  color: Color(0xFF94A3B8),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Belum ada Poli Layanan terdaftar',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Poli layanan untuk jadwal pelayaran ini belum dikonfigurasi.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: AppColors.sub),
                ),
                if (onEdit != null) ...[
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: onEdit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.orange,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                    icon: const Icon(
                      LucideIcons.pencilLine,
                      size: 15,
                      color: Colors.white,
                    ),
                    label: const Text(
                      'Atur Poli Layanan',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: clinics.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final clinic = clinics[index];
              return _clinicCard(clinic);
            },
          ),
      ],
    );
  }

  Widget _clinicCard(ScheduleClinicItem clinic) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFED7AA)),
            ),
            child: const Icon(
              LucideIcons.building2,
              color: Color(0xFFEA580C),
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        clinic.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.text,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1.5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        clinic.code.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    const Icon(
                      LucideIcons.clock,
                      size: 12,
                      color: Color(0xFF94A3B8),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Jam Layanan: ${clinic.operationalHours}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF475569),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFA7F3D0)),
            ),
            child: const Text(
              'Aktif',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF059669),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
