import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_badge.dart';
import '../../../core/widgets/push_detail_page.dart';
import '../../../core/widgets/responsive_master_detail.dart';
import '../../../core/widgets/screen_header.dart';
import '../../patients/data/mock_patient_repository.dart';
import '../../patients/domain/doctor.dart';
import '../../patients/domain/patient.dart';
import '../../patients/domain/resep_item.dart';
import '../../patients/presentation/status_meta.dart';
import '../../profile/presentation/profile_screen.dart';
import '../../shell/presentation/nav_item.dart';
import '../../shell/presentation/role_shell.dart';
import '../../stok_obat/presentation/stok_obat_screen.dart';
import 'resep_detail.dart';

class PharmacyHomeScreen extends ConsumerStatefulWidget {
  const PharmacyHomeScreen({super.key, required this.apotekerName});

  final String apotekerName;

  @override
  ConsumerState<PharmacyHomeScreen> createState() => _PharmacyHomeScreenState();
}

class _PharmacyHomeScreenState extends ConsumerState<PharmacyHomeScreen> {
  String _tab = 'notifikasi';

  @override
  Widget build(BuildContext context) {
    final patients = ref.watch(patientsProvider);
    final withResep = sortRecent(patients.where((p) => p.resepStatus != null).toList());
    final notifs = withResep.where((p) => p.resepStatus == ResepStatus.baru && !p.dilihatPharmacy).toList();

    final tabs = [
      ShellNavItem(key: 'notifikasi', label: 'Notifikasi', icon: LucideIcons.bell, badgeCount: notifs.length),
      const ShellNavItem(key: 'resep', label: 'Daftar Resep', icon: LucideIcons.fileText),
      const ShellNavItem(key: 'stok', label: 'Stok Obat', icon: LucideIcons.pill),
      const ShellNavItem(key: 'profil', label: 'Profil', icon: LucideIcons.user),
    ];

    late final Widget content;
    switch (_tab) {
      case 'notifikasi':
        content = _buildNotifikasi(notifs);
      case 'resep':
        content = _buildResep(withResep);
      case 'stok':
        content = const StokObatScreen(canManage: true);
      default:
        content = ProfileScreen(name: widget.apotekerName, role: 'Apoteker');
    }

    return RoleShell(items: tabs, activeKey: _tab, onChange: (key) => setState(() => _tab = key), child: content);
  }

  Widget _buildNotifikasi(List<Patient> notifs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ScreenHeader(title: 'Notifikasi', subtitle: '${notifs.length} resep baru'),
        Expanded(
          child: notifs.isEmpty
              ? const Center(child: Text('Tidak ada notifikasi baru', style: TextStyle(color: AppColors.sub, fontSize: 13)))
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: notifs.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final p = notifs[index];
                    final doctorName = kDoctors.where((d) => d.id == p.assignedDokterId).map((d) => d.nama).firstOrNull ?? '—';
                    return Material(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () {
                          ref.read(patientsProvider.notifier).markDilihatPharmacy(p.id);
                          pushDetailPage(context, title: p.nama, child: ResepDetail(patientId: p.id));
                        },
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
                                decoration: BoxDecoration(color: AppColors.yellowLt, borderRadius: BorderRadius.circular(11)),
                                child: const Icon(LucideIcons.fileText, size: 19, color: AppColors.yellow),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('Resep baru: ${p.nama}', style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.text)),
                                    const SizedBox(height: 1),
                                    Text('Dari $doctorName · ${p.resep.length} obat', style: const TextStyle(fontSize: 11.5, color: AppColors.sub)),
                                  ],
                                ),
                              ),
                              const Icon(LucideIcons.chevronRight, size: 16, color: AppColors.sub),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildResep(List<Patient> withResep) {
    return ResponsiveMasterDetail(
      title: 'Daftar Resep',
      subtitle: '${withResep.length} resep',
      entries: [
        for (final p in withResep)
          MasterListEntry(
            id: p.id,
            avatarColor: AppColors.yellow,
            avatarBg: AppColors.yellowLt,
            initial: p.nama.isNotEmpty ? p.nama[0] : '?',
            title: p.nama,
            subtitle: '${p.resep.length} obat',
            badge: AppBadge(label: statusMeta(p).label, color: statusMeta(p).color, background: statusMeta(p).background),
          ),
      ],
      detailBuilder: (context, id) => ResepDetail(patientId: id),
      emptyIcon: LucideIcons.fileText,
      emptyTitle: 'Pilih resep',
      emptySubtitle: 'Pilih resep untuk memproses & menyerahkan obat.',
    );
  }
}
