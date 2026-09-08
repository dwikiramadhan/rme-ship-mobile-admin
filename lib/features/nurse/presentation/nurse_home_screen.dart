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
import '../../patients/data/patient_repository.dart';
import '../../patients/domain/medical_history.dart';
import '../../patients/domain/patient.dart';
import '../../patients/presentation/medical_history_detail_view.dart';
import '../../patients/presentation/patient_list_screen.dart';
import '../../patients/presentation/status_meta.dart';
import '../../profile/presentation/profile_screen.dart';
import '../../shell/presentation/nav_item.dart';
import '../../shell/presentation/role_shell.dart';
import 'patient_form.dart';

class NurseHomeScreen extends ConsumerStatefulWidget {
  const NurseHomeScreen({
    super.key,
    required this.perawatName,
    this.roleName = 'Perawat',
  });

  final String perawatName;
  final String roleName;

  @override
  ConsumerState<NurseHomeScreen> createState() => _NurseHomeScreenState();
}

typedef PerawatHomeScreen = NurseHomeScreen;

class _NurseHomeScreenState extends ConsumerState<NurseHomeScreen> {
  String _tab = 'pasien';
  bool _showForm = false;
  Patient? _editingPatient;

  static const _tabs = [
    ShellNavItem(key: 'pasien', label: 'Pasien', icon: LucideIcons.users),
    ShellNavItem(
      key: 'riwayat',
      label: 'Riwayat Kunjungan',
      icon: LucideIcons.bookOpen,
    ),
    ShellNavItem(key: 'stok', label: 'Stok Obat', icon: LucideIcons.pill),
    ShellNavItem(key: 'profil', label: 'Profil', icon: LucideIcons.user),
  ];

  @override
  Widget build(BuildContext context) {
    return RoleShell(
      items: _tabs,
      activeKey: _tab,
      onChange: (key) => setState(() {
        _tab = key;
        _showForm = false;
        _editingPatient = null;
        if (key == 'riwayat') {
          ref.read(medicalHistoryProvider.notifier).fetchHistory(refresh: true);
        } else if (key == 'pasien') {
          ref.read(patientsProvider.notifier).fetchPatients(refresh: true);
        }
      }),
      child: switch (_tab) {
        'pasien' =>
          _showForm
              ? TambahPasienForm(
                  initialPatient: _editingPatient,
                  onBack: () => setState(() {
                    _showForm = false;
                    _editingPatient = null;
                  }),
                  onSaved: () {
                    setState(() {
                      _showForm = false;
                      _editingPatient = null;
                    });
                    ref.read(patientsProvider.notifier).fetchPatients(refresh: true);
                    ref.read(medicalHistoryProvider.notifier).fetchHistory(refresh: true);
                  },
                )
              : PatientListScreen(
                  onAddPatient: () => setState(() {
                    _editingPatient = null;
                    _showForm = true;
                  }),
                ),
        'riwayat' =>
          _showForm
              ? TambahKunjunganScreen(
                  initialPatient: _editingPatient,
                  onBack: () => setState(() {
                    _showForm = false;
                    _editingPatient = null;
                  }),
                  onSaved: () => setState(() {
                    _showForm = false;
                    _editingPatient = null;
                    ref
                        .read(medicalHistoryProvider.notifier)
                        .fetchHistory(refresh: true);
                  }),
                )
              : _buildRiwayatKunjungan(),
        'stok' => const StokObatScreen(canManage: false),
        _ => ProfileScreen(name: widget.perawatName, role: widget.roleName),
      },
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
        onPressed: () => setState(() {
          _editingPatient = null;
          _showForm = true;
        }),
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
        return MedicalHistoryDetailView(history: item);
      },
      emptyIcon: LucideIcons.bookOpen,
      emptyTitle: 'Pilih riwayat kunjungan',
      emptySubtitle:
          'Pilih salah satu rekam medis untuk melihat detail data pasien dan tindakan.',
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
