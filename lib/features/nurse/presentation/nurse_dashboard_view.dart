import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/screen_header.dart';
import '../../patients/data/patient_repository.dart';
import '../../patients/domain/patient.dart';
import '../../schedule/data/schedule_api.dart';
import '../../schedule/domain/trip_schedule.dart';
import '../../schedule/presentation/widgets/edit_clinics_modal.dart';

class NurseDashboardView extends ConsumerStatefulWidget {
  const NurseDashboardView({
    super.key,
    required this.nurseName,
    required this.onNavigateToTab,
  });

  final String nurseName;
  final ValueChanged<String> onNavigateToTab;

  @override
  ConsumerState<NurseDashboardView> createState() => _NurseDashboardViewState();
}

class _NurseDashboardViewState extends ConsumerState<NurseDashboardView> {
  void _editClinics(BuildContext context, JadwalPerjalanan schedule) {
    EditClinicsModal.show(
      context,
      schedule: schedule,
      onSave: (body) async {
        final api = ScheduleApi();
        await api.updateSchedule(schedule.id, body);
        ref.invalidate(scheduleCounterProvider);
        await ref.read(schedulesNotifierProvider.notifier).refresh();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Poli layanan berhasil diperbarui'),
              backgroundColor: AppColors.green,
            ),
          );
        }
      },
    );
  }

  JadwalPerjalanan? _findActiveVoyage(List<JadwalPerjalanan> list) {
    for (final j in list) {
      if (j.isOngoing) return j;
    }
    return list.firstOrNull;
  }

  bool _isToday(dynamic dateValue) {
    if (dateValue == null) return false;
    final now = DateTime.now();
    if (dateValue is DateTime) {
      final local = dateValue.toLocal();
      return local.year == now.year &&
          local.month == now.month &&
          local.day == now.day;
    }
    if (dateValue is String) {
      final trimmed = dateValue.trim();
      if (trimmed.isEmpty || trimmed == '-') return false;
      final parsed = DateTime.tryParse(trimmed);
      if (parsed != null) {
        final local = parsed.toLocal();
        return local.year == now.year &&
            local.month == now.month &&
            local.day == now.day;
      }
      final parts = trimmed.split(RegExp(r'[/ -]'));
      if (parts.length >= 3) {
        final d = int.tryParse(parts[0]);
        final m = int.tryParse(parts[1]);
        final y = int.tryParse(parts[2]);
        if (d != null && m != null && y != null && y > 1000) {
          return d == now.day && m == now.month && y == now.year;
        }
        final y2 = int.tryParse(parts[0]);
        final m2 = int.tryParse(parts[1]);
        final d2 = int.tryParse(parts[2]);
        if (d2 != null && m2 != null && y2 != null && y2 > 1000) {
          return d2 == now.day && m2 == now.month && y2 == now.year;
        }
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final patients = ref.watch(patientsProvider);
    final histories = ref.watch(medicalHistoryProvider);
    final schedules = ref.watch(jadwalPerjalananProvider);

    // Active Voyage: Prefer Ongoing, fallback to first schedule
    final activeVoyage = _findActiveVoyage(schedules);

    // 1. Kunjungan Hari Ini: Riwayat kunjungan yang tercatat hari ini
    final todayVisits = histories.where((h) {
      return _isToday(h.createdAt) || _isToday(h.date) || _isToday(h.updatedAt);
    }).toList();
    final todayVisitCount = todayVisits.length;

    final todayVisitPatientIds = todayVisits
        .map((h) => h.patientId)
        .where((id) => id.isNotEmpty)
        .toSet();
    final todayVisitPatientNiks = todayVisits
        .map((h) => h.patientNik)
        .where((nik) => nik.isNotEmpty)
        .toSet();

    // 2. Pasien Hari Ini: Pasien yang terdaftar hari ini atau tercatat memiliki kunjungan/update hari ini
    final todayPatients = patients.where((p) {
      final isCreatedToday = _isToday(p.createdAt) || _isToday(p.waktuMasuk);
      final isLastVisitToday = _isToday(p.lastVisit);
      final hasVisitToday = todayVisitPatientIds.contains(p.id) ||
          (p.nik.isNotEmpty && todayVisitPatientNiks.contains(p.nik));
      return isCreatedToday || isLastVisitToday || hasVisitToday;
    }).toList();

    final allTodayPatientIds = <String>{
      ...todayVisitPatientIds,
      ...todayPatients.map((p) => p.id).where((id) => id.isNotEmpty),
    };
    final todayPatientCount = allTodayPatientIds.isNotEmpty
        ? allTodayPatientIds.length
        : todayPatients.length;

    // 3. Menunggu Hari Ini: Status Menunggu Dokter dan aktif / terdaftar hari ini
    final todayWaitingCount = patients.where((p) {
      if (p.status != PatientStatus.menungguDokter) return false;
      final isCreatedToday = _isToday(p.createdAt) || _isToday(p.waktuMasuk);
      final isUpdatedToday = _isToday(p.updatedAt);
      final isLastVisitToday = _isToday(p.lastVisit);
      final hasVisitToday = todayVisitPatientIds.contains(p.id) ||
          (p.nik.isNotEmpty && todayVisitPatientNiks.contains(p.nik));
      return isCreatedToday || isUpdatedToday || isLastVisitToday || hasVisitToday;
    }).length;

    final clinics = activeVoyage?.clinics ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ScreenHeader(
          title: 'Dashboard',
          subtitle: 'Ringkasan operasional medis & poli layanan',
        ),
        Expanded(
          child: RefreshIndicator(
            color: AppColors.orange,
            onRefresh: () async {
              ref.invalidate(scheduleCounterProvider);
              await Future.wait([
                ref.read(patientsProvider.notifier).fetchPatients(),
                ref.read(medicalHistoryProvider.notifier).fetchHistory(refresh: true),
                ref.read(schedulesNotifierProvider.notifier).refresh(),
              ]);
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                // 1. M3 Stat Cards (Pasien, Menunggu, Kunjungan, Poli Aktif) - Hari Ini
                Row(
                  children: [
                    Expanded(
                      child: _NurseStatCard(
                        icon: LucideIcons.users,
                        color: AppColors.blue,
                        background: AppColors.blueLt,
                        value: '$todayPatientCount',
                        label: 'Pasien Hari Ini',
                        onTap: () => widget.onNavigateToTab('pasien'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _NurseStatCard(
                        icon: LucideIcons.clock,
                        color: AppColors.orange,
                        background: AppColors.orangeLt,
                        value: '$todayWaitingCount',
                        label: 'Menunggu Hari Ini',
                        onTap: () => widget.onNavigateToTab('pasien'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _NurseStatCard(
                        icon: LucideIcons.bookOpen,
                        color: AppColors.green,
                        background: AppColors.greenLt,
                        value: '$todayVisitCount',
                        label: 'Kunjungan Hari Ini',
                        onTap: () => widget.onNavigateToTab('riwayat'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _NurseStatCard(
                        icon: LucideIcons.building2,
                        color: const Color(0xFF7C3AED),
                        background: const Color(0xFFF5F3FF),
                        value: '${clinics.length}',
                        label: 'Poli Layanan',
                        onTap: activeVoyage != null
                            ? () => _editClinics(context, activeVoyage)
                            : null,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                // 2. Active Voyage Card
                if (activeVoyage != null) ...[
                  _buildActiveVoyageCard(activeVoyage),
                  const SizedBox(height: 18),
                ],

                // 3. Section: Poli Layanan
                _buildPoliLayananSection(context, activeVoyage, clinics),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActiveVoyageCard(JadwalPerjalanan voyage) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: voyage.isOngoing
              ? AppColors.orange.withValues(alpha: 0.35)
              : AppColors.border,
          width: voyage.isOngoing ? 1.4 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: voyage.isOngoing
                ? AppColors.orange.withValues(alpha: 0.06)
                : const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.orangeLt,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  LucideIcons.ship,
                  color: AppColors.orange,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      voyage.namaKapal,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      voyage.shipCode.isNotEmpty ? voyage.shipCode : 'Kapal RS',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: AppColors.sub,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: voyage.isOngoing
                      ? const Color(0xFFECFDF5)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: voyage.isOngoing
                        ? const Color(0xFFA7F3D0)
                        : const Color(0xFFCBD5E1),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: voyage.isOngoing
                            ? const Color(0xFF059669)
                            : const Color(0xFF374151),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      voyage.isOngoing ? 'Berlayar' : voyage.status,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: voyage.isOngoing
                            ? const Color(0xFF059669)
                            : const Color(0xFF374151),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(
                LucideIcons.mapPin,
                size: 13,
                color: Color(0xFF94A3B8),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${voyage.pelabuhanAsal} → ${voyage.pelabuhanTujuan}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF374151),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPoliLayananSection(
    BuildContext context,
    JadwalPerjalanan? schedule,
    List<ScheduleClinicItem> clinics,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              LucideIcons.building2,
              size: 16,
              color: Color(0xFF475569),
            ),
            const SizedBox(width: 8),
            const Text(
              'DAFTAR POLI LAYANAN',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
                color: Color(0xFF475569),
              ),
            ),
            const Spacer(),
            if (schedule != null)
              InkWell(
                onTap: () => _editClinics(context, schedule),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.orangeLt,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.orange.withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        LucideIcons.pencilLine,
                        size: 13,
                        color: AppColors.orange,
                      ),
                      SizedBox(width: 5),
                      Text(
                        'Atur Poli',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.orange,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (schedule == null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: const Column(
              children: [
                Icon(
                  LucideIcons.calendarX,
                  size: 36,
                  color: Color(0xFF94A3B8),
                ),
                SizedBox(height: 10),
                Text(
                  'Tidak ada jadwal pelayaran aktif',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Poli layanan dapat diatur setelah jadwal pelayaran tersedia.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: AppColors.sub),
                ),
              ],
            ),
          )
        else if (clinics.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                const Icon(
                  LucideIcons.building2,
                  size: 40,
                  color: Color(0xFF94A3B8),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Belum ada Poli Layanan terdaftar',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Poli layanan untuk jadwal pelayaran ini belum dikonfigurasi.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: AppColors.sub),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => _editClinics(context, schedule),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.orange,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                  icon: const Icon(
                    LucideIcons.pencilLine,
                    size: 15,
                    color: Colors.white,
                  ),
                  label: const Text(
                    'Atur Poli Layanan',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: clinics.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final clinic = clinics[index];
              return _buildClinicCard(clinic);
            },
          ),
      ],
    );
  }

  Widget _buildClinicCard(ScheduleClinicItem clinic) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFED7AA)),
            ),
            child: const Icon(
              LucideIcons.building2,
              color: Color(0xFFEA580C),
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        clinic.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.text,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1.5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        clinic.code.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    const Icon(
                      LucideIcons.clock,
                      size: 12,
                      color: Color(0xFF94A3B8),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Jam Layanan: ${clinic.operationalHours}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF475569),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFA7F3D0)),
            ),
            child: const Text(
              'Aktif',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF059669),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NurseStatCard extends StatelessWidget {
  const _NurseStatCard({
    required this.icon,
    required this.color,
    required this.background,
    required this.value,
    required this.label,
    this.onTap,
  });

  final IconData icon;
  final Color color;
  final Color background;
  final String value;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: Colors.white,
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: color,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF374151),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
