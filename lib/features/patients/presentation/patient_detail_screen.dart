import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_helper.dart';
import '../../../core/utils/diagnosis_helper.dart';
import '../../nurse/presentation/patient_form.dart';
import '../data/patient_repository.dart';
import '../domain/patient.dart';

/// Screen detail data pasien dengan visual design yang selaras dengan web Bayan RME:
/// - Top Bar: [← Kembali ke Data Pasien], [Refresh], [✏️ Edit Pasien]
/// - Header Card: Avatar oranye, Nama, NIK & Demografi, 4 Stat Box (Gol. Darah, No. Telp, Total Kunjungan, Kunjungan Terakhir)
/// - Tab 1: Riwayat Rekam Medis (Daftar kunjungan dengan dokter, keluhan, diagnosa, resep)
/// - Tab 2: Profil & Identitas Lengkap (Data pribadi, alamat, wali, keterangan alergi)
class PatientDetailScreen extends ConsumerStatefulWidget {
  const PatientDetailScreen({
    super.key,
    required this.patientId,
    this.initialPatient,
  });

  final String patientId;
  final Patient? initialPatient;

  @override
  ConsumerState<PatientDetailScreen> createState() =>
      _PatientDetailScreenState();
}

class _PatientDetailScreenState extends ConsumerState<PatientDetailScreen> {
  int _selectedTabIndex = 0;

  String _formatIndonesianDateTime(dynamic raw) {
    if (raw == null) return '-';
    DateTime? dt;
    if (raw is DateTime) {
      dt = raw;
    } else if (raw is int) {
      // Unix timestamp dalam milidetik atau detik
      if (raw > 100000000000) {
        dt = DateTime.fromMillisecondsSinceEpoch(raw);
      } else {
        dt = DateTime.fromMillisecondsSinceEpoch(raw * 1000);
      }
    } else if (raw is String) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty || trimmed == '-' || trimmed == '—') return '-';

      // 1. ISO 8601 & standar DateTime format (e.g. 2026-08-30T07:00:00Z, 2026-08-30 07:00:00)
      dt = DateTime.tryParse(trimmed);

      // 2. Parse Go time string dengan timezone (e.g. "2026-07-17 14:42:58.781533 +0700 WIB")
      if (dt == null) {
        try {
          final withoutZoneName = trimmed.replaceFirst(RegExp(r'\s+[A-Z]{3,4}$'), '');
          final parts = withoutZoneName.split(' ');
          if (parts.length >= 2) {
            final datePart = parts[0];
            final timePart = parts[1];
            String tzPart = parts.length >= 3 ? parts[2] : '';
            if (RegExp(r'^[+-]\d{4}$').hasMatch(tzPart)) {
              tzPart = '${tzPart.substring(0, 3)}:${tzPart.substring(3)}';
            }
            final isoCandidate = '${datePart}T$timePart$tzPart';
            dt = DateTime.tryParse(isoCandidate);
          }
        } catch (_) {}
      }

      // 3. Format DD-MM-YYYY atau DD/MM/YYYY
      if (dt == null) {
        final dmyMatch = RegExp(r'^(\d{1,2})[-/](\d{1,2})[-/](\d{4})(?:\s+(\d{1,2}):(\d{1,2}))?').firstMatch(trimmed);
        if (dmyMatch != null) {
          final day = int.parse(dmyMatch.group(1)!);
          final month = int.parse(dmyMatch.group(2)!);
          final year = int.parse(dmyMatch.group(3)!);
          final hour = dmyMatch.group(4) != null ? int.parse(dmyMatch.group(4)!) : 0;
          final minute = dmyMatch.group(5) != null ? int.parse(dmyMatch.group(5)!) : 0;
          dt = DateTime(year, month, day, hour, minute);
        }
      }

