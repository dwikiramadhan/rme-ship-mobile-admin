import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/clean_text_helper.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_shimmer.dart';
import '../../doctor/presentation/widgets/doctor_exam_summary.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../patients/data/patient_repository.dart';
import '../../patients/domain/doctor.dart';
import '../../patients/domain/medical_history.dart';
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

  /// This visit's queue item; also has the doctor's SIP and who registered
  /// the visit. Null when the visit isn't in the queue list.
  MedicalHistory? _visit;

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
    // Not during build: the provider can't be modified while widgets build.
    final fromQueue = await Future.microtask(_takeFromQueue);
    if (!mounted) return;
    await Future.wait([
      if (!fromQueue)
        ref
            .read(patientsProvider.notifier)
            .fetchPatientDetail(widget.patientId),
      Future.delayed(const Duration(milliseconds: 250)),
    ]);
    if (mounted) setState(() => _loading = false);
  }

  /// The queue item (GET /medical-history) already has everything this page
  /// shows: patient profile, doctor, diagnosis and the prescription with
  /// item ids. Use it instead of fetching the patient and all their records.
  /// Returns false when the visit isn't in the queue list.
  bool _takeFromQueue() {
    final medRecId = widget.medRecId;
    if (!mounted || medRecId == null || medRecId.isEmpty) return false;
    final item = ref
        .read(pharmacyPrescriptionHistoryProvider)
        .where((h) => h.id == medRecId)
        .firstOrNull;
    if (item == null) return false;
    _visit = item;
    ref.read(patientsProvider.notifier).upsertPatient(item.toPatient());
    return true;
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
        await ref
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
                  letterSpacing: 0,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                ),
              ),
            ),
          ],
        ),
        // Fixed width: otherwise the long question stretches the dialog to
        // its maximum width. Still shrinks on narrower screens.
        content: SizedBox(
          width: 420,
          child: Text(
            'Apakah Anda yakin ingin menyelesaikan resep dan menyerahkan obat kepada pasien ${patient.nama}?',
            style: const TextStyle(
              letterSpacing: 0,
              fontSize: 12,
              color: AppColors.sub,
              height: 1.4,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              'Batal',
              style: TextStyle(
                letterSpacing: 0,
                color: AppColors.text,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
          // Same style as "Tandai Selesai & Serahkan Obat".
          AppButton(
            label: 'Ya, Serahkan',
            icon: LucideIcons.checkCheck,
            variant: AppButtonVariant.success,
            onPressed: () => Navigator.of(ctx).pop(true),
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
    // Select only this patient so list-wide updates (WS polls, paging)
    // don't rebuild the detail pane.
    final patient = ref.watch(
      patientsProvider.select(
        (patients) =>
            patients.where((p) => p.id == widget.patientId).firstOrNull,
      ),
    );
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

    // No extra letter spacing anywhere on this page (the theme adds some).
    return DefaultTextStyle.merge(
      style: const TextStyle(letterSpacing: 0),
      child: Column(
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
                          // The doctor is shown in the body.
                          const Text(
                            'Resep Obat Pasien',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppColors.text,
                            ),
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
                      _buildPeople(doctorDisplayName),
                      const SizedBox(height: 10),

                      // Same diagnosis/procedure detail as the doctor's view.
                      ExamDiagnosisDetail(
                        diagnosa: patient.diagnosa,
                        tindakan: patient.tindakan,
                        inline: true,
                        labelLetterSpacing: 0,
                      ),
                      const SizedBox(height: 16),

                      // Resep Obat Items Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Expanded(
                            child: Row(
                              children: [
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
                                (
                                  obatBaru,
                                  alasan, {
                                  newSku,
                                  newJumlah,
                                  notes,
                                }) => ref
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
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
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
      ),
    );
  }

  /// Doctor and the person who registered the visit (usually the nurse),
  /// in the same bordered blocks as the diagnosis below.
  Widget _buildPeople(String doctorName) {
    final visit = _visit;
    final sip = visit?.doctorSip?.trim() ?? '';
    final doctor = ExamSection(
      label: 'Dokter Pemeriksa',
      labelLetterSpacing: 0,
      child: _PersonInfo(
        name: doctorName,
        extra: sip.isNotEmpty ? 'SIP: $sip' : null,
      ),
    );
    final creator = visit?.createdByName;
    if (creator == null) return doctor;

    final role = visit!.createdByRole;
    final isNurse = role == null || role.toLowerCase() == 'perawat';
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: doctor),
          const SizedBox(width: 10),
          Expanded(
            child: ExamSection(
              label: isNurse ? 'Perawat' : 'Dibuat Oleh',
              labelLetterSpacing: 0,
              child: _PersonInfo(name: creator, extra: isNurse ? null : role),
            ),
          ),
        ],
      ),
    );
  }
}

typedef ResepDetail = PrescriptionDetail;

/// A person's name with an optional second line (SIP, role).
class _PersonInfo extends StatelessWidget {
  const _PersonInfo({required this.name, this.extra});

  final String name;
  final String? extra;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name,
          style: const TextStyle(
            fontSize: 12.5,
            height: 1.3,
            fontWeight: FontWeight.w500,
            color: AppColors.text,
          ),
        ),
        if (extra != null) ...[
          const SizedBox(height: 2),
          Text(
            extra!,
            style: const TextStyle(fontSize: 11, color: AppColors.sub),
          ),
        ],
      ],
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
