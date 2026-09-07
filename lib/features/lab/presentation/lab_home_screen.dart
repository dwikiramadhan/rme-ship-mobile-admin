import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/clean_text_helper.dart';
import '../../../core/widgets/app_badge.dart';
import '../../../core/widgets/push_detail_page.dart';
import '../../../core/widgets/responsive_master_detail.dart';
import '../../../core/widgets/screen_header.dart';
import '../../patients/data/patient_repository.dart';
import '../../patients/domain/doctor.dart';
import '../../patients/domain/lab_order.dart';
import '../../patients/domain/medical_history.dart';
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
  StreamSubscription? _wsSub;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(labOrderHistoryProvider.notifier).fetchHistory();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ws = ref.read(webSocketServiceProvider);
      _wsSub = ws.onEvent.listen((event) {
        final type = event['type'] ?? event['event'];
        if (type == 'lab_order_created' ||
            type == 'order_lab_created' ||
            type == 'new_lab_order') {
          if (!mounted) return;
          ref
              .read(labOrderHistoryProvider.notifier)
              .fetchHistory(refresh: true);
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
        .where((p) =>
            p.labOrder != null && p.labOrder!.status == LabOrderStatus.baru)
        .toList();
    final labHistories = ref.watch(labOrderHistoryProvider);

    final tabs = [
      ShellNavItem(
        key: 'notifikasi',
        label: 'Notifikasi',
        icon: LucideIcons.bell,
        badgeCount: notifs.length,
      ),
      ShellNavItem(
        key: 'order',
        label: 'Daftar Order',
        icon: LucideIcons.flaskConical,
        badgeCount: labHistories.length,
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
      case 'order':
        content = _buildOrder(labHistories);
      default:
        content = ProfileScreen(name: widget.analystName, role: 'Laboratorium');
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
          subtitle: '${notifs.length} order baru',
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
                    final doctorName = (p.doctorName != null &&
                            p.doctorName!.isNotEmpty)
                        ? p.doctorName!
                        : (kDoctors
                                .where((d) => d.id == p.assignedDokterId)
                                .map((d) => d.nama)
                                .firstOrNull ??
                            '—');
                    return Material(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () {
                          ref
                              .read(notificationsProvider.notifier)
                              .markLabSeen(p.id);
                          ref
                              .read(patientsProvider.notifier)
                              .markDilihatLab(p.id);
                          pushDetailPage(
                            context,
                            title: p.nama,
                            child: LabOrderDetail(
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
                                color: AppColors.text
                                    .withValues(alpha: 0.08),
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
                                  color: AppColors.purpleLt,
                                  borderRadius: BorderRadius.circular(11),
                                ),
                                child: const Icon(
                                  LucideIcons.flaskConical,
                                  size: 19,
                                  color: AppColors.purple,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Order lab: ${p.labOrder!.jenis}',
                                      style: const TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.text,
                                      ),
                                    ),
                                    const SizedBox(height: 1),
                                    Text(
                                      '${p.nama} · dari $doctorName',
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

  Widget _buildOrder(List<MedicalHistory> histories) {
    final notifier = ref.read(labOrderHistoryProvider.notifier);
    return ResponsiveMasterDetail(
      title: 'Daftar Order Lab',
      subtitle: notifier.total > 0
          ? '${notifier.total} order lab'
          : '${histories.length} order lab',
      isLoading: notifier.isLoading && histories.isEmpty,
      hasMore: notifier.hasMore,
      isLoadingMore: notifier.isLoadingMore,
      onLoadMore: () => notifier.loadMore(),
      onRefresh: () => notifier.fetchHistory(refresh: true),
      onSearchChanged: (q) => notifier.searchHistory(q),
      searchPlaceholder: 'Cari nama atau NIK pasien...',
      onEntrySelected: (id) {
        final item = histories.where((h) => h.id == id).firstOrNull;
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
        for (final m in histories) () {
          final cleanTitle = CleanTextHelper.cleanName(
            m.patientName,
            fallback: 'Pasien',
          );
          final cleanCode = CleanTextHelper.cleanCode(m.code);
          return MasterListEntry(
            id: m.id,
            avatarColor: AppColors.purple,
            avatarBg: AppColors.purpleLt,
            initial: cleanTitle.isNotEmpty
                ? cleanTitle[0].toUpperCase()
                : '?',
            title: cleanTitle,
            code: cleanCode.isNotEmpty ? cleanCode : null,
            subtitle: _formatLabSubtitle(m),
            badge: _labStatusBadge(m),
          );
        }(),
      ],
      detailBuilder: (context, id) {
        final item = histories.where((h) => h.id == id).firstOrNull;
        final effectivePatientId =
            (item != null && item.patientId.isNotEmpty) ? item.patientId : id;
        final effectiveMedRecId =
            (item != null && item.id.isNotEmpty) ? item.id : null;
        return LabOrderDetail(
          patientId: effectivePatientId,
          medRecId: effectiveMedRecId,
        );
      },
      emptyIcon: LucideIcons.flaskConical,
      emptyTitle: 'Pilih order',
      emptySubtitle: 'Pilih order lab untuk input hasil pemeriksaan.',
    );
  }

  String _formatLabSubtitle(MedicalHistory m) {
    final doctorName = (m.doctorName != null && m.doctorName!.isNotEmpty)
        ? m.doctorName!
        : '';
    String testName = '';
    final notes = (m.notes ?? '').trim();
    if (notes.contains('Order Lab:')) {
      testName = notes
          .substring(notes.indexOf('Order Lab:') + 'Order Lab:'.length)
          .trim();
      final openParen = testName.indexOf('(');
      if (openParen != -1) {
        testName = testName.substring(0, openParen).trim();
      }
    }
    if (testName.isEmpty &&
        m.tindakanDetail != null &&
        m.tindakanDetail!.trim().isNotEmpty &&
        m.tindakanDetail != '—' &&
        m.tindakanDetail != '-') {
      testName = m.tindakanDetail!.trim();
    }
    if (testName.isEmpty &&
        m.treatment != null &&
        m.treatment!.trim().isNotEmpty &&
        m.treatment != '—' &&
        m.treatment != '-' &&
        m.treatment != 'Pemeriksaan awal' &&
        m.treatment != 'Pemeriksaan Dokter') {
      testName = m.treatment!.trim();
    }
    if (testName.isEmpty) {
      testName = 'Pemeriksaan Laboratorium';
    }

    if (doctorName.isNotEmpty) {
      return '$testName · dr. $doctorName';
    }
    return testName;
  }

  Widget _labStatusBadge(MedicalHistory m) {
    final status = m.statusPenanganan ?? 'Menunggu Lab';
    final (label, color, bg) = switch (status.toLowerCase()) {
      'selesai' => ('Selesai', AppColors.green, AppColors.greenLt),
      'diproses' || 'sedang diproses' => (
          'Diproses',
          AppColors.blue,
          AppColors.blueLt
        ),
      _ => ('Menunggu Lab', AppColors.yellow, AppColors.yellowLt),
    };
    return AppBadge(label: label, color: color, background: bg);
  }
}

