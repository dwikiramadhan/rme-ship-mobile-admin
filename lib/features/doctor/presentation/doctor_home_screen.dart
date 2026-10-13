import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_helper.dart';
import '../../../core/widgets/app_badge.dart';
import '../../../core/widgets/app_shimmer.dart';
import '../../../core/widgets/responsive_master_detail.dart';
import '../../../core/widgets/status_filter_button.dart';
import '../../history/presentation/add_visit_screen.dart';
import '../../medicine_stock/presentation/medicine_stock_screen.dart';
import '../../notifications/domain/notification_rules.dart';
import '../../notifications/presentation/notifications_view.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../patients/data/patient_repository.dart';
import '../../patients/domain/medical_history.dart';
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
  String _riwayatStatusFilter = 'SEMUA';

  @override
  Widget build(BuildContext context) {
    // Only the badge count is needed; selecting it means the whole home
    // screen rebuilds only when that number changes.
    final notifsCount = ref.watch(
      notificationsProvider.select(
        (all) => all
            .where((p) => isWaitingForDoctor(p) || isLabResultForDoctor(p))
            .length,
      ),
    );

    final tabs = [
      ShellNavItem(
        key: 'notifikasi',
        label: 'Notifikasi',
        icon: LucideIcons.bell,
        badgeCount: notifsCount,
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

    final Widget content = switch (_tab) {
      'notifikasi' => NotificationsView(
          role: NotificationRole.doctor,
          onTapItem: (context, p, isLab) {
            final notifications = ref.read(notificationsProvider.notifier);
            if (isLab) {
              notifications.markDoctorLabSeen(notificationKey(p));
              ref.read(patientsProvider.notifier).markDilihatDokterLab(p.id);
            } else {
              notifications.markDoctorSeen(notificationKey(p));
              ref.read(patientsProvider.notifier).markDilihatDokter(p.id);
            }
            // The real visit, so it lands in its place in the list.
            final medHist = notifications.recordFor(p) ?? p.toMedicalHistory();
            ref.read(medicalHistoryProvider.notifier).upsertHistory(medHist);
            final uid =
                ref.read(authControllerProvider).session?.user.id ?? '';
            if (uid.isNotEmpty) {
              ref
                  .read(medicalHistoryByUserProvider(uid).notifier)
                  .upsertHistory(medHist);
            }

            setState(() {
              _tab = 'riwayat';
              _selectedRiwayatId = medHist.id;
            });
          },
        ),
      'pasien' => const PatientListScreen(),
      'riwayat' => _buildRiwayatKunjungan(),
      'stok' => const MedicineStockScreen(canManage: false),
      _ => ProfileScreen(name: widget.doctorName, role: 'Dokter'),
    };

    return RoleShell(
      items: tabs,
      activeKey: _tab,
      onChange: (key) => setState(() {
        _tab = key;
        if (key == 'riwayat') {
          ref.read(medicalHistoryProvider.notifier).fetchHistory(refresh: true);
          final uid =
              ref.read(authControllerProvider).session?.user.id ?? '';
          // Only refresh the per-user list if something already uses it;
          // reading it here would create it and fire a second identical fetch.
          if (uid.isNotEmpty && ref.exists(medicalHistoryByUserProvider(uid))) {
            ref
                .read(medicalHistoryByUserProvider(uid).notifier)
                .fetchHistory(refresh: true);
          }
        } else if (key == 'pasien') {
          ref.read(patientsProvider.notifier).fetchPatients();
        }
      }),
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
                // medicalHistoryProvider is already refreshed by the screen.
                final uid =
                    ref.read(authControllerProvider).session?.user.id ?? '';
                if (uid.isNotEmpty && ref.exists(medicalHistoryByUserProvider(uid))) {
                  ref
                      .read(medicalHistoryByUserProvider(uid).notifier)
                      .fetchHistory(refresh: true);
                }
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRiwayatKunjungan() {
    final authState = ref.watch(authControllerProvider);
    final userId = authState.session?.user.id ?? '';
    final historyProvider = userId.isNotEmpty
        ? medicalHistoryByUserProvider(userId)
        : medicalHistoryProvider;
    final histories = ref.watch(historyProvider);
    final notifier = ref.read(historyProvider.notifier);

    final displayHistories = histories.where((m) {
      if (_riwayatStatusFilter == 'SEMUA') return true;
      final status = (m.statusPenanganan ?? '').toLowerCase();
      return status.contains(_riwayatStatusFilter.toLowerCase());
    }).toList();

    return ResponsiveMasterDetail(
      title: 'Riwayat Kunjungan',
      subtitle: '${displayHistories.length} rekam medis',
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
      searchTrailing: StatusFilterButton(
        selectedValue: _riwayatStatusFilter,
        options: riwayatStatusFilterOptions,
        onSelected: (val) {
          setState(() => _riwayatStatusFilter = val);
          if (val == 'SEMUA') {
            notifier.setStatusPenanganan(null);
          } else {
            notifier.setStatusPenanganan(val);
          }
        },
      ),
      entries: [
        for (final m in displayHistories)
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
        final item = displayHistories.where((h) => h.id == id).firstOrNull ??
            histories.where((h) => h.id == id).firstOrNull;
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
    final datePart = switch ((m.createdAt, m.date)) {
      (final String c, _) when c.isNotEmpty => DateHelper.formatDateTime(c),
      (_, final String d) when d.isNotEmpty => DateHelper.formatDate(d),
      _ => null,
    };
    final detailPart = switch ((m.poliName, m.complaint)) {
      (final String p, _) when p.isNotEmpty => p,
      (_, final String c) when c.isNotEmpty => c,
      _ => null,
    };
    final parts = [?datePart, ?detailPart];
    return parts.join(' • ');
  }

  Widget _historyStatusBadge(String? statusPenanganan) {
    final meta = statusMetaFromPenanganan(statusPenanganan);
    return AppBadge(
      label: meta.label,
      color: meta.color,
      background: meta.background,
      fontSize: 10.5,
      fontWeight: FontWeight.w500,
    );
  }
}
