import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_badge.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../patients/data/patient_repository.dart';
import '../../patients/domain/doctor.dart';
import '../../patients/domain/prescription_item.dart';
import '../../patients/presentation/patient_info_card.dart';
import '../../patients/presentation/status_meta.dart';
import 'prescription_medicine_row.dart';

/// Port of the prototype's `PrescriptionDetail` — process a prescription through
/// baru -> diproses -> selesai, with per-drug substitution along the way.
class PrescriptionDetail extends ConsumerWidget {
  const PrescriptionDetail({super.key, required this.patientId});

  final String patientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patients = ref.watch(patientsProvider);
    final patient = patients.firstWhere((p) => p.id == patientId);
    final doctor = kDoctors.where((d) => d.id == patient.assignedDokterId).firstOrNull;
    final meta = statusMeta(patient);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PatientInfoCard(patient: patient),
        const SizedBox(height: 11),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'RESEP DARI ${(doctor?.nama ?? '').toUpperCase()}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.blue),
                    ),
                  ),
                  AppBadge(label: meta.label, color: meta.color, background: meta.background),
                ],
              ),
              const SizedBox(height: 10),
              Text.rich(
                TextSpan(
                  style: const TextStyle(fontSize: 12.5, color: AppColors.sub),
                  children: [
                    const TextSpan(text: 'Diagnosa: '),
                    TextSpan(text: patient.diagnosa ?? '', style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              for (int i = 0; i < patient.resep.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: ResepObatRow(
                    item: patient.resep[i],
                    disabled: patient.resepStatus == ResepStatus.selesai,
                    onGanti: (obatBaru, alasan) => ref.read(patientsProvider.notifier).gantiObat(patient.id, i, obatBaru, alasan),
                  ),
                ),
              const SizedBox(height: 6),
              if (patient.resepStatus == ResepStatus.baru)
                AppButton(
                  label: 'Mulai Proses',
                  full: true,
                  onPressed: () => ref.read(patientsProvider.notifier).setResepStatus(patient.id, ResepStatus.diproses),
                ),
              if (patient.resepStatus == ResepStatus.diproses)
                AppButton(
                  label: 'Tandai Selesai & Serahkan',
                  icon: LucideIcons.check,
                  full: true,
                  variant: AppButtonVariant.success,
                  onPressed: () => ref.read(patientsProvider.notifier).setResepStatus(patient.id, ResepStatus.selesai),
                ),
              if (patient.resepStatus == ResepStatus.selesai)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Center(
                    child: Text('✓ Obat telah diserahkan ke pasien', style: TextStyle(color: AppColors.green, fontWeight: FontWeight.w700, fontSize: 13)),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

typedef ResepDetail = PrescriptionDetail;

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
