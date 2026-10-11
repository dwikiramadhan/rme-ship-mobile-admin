import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/network/api_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_helper.dart';
import '../../../core/utils/diagnosis_helper.dart';
import '../../nurse/presentation/patient_form.dart';
import '../data/patient_repository.dart';
import '../domain/patient.dart';
import 'widgets/medical_record_detail_sheet.dart';

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
  int _previousTabIndex = 0;

  /// The calendar day of a date-only value (e.g. `2026-10-11T00:00:00Z`) as
  /// a local midnight, so it is shown as a date without a time.
  static DateTime? _calendarDay(dynamic raw) {
    final parsed = raw is DateTime ? raw : DateTime.tryParse('${raw ?? ''}');
    if (parsed == null) return null;
    final day = parsed.isUtc ? parsed : parsed.toLocal();
    return DateTime(day.year, day.month, day.day);
  }

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
    return '$dayName, $day-$month-$year $hour:$min ${DateHelper.zoneOf(local)}';
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
        content: const Row(
          children: [
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
    final rawPhoto = data['photo_url'] ?? data['photo'] ?? widget.initialPatient?.photoUrl;
    final photoUrl = (rawPhoto != null && rawPhoto.toString().isNotEmpty && rawPhoto.toString() != 'null')
        ? rawPhoto.toString()
        : null;
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
    final address =
        (data['address'] ?? widget.initialPatient?.alamat ?? '').toString().trim();
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
    // Parse each record's date once instead of twice per comparison; this
    // runs on every rebuild, including during the tab transition.
    final datedRecords = <({DateTime time, Map<String, dynamic> record})>[];
    if (rawRecords is List) {
      for (final r in rawRecords) {
        if (r is Map<String, dynamic>) {
          datedRecords.add((
            time: DateTime.tryParse(r['created_at']?.toString() ?? r['date']?.toString() ?? '') ??
                DateTime.fromMillisecondsSinceEpoch(0),
            record: r,
          ));
        }
      }
    }
    datedRecords.sort((a, b) => b.time.compareTo(a.time));
    final records = [for (final d in datedRecords) d.record];
    final totalVisits = records.isNotEmpty
        ? records.length
        : (widget.initialPatient != null ? 1 : 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Top Bar, fixed above the scrolling content.
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
          child: _buildTopBar(context, data),
        ),
        Expanded(
          child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                  children: [
                    // Avatar Oranye Bulat / Foto Pasien
                    GestureDetector(
                      onTap: (photoUrl != null && photoUrl.isNotEmpty)
                          ? () => _showFullPhoto(
                                context,
                                photoUrl.startsWith('http')
                                    ? photoUrl
                                    : '${ApiConfig.baseUrl}$photoUrl',
                                name,
                              )
                          : null,
                      child: Container(
                        width: 50,
                        height: 50,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE05315),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFFFDBA74),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFEA580C).withValues(alpha: 0.15),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: (photoUrl != null && photoUrl.isNotEmpty)
                            ? Image.network(
                                photoUrl.startsWith('http')
                                    ? photoUrl
                                    : '${ApiConfig.baseUrl}$photoUrl',
                                width: 50,
                                height: 50,
                                // Width only: forcing both dimensions decoded non-square photos
                                // into a square (squashed). This keeps the aspect ratio so
                                // BoxFit.cover crops instead.
                                cacheWidth: 150,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Text(
                                  initials,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              )
                            : Text(
                                initials,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
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
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            (nik.isNotEmpty && nik != '-')
                                ? 'NIK: $nik • $gender • $age tahun${formattedDob.isNotEmpty ? ' ($formattedDob)' : ''}'
                                : (photoUrl != null && photoUrl.isNotEmpty)
                                    ? 'Identitas: Foto • $gender • $age tahun${formattedDob.isNotEmpty ? ' ($formattedDob)' : ''}'
                                    : '$gender • $age tahun${formattedDob.isNotEmpty ? ' ($formattedDob)' : ''}',
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          // Full address, wrapping onto as many lines as needed.
                          if (address.isNotEmpty && address != '-') ...[
                            const SizedBox(height: 4),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.only(top: 1.5),
                                  child: Icon(
                                    LucideIcons.mapPin,
                                    size: 12,
                                    color: AppColors.sub,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    address,
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      height: 1.35,
                                      color: AppColors.sub,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
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

          // 3. Tab Navigation (segmented, sliding indicator)
          _buildTabBar(totalVisits),

          const SizedBox(height: 14),

          // 4. Tab Content with smooth slider effect
          ClipRect(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                final isForward = _selectedTabIndex >= _previousTabIndex;
                final isCurrent =
                    child.key == ValueKey<int>(_selectedTabIndex);

                final inOffset = isForward
                    ? const Offset(0.20, 0.0)
                    : const Offset(-0.20, 0.0);
                final outOffset = isForward
                    ? const Offset(-0.20, 0.0)
                    : const Offset(0.20, 0.0);

                final offsetTween = Tween<Offset>(
                  begin: isCurrent ? inOffset : outOffset,
                  end: Offset.zero,
                );

                return SlideTransition(
                  position: offsetTween.animate(
                    CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    ),
                  ),
                  child: FadeTransition(
                    opacity: CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOut,
                    ),
                    // Own layer: the slide then just moves a cached picture instead
                    // of repainting the whole tab on every animation frame.
                    child: RepaintBoundary(child: child),
                  ),
                );
              },
              child: KeyedSubtree(
                key: ValueKey<int>(_selectedTabIndex),
                child: _selectedTabIndex == 0
                    ? _buildMedicalRecordsTab(context, records, name, lastVisit)
                    : _buildProfileTab(data),
              ),
            ),
          ),
        ],
      ),
          ),
        ),
      ],
    );
  }

  /// [← Kembali ke Data Pasien] ... [Refresh] [Edit Pasien]
  Widget _buildTopBar(BuildContext context, Map<String, dynamic> data) {
    return Row(
      children: [
        // Kembali button: takes the free width, so Edit Pasien sits top-right.
        Expanded(
          child: Align(
          alignment: Alignment.centerLeft,
          child: Material(
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
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    LucideIcons.arrowLeft,
                    size: 15,
                    color: Color(0xFF334155),
                  ),
                  SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Kembali ke Data Pasien',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF334155),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        ),
        ),
        const SizedBox(width: 8),
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
                  // The form is a plain body widget (it is embedded in the
                  // nurse home's Scaffold elsewhere), so a pushed page needs
                  // its own Scaffold for text fields, ink and snackbars.
                  builder: (_) => Scaffold(
                    backgroundColor: AppColors.bg,
                    body: SafeArea(
                      child: PatientForm(
                        initialPatient: patientObj,
                        onBack: () => Navigator.of(context).pop(),
                        onSaved: () {
                          Navigator.of(context).pop();
                          // PatientForm already refreshes patients & history.
                          ref.invalidate(
                            patientDetailProvider(widget.patientId),
                          );
                        },
                      ),
                    ),
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
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
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
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFEA580C),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
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
              fontWeight: FontWeight.w600,
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
              fontWeight: FontWeight.w700,
              color: valueColor ?? const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }

  void _selectTab(int index) {
    if (_selectedTabIndex == index) return;
    setState(() {
      _previousTabIndex = _selectedTabIndex;
      _selectedTabIndex = index;
    });
  }

  /// Two equal segments with one white indicator that slides between them,
  /// so switching tabs is a single smooth motion (no splash, no flicker).
  Widget _buildTabBar(int totalVisits) {
    const duration = Duration(milliseconds: 250);
    return Container(
      height: 46,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: duration,
            curve: Curves.easeOutCubic,
            alignment: _selectedTabIndex == 0
                ? Alignment.centerLeft
                : Alignment.centerRight,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              heightFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 6,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: _buildTabItem(
                  index: 0,
                  icon: LucideIcons.fileText,
                  label: 'Riwayat Rekam Medis ($totalVisits)',
                  duration: duration,
                ),
              ),
              Expanded(
                child: _buildTabItem(
                  index: 1,
                  icon: LucideIcons.user,
                  label: 'Profil & Identitas Lengkap',
                  duration: duration,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabItem({
    required int index,
    required IconData icon,
    required String label,
    required Duration duration,
  }) {
    final isSelected = _selectedTabIndex == index;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _selectTab(index),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        // Only the colour animates; the font weight stays the same so the
        // label never jumps in width.
        child: TweenAnimationBuilder<Color?>(
          duration: duration,
          tween: ColorTween(end: isSelected ? AppColors.orange : AppColors.sub),
          builder: (context, color, _) => Center(
            // Scales the label down slightly on narrow phones instead of
            // overflowing or cutting it off.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 15, color: color),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          ),
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
        child: const Column(
          children: [
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
        // `date` is a calendar date only (stored as midnight UTC): without a
        // real timestamp, show just that day instead of a made-up time.
        final dateOnly = record['date'] ?? record['Date'];
        final rawDate = record['created_at'] ??
            record['CreatedAt'] ??
            record['visit_date'] ??
            record['visitDate'] ??
            _calendarDay(dateOnly) ??
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

        final shipName = (record['service_ship'] is Map
                ? record['service_ship']['name']
                : record['ship_name'])
            ?.toString()
            .trim() ??
            '';
        final harbor = (record['service_ship'] is Map
                ? record['service_ship']['location'] ??
                      record['service_ship']['port_name']
                : record['harbor'])
            ?.toString()
            .trim() ??
            '';

        final statusStr =
            (record['status'] ??
                    record['status_penanganan'] ??
                    'Menunggu Dokter')
                .toString();
        final isSelesai = statusStr.toLowerCase().contains('selesai');

        final doctorName = (record['doctor'] is Map
                ? record['doctor']['name']
                : record['doctor_name'])
            ?.toString()
            .trim() ??
            '';
        final doctorSip = (record['doctor'] is Map
                ? record['doctor']['sip']
                : record['doctor_sip'])
            ?.toString()
            .trim() ??
            '';

        final complaint =
            (record['complaint'] ?? record['keluhan'] ?? record['keluhan_utama'])
                ?.toString()
                .trim() ??
            '';
        final diagnosis = formatDiagnoses(
          record['diagnoses'],
          fallback: record['diagnosis'] ?? record['diagnosa'],
        );
        final prescriptions =
            record['prescriptions'] ??
            record['prescription'] ??
            record['medicines'];

        return _MedicalRecordCard(
          queueNumber: queueNumber,
          date: displayDate,
          shipName: shipName,
          harbor: harbor,
          status: statusStr,
          isDone: isSelesai,
          doctorName: doctorName,
          doctorSip: doctorSip,
          complaint: complaint,
          diagnosis: diagnosis,
          onViewPrescription: () =>
              _showPrescriptionDialog(context, prescriptions, patientName),
          onDownloadPrescription: () => _downloadPrescription(context),
          onTap: () => showMedicalRecordDetailSheet(context, record),
          // By visit number (#1, #2, ...), so colours don't shift when a
          // new visit is added on top.
          isEven: (records.length - index).isEven,
        );
      },
    );
  }

  Widget _buildProfileTab(Map<String, dynamic> data) {
    final name = (data['name'] ?? data['nama'] ?? '-').toString();
    final nik = (data['nik'] ?? '-').toString();
    final rawPhoto = data['photo_url'] ?? data['photo'] ?? widget.initialPatient?.photoUrl;
    final photoUrl = (rawPhoto != null && rawPhoto.toString().isNotEmpty && rawPhoto.toString() != 'null')
        ? rawPhoto.toString()
        : null;
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

    final hasMedicalNote = keterangan.trim().isNotEmpty && keterangan != '-';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ProfileSection(
          title: 'Identitas Diri & Informasi Pribadi',
          icon: LucideIcons.user,
          children: [
            _ProfileFieldGrid([
              _ProfileField('Nama Lengkap', name),
              _ProfileField(
                'Nomor Induk Kependudukan (NIK)',
                (nik.isNotEmpty && nik != '-')
                    ? nik
                    : ((photoUrl != null && photoUrl.isNotEmpty)
                        ? 'Foto Pasien (Terlampir)'
                        : '-'),
              ),
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
                if (photoUrl != null && photoUrl.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            photoUrl.startsWith('http')
                                ? photoUrl
                                : '${ApiConfig.baseUrl}$photoUrl',
                            width: 56,
                            height: 56,
                            // Width only: forcing both dimensions decoded non-square photos
                            // into a square (squashed). This keeps the aspect ratio so
                            // BoxFit.cover crops instead.
                            cacheWidth: 168,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(
                              width: 56,
                              height: 56,
                              color: const Color(0xFFE2E8F0),
                              child: const Icon(LucideIcons.image, color: Color(0xFF94A3B8)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Foto Identitas Pasien',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                              SizedBox(height: 3),
                              Text(
                                'Foto wajah/identitas terdaftar pada rekam medis pasien',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: () => _showFullPhoto(
                            context,
                            photoUrl.startsWith('http')
                                ? photoUrl
                                : '${ApiConfig.baseUrl}$photoUrl',
                            name,
                          ),
                          icon: const Icon(LucideIcons.eye, size: 14),
                          label: const Text('Lihat Foto', style: TextStyle(fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFE05315),
                            side: const BorderSide(color: Color(0xFFFDBA74)),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
          ],
        ),
        const SizedBox(height: 12),
        _ProfileSection(
          title: 'Alamat Tempat Tinggal',
          icon: LucideIcons.mapPin,
          children: [
            _ProfileFieldGrid([
              _ProfileField('Alamat Lengkap', address),
              _ProfileField('Kode Pos', postalCode),
            ]),
          ],
        ),
        const SizedBox(height: 12),
        _ProfileSection(
          title: 'Kontak Darurat & Wali',
          icon: LucideIcons.users,
          children: [
            _ProfileFieldGrid([
              _ProfileField('Nama Wali', namaWali),
              _ProfileField('Hubungan Wali', hubunganWali),
            ]),
          ],
        ),
        const SizedBox(height: 12),
        _ProfileSection(
          title: 'Informasi Layanan & Catatan Khusus',
          icon: LucideIcons.stethoscope,
          children: [
            _ProfileFieldGrid([
              _ProfileField('Kapal Layanan Terdaftar', shipName),
              _ProfileField('Poliklinik Terdaftar', poliName),
              if (!hasMedicalNote)
                const _ProfileField('Catatan Medis / Riwayat Alergi', '-'),
            ]),
            // Allergies / medical notes matter clinically: give them their own
            // highlighted box instead of a plain field.
            if (hasMedicalNote) ...[
              const SizedBox(height: 12),
              _MedicalNoteCallout(note: keterangan),
            ],
          ],
        ),
      ],
    );
  }


  void _showFullPhoto(BuildContext context, String imageUrl, String name) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              constraints: const BoxConstraints(maxWidth: 480, maxHeight: 600),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(16),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppBar(
                    backgroundColor: Colors.black.withValues(alpha: 0.6),
                    elevation: 0,
                    title: Text(
                      'Foto $name',
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                    leading: IconButton(
                      icon: const Icon(LucideIcons.x, color: Colors.white),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ),
                  Flexible(
                    child: InteractiveViewer(
                      clipBehavior: Clip.none,
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.contain,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return const Padding(
                            padding: EdgeInsets.all(40),
                            child: CircularProgressIndicator(color: Colors.white),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) => const Padding(
                          padding: EdgeInsets.all(32),
                          child: Text(
                            'Gagal memuat foto',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileField {
  const _ProfileField(this.label, this.value);
  final String label;
  final String value;
}

/// One visit in "Riwayat Rekam Medis": header (number, date, ship, status),
/// the clinical summary, and the prescription actions for finished visits.
class _MedicalRecordCard extends StatelessWidget {
  const _MedicalRecordCard({
    required this.queueNumber,
    required this.date,
    required this.shipName,
    required this.harbor,
    required this.status,
    required this.isDone,
    required this.doctorName,
    required this.doctorSip,
    required this.complaint,
    required this.diagnosis,
    required this.onViewPrescription,
    required this.onDownloadPrescription,
    required this.onTap,
    required this.isEven,
  });

  final String queueNumber;
  final String date;
  final String shipName;
  final String harbor;
  final String status;
  final bool isDone;
  final String doctorName;
  final String doctorSip;
  final String complaint;
  final String diagnosis;
  final VoidCallback onViewPrescription;
  final VoidCallback onDownloadPrescription;

  /// Opens the visit's full detail.
  final VoidCallback onTap;

  /// Even-numbered visits get a soft tinted background (odd ones stay white)
  /// so neighbouring cards are easy to tell apart.
  final bool isEven;

  String get _location => [
    shipName,
    harbor,
  ].where((s) => s.isNotEmpty).join(' · ');

  @override
  Widget build(BuildContext context) {
    final statusColor = isDone ? AppColors.green : AppColors.sky;
    final statusBg = isDone ? AppColors.greenLt : AppColors.skyLt;

    final radius = BorderRadius.circular(14);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Ink(
      decoration: BoxDecoration(
        color: isEven ? AppColors.orangeLt : AppColors.card,
        borderRadius: radius,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            // Badge, date block, status and arrow share one centre line.
            child: Row(
              children: [
                Container(
                  constraints: const BoxConstraints(minWidth: 34),
                  height: 34,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    // On the tinted card the badge turns white to stay visible.
                    color: isEven ? AppColors.card : AppColors.orangeLt,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.orange.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Text(
                    queueNumber,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.orange,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            LucideIcons.calendar,
                            size: 13,
                            color: AppColors.orange,
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              date,
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.text,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_location.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 1),
                              child: Icon(
                                LucideIcons.ship,
                                size: 12,
                                color: AppColors.sub,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                _location,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.sub,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        status,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 2),
                const Icon(
                  LucideIcons.chevronRight,
                  size: 16,
                  color: AppColors.sub,
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: AppColors.border),

          // Clinical summary: three columns when there is room, stacked on phones.
          Padding(
            padding: const EdgeInsets.all(14),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final doctor = _RecordFact(
                  icon: LucideIcons.stethoscope,
                  label: 'Dokter Pemeriksa',
                  value: doctorName.isNotEmpty ? doctorName : '-',
                  detail: doctorSip.isNotEmpty ? 'SIP: $doctorSip' : null,
                );
                final keluhan = _RecordFact(
                  icon: LucideIcons.messageSquare,
                  label: 'Keluhan Utama',
                  value: complaint.isNotEmpty ? complaint : '-',
                );
                final diagnosa = _DiagnosisBox(diagnosis: diagnosis);

                if (constraints.maxWidth >= 600) {
                  return IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(flex: 4, child: doctor),
                        const SizedBox(width: 16),
                        Expanded(flex: 3, child: keluhan),
                        const SizedBox(width: 16),
                        Expanded(flex: 4, child: diagnosa),
                      ],
                    ),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    doctor,
                    const SizedBox(height: 12),
                    keluhan,
                    const SizedBox(height: 12),
                    diagnosa,
                  ],
                );
              },
            ),
          ),

          if (isDone) ...[
            const Divider(height: 1, thickness: 1, color: AppColors.border),
            Container(
              // Footer stays a shade darker than the card body.
              color: isEven
                  ? AppColors.orange.withValues(alpha: 0.06)
                  : AppColors.card2,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: onViewPrescription,
                    icon: const Icon(LucideIcons.eye, size: 14),
                    label: const Text('Detail Resep'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.orange,
                      side: BorderSide(
                        color: AppColors.orange.withValues(alpha: 0.45),
                      ),
                      backgroundColor: AppColors.card,
                      minimumSize: const Size(0, 34),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      textStyle: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: onDownloadPrescription,
                    icon: const Icon(LucideIcons.download, size: 14),
                    label: const Text('Unduh Resep'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.orange,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 34),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      textStyle: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
        ),
      ),
        ),
      ),
    );
  }
}

/// Icon + small caps label + bold value (+ optional muted detail line).
class _RecordFact extends StatelessWidget {
  const _RecordFact({
    required this.icon,
    required this.label,
    required this.value,
    this.detail,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.bg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 14, color: AppColors.sub),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: const TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.sub,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: AppColors.text,
                ),
              ),
              if (detail != null) ...[
                const SizedBox(height: 2),
                Text(
                  detail!,
                  style: const TextStyle(fontSize: 10.5, color: AppColors.sub),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// The visit's diagnosis, emphasised with an orange accent bar.
class _DiagnosisBox extends StatelessWidget {
  const _DiagnosisBox({required this.diagnosis});

  final String diagnosis;

  @override
  Widget build(BuildContext context) {
    final text = diagnosis.trim();
    final isEmpty = text.isEmpty || text == '-' || text == '—';

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 9, 12, 10),
      decoration: BoxDecoration(
        color: AppColors.orangeLt,
        borderRadius: BorderRadius.circular(10),
        border: const Border(
          left: BorderSide(color: AppColors.orange, width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'DIAGNOSIS',
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              color: AppColors.orange,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            isEmpty ? 'Belum ada diagnosis' : text,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: isEmpty ? FontWeight.w400 : FontWeight.w600,
              color: isEmpty ? AppColors.sub : AppColors.text,
            ),
          ),
        ],
      ),
    );
  }
}

/// A titled white card for one group of profile data.
class _ProfileSection extends StatelessWidget {
  const _ProfileSection({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.orangeLt,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 15, color: AppColors.orange),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: AppColors.border),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

/// Label/value pairs, two per row when there is room, each underlined.
class _ProfileFieldGrid extends StatelessWidget {
  const _ProfileFieldGrid(this.fields);

  final List<_ProfileField> fields;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 20.0;
        final twoColumns = constraints.maxWidth >= 560;
        final width = twoColumns
            ? (constraints.maxWidth - gap) / 2
            : constraints.maxWidth;
        return Wrap(
          spacing: gap,
          children: [
            for (final f in fields)
              SizedBox(width: width, child: _ProfileFieldTile(field: f)),
          ],
        );
      },
    );
  }
}

class _ProfileFieldTile extends StatelessWidget {
  const _ProfileFieldTile({required this.field});

  final _ProfileField field;

  @override
  Widget build(BuildContext context) {
    final value = field.value.trim();
    final isEmpty = value.isEmpty || value == '-' || value == 'null';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.bg, width: 1.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            field.label.toUpperCase(),
            style: const TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              color: AppColors.sub,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isEmpty ? '-' : value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isEmpty ? FontWeight.w400 : FontWeight.w500,
              color: isEmpty ? AppColors.sub : AppColors.text,
            ),
          ),
        ],
      ),
    );
  }
}

/// Highlighted box for allergies / special medical notes.
class _MedicalNoteCallout extends StatelessWidget {
  const _MedicalNoteCallout({required this.note});

  final String note;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.redLt,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.red.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(LucideIcons.triangleAlert, size: 16, color: AppColors.red),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'CATATAN MEDIS / RIWAYAT ALERGI',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.red,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  note.trim(),
                  style: const TextStyle(
                    fontSize: 13,
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
}
