import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_badge.dart';
import '../../../core/widgets/push_detail_page.dart';
import '../../../core/widgets/responsive_master_detail.dart';
import '../../../core/widgets/screen_header.dart';
import '../../patients/data/patient_repository.dart';
import '../../patients/domain/doctor.dart';
import '../../patients/domain/lab_order.dart';
import '../../patients/domain/patient.dart';
import '../../profile/presentation/profile_screen.dart';
import '../../shell/presentation/nav_item.dart';
import '../../shell/presentation/role_shell.dart';
import 'lab_order_detail.dart';

class LabHomeScreen extends ConsumerStatefulWidget {
  const LabHomeScreen({super.key, required this.analystName});

  final String analystName;

  @override
  ConsumerState<LabHomeScreen> createState() => _LabHomeScreenState();
}

class _LabHomeScreenState extends ConsumerState<LabHomeScreen> {
  String _tab = 'notifikasi';

  @override
  Widget build(BuildContext context) {
    final patients = ref.watch(patientsProvider);
    final withLab = sortRecent(patients.where((p) => p.labOrder != null).toList());
    final notifs = withLab.where((p) => p.labOrder!.status == LabOrderStatus.baru && !p.dilihatLab).toList();

    final tabs = [
      ShellNavItem(key: 'notifikasi', label: 'Notifikasi', icon: LucideIcons.bell, badgeCount: notifs.length),
      const ShellNavItem(key: 'order', label: 'Daftar Order', icon: LucideIcons.flaskConical),
      const ShellNavItem(key: 'profil', label: 'Profil', icon: LucideIcons.user),
    ];

    late final Widget content;
    switch (_tab) {
      case 'notifikasi':
        content = _buildNotifikasi(notifs);
      case 'order':
        content = _buildOrder(withLab);
      default:
        content = ProfileScreen(name: widget.analystName, role: 'Laboratorium');
    }

    return RoleShell(items: tabs, activeKey: _tab, onChange: (key) => setState(() => _tab = key), child: content);
  }

  Widget _buildNotifikasi(List<Patient> notifs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ScreenHeader(title: 'Notifikasi', subtitle: '${notifs.length} order baru'),
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
                          ref.read(patientsProvider.notifier).markDilihatLab(p.id);
                          pushDetailPage(context, title: p.nama, child: LabOrderDetail(patientId: p.id));
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
                                decoration: BoxDecoration(color: AppColors.purpleLt, borderRadius: BorderRadius.circular(11)),
                                child: const Icon(LucideIcons.flaskConical, size: 19, color: AppColors.purple),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('Order lab: ${p.labOrder!.jenis}', style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.text)),
                                    const SizedBox(height: 1),
                                    Text('${p.nama} · dari $doctorName', style: const TextStyle(fontSize: 11.5, color: AppColors.sub)),
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

  Widget _buildOrder(List<Patient> withLab) {
    final notifier = ref.read(patientsProvider.notifier);
    return ResponsiveMasterDetail(
      title: 'Daftar Order Lab',
      subtitle: '${withLab.length} order lab',
      isLoading: notifier.isLoading,
      hasMore: notifier.hasMore,
      isLoadingMore: notifier.isLoadingMore,
      onLoadMore: () => notifier.loadMore(),
      onRefresh: () => notifier.fetchPatients(refresh: true),
      onEntrySelected: (id) => notifier.fetchPatientDetail(id),
      entries: [
        for (final p in withLab)
          MasterListEntry(
            id: p.id,
            avatarColor: AppColors.purple,
            avatarBg: AppColors.purpleLt,
            initial: p.nama.isNotEmpty ? p.nama[0] : '?',
            title: p.nama,
            subtitle: p.labOrder!.jenis,
            badge: _orderStatusBadge(p.labOrder!.status),
          ),
      ],
      detailBuilder: (context, id) => LabOrderDetail(patientId: id),
      emptyIcon: LucideIcons.flaskConical,
      emptyTitle: 'Pilih order',
      emptySubtitle: 'Pilih order lab untuk input hasil pemeriksaan.',
    );
  }

  Widget _orderStatusBadge(LabOrderStatus status) {
    final (label, color, bg) = switch (status) {
      LabOrderStatus.selesai => ('Selesai', AppColors.green, AppColors.greenLt),
      LabOrderStatus.diproses => ('Diproses', AppColors.blue, AppColors.blueLt),
      LabOrderStatus.baru => ('Baru', AppColors.yellow, AppColors.yellowLt),
    };
    return AppBadge(label: label, color: color, background: bg);
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
