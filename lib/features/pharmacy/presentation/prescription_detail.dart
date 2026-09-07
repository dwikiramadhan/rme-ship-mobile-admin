import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/clean_text_helper.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_shimmer.dart';
import '../../doctor/data/icd10_api.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../patients/data/patient_repository.dart';
import '../../patients/domain/doctor.dart';
import '../../patients/domain/patient.dart';
import '../../patients/domain/prescription_item.dart';
import '../../patients/presentation/patient_info_card.dart';
import 'prescription_medicine_row.dart';

/// Port of the prototype's `PrescriptionDetail` — process a prescription through
/// baru -> diproses -> selesai, with per-drug substitution along the way.
class PrescriptionDetail extends ConsumerStatefulWidget {
  const PrescriptionDetail({super.key, required this.patientId, this.medRecId});

  final String patientId;
  final String? medRecId;

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
    if (oldWidget.patientId != widget.patientId ||
        oldWidget.medRecId != widget.medRecId) {
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
      if (newStatus == ResepStatus.selesai) {
        final medRecId =
            (widget.medRecId != null && widget.medRecId!.isNotEmpty)
            ? widget.medRecId!
            : ((patient.medicalRecordId != null &&
                      patient.medicalRecordId!.isNotEmpty)
                  ? patient.medicalRecordId!
                  : patient.id);

        final authState = ref.read(authControllerProvider);
        final dispensedById = authState.session?.user.id ?? '';

        await ref
            .read(patientsProvider.notifier)
            .dispensePrescription(
              medRecId: medRecId,
              patientId: patient.id,
              dispensedById: dispensedById,
              items: patient.resep,
            );

        // Refresh real prescription list for pharmacy
        ref
            .read(pharmacyPrescriptionHistoryProvider.notifier)
            .fetchHistory(refresh: true);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Obat telah diserahkan ke pasien'),
            backgroundColor: AppColors.green,
          ),
        );
      } else {
        await ref
            .read(patientsProvider.notifier)
            .setResepStatus(patient.id, newStatus);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memproses resep: $e'),
          backgroundColor: AppColors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmAndDispense(Patient patient) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        actionsPadding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.greenLt,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                LucideIcons.checkCircle2,
                color: AppColors.green,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Konfirmasi Penyerahan Obat',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'Apakah Anda yakin ingin menyelesaikan resep dan menyerahkan obat kepada pasien ${patient.nama}?',
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.sub,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              'Batal',
              style: TextStyle(
                color: AppColors.sub,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.green,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Ya, Serahkan',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _handleStatusChange(patient, ResepStatus.selesai);
    }
  }

  @override
  Widget build(BuildContext context) {
    final patients = ref.watch(patientsProvider);
    final patient = patients.where((p) => p.id == widget.patientId).firstOrNull;
    if (_loading || patient == null) {
      return const SkeletonPatientDetail();
    }
    final doctorsList = ref.watch(doctorsProvider).valueOrNull ?? kDoctors;
    Doctor? doctor;
    if (patient.assignedDokterId.isNotEmpty) {
      doctor = doctorsList
          .where(
            (d) => d.id.toLowerCase() == patient.assignedDokterId.toLowerCase(),
          )
          .firstOrNull;
    }
    final doctorDisplayName = CleanTextHelper.cleanName(
      patient.doctorName,
      fallback: doctor?.nama ?? '-',
    );
    final isSelesai =
        patient.statusPenanganan == 'Selesai' ||
        patient.resepStatus == ResepStatus.selesai;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PatientInfoCard(patient: patient),
        const SizedBox(height: 14),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white, Color(0xFFFFFDF7)],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.yellow.withValues(alpha: 0.3),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.yellow.withValues(alpha: 0.06),
                blurRadius: 16,
                offset: const Offset(0, 5),
              ),
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.02),
                blurRadius: 4,
                offset: const Offset(0, 1),
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
                                color: AppColors.text,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Dokter: $doctorDisplayName',
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: AppColors.text,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
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
                              color: AppColors.sub,
                            ),
                          ),
                          const SizedBox(height: 3),
                          _PrescriptionDiagnosaView(diagnosa: patient.diagnosa),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Resep Obat Items Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: const [
                              Icon(
                                LucideIcons.pill,
                                size: 15,
                                color: AppColors.yellow,
                              ),
                              SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Rincian Obat (Dapat Disesuaikan / Diganti)',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.text,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.greenLt,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${patient.resep.length} Item Obat',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: AppColors.green,
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
                          shipCode: patient.serviceShipCode,
                          disabled: isSelesai,
                          onGanti:
                              (obatBaru, alasan, {newSku, newJumlah, notes}) =>
                                  ref
                                      .read(patientsProvider.notifier)
                                      .gantiObat(
                                        patient.id,
                                        i,
                                        obatBaru,
                                        alasan,
                                        newSku: newSku,
                                        newJumlah: newJumlah,
                                        notes: notes,
                                      ),
                        ),
                      ),
                    const SizedBox(height: 14),

                    // Action Buttons
                    if (isSelesai)
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
                      )
                    else
                      AppButton(
                        label: 'Tandai Selesai & Serahkan Obat',
                        icon: LucideIcons.checkCheck,
                        full: true,
                        loading: _saving,
                        variant: AppButtonVariant.success,
                        onPressed: _saving
                            ? null
                            : () => _confirmAndDispense(patient),
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

class _PrescriptionDiagnosaView extends ConsumerWidget {
  const _PrescriptionDiagnosaView({this.diagnosa});

  final String? diagnosa;

  static bool _isJustCode(String text) {
    if (text.contains(' - ') || (text.contains('(') && text.contains(')'))) {
      return false;
    }
    final parts = text
        .split(',')
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return false;
    return parts.every((p) => !p.contains(' ') && p.length <= 8);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final raw = diagnosa?.trim();
    if (raw == null || raw.isEmpty || raw == '—' || raw == '-') {
      return const Text(
        '—',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppColors.text,
        ),
      );
    }

    if (!_isJustCode(raw)) {
      return Text(
        raw,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppColors.text,
        ),
      );
    }

    final codes = raw
        .split(',')
        .map((c) => c.trim())
        .where((c) => c.isNotEmpty)
        .toList();

    if (codes.isEmpty) {
      return Text(
        raw,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppColors.text,
        ),
      );
    }

    final results = <String>[];
    for (final code in codes) {
      final asyncItem = ref.watch(icd10LookupProvider(code));
      final item = asyncItem.valueOrNull;
      if (item != null && item.display.isNotEmpty) {
        if (item.display.contains(item.code)) {
          results.add(item.display);
        } else {
          results.add('${item.display} (${item.code})');
        }
      } else {
        results.add(code);
      }
    }

    return Text(
      results.join(', '),
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: AppColors.text,
      ),
    );
  }
}
