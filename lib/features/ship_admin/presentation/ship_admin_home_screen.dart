import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/screen_header.dart';
import '../../profile/presentation/profile_screen.dart';
import '../../schedule/data/schedule_api.dart';
import '../../schedule/data/schedule_repository.dart';
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
      icon: LucideIcons.layoutGrid,
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
    final counterAsync = ref.watch(scheduleCounterProvider);
    final counter = counterAsync.valueOrNull ?? const ScheduleCounter();
    final ongoingCount = counter.ongoing;
    final scheduledCount = counter.scheduled;
    final completedCount = counter.completed;

    final jadwal = ref.watch(jadwalPerjalananProvider);
    final activeVoyages = jadwal.where((j) => j.isOngoing).toList();

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
              // M3 Stat Cards Row (Ongoing, Scheduled, Completed)
              Row(
                children: [
                  Expanded(
                    child: _M3DashboardStatCard(
                      icon: LucideIcons.navigation,
                      color: AppColors.blue,
                      background: AppColors.blueLt,
                      value: '$ongoingCount',
                      label: 'Ongoing',
                      onTap: () => setState(() => _tab = 'jadwal'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _M3DashboardStatCard(
                      icon: LucideIcons.calendarCheck2,
                      color: AppColors.yellow,
                      background: AppColors.yellowLt,
                      value: '$scheduledCount',
                      label: 'Scheduled',
                      onTap: () => setState(() => _tab = 'jadwal'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _M3DashboardStatCard(
                      icon: LucideIcons.checkCircle2,
                      color: AppColors.green,
                      background: AppColors.greenLt,
                      value: '$completedCount',
                      label: 'Completed',
                      onTap: () => setState(() => _tab = 'jadwal'),
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
                              letterSpacing: 0.12,
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: background,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, size: 14, color: color),
                  ),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.text,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
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
        ),
      ),
    );
  }
}
