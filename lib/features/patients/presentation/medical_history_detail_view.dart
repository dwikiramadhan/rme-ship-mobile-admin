import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/network/api_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_helper.dart';
import '../../../core/utils/diagnosis_helper.dart';
import '../../../core/widgets/app_badge.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/vital_tile.dart';
import '../../auth/domain/user_role.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../doctor/data/icd10_api.dart';
import '../../doctor/data/icd9_api.dart';
import '../../doctor/presentation/widgets/examination_input_modal.dart';
import '../data/patient_repository.dart';
import '../domain/lab_order.dart';
import '../domain/medical_history.dart';
import '../domain/patient.dart';
import '../domain/vitals.dart';
import 'patient_detail_screen.dart';
import 'patient_info_card.dart';
import 'status_meta.dart';

/// Detail pane for a selected [MedicalHistory] item shown on the right side of
/// the screen on tablet, and pushed as a full page on mobile.
class MedicalHistoryDetailView extends ConsumerWidget {
  const MedicalHistoryDetailView({
    super.key,
    required this.history,
    this.canExamine,
  });

  final MedicalHistory history;
  final bool? canExamine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final userId = authState.session?.user.id ?? '';
    final historyProvider = userId.isNotEmpty
        ? medicalHistoryByUserProvider(userId)
        : medicalHistoryProvider;
    final allHistories = ref.watch(historyProvider);
    final history =
        allHistories
            .where(
              (h) =>
                  h.id == this.history.id ||
                  (this.history.patientId.isNotEmpty &&
                      h.patientId == this.history.patientId),
            )
            .firstOrNull ??
        this.history;

    final patientObj = history.toPatient();
    final meta = statusMetaFromPenanganan(history.statusPenanganan);

    final userRole = authState.session?.user.role;
    final isDoctor = canExamine ?? (userRole == UserRole.dokter);
    final statusPenanganan =
        (history.statusPenanganan ?? patientObj.statusPenanganan ?? '').trim();
    final lowerStatus = statusPenanganan.toLowerCase();
    final isMenungguDokter =
        lowerStatus == 'menunggu dokter' ||
        lowerStatus == 'antrian' ||
        lowerStatus == 'waiting';
    final hasDiagnosis =
        (history.diagnosis != null &&
            history.diagnosis!.trim().isNotEmpty &&
            history.diagnosis != '—' &&
            history.diagnosis != '-') ||
        (history.diagnosisDetail != null &&
            history.diagnosisDetail!.trim().isNotEmpty &&
            history.diagnosisDetail != '—' &&
            history.diagnosisDetail != '-');
    final isDiagnosed = !isMenungguDokter && hasDiagnosis;

    final hasTreatment =
        (history.treatment != null &&
            history.treatment!.trim().isNotEmpty &&
            history.treatment != '—' &&
            history.treatment != '-') ||
        (history.tindakanDetail != null &&
            history.tindakanDetail!.trim().isNotEmpty &&
            history.tindakanDetail != '—' &&
            history.tindakanDetail != '-');

    final isMenungguLab = lowerStatus.contains('lab');
    final isSelesai =
        lowerStatus.contains('selesai') ||
        lowerStatus == 'completed' ||
        lowerStatus == 'done';
    final isMenungguObat =
        lowerStatus.contains('obat') ||
        lowerStatus.contains('farmasi') ||
        lowerStatus.contains('resep');

    // Operation info
    final opVal =
        (history.operation ??
                history.rawJson['operation']?.toString() ??
                history.rawJson['Operation']?.toString() ??
                '')
            .trim();
    final hasOperation = opVal.isNotEmpty && opVal != '-' && opVal != '—';
    final isMajorOp = opVal.toLowerCase() == 'major';
    final isMinorOp = opVal.toLowerCase() == 'minor';

