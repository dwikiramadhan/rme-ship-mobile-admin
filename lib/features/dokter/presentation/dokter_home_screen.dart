import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_badge.dart';
import '../../../core/widgets/push_detail_page.dart';
import '../../../core/widgets/responsive_master_detail.dart';
import '../../../core/widgets/screen_header.dart';
import '../../patients/data/mock_patient_repository.dart';
import '../../patients/domain/lab_order.dart';
import '../../patients/domain/patient.dart';
import '../../patients/presentation/status_meta.dart';
import '../../profile/presentation/profile_screen.dart';
import '../../riwayat/presentation/riwayat_kunjungan_screen.dart';
import '../../shell/presentation/nav_item.dart';
import '../../shell/presentation/role_shell.dart';
import '../../stok_obat/presentation/stok_obat_screen.dart';
import 'dokter_patient_detail.dart';

class DokterHomeScreen extends ConsumerStatefulWidget {
  const DokterHomeScreen({super.key, required this.doctorId, required this.doctorName});

  final String doctorId;
  final String doctorName;

  @override
  ConsumerState<DokterHomeScreen> createState() => _DokterHomeScreenState();
}

class _DokterHomeScreenState extends ConsumerState<DokterHomeScreen> {
  String _tab = 'notifikasi';

  @override
  Widget build(BuildContext context) {
    final patients = ref.watch(patientsProvider);
    final mine = sortRecent(patients.where((p) => p.assignedDokterId == widget.doctorId).toList());
    final notifs = mine.where(_isUnreadNotif).toList();

    final tabs = [
      ShellNavItem(key: 'notifikasi', label: 'Notifikasi', icon: LucideIcons.bell, badgeCount: notifs.length),
      const ShellNavItem(key: 'pasien', label: 'Pasien Saya', icon: LucideIcons.users),
      const ShellNavItem(key: 'riwayat', label: 'Riwayat', icon: LucideIcons.bookOpen),
      const ShellNavItem(key: 'stok', label: 'Stok Obat', icon: LucideIcons.pill),
      const ShellNavItem(key: 'profil', label: 'Profil', icon: LucideIcons.user),
    ];

    late final Widget content;
    switch (_tab) {
      case 'notifikasi':
        content = _buildNotifikasi(notifs);
      case 'pasien':
        content = _buildPasien(mine);
      case 'riwayat':
        content = RiwayatKunjunganScreen(canEdit: true, dokterNama: widget.doctorName);
      case 'stok':
        content = const StokObatScreen(canManage: false);
      default:
        content = ProfileScreen(name: widget.doctorName, role: 'Dokter');
    }

    return RoleShell(items: tabs, activeKey: _tab, onChange: (key) => setState(() => _tab = key), child: content);
  }

  bool _isUnreadNotif(Patient p) {
    final labReady = p.labOrder?.status == LabOrderStatus.selesai && !p.dilihatDokterLab;
    final newPatient = p.status == PatientStatus.menungguDokter && !p.dilihatDokter;
    return newPatient || labReady;
  }

  Widget _buildNotifikasi(List<Patient> notifs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ScreenHeader(title: 'Notifikasi', subtitle: '${notifs.length} belum dibaca'),
        Expanded(
          child: notifs.isEmpty
              ? const Center(child: Text('Tidak ada notifikasi baru', style: TextStyle(color: AppColors.sub, fontSize: 13)))
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: notifs.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final p = notifs[index];
                    final isLab = p.labOrder?.status == LabOrderStatus.selesai && !p.dilihatDokterLab;
                    return _NotifTile(
                      icon: isLab ? LucideIcons.flaskConical : LucideIcons.users,
                      iconColor: isLab ? AppColors.purple : AppColors.yellow,
                      iconBg: isLab ? AppColors.purpleLt : AppColors.yellowLt,
                      title: isLab ? 'Hasil lab tersedia: ${p.nama}' : 'Pasien baru: ${p.nama}',
                      subtitle: isLab ? (p.labOrder?.jenis ?? '') : p.keluhanUtama,
                      onTap: () {
                        if (isLab) {
                          ref.read(patientsProvider.notifier).markDilihatDokterLab(p.id);
                        } else {
                          ref.read(patientsProvider.notifier).markDilihatDokter(p.id);
                        }
                        pushDetailPage(context, title: p.nama, child: DokterPatientDetail(patientId: p.id));
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildPasien(List<Patient> mine) {
    return ResponsiveMasterDetail(
      title: 'Pasien Saya',
      subtitle: '${mine.length} pasien ditugaskan',
      entries: [
        for (final p in mine)
          MasterListEntry(
            id: p.id,
            avatarColor: AppColors.blue,
            avatarBg: AppColors.blueLt,
            initial: p.nama.isNotEmpty ? p.nama[0] : '?',
            title: p.nama,
            subtitle: p.keluhanUtama,
            badge: AppBadge(label: statusMeta(p).label, color: statusMeta(p).color, background: statusMeta(p).background),
          ),
      ],
      detailBuilder: (context, id) => DokterPatientDetail(patientId: id),
      emptyIcon: LucideIcons.users,
      emptyTitle: 'Pilih pasien',
      emptySubtitle: 'Pilih pasien untuk melihat data & input diagnosa.',
    );
  }
}

class _NotifTile extends StatelessWidget {
  const _NotifTile({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: AppColors.text.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, 4))],
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(11)),
                child: Icon(icon, size: 19, color: iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.text)),
                    const SizedBox(height: 1),
                    Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: AppColors.sub)),
                  ],
                ),
              ),
              const Icon(LucideIcons.chevronRight, size: 16, color: AppColors.sub),
            ],
          ),
        ),
      ),
    );
  }
}