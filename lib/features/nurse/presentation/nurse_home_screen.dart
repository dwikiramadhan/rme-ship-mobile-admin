import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_badge.dart';
import '../../../core/widgets/responsive_master_detail.dart';
import '../../../core/widgets/screen_header.dart';
import '../../patients/data/mock_patient_repository.dart';
import '../../patients/domain/doctor.dart';
import '../../patients/domain/patient.dart';
import '../../patients/presentation/patient_info_card.dart';
import '../../patients/presentation/status_meta.dart';
import '../../profile/presentation/profile_screen.dart';
import '../../riwayat/presentation/riwayat_kunjungan_screen.dart';
import '../../shell/presentation/nav_item.dart';
import '../../shell/presentation/role_shell.dart';
import '../../stok_obat/presentation/stok_obat_screen.dart';
import 'tambah_pasien_form.dart';

class PerawatHomeScreen extends ConsumerStatefulWidget {
  const PerawatHomeScreen({super.key, required this.perawatName, this.roleName = 'Perawat'});

  final String perawatName;
  final String roleName;

  @override
  ConsumerState<PerawatHomeScreen> createState() => _PerawatHomeScreenState();
}

class _PerawatHomeScreenState extends ConsumerState<PerawatHomeScreen> {
  String _tab = 'antrian';
  bool _showForm = false;

  static const _tabs = [
    ShellNavItem(key: 'antrian', label: 'Antrian', icon: LucideIcons.clipboardList),
    ShellNavItem(key: 'riwayat', label: 'Riwayat', icon: LucideIcons.bookOpen),
    ShellNavItem(key: 'stok', label: 'Stok Obat', icon: LucideIcons.pill),
    ShellNavItem(key: 'profil', label: 'Profil', icon: LucideIcons.user),
  ];

  @override
  Widget build(BuildContext context) {
    final patients = ref.watch(patientsProvider);

    return RoleShell(
      items: _tabs,
      activeKey: _tab,
      onChange: (key) => setState(() {
        _tab = key;
        _showForm = false;
      }),
      child: switch (_tab) {
        'antrian' => _showForm
            ? TambahPasienForm(
                onBack: () => setState(() => _showForm = false),
                onSaved: () => setState(() => _showForm = false),
              )
            : _buildAntrian(patients),
        'riwayat' => const RiwayatKunjunganScreen(canEdit: false),
        'stok' => const StokObatScreen(canManage: false),
        _ => ProfileScreen(name: widget.perawatName, role: widget.roleName),
      },
    );
  }

  Widget _buildAntrian(List<Patient> patients) {
    final sorted = sortRecent(patients);
    return ResponsiveMasterDetail(
      title: 'Antrian Pasien',
      subtitle: '${patients.length} pasien hari ini',
      trailing: HeaderActionButton(icon: LucideIcons.plus, onPressed: () => setState(() => _showForm = true)),
      entries: [
        for (final p in sorted)
          MasterListEntry(
            id: p.id,
            avatarColor: AppColors.blue,
            avatarBg: AppColors.blueLt,
            initial: p.nama.isNotEmpty ? p.nama[0] : '?',
            title: p.nama,
            subtitle: '${_doctorName(p.assignedDokterId)} · ${p.waktuMasuk}',
            badge: _statusBadge(p),
          ),
      ],
      detailBuilder: (context, id) {
        final patient = patients.firstWhere((p) => p.id == id);
        return PatientInfoCard(patient: patient);
      },
      emptyIcon: LucideIcons.clipboardList,
      emptyTitle: 'Pilih pasien',
      emptySubtitle: 'Pilih pasien di antrian untuk melihat data yang sudah diinput.',
    );
  }

  String _doctorName(String id) {
    for (final d in kDoctors) {
      if (d.id == id) return d.nama;
    }
    return '—';
  }

  Widget _statusBadge(Patient p) {
    final meta = statusMeta(p);
    return AppBadge(label: meta.label, color: meta.color, background: meta.background);
  }
}