    // Lab info (from lab_examination)
    final effectiveAttachmentUrl = history.labAttachmentUrl ??
        this.history.labAttachmentUrl ??
        patientObj.labOrder?.hasil?.fileName ??
        this.history.patient?.labOrder?.hasil?.fileName;
    final labExam = history.labExamination ?? this.history.labExamination;
    final labItems = history.labExaminationItems.isNotEmpty
        ? history.labExaminationItems
        : this.history.labExaminationItems;
    final labOrder = patientObj.labOrder ?? this.history.patient?.labOrder;
    String labJenisText = labOrder?.jenis ?? '';
    if (labJenisText.isEmpty && history.labExaminationCode != null) {
      labJenisText = 'Pemeriksaan Lab (${history.labExaminationCode})';
    }
    if (labJenisText.isEmpty && this.history.labExaminationCode != null) {
      labJenisText = 'Pemeriksaan Lab (${this.history.labExaminationCode})';
    }
    if (labJenisText.isEmpty && history.rawJson['lab_order'] is Map) {
      final lo = history.rawJson['lab_order'] as Map;
      labJenisText = (lo['jenis'] ?? lo['name'] ?? lo['test_name'] ?? '')
          .toString();
    }
    if (labJenisText.isEmpty && history.rawJson['order_lab'] is Map) {
      final lo = history.rawJson['order_lab'] as Map;
      labJenisText = (lo['jenis'] ?? lo['name'] ?? lo['test_name'] ?? '')
          .toString();
    }
    if (labJenisText.isEmpty && (labExam != null || labItems.isNotEmpty)) {
      labJenisText = 'Pemeriksaan Laboratorium';
    }
    if (labJenisText.isEmpty && isMenungguLab) {
      labJenisText = 'Rujukan Lab';
    }

    String labCatatanText = labOrder?.catatan ?? '';
    if (labCatatanText.isEmpty && labExam?['notes'] != null) {
      labCatatanText = labExam!['notes'].toString();
    }
    if (labCatatanText.isEmpty && history.rawJson['lab_order'] is Map) {
      final lo = history.rawJson['lab_order'] as Map;
      labCatatanText = (lo['catatan'] ?? lo['notes'] ?? '').toString();
    }

    final hasLab =
        labExam != null ||
        labItems.isNotEmpty ||
        labJenisText.trim().isNotEmpty ||
        (effectiveAttachmentUrl != null && effectiveAttachmentUrl.trim().isNotEmpty) ||
        isMenungguLab;