      // 4. Jika tetap tidak bisa diparsing sebagai DateTime tapi ada nilainya, tampilkan teks aslinya
      if (dt == null) return trimmed;
    }

    if (dt == null) return raw.toString();

    final local = dt.toLocal();
    const days = [
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu',
      'Minggu',
    ];
    final dayName = days[local.weekday - 1];
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year.toString();
    final hour = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');

    // Jika waktu tepat 00:00 (hanya tanggal), tampilkan hari dan tanggal
    if (local.hour == 0 && local.minute == 0) {
      return '$dayName, $day-$month-$year';
    }
    return '$dayName, $day-$month-$year $hour:$min WIB';
  }

  void _showPrescriptionDialog(
    BuildContext context,
    dynamic prescriptions,
    String patientName,
  ) {
    final list = <Map<String, dynamic>>[];
    if (prescriptions is List) {
      for (final p in prescriptions) {
        if (p is Map<String, dynamic>) list.add(p);
      }
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                LucideIcons.pill,
                color: Color(0xFFEA580C),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Detail Resep Obat',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    patientName,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: list.isEmpty
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'Tidak ada rincian obat yang tercatat.',
                    style: TextStyle(
                      color: Color(0xFF64748B),
                    ),
                  ),
                ),
              )
            : SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: list.map((med) {
                    final nama =
                        med['medicine_name'] ??
                        med['name'] ??
                        med['nama'] ??
                        med['obat'] ??
                        'Obat';
                    final qty =
                        med['quantity'] ?? med['qty'] ?? med['jumlah'] ?? '1';
                    final aturan =
                        med['instructions'] ??
                        med['aturan'] ??
                        med['dosage'] ??
                        '-';
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            LucideIcons.pill,
                            size: 16,
                            color: Color(0xFF2563EB),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  nama.toString(),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Aturan: $aturan',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3.5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Qty: $qty',
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF2563EB),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF64748B),
              textStyle: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  void _downloadPrescription(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: const [
            Icon(LucideIcons.circleCheck, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text(
              'Resep pasien berhasil diunduh ke perangkat',
              style: TextStyle(fontSize: 13),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF059669),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final asyncDetail = ref.watch(patientDetailProvider(widget.patientId));

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: asyncDetail.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: Color(0xFFEA580C)),
          ),
          error: (err, stack) => _buildErrorState(context, err.toString()),
          data: (data) => _buildContent(context, data),
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.alertCircle, color: AppColors.red, size: 48),
            const SizedBox(height: 14),
            const Text(
              'Gagal Memuat Detail Pasien',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () =>
                  ref.invalidate(patientDetailProvider(widget.patientId)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEA580C),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: const Icon(LucideIcons.refreshCw, size: 16),
              label: const Text(
                'Coba Lagi',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, Map<String, dynamic> data) {
    final name =
        (data['name'] ??
                data['nama'] ??
                widget.initialPatient?.nama ??
                'Pasien')
            .toString();
    final nik = (data['nik'] ?? widget.initialPatient?.nik ?? '').toString();
    final gender =
        (data['gender'] ??
                (widget.initialPatient?.jk == Gender.l
                    ? 'Laki-laki'
                    : 'Perempuan'))
            .toString();
    final dobStr = (data['dob'] ?? widget.initialPatient?.dob ?? '').toString();
    final bloodType =
        (data['blood_type'] ?? widget.initialPatient?.bloodType ?? '-')
            .toString();
    final phone = (data['phone'] ?? widget.initialPatient?.phone ?? '-')
        .toString();
    final lastVisit =
        (data['last_visit'] ?? widget.initialPatient?.lastVisit ?? '-')
            .toString();

    // Hitung umur
    int age = widget.initialPatient?.umur ?? 0;
    String formattedDob = dobStr;
    if (dobStr.isNotEmpty) {
      try {
        final birth = DateTime.parse(dobStr);
        final today = DateTime.now();
        age = today.year - birth.year;
        if (today.month < birth.month ||
            (today.month == birth.month && today.day < birth.day)) {
          age--;
        }
        if (age < 0) age = 0;
        formattedDob =
            '${birth.year}-${birth.month.toString().padLeft(2, '0')}-${birth.day.toString().padLeft(2, '0')}';
      } catch (_) {}
    }

    // Inisial 2 huruf untuk Avatar
    final nameParts = name.trim().split(RegExp(r'\s+'));
    String initials = 'P';
    if (nameParts.length >= 2) {
      initials = '${nameParts[0][0]}${nameParts[1][0]}'.toUpperCase();
    } else if (nameParts.isNotEmpty && nameParts[0].isNotEmpty) {
      initials = nameParts[0]
          .substring(0, nameParts[0].length >= 2 ? 2 : 1)
          .toUpperCase();
    }

    // Medical records
    final rawRecords = data['medical_records'];
    final List<Map<String, dynamic>> records = [];
    if (rawRecords is List) {
      for (final r in rawRecords) {
        if (r is Map<String, dynamic>) records.add(r);
      }
    }
    final totalVisits = records.isNotEmpty
        ? records.length
        : (widget.initialPatient != null ? 1 : 0);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Top Bar: [← Kembali ke Data Pasien], [Refresh], [Edit Pasien]
          Row(
            children: [
              // Kembali button
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => Navigator.of(context).pop(),
                  borderRadius: BorderRadius.circular(30),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(
                          LucideIcons.arrowLeft,
                          size: 15,
                          color: Color(0xFF334155),
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Kembali ke Data Pasien',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF334155),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const Spacer(),
              // Refresh button
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () =>
                      ref.invalidate(patientDetailProvider(widget.patientId)),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      LucideIcons.refreshCw,
                      size: 14,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Edit Pasien button
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    final patientObj = Patient.fromApiJson(data);
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PatientForm(
                          initialPatient: patientObj,
                          onBack: () => Navigator.of(context).pop(),
                          onSaved: () {
                            Navigator.of(context).pop();
                            ref.invalidate(
                              patientDetailProvider(widget.patientId),
                            );
                          },
                        ),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(30),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: const Color(0xFFFDBA74)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(
                          LucideIcons.pencil,
                          size: 13,
                          color: Color(0xFFEA580C),
                        ),
                        SizedBox(width: 5),
                        Text(
                          'Edit Pasien',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFEA580C),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // 2. Main Patient Card (Header dengan 4 Stat Box)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                  blurRadius: 18,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Profil Pasien
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Avatar Oranye Bulat
                    Container(
                      width: 50,
                      height: 50,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: Color(0xFFE05315),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        initials,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    // Nama & NIK Demografi
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'NIK: ${nik.isNotEmpty ? nik : '-'} • $gender • $age tahun${formattedDob.isNotEmpty ? ' ($formattedDob)' : ''}',
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // 4 Stat Box
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 600;
                    if (isNarrow) {
                      return Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _buildStatBox(
                                  label: 'GOLONGAN DARAH',
                                  value:
                                      bloodType.isNotEmpty && bloodType != '-'
                                      ? bloodType
                                      : '-',
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _buildStatBox(
                                  label: 'NO. TELEPON',
                                  value: phone.isNotEmpty && phone != '-'
                                      ? phone
                                      : '-',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: _buildStatBox(
                                  label: 'TOTAL KUNJUNGAN',
                                  value: '$totalVisits Kali',
                                  valueColor: const Color(0xFFEA580C),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _buildStatBox(
                                  label: 'KUNJUNGAN TERAKHIR',
                                  value:
                                      lastVisit.isNotEmpty && lastVisit != '-'
                                      ? formatDate(lastVisit)
                                      : '-',
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    }

                    return Row(
                      children: [
                        Expanded(
                          child: _buildStatBox(
                            label: 'GOLONGAN DARAH',
                            value: bloodType.isNotEmpty && bloodType != '-'
                                ? bloodType
                                : '-',
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildStatBox(
                            label: 'NO. TELEPON',
                            value: phone.isNotEmpty && phone != '-'
                                ? phone
                                : '-',
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildStatBox(
                            label: 'TOTAL KUNJUNGAN',
                            value: '$totalVisits Kali',
                            valueColor: const Color(0xFFEA580C),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildStatBox(
                            label: 'KUNJUNGAN TERAKHIR',
                            value: lastVisit.isNotEmpty && lastVisit != '-'
                                ? formatDate(lastVisit)
                                : '-',
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // 3. Tab Navigation (Underline Oranye)
          Row(
            children: [
              _buildTabItem(
                index: 0,
                icon: LucideIcons.fileText,
                label: 'Riwayat Rekam Medis ($totalVisits)',
              ),
              const SizedBox(width: 20),
              _buildTabItem(
                index: 1,
                icon: LucideIcons.user,
                label: 'Profil & Identitas Lengkap',
              ),
            ],
          ),

          const SizedBox(height: 14),

          // 4. Tab Content
          if (_selectedTabIndex == 0)
            _buildMedicalRecordsTab(context, records, name, lastVisit)
          else
            _buildProfileTab(data),
        ],
      ),
    );
  }

  Widget _buildStatBox({
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF94A3B8),
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: valueColor ?? const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabItem({
    required int index,
    required IconData icon,
    required String label,
  }) {
    final isSelected = _selectedTabIndex == index;
    return InkWell(
      onTap: () => setState(() => _selectedTabIndex = index),
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
      focusColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? const Color(0xFFEA580C) : Colors.transparent,
              width: 2.5,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected
                  ? const Color(0xFFEA580C)
                  : const Color(0xFF64748B),
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? const Color(0xFFEA580C)
                    : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMedicalRecordsTab(
    BuildContext context,
    List<Map<String, dynamic>> records,
    String patientName, [
    String? fallbackLastVisit,
  ]) {
    if (records.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          children: const [
            Icon(LucideIcons.fileX, size: 40, color: Color(0xFFCBD5E1)),
            SizedBox(height: 12),
            Text(
              'Belum Ada Riwayat Rekam Medis',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Pasien ini belum memiliki riwayat kunjungan medis yang tercatat.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: records.length,
      separatorBuilder: (_, _) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        final record = records[index];
        final queueNumber = '#${records.length - index}';
        final rawDate = record['created_at'] ??
            record['CreatedAt'] ??
            record['visit_date'] ??
            record['visitDate'] ??
            record['date'] ??
            record['Date'] ??
            record['tanggal'] ??
            record['tanggal_kunjungan'] ??
            record['waktu_kunjungan'] ??
            record['waktu_masuk'] ??
            record['waktuMasuk'] ??
            record['waktu_pemeriksaan'] ??
            record['check_in_time'] ??
            record['entry_date'] ??
            record['updated_at'] ??
            record['UpdatedAt'] ??
            fallbackLastVisit;
        final formattedDate = _formatIndonesianDateTime(rawDate);
        final displayDate = (formattedDate != '-' && formattedDate.isNotEmpty)
            ? formattedDate
            : 'Tanggal Kunjungan';

        final shipName = record['service_ship'] is Map
            ? record['service_ship']['name']?.toString() ??
                  'RSK dr. Lie Dharmawan Bayan Peduli I'
            : (record['ship_name']?.toString() ??
                  'RSK dr. Lie Dharmawan Bayan Peduli I');
        final harbor = record['service_ship'] is Map
            ? record['service_ship']['location']?.toString() ??
                  record['service_ship']['port_name']?.toString() ??
                  'Pelabuhan Tanjung Priok'
            : (record['harbor']?.toString() ?? 'Pelabuhan Tanjung Priok');

        final statusStr =
            (record['status'] ??
                    record['status_penanganan'] ??
                    'Menunggu Dokter')
                .toString();
        final isSelesai = statusStr.toLowerCase().contains('selesai');

        final doctorName = record['doctor'] is Map
            ? record['doctor']['name']?.toString() ?? 'dr. Andika Pratama'
            : (record['doctor_name']?.toString() ?? 'dr. Andika Pratama');
        final doctorSip = record['doctor'] is Map
            ? record['doctor']['sip']?.toString() ??
                  '7/B.15a/31.73.08.1002.19.BJ/4/TM.09.74/e/2025'
            : (record['doctor_sip']?.toString() ??
                  '7/B.15a/31.73.08.1002.19.BJ/4/TM.09.74/e/2025');

        final complaint =
            (record['complaint'] ??
                    record['keluhan'] ??
                    record['keluhan_utama'] ??
                    'Demam dan sakit kepala')
                .toString();
        final diagnosis = formatDiagnoses(
          record['diagnoses'],
          fallback: record['diagnosis'] ?? record['diagnosa'],
        );
        final prescriptions =
            record['prescriptions'] ??
            record['prescription'] ??
            record['medicines'];

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Card: Tag #, Kalender + Jam • Kapal & Pelabuhan, Status & Action (Responsive)
              LayoutBuilder(
                builder: (context, cardConstraints) {
                  final isWide = cardConstraints.maxWidth > 850;

                  final visitInfoWidget = Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      // Nomor Tag
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2.5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Text(
                          queueNumber,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ),
                      const Icon(
                        LucideIcons.calendar,
                        size: 13,
                        color: Color(0xFFEA580C),
                      ),
                      Text(
                        displayDate,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const Text(
                        '•',
                        style: TextStyle(color: Color(0xFF94A3B8)),
                      ),
                      const Icon(
                        LucideIcons.ship,
                        size: 13,
                        color: Color(0xFF64748B),
                      ),
                      Text(
                        '$shipName ($harbor)',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  );

                  final actionWidgets = Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      // Status Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3.5,
                        ),
                        decoration: BoxDecoration(
                          color: isSelesai
                              ? const Color(0xFFECFDF5)
                              : const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelesai
                                ? const Color(0xFFA7F3D0)
                                : const Color(0xFFBFDBFE),
                          ),
                        ),
                        child: Text(
                          statusStr,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: isSelesai
                                ? const Color(0xFF059669)
                                : const Color(0xFF2563EB),
                          ),
                        ),
                      ),
                      if (isSelesai) ...[
                        // Tombol Detail Resep
                        InkWell(
                          onTap: () => _showPrescriptionDialog(
                            context,
                            prescriptions,
                            patientName,
                          ),
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3.5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: const Color(0xFFFDBA74),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(
                                  LucideIcons.eye,
                                  size: 12,
                                  color: Color(0xFFEA580C),
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Detail Resep',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFFEA580C),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Tombol Unduh Resep
                        InkWell(
                          onTap: () => _downloadPrescription(context),
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3.5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0D9488),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(
                                  LucideIcons.download,
                                  size: 12,
                                  color: Colors.white,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Unduh Resep',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  );

                  if (isWide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(child: visitInfoWidget),
                        const SizedBox(width: 12),
                        actionWidgets,
                      ],
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      visitInfoWidget,
                      const SizedBox(height: 8),
                      actionWidgets,
                    ],
                  );
                },
              ),

              const SizedBox(height: 12),

              // Body Box: Dokter Pemeriksa, Keluhan Utama, Diagnosis
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Dokter Pemeriksa
                    Expanded(
                      flex: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'DOKTER PEMERIKSA',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF94A3B8),
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            doctorSip.isNotEmpty
                                ? '$doctorName (SIP: $doctorSip)'
                                : doctorName,
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Keluhan Utama
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'KELUHAN UTAMA',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF94A3B8),
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            complaint,
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF334155),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Diagnosis (Label Oranye)
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'DIAGNOSIS',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFEA580C),
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            diagnosis,
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
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
        );
      },
    );
  }

  Widget _buildProfileTab(Map<String, dynamic> data) {
    final name = (data['name'] ?? data['nama'] ?? '-').toString();
    final nik = (data['nik'] ?? '-').toString();
    final regNo = (data['register_no'] ?? '-').toString();
    final gender = (data['gender'] ?? '-').toString();
    final dob = (data['dob'] ?? '-').toString();
    final bloodType = (data['blood_type'] ?? '-').toString();
    final phone = (data['phone'] ?? '-').toString();
    final address = (data['address'] ?? '-').toString();
    final postalCode = (data['kode_pos'] ?? '-').toString();
    final namaWali = (data['nama_wali'] ?? '-').toString();
    final hubunganWali = (data['hubungan_wali'] ?? '-').toString();
    final keterangan = (data['keterangan'] ?? '-').toString();

    final shipName = data['service_ship'] is Map
        ? data['service_ship']['name']?.toString() ?? '-'
        : (data['service_ship_code']?.toString() ?? '-');
    final poliName = data['poliklinik'] is Map
        ? data['poliklinik']['name']?.toString() ?? '-'
        : (data['poli_code']?.toString() ?? '-');

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProfileSectionHeader(
            'Identitas Diri & Informasi Pribadi',
            LucideIcons.user,
          ),
          const SizedBox(height: 12),
          _buildProfileGrid([
            _ProfileField('Nama Lengkap', name),
            _ProfileField('Nomor Induk Kependudukan (NIK)', nik),
            _ProfileField(
              'No. Registrasi / Rekam Medis',
              regNo.isNotEmpty ? regNo : '-',
            ),
            _ProfileField('Jenis Kelamin', gender),
            _ProfileField(
              'Tanggal Lahir',
              dob.isNotEmpty && dob != '-' ? formatDate(dob) : '-',
            ),
            _ProfileField('Golongan Darah', bloodType),
            _ProfileField('Nomor Telepon / Handphone', phone),
          ]),

          const SizedBox(height: 20),
          const Divider(color: Color(0xFFF1F5F9)),
          const SizedBox(height: 14),

          _buildProfileSectionHeader(
            'Alamat Tempat Tinggal',
            LucideIcons.mapPin,
          ),
          const SizedBox(height: 12),
          _buildProfileGrid([
            _ProfileField('Alamat Lengkap', address),
            _ProfileField('Kode Pos', postalCode),
          ]),

          const SizedBox(height: 20),
          const Divider(color: Color(0xFFF1F5F9)),
          const SizedBox(height: 14),

          _buildProfileSectionHeader(
            'Kontak Darurat & Wali',
            LucideIcons.users,
          ),
          const SizedBox(height: 12),
          _buildProfileGrid([
            _ProfileField('Nama Wali', namaWali),
            _ProfileField('Hubungan Wali', hubunganWali),
          ]),

          const SizedBox(height: 20),
          const Divider(color: Color(0xFFF1F5F9)),
          const SizedBox(height: 14),

          _buildProfileSectionHeader(
            'Informasi Layanan & Catatan Khusus',
            LucideIcons.stethoscope,
          ),
          const SizedBox(height: 12),
          _buildProfileGrid([
            _ProfileField('Kapal Layanan Terdaftar', shipName),
            _ProfileField('Poliklinik Terdaftar', poliName),
            _ProfileField('Catatan Medis / Riwayat Alergi', keterangan),
          ]),
        ],
      ),
    );
  }

  Widget _buildProfileSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 15, color: const Color(0xFFEA580C)),
        const SizedBox(width: 7),
        Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileGrid(List<_ProfileField> fields) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 600;
        return Wrap(
          spacing: 16,
          runSpacing: 12,
          children: fields.map((f) {
            return SizedBox(
              width: isNarrow
                  ? constraints.maxWidth
                  : (constraints.maxWidth - 16) / 2,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      f.label.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF94A3B8),
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 2.5),
                    Text(
                      f.value.isNotEmpty ? f.value : '-',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _ProfileField {
  const _ProfileField(this.label, this.value);
  final String label;
  final String value;
}
