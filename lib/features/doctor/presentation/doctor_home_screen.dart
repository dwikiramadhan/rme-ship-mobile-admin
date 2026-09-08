import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_helper.dart';
import '../../../core/widgets/app_badge.dart';
import '../../../core/widgets/app_shimmer.dart';
import '../../../core/widgets/responsive_master_detail.dart';
import '../../history/presentation/tambah_kunjungan_screen.dart';
import '../../medicine_stock/presentation/medicine_stock_screen.dart';
import '../../notifications/presentation/notifications_view.dart';
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
  String? _selectedRiwayatId;

  @override
  Widget build(BuildContext context) {
    final allNotifs = ref.watch(notificationsProvider);

    final notifs = allNotifs.where((p) {
      final isWaitingDoc = p.status == PatientStatus.menungguDokter;
      final isLabReady = p.labOrder?.status == LabOrderStatus.selesai;
      return isWaitingDoc || isLabReady;
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
        content = NotificationsView(
          role: NotificationRole.doctor,
          onTapItem: (context, p, isLab) {
            if (isLab) {
              ref.read(notificationsProvider.notifier).markDoctorLabSeen(p.id);
              ref.read(patientsProvider.notifier).markDilihatDokterLab(p.id);
            } else {
              ref.read(notificationsProvider.notifier).markDoctorSeen(p.id);
              ref.read(patientsProvider.notifier).markDilihatDokter(p.id);
            }
            final medHist = p.toMedicalHistory();
            ref.read(medicalHistoryProvider.notifier).upsertHistory(medHist);

            setState(() {
              _tab = 'riwayat';
              _selectedRiwayatId = medHist.id;
            });
          },
        );
      case 'pasien':
        content = const PatientListScreen();
      case 'riwayat':
        content = _buildRiwayatKunjungan();
      case 'stok':
        content = const MedicineStockScreen(canManage: false);
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
      selectedId: _selectedRiwayatId,
      onEntrySelected: (id) {
        setState(() => _selectedRiwayatId = id);
      },
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