    Widget? labStatusBadge;
    if (hasLab) {
      final labStatus = labOrder?.status;
      final isLabSelesai =
          labExam != null ||
          labItems.isNotEmpty ||
          labStatus == LabOrderStatus.selesai ||
          isSelesai;
      final statusLabel = isLabSelesai
          ? 'Selesai'
          : (labStatus == LabOrderStatus.diproses
                ? 'Diproses'
                : (isMenungguLab ? 'Menunggu Lab' : null));
      if (statusLabel != null) {
        final isDone = statusLabel == 'Selesai';
        labStatusBadge = Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: isDone ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            statusLabel,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: isDone ? const Color(0xFF166534) : const Color(0xFF92400E),
              letterSpacing: 0,
            ),
          ),
        );
      }
    }

    return DefaultTextStyle.merge(
      style: const TextStyle(letterSpacing: 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Status Penanganan Info Banner (Card Terpisah)
          if (!isDiagnosed) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(
                children: [
                  const Icon(
                    LucideIcons.alertCircle,
                    size: 18,
                    color: Color(0xFFD97706),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isDoctor
                          ? 'Pasien belum memiliki diagnosa klinis. Klik tombol di bawah untuk memeriksa dan mengisi rekam medis.'
                          : 'Pasien dalam status Menunggu Dokter untuk pemeriksaan klinis.',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0,
                        color: Color(0xFF92400E),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ] else if (isMenungguLab) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F9FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFBAE6FD)),
              ),
              child: const Row(
                children: [
                  Icon(
                    LucideIcons.flaskConical,
                    size: 18,
                    color: Color(0xFF0284C7),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Pasien dalam status Menunggu Lab. Menunggu pemeriksaan atau hasil laboratorium selesai diproses.',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0,
                        color: Color(0xFF0369A1),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ] else if (isMenungguObat) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF9C3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFEF08A)),
              ),
              child: const Row(
                children: [
                  Icon(LucideIcons.pill, size: 18, color: Color(0xFFCA8A04)),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Pasien dalam status Menunggu Obat. Resep obat sedang diproses oleh bagian farmasi.',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0,
                        color: Color(0xFF854D0E),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ] else if (isSelesai) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: const Row(
                children: [
                  Icon(
                    LucideIcons.checkCircle2,
                    size: 18,
                    color: Color(0xFF16A34A),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Status Pelayanan Selesai. Seluruh tahapan pemeriksaan dan pelayanan pasien telah selesai.',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0,
                        color: Color(0xFF166534),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // 2. Patient Info Summary Card
          PatientInfoCard(patient: patientObj),
          const SizedBox(height: 12),

          // 3. Detail Kunjungan & Pemeriksaan Medis
          AppCard(
            border: Border.all(color: AppColors.orange),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Card
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.blueLt,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        LucideIcons.stethoscope,
                        size: 18,
                        color: AppColors.blue,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'DETAIL',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0,
                              color: AppColors.blue,
                            ),
                          ),
                          if (history.code.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              history.code,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0,
                                color: AppColors.text,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    AppBadge(
                      label: meta.label,
                      color: meta.color,
                      background: meta.background,
                    ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Divider(height: 1, color: AppColors.border),
                ),

                // Detail Info Grid / Rows
                _buildInfoRow(
                  icon: LucideIcons.calendar,
                  label: 'Waktu Kunjungan',
                  value:
                      (history.createdAt != null &&
                          history.createdAt!.isNotEmpty)
                      ? DateHelper.formatDateTime(history.createdAt)
                      : (history.date ?? '-'),
                ),
                const SizedBox(height: 10),
                _buildInfoRow(
                  icon: LucideIcons.building,
                  label: 'Poliklinik',
                  value: history.poliName?.isNotEmpty == true
                      ? history.poliName!
                      : (history.poliCode ?? 'Poli Umum'),
                ),
                const SizedBox(height: 10),
                _buildInfoRow(
                  icon: LucideIcons.userCheck,
                  label: 'Dokter Pemeriksa',
                  value: history.doctorName?.isNotEmpty == true
                      ? history.doctorName!
                      : '-',
                  extra: history.doctorSip?.isNotEmpty == true
                      ? 'SIP: ${history.doctorSip}'
                      : null,
                ),
                if (history.shipName?.isNotEmpty == true ||
                    history.portName?.isNotEmpty == true) ...[
                  const SizedBox(height: 10),
                  _buildInfoRow(
                    icon: LucideIcons.ship,
                    label: 'Kapal & Pelabuhan',
                    value: [
                      if (history.shipName?.isNotEmpty == true)
                        history.shipName!,
                      if (history.portName?.isNotEmpty == true)
                        history.portName!,
                    ].join(' • '),
                  ),
                ],

                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Divider(height: 1, color: AppColors.border),
                ),

                // Tanda-Tanda Vital
                _buildSectionTitle('Tanda-Tanda Vital Pemeriksaan'),
                const SizedBox(height: 10),
                _buildVitalsGrid(history.vitals),

                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Divider(height: 1, color: AppColors.border),
                ),

                // Hasil Pemeriksaan Klinis
                _buildSectionTitle('Hasil Pemeriksaan & Catatan Medis'),
                const SizedBox(height: 10),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFFE2E8F0),
                      width: 0.8,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildClinicalItem(
                        icon: LucideIcons.messageSquare,
                        label: 'Keluhan Pasien',
                        value: history.complaint?.isNotEmpty == true
                            ? history.complaint!
                            : 'Tidak ada keluhan tercatat',
                        isMuted: history.complaint?.isNotEmpty != true,
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 10),
                        child: Divider(height: 1, color: Color(0xFFE2E8F0)),
                      ),
                      _buildClinicalItem(
                        icon: LucideIcons.activity,
                        label: 'Diagnosa',
                        customContent: _DiagnosaDetailValue(history: history),
                        labelColor: hasDiagnosis ? AppColors.blue : null,
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 10),
                        child: Divider(height: 1, color: Color(0xFFE2E8F0)),
                      ),
                      _buildClinicalItem(
                        icon: LucideIcons.fileCheck,
                        label: 'Tindakan / Terapi',
                        customContent: _TindakanDetailValue(history: history),
                        labelColor: hasTreatment
                            ? const Color(0xFF0D9488)
                            : null,
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 10),
                        child: Divider(height: 1, color: Color(0xFFE2E8F0)),
                      ),
                      _buildClinicalItem(
                        icon: LucideIcons.scissors,
                        label: 'Operasi (Operation)',
                        value: hasOperation
                            ? '$opVal${isMajorOp
                                  ? " (Operasi Besar)"
                                  : isMinorOp
                                  ? " (Operasi Kecil)"
                                  : ""}'
                            : 'Tidak ada tindakan operasi',
                        isMuted: !hasOperation,
                        labelColor: hasOperation
                            ? (isMajorOp
                                  ? const Color(0xFFDC2626)
                                  : const Color(0xFF0284C7))
                            : null,
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 10),
                        child: Divider(height: 1, color: Color(0xFFE2E8F0)),
                      ),
                      _buildClinicalItem(
                        icon: LucideIcons.flaskConical,
                        label: 'Pemeriksaan Laboratorium',
                        customContent: hasLab
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (labJenisText.isNotEmpty ||
                                      labStatusBadge != null) ...[
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        if (labJenisText.isNotEmpty)
                                          Flexible(
                                            child: Text(
                                              labJenisText,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF0369A1),
                                                letterSpacing: 0,
                                              ),
                                            ),
                                          )
                                        else
                                          const Spacer(),
                                        ?labStatusBadge,
                                      ],
                                    ),
                                  ],

                                  // Parameter pemeriksaan lab (lab_examination.items)
                                  if (labItems.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    for (final item in labItems)
                                      Container(
                                        margin: const EdgeInsets.only(
                                          bottom: 6,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF8FAFC),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: const Color(0xFFE2E8F0),
                                            width: 0.8,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    item.testName,
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: AppColors.text,
                                                      letterSpacing: 0,
                                                    ),
                                                  ),
                                                  if (item
                                                      .testCategory
                                                      .isNotEmpty) ...[
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      item.testCategory,
                                                      style: const TextStyle(
                                                        fontSize: 10.5,
                                                        color: AppColors.sub,
                                                        letterSpacing: 0,
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.end,
                                              children: [
                                                Text(
                                                  item.notes.isNotEmpty
                                                      ? item.notes
                                                      : (item.unit.isNotEmpty
                                                            ? '- ${item.unit}'
                                                            : '—'),
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w700,
                                                    color: Color(0xFF0284C7),
                                                    letterSpacing: 0,
                                                  ),
                                                ),
                                                if (item
                                                    .referenceRange
                                                    .isNotEmpty) ...[
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    'Rujukan: ${item.referenceRange}',
                                                    style: const TextStyle(
                                                      fontSize: 10,
                                                      color: AppColors.sub,
                                                      letterSpacing: 0,
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],

                                  if (effectiveAttachmentUrl != null &&
                                      effectiveAttachmentUrl.trim().isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: const Color(0xFFE2E8F0),
                                          width: 0.8,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFE0F2FE),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: const Icon(
                                              LucideIcons.fileText,
                                              size: 14,
                                              color: Color(0xFF0284C7),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                const Text(
                                                  'Lampiran Hasil Lab',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                    color: AppColors.text,
                                                    letterSpacing: 0,
                                                  ),
                                                ),
                                                const SizedBox(height: 1),
                                                Text(
                                                  effectiveAttachmentUrl,
                                                  style: const TextStyle(
                                                    fontSize: 10.5,
                                                    color: AppColors.sub,
                                                    letterSpacing: 0,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          OutlinedButton.icon(
                                            onPressed: () {
                                              final rawUrl =
                                                  effectiveAttachmentUrl.trim();
                                              final fullUrl = rawUrl.startsWith('http')
                                                  ? rawUrl
                                                  : (rawUrl.startsWith('/')
                                                      ? '${ApiConfig.baseUrl}$rawUrl'
                                                      : '${ApiConfig.baseUrl}/$rawUrl');
                                              _showLabDocument(
                                                context,
                                                fullUrl,
                                                'Dokumen Hasil Lab',
                                              );
                                            },
                                            icon: const Icon(
                                              LucideIcons.eye,
                                              size: 13,
                                            ),
                                            label: const Text(
                                              'Lihat Dokumen',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                letterSpacing: 0,
                                              ),
                                            ),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: const Color(0xFF0284C7),
                                              side: const BorderSide(
                                                color: Color(0xFFBAE6FD),
                                              ),
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 9,
                                                vertical: 6,
                                              ),
                                              minimumSize: Size.zero,
                                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              )
                            : const Text(
                                'Tidak ada rujukan laboratorium',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w400,
                                  fontStyle: FontStyle.italic,
                                  color: AppColors.sub,
                                  letterSpacing: 0,
                                ),
                              ),
                        labelColor: hasLab ? const Color(0xFF0284C7) : null,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Button 1: Doctor Examination / Medical Record Form (Hanya jika belum didiagnosa)
                if (isDoctor && !isDiagnosed) ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _openDoctorExamination(
                        context,
                        ref,
                        history,
                        patientObj,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0284C7),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 1,
                      ),
                      icon: const Icon(
                        LucideIcons.stethoscope,
                        size: 15,
                        color: Colors.white,
                      ),
                      label: const Text(
                        'Periksa Pasien / Input Rekam Medis',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],

                // Button 2: View full patient medical history
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      final targetId = history.patientId.isNotEmpty
                          ? history.patientId
                          : history.id;
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => PatientDetailScreen(
                            patientId: targetId,
                            initialPatient: patientObj,
                          ),
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      foregroundColor: AppColors.blue,
                      side: const BorderSide(color: AppColors.blue, width: 1.2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(LucideIcons.fileText, size: 15),
                    label: const Text(
                      'Buka Rekam Medis Lengkap Pasien',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openDoctorExamination(
    BuildContext context,
    WidgetRef ref,
    MedicalHistory history,
    Patient patientObj,
  ) async {
    final res = await showExaminationInputModal(
      context,
      patient: patientObj,
      history: history,
    );
    if (res == true && context.mounted) {
      final userId = ref.read(authControllerProvider).session?.user.id ?? '';
      unawaited(
        ref.read(medicalHistoryProvider.notifier).fetchHistory(refresh: true),
      );
      if (userId.isNotEmpty) {
        unawaited(
          ref
              .read(medicalHistoryByUserProvider(userId).notifier)
              .fetchHistory(refresh: true),
        );
      }
      unawaited(ref.read(patientsProvider.notifier).fetchPatients());
    }
  }

  void _showLabDocument(BuildContext context, String url, String title) {
    final fileName = url.split('/').last.split('?').first;
    final lower = fileName.toLowerCase();
    final isPdf = lower.endsWith('.pdf');

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 540, maxHeight: 680),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 20,
                offset: Offset(0, 8),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  border: Border(
                    bottom: BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: isPdf ? const Color(0xFFFEE2E2) : const Color(0xFFE0F2FE),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        isPdf ? LucideIcons.fileText : LucideIcons.image,
                        size: 16,
                        color: isPdf ? const Color(0xFFDC2626) : const Color(0xFF0284C7),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.text,
                              letterSpacing: 0,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            fileName,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.sub,
                              letterSpacing: 0,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(LucideIcons.x, size: 18, color: AppColors.sub),
                      onPressed: () => Navigator.of(ctx).pop(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                  ],
                ),
              ),
              // Body
              Flexible(
                child: isPdf
                    ? Container(
                        padding: const EdgeInsets.all(32),
                        color: const Color(0xFFF8FAFC),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 68,
                                height: 68,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEE2E2),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Icon(
                                  LucideIcons.fileText,
                                  size: 36,
                                  color: Color(0xFFDC2626),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                fileName,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.text,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Dokumen Hasil Pemeriksaan Laboratorium (PDF)',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: AppColors.sub,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 14),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  url,
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    color: AppColors.sub,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : Container(
                        color: Colors.black,
                        child: InteractiveViewer(
                          clipBehavior: Clip.none,
                          child: Center(
                            child: Image.network(
                              url,
                              fit: BoxFit.contain,
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return const Padding(
                                  padding: EdgeInsets.all(40),
                                  child: CircularProgressIndicator(color: Colors.white),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) => Padding(
                                padding: const EdgeInsets.all(32),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      LucideIcons.alertCircle,
                                      size: 36,
                                      color: Colors.white70,
                                    ),
                                    const SizedBox(height: 10),
                                    const Text(
                                      'Gagal memuat dokumen gambar',
                                      style: TextStyle(color: Colors.white, fontSize: 13),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      fileName,
                                      style: const TextStyle(color: Colors.white60, fontSize: 11),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppColors.sub,
        letterSpacing: 0,
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    String? extra,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: AppColors.sub),
        const SizedBox(width: 8),
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.sub,
              fontWeight: FontWeight.w500,
              letterSpacing: 0,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                  letterSpacing: 0,
                ),
              ),
              if (extra != null)
                Text(
                  extra,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.sub,
                    letterSpacing: 0,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildClinicalItem({
    required IconData icon,
    required String label,
    String? value,
    Widget? customContent,
    Color? labelColor,
    bool isMuted = false,
  }) {
    final effectiveColor = labelColor ?? AppColors.sub;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: effectiveColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 0,
                fontWeight: FontWeight.w600,
                color: effectiveColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        customContent ??
            Text(
              value ?? '-',
              style: TextStyle(
                fontSize: 12,
                fontWeight: isMuted ? FontWeight.w400 : FontWeight.w500,
                fontStyle: isMuted ? FontStyle.italic : FontStyle.normal,
                color: isMuted ? AppColors.sub : AppColors.text,
                height: 1.35,
                letterSpacing: 0,
              ),
            ),
      ],
    );
  }

  Widget _buildVitalsGrid(Vitals vitals) {
    final td = vitals.tekananDarah.isNotEmpty
        ? vitals.tekananDarah
        : (vitals.systolic != null && vitals.diastolic != null
              ? '${vitals.systolic}/${vitals.diastolic}'
              : '—');
    final nadi = vitals.nadi.isNotEmpty
        ? vitals.nadi
        : (vitals.heartRate?.toString() ?? '—');
    final suhu = vitals.suhu.isNotEmpty
        ? vitals.suhu
        : (vitals.temperature != null
              ? (vitals.temperature! % 1 == 0
                    ? vitals.temperature!.toInt().toString()
                    : vitals.temperature!.toString())
              : '—');
    final rr = vitals.frekuensiNapas.isNotEmpty
        ? vitals.frekuensiNapas
        : (vitals.respiratoryRate?.toString() ?? '—');
    final spo2 = vitals.spo2.isNotEmpty
        ? vitals.spo2
        : (vitals.oxygenSaturation != null
              ? (vitals.oxygenSaturation! % 1 == 0
                    ? vitals.oxygenSaturation!.toInt().toString()
                    : vitals.oxygenSaturation!.toString())
              : '—');

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final int crossAxisCount = w >= 700 ? 5 : (w >= 440 ? 3 : 2);
        final double childAspectRatio = w >= 700 ? 2.1 : (w >= 440 ? 2.6 : 2.5);

        return GridView.count(
          padding: EdgeInsets.zero,
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: childAspectRatio,
          children: [
            VitalTile(
              icon: LucideIcons.heart,
              label: 'Tekanan Darah',
              value: td,
              unit: 'mmHg',
              color: AppColors.red,
            ),
            VitalTile(
              icon: LucideIcons.activity,
              label: 'Nadi',
              value: nadi,
              unit: 'bpm',
              color: AppColors.blue,
            ),
            VitalTile(
              icon: LucideIcons.thermometer,
              label: 'Suhu Tubuh',
              value: suhu,
              unit: '°C',
              color: AppColors.yellow,
            ),
            VitalTile(
              icon: LucideIcons.activity,
              label: 'Frek. Napas',
              value: rr,
              unit: 'x/mnt',
              color: AppColors.purple,
            ),
            VitalTile(
              icon: LucideIcons.droplet,
              label: 'SpO₂',
              value: spo2,
              unit: '%',
              color: AppColors.green,
            ),
          ],
        );
      },
    );
  }
}

bool _isJustCode(String text) {
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

class _DiagnosaDetailValue extends ConsumerWidget {
  const _DiagnosaDetailValue({required this.history});

  final MedicalHistory history;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1. Prioritaskan rawJson['diagnoses'] jika ada list map dari backend
    final rawDiagnoses = history.rawJson['diagnoses'];
    if (rawDiagnoses is List && rawDiagnoses.isNotEmpty) {
      final formatted = DiagnosisHelper.formatDiagnoses(rawDiagnoses);
      if (formatted.isNotEmpty && formatted != '—' && !_isJustCode(formatted)) {
        return Text(
          formatted,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.text,
            height: 1.35,
            letterSpacing: 0,
          ),
        );
      }
    }

    // 2. Gunakan diagnosisDetail jika ada dan memuat nama
    final detail = history.diagnosisDetail?.trim();
    if (detail != null && detail.isNotEmpty && detail != '—' && detail != '-') {
      if (!_isJustCode(detail)) {
        return Text(
          detail,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.text,
            height: 1.35,
            letterSpacing: 0,
          ),
        );
      }
    }

    // 3. Jika hanya ada diagnosis (kode) atau diagnosisDetail hanya kode
    final rawCodes = (history.diagnosis?.trim().isNotEmpty == true)
        ? history.diagnosis!.trim()
        : detail;

    if (rawCodes == null ||
        rawCodes.isEmpty ||
        rawCodes == '—' ||
        rawCodes == '-') {
      return const Text(
        'Belum ada diagnosa dokter',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          fontStyle: FontStyle.italic,
          color: AppColors.sub,
          letterSpacing: 0,
        ),
      );
    }

    // Jika rawCodes sudah memuat nama
    if (!_isJustCode(rawCodes)) {
      return Text(
        rawCodes,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.text,
          height: 1.35,
          letterSpacing: 0,
        ),
      );
    }

    // Split kode dan lookup nama ICD-10
    final codes = rawCodes
        .split(',')
        .map((c) => c.trim())
        .where((c) => c.isNotEmpty)
        .toList();

    if (codes.isEmpty) {
      return Text(
        rawCodes,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.text,
          height: 1.35,
          letterSpacing: 0,
        ),
      );
    }

    return _Icd10CodesResolver(codes: codes, fallback: rawCodes);
  }
}

