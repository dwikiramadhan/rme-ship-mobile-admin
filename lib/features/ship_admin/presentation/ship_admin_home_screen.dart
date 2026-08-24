import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/screen_header.dart';
import '../../patients/data/patient_repository.dart';
import '../../profile/presentation/profile_screen.dart';
import '../../schedule/domain/trip_schedule.dart';
import '../../schedule/presentation/trip_schedule_screen.dart';
import '../../schedule/presentation/widgets/trip_schedule_card.dart';
import '../../shell/presentation/nav_item.dart';
import '../../shell/presentation/role_shell.dart';

/// Admin Kapal home — scoped per the RBAC matrix (Ship Web Admin sheet):
/// Dashboard (R), Jadwal Perjalanan (R), Ubah Kata Sandi (in Profil).
/// No patient-data access: Data Pasien / Rekam Medis are Doctor & Perawat
/// only, so this role no longer reuses PerawatHomeScreen.
class ShipAdminHomeScreen extends ConsumerStatefulWidget {
  const ShipAdminHomeScreen({super.key, required this.adminName});

  final String adminName;

  @override
  ConsumerState<ShipAdminHomeScreen> createState() =>
      _ShipAdminHomeScreenState();
}

typedef AdminKapalHomeScreen = ShipAdminHomeScreen;

class _ShipAdminHomeScreenState extends ConsumerState<ShipAdminHomeScreen> {
  String _tab = 'dashboard';

  static const _tabs = [
    ShellNavItem(
      key: 'dashboard',
      label: 'Dashboard',
      icon: LucideIcons.layoutDashboard,
    ),
    ShellNavItem(
      key: 'jadwal',
      label: 'Jadwal',
      icon: LucideIcons.calendarDays,
    ),
    ShellNavItem(key: 'profil', label: 'Profil', icon: LucideIcons.user),
  ];

  @override
  Widget build(BuildContext context) {
    late final Widget content;
    switch (_tab) {
      case 'dashboard':
        content = _buildDashboard();
      case 'jadwal':
        content = const TripScheduleScreen();
      default:
        content = ProfileScreen(name: widget.adminName, role: 'Admin Kapal');
    }

    return RoleShell(
      items: _tabs,
      activeKey: _tab,
      onChange: (key) => setState(() => _tab = key),
      child: content,
    );
  }

  Widget _buildDashboard() {
    final patients = ref.watch(patientsProvider);
    final jadwal = ref.watch(jadwalPerjalananProvider);
    final activeVoyages =
        jadwal.where((j) => j.isOngoing).toList();
    final upcomingVoyages =
        jadwal.where((j) => j.isScheduled).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ScreenHeader(
          title: 'Dashboard',
          subtitle: 'Ringkasan operasional kapal',
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              // M3 Stat Cards Row
              Row(
                children: [
                  Expanded(
                    child: _M3DashboardStatCard(
                      icon: LucideIcons.users,
                      color: AppColors.orange,
                      background: AppColors.orangeLt,
                      value: '${patients.length}',
                      label: 'Pasien Hari Ini',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _M3DashboardStatCard(
                      icon: LucideIcons.navigation,
                      color: AppColors.blue,
                      background: AppColors.blueLt,
                      value: '${activeVoyages.length}',
                      label: 'Sedang Berlayar',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _M3DashboardStatCard(
                      icon: LucideIcons.calendarCheck2,
                      color: AppColors.yellow,
                      background: AppColors.yellowLt,
                      value: '$upcomingVoyages',
                      label: 'Jadwal Terdekat',
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Active Sailing Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Pelayaran Aktif Saat Ini',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.text,
                    ),
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () => setState(() => _tab = 'jadwal'),
                    icon: const Text(
                      'Lihat Semua',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.orange,
                      ),
                    ),
                    label: const Icon(
                      LucideIcons.chevronRight,
                      size: 14,
                      color: AppColors.orange,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              if (activeVoyages.isEmpty)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Center(
                    child: Text(
                      'Tidak ada kapal yang sedang berlayar saat ini',
                      style: TextStyle(fontSize: 13, color: AppColors.sub),
                    ),
                  ),
                )
              else
                ...activeVoyages.map((item) => TripScheduleCard(item: item)),

              const SizedBox(height: 16),

              // RBAC Info Card
              AppCard(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.card2,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        LucideIcons.shieldCheck,
                        size: 20,
                        color: AppColors.sub,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Informasi Hak Akses',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.text,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Akses Admin Kapal terbatas pada pemantauan dashboard operasional dan jadwal perjalanan kapal. '
                            'Data rekam medis pasien dikelola khusus oleh tenaga medis terverifikasi.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.sub,
                              height: 1.35,
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

class _M3DashboardStatCard extends StatelessWidget {
  const _M3DashboardStatCard({
    required this.icon,
    required this.color,
    required this.background,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final Color background;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppColors.sub,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
