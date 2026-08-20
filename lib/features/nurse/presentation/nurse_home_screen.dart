import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/responsive/breakpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_badge.dart';
import '../../../core/widgets/app_shimmer.dart';
import '../../../core/widgets/responsive_master_detail.dart';
import '../../history/presentation/visit_history_screen.dart';
import '../../medicine_stock/presentation/medicine_stock_screen.dart';
import '../../patients/data/patient_repository.dart';
import '../../patients/domain/patient.dart';
import '../../patients/presentation/patient_info_card.dart';
import '../../patients/presentation/status_meta.dart';
import '../../profile/presentation/profile_screen.dart';
import '../../shell/presentation/nav_item.dart';
import '../../shell/presentation/role_shell.dart';
import 'patient_form.dart';

class NurseHomeScreen extends ConsumerStatefulWidget {
  const NurseHomeScreen({super.key, required this.perawatName, this.roleName = 'Perawat'});

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
    ShellNavItem(key: 'pasien', label: 'Pasien', icon: LucideIcons.clipboardList),
    ShellNavItem(key: 'riwayat', label: 'Riwayat', icon: LucideIcons.bookOpen),
    ShellNavItem(key: 'stok', label: 'Stok Obat', icon: LucideIcons.pill),
    ShellNavItem(key: 'profil', label: 'Profil', icon: LucideIcons.user),
  ];

  void _openEdit(BuildContext context, Patient patient) {
    if (isTabletLayout(context)) {
      setState(() {
        _editingPatient = patient;
        _showForm = true;
      });
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (ctx) => Scaffold(
            backgroundColor: AppColors.bg,
            body: SafeArea(
              child: TambahPasienForm(
                initialPatient: patient,
                onBack: () => Navigator.of(ctx).pop(),
                onSaved: () => Navigator.of(ctx).pop(),
              ),
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final patients = ref.watch(patientsProvider);

    return RoleShell(
      items: _tabs,
      activeKey: _tab,
      onChange: (key) => setState(() {
        _tab = key;
        _showForm = false;
        _editingPatient = null;
      }),
      child: switch (_tab) {
        'pasien' => _showForm
            ? TambahPasienForm(
                initialPatient: _editingPatient,
                onBack: () => setState(() {
                  _showForm = false;
                  _editingPatient = null;
                }),
                onSaved: () => setState(() {
                  _showForm = false;
                  _editingPatient = null;
                }),
              )
            : _buildPasien(patients),
        'riwayat' => const RiwayatKunjunganScreen(canEdit: false),
        'stok' => const StokObatScreen(canManage: false),
        _ => ProfileScreen(name: widget.perawatName, role: widget.roleName),
      },
    );
  }

  Widget _buildPasien(List<Patient> patients) {
    final notifier = ref.read(patientsProvider.notifier);
    final sorted = sortRecent(patients);
    return ResponsiveMasterDetail(
      title: 'Data Pasien',
      isLoading: notifier.isLoading,
      hasMore: notifier.hasMore,
      isLoadingMore: notifier.isLoadingMore,
      onLoadMore: () => notifier.loadMore(),
      onRefresh: () => notifier.fetchPatients(refresh: true),
      onEntrySelected: (id) => notifier.fetchPatientDetail(id),
      onSearchChanged: (q) => notifier.searchPatients(q),
      searchPlaceholder: 'Cari nama atau NIK pasien...',
      trailing: HeaderActionButton(
        icon: LucideIcons.plus,
        onPressed: () => setState(() {
          _editingPatient = null;
          _showForm = true;
        }),
      ),
      entries: [
        for (final p in sorted)
          MasterListEntry(
            id: p.id,
            avatarColor: AppColors.blue,
            avatarBg: AppColors.blueLt,
            initial: p.nama.isNotEmpty ? p.nama[0] : '?',
            title: p.nama,
            subtitle: p.waktuMasuk,
            badge: _statusBadge(p),
          ),
      ],
      detailBuilder: (context, id) {
        final currentPatients = ref.watch(patientsProvider);
        final patient = currentPatients.where((p) => p.id == id).firstOrNull ??
            patients.where((p) => p.id == id).firstOrNull;
        if (patient == null) {
          return const SkeletonPatientDetail();
        }
        return PatientInfoCard(
          patient: patient,
          onEdit: () => _openEdit(context, patient),
        );
      },
      emptyIcon: LucideIcons.clipboardList,
      emptyTitle: 'Pilih pasien',
      emptySubtitle: 'Pilih pasien di antrian untuk melihat data yang sudah diinput.',
    );
  }

  Widget _statusBadge(Patient p) {
    final meta = statusMeta(p);
    return AppBadge(label: meta.label, color: meta.color, background: meta.background);
  }
}