class _Icd10CodesResolver extends ConsumerWidget {
  const _Icd10CodesResolver({required this.codes, required this.fallback});

  final List<String> codes;
  final String fallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final results = <String>[];
    bool anyLoading = false;

    for (final code in codes) {
      final asyncItem = ref.watch(icd10LookupProvider(code));
      asyncItem.when(
        data: (item) {
          if (item != null && item.display.isNotEmpty) {
            if (item.display.contains(item.code)) {
              results.add(item.display);
            } else {
              results.add('${item.display} (${item.code})');
            }
          } else {
            results.add(code);
          }
        },
        loading: () {
          anyLoading = true;
          results.add(code);
        },
        error: (_, _) {
          results.add(code);
        },
      );
    }

    if (results.isEmpty) {
      return Text(
        anyLoading ? 'Memuat diagnosa ($fallback)...' : fallback,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.text,
          height: 1.35,
          letterSpacing: 0,
        ),
      );
    }

    return Text(
      results.join(', '),
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.text,
        height: 1.35,
        letterSpacing: 0,
      ),
    );
  }
}

class _TindakanDetailValue extends ConsumerWidget {
  const _TindakanDetailValue({required this.history});

  final MedicalHistory history;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1. Prioritaskan rawJson['procedures'] jika ada list map dari backend
    final rawProcedures = history.rawJson['procedures'];
    if (rawProcedures is List && rawProcedures.isNotEmpty) {
      final formatted = DiagnosisHelper.formatDiagnoses(rawProcedures);
      if (formatted.isNotEmpty && formatted != '—' && !_isJustCode(formatted)) {
        return Text(
          formatted,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.text,
            height: 1.35,
            letterSpacing: 0,
          ),
        );
      }
    }

    // 2. Gunakan tindakanDetail jika ada dan memuat nama
    final detail = history.tindakanDetail?.trim();
    if (detail != null && detail.isNotEmpty && detail != '—' && detail != '-') {
      if (!_isJustCode(detail)) {
        return Text(
          detail,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.text,
            height: 1.35,
            letterSpacing: 0,
          ),
        );
      }
    }

    // 3. Jika hanya ada treatment (kode) atau tindakanDetail hanya kode
    final rawCodes = (history.treatment?.trim().isNotEmpty == true)
        ? history.treatment!.trim()
        : detail;

    if (rawCodes == null ||
        rawCodes.isEmpty ||
        rawCodes == '—' ||
        rawCodes == '-') {
      return const Text(
        'Tidak ada tindakan klinis',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          fontStyle: FontStyle.italic,
          color: AppColors.sub,
          letterSpacing: 0,
        ),
      );
    }

    // Jika rawCodes sudah memuat nama
    if (!_isJustCode(rawCodes)) {
      return Text(
        rawCodes,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: AppColors.text,
          height: 1.35,
          letterSpacing: 0,
        ),
      );
    }

    // Split kode dan lookup nama ICD-9
    final codes = rawCodes
        .split(',')
        .map((c) => c.trim())
        .where((c) => c.isNotEmpty)
        .toList();

    if (codes.isEmpty) {
      return Text(
        rawCodes,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: AppColors.text,
          height: 1.35,
          letterSpacing: 0,
        ),
      );
    }

    return _Icd9CodesResolver(codes: codes, fallback: rawCodes);
  }
}

class _Icd9CodesResolver extends ConsumerWidget {
  const _Icd9CodesResolver({required this.codes, required this.fallback});

  final List<String> codes;
  final String fallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final results = <String>[];
    bool anyLoading = false;

    for (final code in codes) {
      final asyncItem = ref.watch(icd9LookupProvider(code));
      asyncItem.when(
        data: (item) {
          if (item != null && item.display.isNotEmpty) {
            if (item.display.contains(item.code)) {
              results.add(item.display);
            } else {
              results.add('${item.display} (${item.code})');
            }
          } else {
            results.add(code);
          }
        },
        loading: () {
          anyLoading = true;
          results.add(code);
        },
        error: (_, _) {
          results.add(code);
        },
      );
    }

    if (results.isEmpty) {
      return Text(
        anyLoading ? 'Memuat tindakan ($fallback)...' : fallback,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: AppColors.text,
          height: 1.35,
          letterSpacing: 0,
        ),
      );
    }

    return Text(
      results.join(', '),
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: AppColors.text,
        height: 1.35,
        letterSpacing: 0,
      ),
    );
  }
}
