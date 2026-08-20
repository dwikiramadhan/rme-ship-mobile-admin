import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_badge.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/screen_header.dart';
import '../../patients/data/patient_repository.dart';
import '../../profile/presentation/profile_screen.dart';
import '../../schedule/domain/trip_schedule.dart';
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
  ConsumerState<ShipAdminHomeScreen> createState() => _ShipAdminHomeScreenState();
}

typedef AdminKapalHomeScreen = ShipAdminHomeScreen;

class _ShipAdminHomeScreenState extends ConsumerState<ShipAdminHomeScreen> {
  String _tab = 'dashboard';

  static const _tabs = [
    ShellNavItem(key: 'dashboard', label: 'Dashboard', icon: LucideIcons.layoutDashboard),
    ShellNavItem(key: 'jadwal', label: 'Jadwal', icon: LucideIcons.calendarDays),
    ShellNavItem(key: 'profil', label: 'Profil', icon: LucideIcons.user),
  ];

  @override
  Widget build(BuildContext context) {
    late final Widget content;
    switch (_tab) {
      case 'dashboard':
        content = _buildDashboard();
      case 'jadwal':
        content = _buildJadwal();
      default:
        content = ProfileScreen(name: widget.adminName, role: 'Admin Kapal');
    }

    return RoleShell(items: _tabs, activeKey: _tab, onChange: (key) => setState(() => _tab = key), child: content);
  }

  Widget _buildDashboard() {
    final patients = ref.watch(patientsProvider);
    final jadwal = ref.watch(jadwalPerjalananProvider);
    final upcoming = jadwal.where((j) => j.status != 'Selesai').length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ScreenHeader(title: 'Dashboard', subtitle: 'Ringkasan operasional kapal'),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      icon: LucideIcons.users,
                      color: AppColors.blue,
                      background: AppColors.blueLt,
                      value: '${patients.length}',
                      label: 'Pasien hari ini',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatCard(
                      icon: LucideIcons.calendarDays,
                      color: AppColors.purple,
                      background: AppColors.purpleLt,
                      value: '$upcoming',
                      label: 'Jadwal aktif',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Informasi', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.text)),
                    const SizedBox(height: 6),
                    Text(
                      'Akses Admin Kapal terbatas pada pemantauan dashboard dan jadwal perjalanan kapal penugasan. '
                      'Data pasien dan rekam medis hanya dapat diakses oleh tenaga medis (Dokter & Perawat).',
                      style: const TextStyle(fontSize: 12.5, color: AppColors.sub),
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

  Widget _buildJadwal() {
    final jadwal = ref.watch(jadwalPerjalananProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ScreenHeader(title: 'Jadwal Perjalanan', subtitle: '${jadwal.length} jadwal'),
        Expanded(
          child: jadwal.isEmpty
              ? const Center(child: Text('Belum ada jadwal', style: TextStyle(color: AppColors.sub, fontSize: 13)))
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: jadwal.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) => _JadwalTile(item: jadwal[index]),
                ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
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
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(height: 10),
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.text)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 11.5, color: AppColors.sub)),
        ],
      ),
    );
  }
}

class _JadwalTile extends StatelessWidget {
  const _JadwalTile({required this.item});

  final JadwalPerjalanan item;

  String _fmt(DateTime d) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '${d.day} ${months[d.month - 1]} · $h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final done = item.status == 'Selesai';
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(item.namaKapal, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.text)),
              ),
              AppBadge(
                label: item.status,
                color: done ? AppColors.sub : AppColors.green,
                background: done ? AppColors.card2 : AppColors.greenLt,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(LucideIcons.anchor, size: 14, color: AppColors.sub),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${item.pelabuhanAsal} → ${item.pelabuhanTujuan}',
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.text),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(LucideIcons.clock, size: 14, color: AppColors.sub),
              const SizedBox(width: 6),
              Text(
                'Berangkat ${_fmt(item.berangkat)} · Tiba ${_fmt(item.tiba)}',
                style: const TextStyle(fontSize: 11.5, color: AppColors.sub),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
