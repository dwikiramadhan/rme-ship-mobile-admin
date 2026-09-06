import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

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
    final patientObj = history.toPatient();
    final meta = statusMetaFromPenanganan(history.statusPenanganan);

    final authState = ref.watch(authControllerProvider);
    final userRole = authState.session?.user.role;
    final isDoctor = canExamine ?? (userRole == UserRole.dokter);
    final isMenungguDokter =
        (history.statusPenanganan ?? '').trim().toLowerCase() ==
        'menunggu dokter';
    final hasDiagnosis = (history.diagnosis != null &&
            history.diagnosis!.trim().isNotEmpty &&
            history.diagnosis != '—' &&
            history.diagnosis != '-') ||
        (history.diagnosisDetail != null &&
            history.diagnosisDetail!.trim().isNotEmpty &&
            history.diagnosisDetail != '—' &&
            history.diagnosisDetail != '-');
    final isDiagnosed = !isMenungguDokter && hasDiagnosis;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Patient Info Summary Card
        PatientInfoCard(patient: patientObj),
        const SizedBox(height: 12),

        // 2. Detail Kunjungan & Pemeriksaan Medis
        AppCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Card
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
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
                            letterSpacing: 0.5,
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
                    (history.createdAt != null && history.createdAt!.isNotEmpty)
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
                    if (history.shipName?.isNotEmpty == true) history.shipName!,
                    if (history.portName?.isNotEmpty == true) history.portName!,
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

              _buildDetailBox(
                label: 'Keluhan Pasien',
                value: history.complaint?.isNotEmpty == true
                    ? history.complaint!
                    : 'Tidak ada keluhan tercatat',
                icon: LucideIcons.messageSquare,
              ),
              const SizedBox(height: 8),

              _buildDetailBox(
                label: 'Diagnosa',
                customContent: _DiagnosaDetailValue(history: history),
                icon: LucideIcons.activity,
                isHighlight: hasDiagnosis,
              ),
              const SizedBox(height: 8),

              _buildDetailBox(
                label: 'Tindakan / Terapi',
                customContent: _TindakanDetailValue(history: history),
                icon: LucideIcons.fileCheck,
              ),

              if (history.notes != null &&
                  history.notes!.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                _buildDetailBox(
                  label: 'Catatan Khusus / Riwayat Alergi',
                  value: history.notes!,
                  icon: LucideIcons.alertTriangle,
                  isWarning: true,
                ),
              ],

              if (isDoctor && !isDiagnosed) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        LucideIcons.alertCircle,
                        size: 17,
                        color: Color(0xFFD97706),
                      ),
                      SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          'Pasien belum memiliki diagnosa klinis. Klik tombol di bawah untuk memeriksa dan mengisi rekam medis.',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF92400E),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // Button 1: Doctor Examination / Medical Record Form
              if (isDoctor) ...[
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
                      backgroundColor: isDiagnosed
                          ? const Color(0xFF2563EB)
                          : const Color(0xFF0284C7),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 1,
                    ),
                    icon: Icon(
                      isDiagnosed
                          ? LucideIcons.fileEdit
                          : LucideIcons.stethoscope,
                      size: 17,
                      color: Colors.white,
                    ),
                    label: Text(
                      isDiagnosed
                          ? 'Ubah Pemeriksaan / Diagnosa Dokter'
                          : 'Periksa Pasien / Input Rekam Medis',
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
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
                  icon: const Icon(LucideIcons.fileText, size: 16),
                  label: const Text(
                    'Buka Rekam Medis Lengkap Pasien',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _openDoctorExamination(
    BuildContext context,
    WidgetRef ref,
    MedicalHistory history,
    Patient patientObj,
  ) {
    showExaminationInputModal(
      context,
      patient: patientObj,
      history: history,
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: AppColors.sub,
        letterSpacing: 0.3,
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
                ),
              ),
              if (extra != null)
                Text(
                  extra,
                  style: const TextStyle(fontSize: 11, color: AppColors.sub),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailBox({
    required String label,
    String? value,
    Widget? customContent,
    required IconData icon,
    bool isHighlight = false,
    bool isWarning = false,
  }) {
    final bgColor = isWarning
        ? AppColors.orangeLt
        : (isHighlight ? AppColors.blueLt : AppColors.card2);
    final borderColor = isWarning
        ? AppColors.orange.withValues(alpha: 0.3)
        : (isHighlight
              ? AppColors.blue.withValues(alpha: 0.3)
              : AppColors.border);
    final iconColor = isWarning
        ? AppColors.orange
        : (isHighlight ? AppColors.blue : AppColors.sub);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor, width: 0.8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: iconColor),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: iconColor,
                  ),
                ),
                const SizedBox(height: 2),
                if (customContent != null)
                  customContent
                else
                  Text(
                    value ?? '',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: AppColors.text,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
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
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            color: AppColors.text,
          ),
        );
      }
    }

    // 2. Gunakan diagnosisDetail jika ada dan memuat nama
    final detail = history.diagnosisDetail?.trim();
    if (detail != null &&
        detail.isNotEmpty &&
        detail != '—' &&
        detail != '-') {
      if (!_isJustCode(detail)) {
        return Text(
          detail,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            color: AppColors.text,
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
          fontSize: 12.5,
          fontWeight: FontWeight.w500,
          color: AppColors.sub,
        ),
      );
    }

    // Jika rawCodes sudah memuat nama
    if (!_isJustCode(rawCodes)) {
      return Text(
        rawCodes,
        style: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w500,
          color: AppColors.text,
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
          fontSize: 12.5,
          fontWeight: FontWeight.w500,
          color: AppColors.text,
        ),
      );
    }

    return _Icd10CodesResolver(codes: codes, fallback: rawCodes);
  }
}

class _Icd10CodesResolver extends ConsumerWidget {
  const _Icd10CodesResolver({
    required this.codes,
    required this.fallback,
  });

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
          fontSize: 12.5,
          fontWeight: FontWeight.w500,
          color: AppColors.text,
        ),
      );
    }

    return Text(
      results.join(', '),
      style: const TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w500,
        color: AppColors.text,
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
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            color: AppColors.text,
          ),
        );
      }
    }

    // 2. Gunakan tindakanDetail jika ada dan memuat nama
    final detail = history.tindakanDetail?.trim();
    if (detail != null &&
        detail.isNotEmpty &&
        detail != '—' &&
        detail != '-') {
      if (!_isJustCode(detail)) {
        return Text(
          detail,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            color: AppColors.text,
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
          fontSize: 12.5,
          fontWeight: FontWeight.w500,
          color: AppColors.sub,
        ),
      );
    }

    // Jika rawCodes sudah memuat nama
    if (!_isJustCode(rawCodes)) {
      return Text(
        rawCodes,
        style: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w500,
          color: AppColors.text,
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
          fontSize: 12.5,
          fontWeight: FontWeight.w500,
          color: AppColors.text,
        ),
      );
    }

    return _Icd9CodesResolver(codes: codes, fallback: rawCodes);
  }
}

class _Icd9CodesResolver extends ConsumerWidget {
  const _Icd9CodesResolver({
    required this.codes,
    required this.fallback,
  });

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
          fontSize: 12.5,
          fontWeight: FontWeight.w500,
          color: AppColors.text,
        ),
      );
    }

    return Text(
      results.join(', '),
      style: const TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w500,
        color: AppColors.text,
      ),
    );
  }
}
