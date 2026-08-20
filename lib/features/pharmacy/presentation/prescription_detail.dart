import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_badge.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_shimmer.dart';
import '../../patients/data/patient_repository.dart';
import '../../patients/domain/doctor.dart';
import '../../patients/domain/patient.dart';
import '../../patients/domain/prescription_item.dart';
import '../../patients/presentation/patient_info_card.dart';
import '../../patients/presentation/status_meta.dart';
import 'prescription_medicine_row.dart';

/// Port of the prototype's `PrescriptionDetail` — process a prescription through
/// baru -> diproses -> selesai, with per-drug substitution along the way.
class PrescriptionDetail extends ConsumerStatefulWidget {
  const PrescriptionDetail({super.key, required this.patientId});

  final String patientId;

  @override
  ConsumerState<PrescriptionDetail> createState() => _PrescriptionDetailState();
}

class _PrescriptionDetailState extends ConsumerState<PrescriptionDetail> {
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant PrescriptionDetail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.patientId != widget.patientId) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    await Future.wait([
      ref.read(patientsProvider.notifier).fetchPatientDetail(widget.patientId),
      Future.delayed(const Duration(milliseconds: 250)),
    ]);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _handleStatusChange(
    Patient patient,
    ResepStatus newStatus,
  ) async {
    setState(() => _saving = true);
    try {
      await ref
          .read(patientsProvider.notifier)
          .setResepStatus(patient.id, newStatus);
      if (!mounted) return;
      if (newStatus == ResepStatus.selesai) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Obat telah diserahkan & status penanganan pasien telah Selesai di API!',
            ),
            backgroundColor: AppColors.green,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memperbarui status ke API: $e'),
          backgroundColor: AppColors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final patients = ref.watch(patientsProvider);
    final patient = patients.where((p) => p.id == widget.patientId).firstOrNull;
    if (_loading || patient == null) {
      return const SkeletonPatientDetail();
    }
    final doctor = kDoctors
        .where((d) => d.id == patient.assignedDokterId)
        .firstOrNull;
    final meta = statusMeta(patient);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PatientInfoCard(patient: patient),
        const SizedBox(height: 14),
        Container(
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.yellow.withValues(alpha: 0.35),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.yellow.withValues(alpha: 0.05),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with Doctor & Status
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.yellowLt,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            LucideIcons.fileText,
                            size: 19,
                            color: AppColors.yellow,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'RESEP OBAT PASIEN',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                                color: AppColors.text,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Dokter: ${doctor?.nama ?? 'Dokter Pemeriksa'}',
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: AppColors.sub,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    AppBadge(
                      label: meta.label,
                      color: meta.color,
                      background: meta.background,
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, thickness: 1, color: AppColors.border),

              // Card Body
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Diagnosa Box
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.card2,
                        borderRadius: BorderRadius.circular(10),
                        border: const Border(
                          left: BorderSide(color: AppColors.blue, width: 3.5),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'DIAGNOSA KLINIS',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                              color: AppColors.sub,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            (patient.diagnosa != null &&
                                    patient.diagnosa!.trim().isNotEmpty)
                                ? patient.diagnosa!.trim()
                                : '—',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.text,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Resep Obat Items Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: const [
                            Icon(
                              LucideIcons.pill,
                              size: 15,
                              color: AppColors.yellow,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Daftar Obat yang Diresepkan',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.text,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.yellowLt,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${patient.resep.length} Item Obat',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: AppColors.yellow,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Medicine Rows
                    for (int i = 0; i < patient.resep.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: ResepObatRow(
                          index: i,
                          item: patient.resep[i],
                          disabled: patient.resepStatus == ResepStatus.selesai,
                          onGanti: (obatBaru, alasan) => ref
                              .read(patientsProvider.notifier)
                              .gantiObat(patient.id, i, obatBaru, alasan),
                        ),
                      ),
                    const SizedBox(height: 14),

                    // Action Buttons
                    if (patient.resepStatus == ResepStatus.baru)
                      AppButton(
                        label: 'Mulai Proses Penyiapan Obat',
                        icon: LucideIcons.play,
                        full: true,
                        loading: _saving,
                        onPressed: _saving
                            ? null
                            : () => _handleStatusChange(
                                patient,
                                ResepStatus.diproses,
                              ),
                      ),
                    if (patient.resepStatus == ResepStatus.diproses)
                      AppButton(
                        label: 'Tandai Selesai & Serahkan ke Pasien',
                        icon: LucideIcons.checkCheck,
                        full: true,
                        loading: _saving,
                        variant: AppButtonVariant.success,
                        onPressed: _saving
                            ? null
                            : () => _handleStatusChange(
                                patient,
                                ResepStatus.selesai,
                              ),
                      ),
                    if (patient.resepStatus == ResepStatus.selesai)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.greenLt,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppColors.green.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(
                              LucideIcons.checkCircle2,
                              size: 18,
                              color: AppColors.green,
                            ),
                            SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'Obat telah selesai diserahkan ke pasien',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: AppColors.green,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
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
