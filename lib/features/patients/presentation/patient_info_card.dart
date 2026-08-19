import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/vital_tile.dart';
import '../data/patient_repository.dart';
import '../domain/doctor.dart';
import '../domain/patient.dart';

/// Port of the prototype's `PatientInfoCard` — the identity +
/// keluhan + vitals summary shown in every role's detail pane,
/// with optional [onEdit] action for Perawat / Admin.
class PatientInfoCard extends ConsumerWidget {
  const PatientInfoCard({
    super.key,
    required this.patient,
    this.onEdit,
  });

  final Patient patient;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final doctorsList = ref.watch(doctorsProvider).valueOrNull ?? kDoctors;
    Doctor? doctor;
    for (final d in doctorsList) {
      if (d.id == patient.assignedDokterId) {
        doctor = d;
        break;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: AppColors.blueLt, borderRadius: BorderRadius.circular(14)),
                    child: Text(
                      patient.nama.isNotEmpty ? patient.nama[0] : '?',
                      style: const TextStyle(color: AppColors.blue, fontWeight: FontWeight.w800, fontSize: 18),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(patient.nama, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.text)),
                        const SizedBox(height: 1),
                        Text(
                          '${patient.jk.label} · ${patient.umur} tahun · ${patient.alamat}',
                          style: const TextStyle(fontSize: 12, color: AppColors.sub),
                        ),
                      ],
                    ),
                  ),
                  if (onEdit != null)
                    AppButton(
                      label: 'Edit',
                      icon: LucideIcons.pencil,
                      small: true,
                      variant: AppButtonVariant.ghost,
                      onPressed: onEdit,
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.only(top: 9),
                decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
                child: Wrap(
                  spacing: 14,
                  runSpacing: 4,
                  children: [
                    Text('NIK: ${patient.nik}', style: const TextStyle(fontSize: 11.5, color: AppColors.sub)),
                    Text('Terdaftar: ${patient.waktuMasuk}', style: const TextStyle(fontSize: 11.5, color: AppColors.sub)),
                    if (doctor != null) Text('Dokter: ${doctor.nama}', style: const TextStyle(fontSize: 11.5, color: AppColors.sub)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 11),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Keluhan Awal', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.text)),
              const SizedBox(height: 9),
              Text(patient.keluhanUtama, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text)),
              const SizedBox(height: 5),
              Wrap(
                spacing: 14,
                runSpacing: 2,
                children: [
                  Text('Durasi: ${patient.durasiKeluhan}', style: const TextStyle(fontSize: 12, color: AppColors.sub)),
                  Text('Lokasi: ${patient.lokasiKeluhan}', style: const TextStyle(fontSize: 12, color: AppColors.sub)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 11),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Tanda Vital', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.text)),
              const SizedBox(height: 10),
              LayoutBuilder(
                builder: (context, constraints) {
                  final w = constraints.maxWidth;
                  final int crossAxisCount = w >= 700
                      ? 5
                      : (w >= 440 ? 3 : 2);
                  final double childAspectRatio = w >= 700
                      ? 2.1
                      : (w >= 440 ? 2.6 : 2.5);
                  return GridView.count(
                    padding: EdgeInsets.zero,
                    crossAxisCount: crossAxisCount,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: childAspectRatio,
                    children: [
                      VitalTile(icon: LucideIcons.heart, label: 'Tekanan Darah', value: patient.vitals.tekananDarah, unit: 'mmHg', color: AppColors.red),
                      VitalTile(icon: LucideIcons.activity, label: 'Nadi', value: patient.vitals.nadi, unit: 'bpm', color: AppColors.blue),
                      VitalTile(icon: LucideIcons.thermometer, label: 'Suhu Tubuh', value: patient.vitals.suhu, unit: '°C', color: AppColors.yellow),
                      VitalTile(icon: LucideIcons.activity, label: 'Frek. Napas', value: patient.vitals.frekuensiNapas, unit: 'x/mnt', color: AppColors.purple),
                      VitalTile(icon: LucideIcons.droplet, label: 'SpO₂', value: patient.vitals.spo2, unit: '%', color: AppColors.green),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
