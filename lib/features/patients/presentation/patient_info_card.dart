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
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                child: Row(
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
              ),
              const Divider(height: 1, thickness: 1, color: AppColors.border),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: const BoxDecoration(
                  color: AppColors.card2,
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(14)),
                ),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _MuiPatientMetaItem(
                      icon: LucideIcons.creditCard,
                      label: 'NIK',
                      value: patient.nik,
                    ),
                    _MuiPatientMetaItem(
                      icon: LucideIcons.calendar,
                      label: 'Terdaftar',
                      value: patient.waktuMasuk,
                    ),
                    if (doctor != null)
                      _MuiPatientMetaItem(
                        icon: LucideIcons.stethoscope,
                        label: 'Dokter',
                        value: doctor.nama,
                        accentColor: AppColors.orange,
                      ),
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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.orangeLt,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      LucideIcons.clipboardList,
                      size: 15,
                      color: AppColors.orange,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'KELUHAN AWAL',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: AppColors.orange,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 11),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.card2,
                  borderRadius: BorderRadius.circular(10),
                  border: const Border(
                    left: BorderSide(color: AppColors.orange, width: 3.5),
                  ),
                ),
                child: Text(
                  patient.keluhanUtama.trim().isNotEmpty ? patient.keluhanUtama.trim() : 'Tidak ada catatan keluhan utama',
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text,
                  ),
                ),
              ),
              const SizedBox(height: 11),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _MuiMetaChip(
                    icon: LucideIcons.clock,
                    label: 'Durasi',
                    value: patient.durasiKeluhan.isNotEmpty ? patient.durasiKeluhan : '—',
                  ),
                  _MuiMetaChip(
                    icon: LucideIcons.mapPin,
                    label: 'Lokasi',
                    value: patient.lokasiKeluhan.isNotEmpty ? patient.lokasiKeluhan : '—',
                  ),
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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.orangeLt,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      LucideIcons.activity,
                      size: 15,
                      color: AppColors.orange,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'TANDA VITAL',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: AppColors.orange,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 11),
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

class _MuiMetaChip extends StatelessWidget {
  const _MuiMetaChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.card2,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.sub),
          const SizedBox(width: 5),
          Text(
            '$label: ',
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: AppColors.sub,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: AppColors.text,
            ),
          ),
        ],
      ),
    );
  }
}

class _MuiPatientMetaItem extends StatelessWidget {
  const _MuiPatientMetaItem({
    required this.icon,
    required this.label,
    required this.value,
    this.accentColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final color = accentColor ?? AppColors.sub;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            '$label: ',
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: AppColors.sub,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: accentColor ?? AppColors.text,
            ),
          ),
        ],
      ),
    );
  }
}
