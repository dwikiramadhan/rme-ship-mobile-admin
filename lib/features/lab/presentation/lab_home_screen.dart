import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/clean_text_helper.dart';
import '../../../core/widgets/app_badge.dart';
import '../../../core/widgets/responsive_master_detail.dart';
import '../../notifications/presentation/notifications_view.dart';
import '../../patients/data/patient_repository.dart';
import '../../patients/domain/lab_order.dart';
import '../../patients/domain/medical_history.dart';
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
  String? _selectedLabId;
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
        label: 'Antrian Lab',
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
        content = NotificationsView(
          role: NotificationRole.lab,
          onTapItem: (context, p, _) {
            ref.read(notificationsProvider.notifier).markLabSeen(p.id);
            ref.read(patientsProvider.notifier).markDilihatLab(p.id);
            final medHist = p.toMedicalHistory();
            ref.read(labOrderHistoryProvider.notifier).upsertHistory(medHist);
            ref.read(patientsProvider.notifier).upsertPatient(p);
            setState(() {
              _tab = 'order';
              _selectedLabId = medHist.id;
            });
          },
        );
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

  Widget _buildOrder(List<MedicalHistory> histories) {
    final notifier = ref.read(labOrderHistoryProvider.notifier);
    return ResponsiveMasterDetail(
      title: 'Antrian Lab',
      selectedId: _selectedLabId,
      subtitle: notifier.total > 0
          ? '${notifier.total} antrian lab'
          : '${histories.length} antrian lab',
      isLoading: notifier.isLoading && histories.isEmpty,
      hasMore: notifier.hasMore,
      isLoadingMore: notifier.isLoadingMore,
      onLoadMore: () => notifier.loadMore(),
      onRefresh: () => notifier.fetchHistory(refresh: true),
      onSearchChanged: (q) => notifier.searchHistory(q),
      searchPlaceholder: 'Cari nama atau NIK pasien...',
      onEntrySelected: (id) {
        setState(() => _selectedLabId = id);
        final item = histories.where((h) => h.id == id).firstOrNull;
        final effectivePatientId =
            (item != null && item.patientId.isNotEmpty) ? item.patientId : id;
        if (item != null) {
          ref.read(patientsProvider.notifier).upsertPatient(item.toPatient());
        }
        ref
            .read(notificationsProvider.notifier)
            .markLabSeen(effectivePatientId);
        ref
            .read(patientsProvider.notifier)
            .markDilihatLab(effectivePatientId);
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
      emptyTitle: 'Pilih antrian',
      emptySubtitle: 'Pilih antrian lab untuk input hasil pemeriksaan.',
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

