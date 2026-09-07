import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/clean_text_helper.dart';
import '../../../core/utils/date_helper.dart';
import '../../../core/widgets/app_badge.dart';
import '../../../core/widgets/push_detail_page.dart';
import '../../../core/widgets/responsive_master_detail.dart';
import '../../../core/widgets/screen_header.dart';
import '../../medicine_stock/presentation/medicine_stock_screen.dart';
import '../../patients/data/patient_repository.dart';
import '../../patients/domain/doctor.dart';
import '../../patients/domain/medical_history.dart';
import '../../patients/domain/patient.dart';
import '../../patients/domain/prescription_item.dart';
import '../../patients/presentation/status_meta.dart';
import '../../profile/presentation/profile_screen.dart';
import '../../shell/presentation/nav_item.dart';
import '../../shell/presentation/role_shell.dart';
import 'prescription_detail.dart';

class PharmacyHomeScreen extends ConsumerStatefulWidget {
  const PharmacyHomeScreen({super.key, required this.apotekerName});

  final String apotekerName;

  @override
  ConsumerState<PharmacyHomeScreen> createState() => _PharmacyHomeScreenState();
}

class _PharmacyHomeScreenState extends ConsumerState<PharmacyHomeScreen> {
  String _tab = 'notifikasi';
  String _statusFilter = 'Menunggu Obat';
  StreamSubscription? _wsSub;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(pharmacyPrescriptionHistoryProvider.notifier).fetchHistory();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ws = ref.read(webSocketServiceProvider);
      _wsSub = ws.onEvent.listen((event) {
        final type = event['type'] ?? event['event'];
        if (type == 'prescription_created') {
          if (!mounted) return;
          ref
              .read(pharmacyPrescriptionHistoryProvider.notifier)
              .fetchHistory(refresh: true);
          final patientName = event['patient_name'] ?? 'Pasien';
          final count = event['resep_count'] ?? 1;

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.card,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppColors.yellow, width: 1.5),
              ),
              content: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: AppColors.yellowLt,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      LucideIcons.bellRing,
                      size: 16,
                      color: AppColors.yellow,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Resep Baru Masuk!',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.text,
                          ),
                        ),
                        Text(
                          'Dokter telah menyelesaikan $count resep obat untuk $patientName',
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: AppColors.sub,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      });
    });
  }

  @override
  void dispose() {
    _wsSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allNotifs = ref.watch(notificationsProvider);
    final notifs = allNotifs
        .where(
          (p) =>
              p.statusPenanganan == 'Menunggu Obat' ||
              p.resepStatus == ResepStatus.baru,
        )
        .toList();

    final tabs = [
      ShellNavItem(
        key: 'notifikasi',
        label: 'Notifikasi',
        icon: LucideIcons.bell,
        badgeCount: notifs.length,
      ),
      const ShellNavItem(
        key: 'resep',
        label: 'Antrian Resep',
        icon: LucideIcons.fileText,
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
      case 'resep':
        content = _buildResep();
      case 'stok':
        content = const StokObatScreen(canManage: true);
      default:
        content = ProfileScreen(name: widget.apotekerName, role: 'Apoteker');
    }

    return RoleShell(
      items: tabs,
      activeKey: _tab,
      onChange: (key) {
        if (key == 'resep') {
          ref.read(pharmacyPrescriptionHistoryProvider.notifier).fetchHistory();
        }
        setState(() => _tab = key);
      },
      child: content,
    );
  }

  Widget _buildNotifikasi(List<Patient> notifs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ScreenHeader(
          title: 'Notifikasi',
          subtitle: '${notifs.length} resep baru',
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
                    final doctorName =
                        kDoctors
                            .where((d) => d.id == p.assignedDokterId)
                            .map((d) => d.nama)
                            .firstOrNull ??
                        '—';
                    final cleanPatientName = CleanTextHelper.cleanName(p.nama, fallback: 'Pasien');
                    final cleanPatientNik = CleanTextHelper.cleanCode(p.nik);
                    return Material(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () {
                          ref
                              .read(notificationsProvider.notifier)
                              .markPharmacySeen(p.id);
                          ref
                              .read(patientsProvider.notifier)
                              .markDilihatPharmacy(p.id);
                          pushDetailPage(
                            context,
                            title: cleanPatientName,
                            child: ResepDetail(
                              patientId: p.id,
                              medRecId: p.medicalRecordId,
                            ),
                          );
                        },
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
                                  color: AppColors.yellowLt,
                                  borderRadius: BorderRadius.circular(11),
                                ),
                                child: const Icon(
                                  LucideIcons.fileText,
                                  size: 19,
                                  color: AppColors.yellow,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Resep baru: $cleanPatientName',
                                      style: const TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.text,
                                      ),
                                    ),
                                    const SizedBox(height: 1),
                                    Text(
                                      '$doctorName · ${cleanPatientNik.isNotEmpty ? cleanPatientNik : '—'}',
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
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildResep() {
    final histories = ref.watch(pharmacyPrescriptionHistoryProvider);
    final notifier = ref.read(pharmacyPrescriptionHistoryProvider.notifier);

    final displayHistories = histories.where((m) {
      final status = m.statusPenanganan ?? m.status;
      if (_statusFilter == 'Menunggu Obat') {
        return status == 'Menunggu Obat';
      } else if (_statusFilter == 'Selesai') {
        return status == 'Selesai';
      }
      return status == 'Menunggu Obat' ||
          status == 'Selesai' ||
          (status != null && status.toLowerCase().contains('obat')) ||
          (status != null && status.toLowerCase().contains('selesai'));
    }).toList();

    return ResponsiveMasterDetail(
      title: 'Antrian Resep',
      isLoading: notifier.isLoading,
      hasMore: notifier.hasMore,
      isLoadingMore: notifier.isLoadingMore,
      onLoadMore: () => notifier.loadMore(),
      onRefresh: () => notifier.fetchHistory(refresh: true),
      onSearchChanged: (q) => notifier.searchHistory(q),
      searchPlaceholder: 'Cari nama atau NIK pasien...',
      searchTrailing: _buildStatusFilterButton(notifier),
      onEntrySelected: (id) {
        final item = displayHistories.where((h) => h.id == id).firstOrNull ??
            histories.where((h) => h.id == id).firstOrNull;
        final effectivePatientId =
            (item != null && item.patientId.isNotEmpty) ? item.patientId : id;
        if (item != null) {
          ref.read(patientsProvider.notifier).upsertPatient(item.toPatient());
        }
        ref
            .read(patientsProvider.notifier)
            .fetchPatientDetail(effectivePatientId);
      },
      entries: [
        for (final m in displayHistories) () {
          final cleanTitle = CleanTextHelper.cleanName(
            m.patientName,
            fallback: 'Pasien',
          );
          final cleanCode = CleanTextHelper.cleanCode(m.code);
          return MasterListEntry(
            id: m.id,
            avatarColor: AppColors.yellow,
            avatarBg: AppColors.yellowLt,
            initial: cleanTitle.isNotEmpty
                ? cleanTitle[0].toUpperCase()
                : '?',
            title: cleanTitle,
            code: cleanCode.isNotEmpty ? cleanCode : null,
            subtitle: _formatResepSubtitle(m),
            badge: _resepStatusBadge(m),
          );
        }(),
      ],
      detailBuilder: (context, id) {
        final item = displayHistories.where((h) => h.id == id).firstOrNull ??
            histories.where((h) => h.id == id).firstOrNull;
        final effectivePatientId =
            (item != null && item.patientId.isNotEmpty) ? item.patientId : id;
        return ResepDetail(
          patientId: effectivePatientId,
          medRecId: item?.id ?? id,
        );
      },
      emptyIcon: LucideIcons.fileText,
      emptyTitle: 'Pilih resep',
      emptySubtitle: 'Pilih resep untuk memproses & menyerahkan obat.',
    );
  }

  Widget _buildStatusFilterButton(MedicalHistoryNotifier notifier) {
    final isFiltered = _statusFilter != 'SEMUA';

    return PopupMenuButton<String>(
      tooltip: 'Filter Status Penanganan',
      initialValue: _statusFilter,
      onSelected: (val) {
        setState(() => _statusFilter = val);
        if (val == 'SEMUA') {
          notifier.setStatusPenanganan('Menunggu Obat,Selesai');
        } else {
          notifier.setStatusPenanganan(val);
        }
      },
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      color: Colors.white,
      elevation: 3,
      itemBuilder: (context) => [
        _buildPopupItem(
          value: 'SEMUA',
          label: 'Semua Status',
          selected: _statusFilter == 'SEMUA',
          color: AppColors.orange,
        ),
        _buildPopupItem(
          value: 'Menunggu Obat',
          label: 'Menunggu Obat',
          selected: _statusFilter == 'Menunggu Obat',
          color: AppColors.yellow,
        ),
        _buildPopupItem(
          value: 'Selesai',
          label: 'Selesai',
          selected: _statusFilter == 'Selesai',
          color: AppColors.green,
        ),
      ],
      child: Container(
        width: 42,
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isFiltered ? AppColors.orangeLt : AppColors.card2,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isFiltered ? AppColors.orange : AppColors.border,
            width: isFiltered ? 1.5 : 1,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              LucideIcons.filter,
              size: 17,
              color: isFiltered ? AppColors.orange : AppColors.sub,
            ),
            if (isFiltered)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: AppColors.orange,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<String> _buildPopupItem({
    required String value,
    required String label,
    required bool selected,
    required Color color,
  }) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(
            selected ? LucideIcons.check : LucideIcons.circle,
            size: 15,
            color: selected ? color : AppColors.sub.withValues(alpha: 0.4),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? color : AppColors.text,
            ),
          ),
        ],
      ),
    );
  }

  String _formatResepSubtitle(MedicalHistory m) {
    final parts = <String>[];
    final cleanNik = CleanTextHelper.cleanCode(m.patientNik);
    if (cleanNik.isNotEmpty) {
      parts.add(cleanNik);
    }
    if (m.createdAt != null && m.createdAt!.isNotEmpty) {
      parts.add(DateHelper.formatDateTime(m.createdAt));
    } else if (m.date != null && m.date!.isNotEmpty) {
      parts.add(DateHelper.formatDate(m.date));
    }
    if (parts.isEmpty) return '—';
    return parts.join(' • ');
  }

  Widget _resepStatusBadge(MedicalHistory m) {
    final meta = statusMetaFromPenanganan(m.statusPenanganan ?? m.status);
    return AppBadge(
      label: meta.label,
      color: meta.color,
      background: meta.background,
    );
  }
}
