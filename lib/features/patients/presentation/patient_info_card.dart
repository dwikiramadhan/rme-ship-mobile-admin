import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/clean_text_helper.dart';
import '../../../core/widgets/app_card.dart';
import '../domain/patient.dart';

/// Port of the prototype's `PatientInfoCard` — the identity +
/// keluhan + vitals summary shown in every role's detail pane,
/// with optional [onEdit] action for Perawat / Admin.
class PatientInfoCard extends StatelessWidget {
  const PatientInfoCard({
    super.key,
    required this.patient,
    this.onEdit,
    this.showKeluhanAwal = false,
  });

  final Patient patient;
  final VoidCallback? onEdit;
  final bool showKeluhanAwal;

  @override
  Widget build(BuildContext context) {
    final cleanNama = CleanTextHelper.cleanName(patient.nama, fallback: 'Pasien');
    final cleanNik = CleanTextHelper.cleanCode(patient.nik);

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
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFFFFEDD5), Color(0xFFFED7AA)],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppColors.orange.withValues(alpha: 0.25),
                          width: 1.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.orange.withValues(alpha: 0.12),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Text(
                        cleanNama.isNotEmpty ? cleanNama[0] : '?',
                        style: const TextStyle(
                          color: AppColors.orange,
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  cleanNama,
                                  style: const TextStyle(
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.text,
                                  ),
                                ),
                              ),
                              if (onEdit != null)
                                Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: onEdit,
                                    borderRadius: BorderRadius.circular(6),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                        vertical: 2,
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: const [
                                          Icon(
                                            LucideIcons.edit2,
                                            size: 13,
                                            color: AppColors.blue,
                                          ),
                                          SizedBox(width: 4),
                                          Text(
                                            'Edit',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.blue,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${patient.jk.label} • ${patient.umur} tahun',
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: AppColors.sub,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Icon(
                                LucideIcons.mapPin,
                                size: 12,
                                color: AppColors.sub,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  patient.alamat,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.sub,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 9,
                ),
                decoration: const BoxDecoration(
                  color: AppColors.card2,
                  border: Border(
                    top: BorderSide(color: AppColors.border, width: 0.8),
                  ),
                ),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _MuiPatientMetaItem(
                      icon: LucideIcons.creditCard,
                      label: 'NIK',
                      value: cleanNik.isNotEmpty ? cleanNik : '—',
                    ),
                    if (patient.bloodType != null &&
                        patient.bloodType!.isNotEmpty &&
                        patient.bloodType != '-')
                      _MuiPatientMetaItem(
                        icon: LucideIcons.droplet,
                        label: 'Gol. Darah',
                        value: patient.bloodType!,
                        accentColor: AppColors.red,
                      ),
                    _MuiPatientMetaItem(
                      icon: LucideIcons.calendar,
                      label: 'Terdaftar',
                      value: patient.waktuMasuk,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (showKeluhanAwal) ...[
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
                        color: AppColors.orange,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 11),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.orangeLt.withValues(alpha: 0.6),
                        AppColors.card2,
                      ],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                    border: const Border(
                      left: BorderSide(color: AppColors.orange, width: 3.5),
                    ),
                  ),
                  child: Text(
                    patient.keluhanUtama.trim().isNotEmpty
                        ? patient.keluhanUtama.trim()
                        : 'Tidak ada catatan keluhan utama',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.text,
                      height: 1.35,
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
                      value: patient.durasiKeluhan.isNotEmpty
                          ? patient.durasiKeluhan
                          : '—',
                    ),
                    _MuiMetaChip(
                      icon: LucideIcons.mapPin,
                      label: 'Lokasi',
                      value: patient.lokasiKeluhan.isNotEmpty
                          ? patient.lokasiKeluhan
                          : '—',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
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
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: (accentColor != null)
              ? accentColor!.withValues(alpha: 0.25)
              : const Color(0xFFE2E8F0),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
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
              color: accentColor != null ? AppColors.orange : AppColors.text,
            ),
          ),
        ],
      ),
    );
  }
}
