import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_helper.dart';
import '../../../core/widgets/app_badge.dart';
import '../../../core/widgets/app_shimmer.dart';
import '../../../core/widgets/push_detail_page.dart';
import '../../../core/widgets/responsive_master_detail.dart';
import '../../../core/widgets/screen_header.dart';
import '../../history/presentation/tambah_kunjungan_screen.dart';
import '../../medicine_stock/presentation/medicine_stock_screen.dart';
import '../../patients/data/patient_repository.dart';
import '../../patients/domain/lab_order.dart';
import '../../patients/domain/medical_history.dart';
import '../../patients/domain/patient.dart';
import '../../patients/presentation/medical_history_detail_view.dart';
import '../../patients/presentation/patient_list_screen.dart';
import '../../patients/presentation/status_meta.dart';
import '../../profile/presentation/profile_screen.dart';
import '../../shell/presentation/nav_item.dart';
import '../../shell/presentation/role_shell.dart';
import 'doctor_patient_detail.dart';

class DoctorHomeScreen extends ConsumerStatefulWidget {
  const DoctorHomeScreen({
    super.key,
    required this.doctorId,
    required this.doctorName,
  });

  final String doctorId;
  final String doctorName;

  @override
  ConsumerState<DoctorHomeScreen> createState() => _DoctorHomeScreenState();
}

typedef DokterHomeScreen = DoctorHomeScreen;

class _DoctorHomeScreenState extends ConsumerState<DoctorHomeScreen> {
  String _tab = 'notifikasi';

  @override
  Widget build(BuildContext context) {
    final allNotifs = ref.watch(notificationsProvider);

    final notifs = allNotifs.where((p) {
      final isMine =
          p.assignedDokterId == widget.doctorId || p.assignedDokterId.isEmpty;
      final isNewPatient = p.status == PatientStatus.menungguDokter;
      final isLabReady = p.labOrder?.status == LabOrderStatus.selesai;
      return isMine && (isNewPatient || isLabReady);
    }).toList();

    final tabs = [
      ShellNavItem(
        key: 'notifikasi',
        label: 'Notifikasi',
        icon: LucideIcons.bell,
        badgeCount: notifs.length,
      ),
      const ShellNavItem(
        key: 'pasien',
        label: 'Pasien',
        icon: LucideIcons.users,
      ),
      const ShellNavItem(
        key: 'riwayat',
        label: 'Riwayat Kunjungan',
        icon: LucideIcons.bookOpen,
      ),
      const ShellNavItem(
        key: 'stok',
        label: 'Stok Obat',
        icon: LucideIcons.pill,
      ),
      const ShellNavItem(
        key: 'profil',
        label: 'Profil',
        icon: LucideIcons.user,
      ),
    ];

    late final Widget content;
    switch (_tab) {
      case 'notifikasi':
        content = _buildNotifikasi(notifs);
      case 'pasien':
        content = const PatientListScreen();
      case 'riwayat':
        content = _buildRiwayatKunjungan();
      case 'stok':
        content = const StokObatScreen(canManage: false);
      default:
        content = ProfileScreen(name: widget.doctorName, role: 'Dokter');
    }

    return RoleShell(
      items: tabs,
      activeKey: _tab,
      onChange: (key) => setState(() => _tab = key),
      child: content,
    );
  }

  Widget _buildNotifikasi(List<Patient> notifs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ScreenHeader(
          title: 'Notifikasi',
          subtitle: '${notifs.length} belum dibaca',
        ),
        Expanded(
          child: notifs.isEmpty
              ? const Center(
                  child: Text(
                    'Tidak ada notifikasi baru',
                    style: TextStyle(color: AppColors.sub, fontSize: 13),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: notifs.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final p = notifs[index];
                    final isLab = p.labOrder?.status == LabOrderStatus.selesai;
                    return _NotifTile(
                      icon: isLab
                          ? LucideIcons.flaskConical
                          : LucideIcons.users,
                      iconColor: isLab ? AppColors.purple : AppColors.yellow,
                      iconBg: isLab ? AppColors.purpleLt : AppColors.yellowLt,
                      title: isLab
                          ? 'Hasil lab tersedia: ${p.nama}'
                          : 'Pasien baru: ${p.nama}',
                      subtitle: isLab
                          ? (p.labOrder?.jenis ?? '')
                          : p.keluhanUtama,
                      onTap: () {
                        if (isLab) {
                          ref
                              .read(notificationsProvider.notifier)
                              .markDoctorLabSeen(p.id);
                          ref
                              .read(patientsProvider.notifier)
                              .markDilihatDokterLab(p.id);
                        } else {
                          ref
                              .read(notificationsProvider.notifier)
                              .markDoctorSeen(p.id);
                          ref
                              .read(patientsProvider.notifier)
                              .markDilihatDokter(p.id);
                        }
                        pushDetailPage(
                          context,
                          title: p.nama,
                          child: DokterPatientDetail(patientId: p.id),
                        );
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _showAddKunjungan(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => Scaffold(
          backgroundColor: AppColors.bg,
          body: SafeArea(
            child: TambahKunjunganScreen(
              onBack: () => Navigator.of(ctx).pop(),
              onSaved: () {
                Navigator.of(ctx).pop();
                ref
                    .read(medicalHistoryProvider.notifier)
                    .fetchHistory(refresh: true);
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRiwayatKunjungan() {
    final histories = ref.watch(medicalHistoryProvider);
    final notifier = ref.read(medicalHistoryProvider.notifier);

    return ResponsiveMasterDetail(
      title: 'Riwayat Kunjungan',
      trailing: HeaderActionButton(
        icon: LucideIcons.plus,
        tooltip: 'Tambah Kunjungan',
        onPressed: () => _showAddKunjungan(context),
      ),
      isLoading: notifier.isLoading,
      hasMore: notifier.hasMore,
      isLoadingMore: notifier.isLoadingMore,
      onLoadMore: () => notifier.loadMore(),
      onRefresh: () => notifier.fetchHistory(refresh: true),
      onSearchChanged: (q) => notifier.searchHistory(q),
      searchPlaceholder: 'Cari nama atau NIK pasien...',
      entries: [
        for (final m in histories)
          MasterListEntry(
            id: m.id,
            avatarColor: AppColors.blue,
            avatarBg: AppColors.blueLt,
            initial: m.patientName.isNotEmpty
                ? m.patientName[0].toUpperCase()
                : '?',
            title: m.patientName,
            code: m.code,
            subtitle: _formatHistorySubtitle(m),
            badge: _historyStatusBadge(m.statusPenanganan),
          ),
      ],
      detailBuilder: (context, id) {
        final item = histories.where((h) => h.id == id).firstOrNull;
        if (item == null) {
          return const SkeletonPatientDetail();
        }
        return MedicalHistoryDetailView(history: item, canExamine: true);
      },
      emptyIcon: LucideIcons.bookOpen,
      emptyTitle: 'Pilih kunjungan',
      emptySubtitle: 'Pilih pasien untuk melihat data & rekam medis.',
    );
  }

  String _formatHistorySubtitle(MedicalHistory m) {
    final parts = <String>[];
    if (m.createdAt != null && m.createdAt!.isNotEmpty) {
      parts.add(DateHelper.formatDateTime(m.createdAt));
    } else if (m.date != null && m.date!.isNotEmpty) {
      parts.add(DateHelper.formatDate(m.date));
    }
    if (m.poliName != null && m.poliName!.isNotEmpty) {
      parts.add(m.poliName!);
    } else if (m.complaint != null && m.complaint!.isNotEmpty) {
      parts.add(m.complaint!);
    }
    return parts.join(' • ');
  }

  Widget _historyStatusBadge(String? statusPenanganan) {
    final meta = statusMetaFromPenanganan(statusPenanganan);
    return AppBadge(
      label: meta.label,
      color: meta.color,
      background: meta.background,
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
            boxShadow: [
              BoxShadow(
                color: AppColors.text.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, size: 19, color: iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.sub,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                LucideIcons.chevronRight,
                size: 16,
                color: AppColors.sub,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
