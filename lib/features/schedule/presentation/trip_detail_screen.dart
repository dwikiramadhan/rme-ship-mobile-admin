import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../domain/trip_schedule.dart';
import 'widgets/edit_clinics_modal.dart';
import 'widgets/edit_schedule_modal.dart';

class TripDetailScreen extends ConsumerStatefulWidget {
  const TripDetailScreen({super.key, required this.item});

  final JadwalPerjalanan item;

  @override
  ConsumerState<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends ConsumerState<TripDetailScreen> {
  int _selectedTabIndex = 0;
  int _previousTabIndex = 0;
  OverlayEntry? _activeToastEntry;

  @override
  void dispose() {
    _activeToastEntry?.remove();
    _activeToastEntry = null;
    super.dispose();
  }

  void _showTopRightSuccessToast(BuildContext context, String message) {
    _activeToastEntry?.remove();
    _activeToastEntry = null;

    final overlay = Overlay.of(context, rootOverlay: true);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (ctx) => _TopRightToast(
        message: message,
        onDismiss: () {
          if (entry.mounted) {
            entry.remove();
            if (_activeToastEntry == entry) {
              _activeToastEntry = null;
            }
          }
        },
      ),
    );

    _activeToastEntry = entry;
    overlay.insert(entry);
  }

  String _formatFullDateTime(DateTime? dt, [String tz = 'WIB']) {
    if (dt == null) return '—';
    const days = [
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu',
      'Minggu',
    ];
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    final dayName = days[dt.weekday - 1];
    final day = dt.day.toString().padLeft(2, '0');
    final month = months[dt.month - 1];
    final year = dt.year;
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$dayName, $day $month $year $hour:$minute $tz';
  }

  String _getInitials(String name) {
    final clean = name
        .replaceAll(RegExp(r'^(dr\.|drg\.|Ns\.)\s*', caseSensitive: false), '')
        .trim();
    final parts = clean
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
    }
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  void _editSchedule(BuildContext context, JadwalPerjalanan item) {
    EditScheduleModal.show(
      context,
      schedule: item,
      onSave: (body) async {
        await ref
            .read(tripDetailNotifierProvider(widget.item).notifier)
            .updateSchedule(body);
        if (context.mounted) {
          _showTopRightSuccessToast(
            context,
            'Jadwal perjalanan berhasil diperbarui',
          );
        }
      },
    );
  }

  void _editClinics(BuildContext context, JadwalPerjalanan item) {
    EditClinicsModal.show(
      context,
      schedule: item,
      onSave: (body) async {
        await ref
            .read(tripDetailNotifierProvider(widget.item).notifier)
            .updateSchedule(body);
        if (context.mounted) {
          _showTopRightSuccessToast(
            context,
            'Poli layanan berhasil diperbarui',
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(tripDetailNotifierProvider(widget.item));
    final schedule = detailAsync.valueOrNull ?? widget.item;
    final status = schedule.tripStatus;
    final isOngoing = schedule.isOngoing;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(
            LucideIcons.arrowLeft,
            color: AppColors.text,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Detail Jadwal Perjalanan',
          style: TextStyle(
            fontSize: 16.5,
            fontWeight: FontWeight.w800,
            color: AppColors.text,
          ),
        ),
        actions: const [SizedBox(width: 8)],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref
              .read(tripDetailNotifierProvider(widget.item).notifier)
              .refresh(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 40),
            children: [
              // 1. Hero Header Card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: AppColors.orangeLt,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.orange.withValues(alpha: 0.2),
                        ),
                      ),
                      child: const Icon(
                        LucideIcons.ship,
                        color: AppColors.orange,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            schedule.namaKapal,
                            style: const TextStyle(
                              fontSize: 17.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.text,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Text(
                                schedule.shipCode,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.sub,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                width: 3,
                                height: 3,
                                decoration: const BoxDecoration(
                                  color: AppColors.sub,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  schedule.shipType,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.sub,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: status.containerColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: status.color.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isOngoing)
                            Container(
                              width: 7,
                              height: 7,
                              margin: const EdgeInsets.only(right: 6),
                              decoration: BoxDecoration(
                                color: status.color,
                                shape: BoxShape.circle,
                              ),
                            ),
                          Text(
                            status.label,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: status.color,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // 2. Custom Pill Tab Bar
              _buildTabBar(schedule),

              const SizedBox(height: 16),

              // 3. Tab Contents with smooth slider effect
              ClipRect(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) {
                    final isForward = _selectedTabIndex >= _previousTabIndex;
                    final isCurrent =
                        child.key == ValueKey<int>(_selectedTabIndex);

                    final inOffset = isForward
                        ? const Offset(0.20, 0.0)
                        : const Offset(-0.20, 0.0);
                    final outOffset = isForward
                        ? const Offset(-0.20, 0.0)
                        : const Offset(0.20, 0.0);

                    final offsetTween = Tween<Offset>(
                      begin: isCurrent ? inOffset : outOffset,
                      end: Offset.zero,
                    );

                    return SlideTransition(
                      position: offsetTween.animate(
                        CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeOutCubic,
                        ),
                      ),
                      child: FadeTransition(
                        opacity: CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeOut,
                        ),
                        child: child,
                      ),
                    );
                  },
                  child: KeyedSubtree(
                    key: ValueKey<int>(_selectedTabIndex),
                    child: _buildCurrentTab(schedule),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentTab(JadwalPerjalanan schedule) {
    switch (_selectedTabIndex) {
      case 0:
        return _buildTabInfoJadwal(schedule);
      case 1:
        return _buildTabPoliLayanan(schedule);
      case 2:
        return _buildTabPersediaan(schedule);
      case 3:
      default:
        return _buildTabKendala(schedule);
    }
  }

  // ==========================================
  // TAB BAR WIDGET
  // ==========================================
  Widget _buildTabBar(JadwalPerjalanan schedule) {
    final clinicsCount = schedule.clinics.length;
    final provisionsCount = schedule.provisions.length;
    final issuesCount = schedule.tripIssues.length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFEBF7EE),
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Color(0xFFE6F4EA), // Hijau lembut
            Color(0xFFF2FAF5), // Hijau ke putih-putihan
            Color(0xFFF9FCFA), // Putih bersih
          ],
        ),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFFD3EBD7), width: 1),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildTabItem(
              index: 0,
              icon: LucideIcons.settings,
              label: 'Info Jadwal',
            ),
            _buildTabItem(
              index: 1,
              icon: LucideIcons.building2,
              label: 'Poli Layanan',
              badgeCount: clinicsCount,
              badgeColor: const Color(0xFFF97316),
              badgeBg: const Color(0xFFFFEDD5),
            ),
            _buildTabItem(
              index: 2,
              icon: LucideIcons.fuel,
              label: 'Persediaan',
              badgeCount: provisionsCount,
              badgeColor: const Color(0xFFD97706),
              badgeBg: const Color(0xFFFEF3C7),
            ),
            _buildTabItem(
              index: 3,
              icon: LucideIcons.triangleAlert,
              label: 'Kendala Perjalanan',
              badgeCount: issuesCount,
              badgeColor: const Color(0xFFE11D48),
              badgeBg: const Color(0xFFFFE4E6),
              isAlert: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabItem({
    required int index,
    required IconData icon,
    required String label,
    int? badgeCount,
    Color? badgeColor,
    Color? badgeBg,
    bool isAlert = false,
  }) {
    final isSelected = _selectedTabIndex == index;
    final activeTextColor = isAlert ? const Color(0xFFE11D48) : AppColors.text;

    return GestureDetector(
      onTap: () {
        if (_selectedTabIndex != index) {
          setState(() {
            _previousTabIndex = _selectedTabIndex;
            _selectedTabIndex = index;
          });
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          boxShadow: isSelected
              ? const [
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ]
              : const [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? (isAlert ? const Color(0xFFE11D48) : AppColors.orange)
                  : const Color(0xFF64748B),
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected ? activeTextColor : const Color(0xFF64748B),
              ),
            ),
            if (badgeCount != null && badgeCount > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 1.5,
                ),
                decoration: BoxDecoration(
                  color: badgeBg ?? const Color(0xFFFFEDD5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$badgeCount',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: badgeColor ?? const Color(0xFFF97316),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ==========================================
  // TAB 1: INFO JADWAL
  // ==========================================
  Widget _buildTabInfoJadwal(JadwalPerjalanan schedule) {
    final isWide = MediaQuery.sizeOf(context).width >= 720;
    if (isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 6,
            child: Column(
              children: [
                _buildRutePerjalananCard(schedule),
                const SizedBox(height: 14),
                _buildLogistikAwalCard(schedule),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            flex: 4,
            child: Column(
              children: [
                _buildPersonnelCard(
                  title: 'DOKTER BERTUGAS',
                  icon: LucideIcons.stethoscope,
                  iconColor: AppColors.orange,
                  badgeBg: const Color(0xFFFFEDD5),
                  badgeColor: const Color(0xFFF97316),
                  items: schedule.doctorStaff.isNotEmpty
                      ? schedule.doctorStaff
                      : schedule.doctors
                            .map(
                              (d) => SchedulePersonnelItem(
                                name: d,
                                role: 'DOKTER',
                                specialization: 'Dokter Umum',
                              ),
                            )
                            .toList(),
                  avatarBg: const Color(0xFFFFEEDB),
                  avatarTextColor: const Color(0xFFD97706),
                  emptyText: 'Belum ada dokter yang ditugaskan',
                ),
                const SizedBox(height: 14),
                _buildPersonnelCard(
                  title: 'PERAWAT BERTUGAS',
                  icon: LucideIcons.heartPulse,
                  iconColor: const Color(0xFF059669),
                  badgeBg: const Color(0xFFD1FAE5),
                  badgeColor: const Color(0xFF059669),
                  items: schedule.nurseStaff,
                  avatarBg: const Color(0xFFE6F7F0),
                  avatarTextColor: const Color(0xFF059669),
                  emptyText: 'Belum ada perawat yang ditugaskan',
                ),
                const SizedBox(height: 14),
                _buildCrewCard(schedule),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        _buildRutePerjalananCard(schedule),
        const SizedBox(height: 14),
        _buildLogistikAwalCard(schedule),
        const SizedBox(height: 14),
        _buildPersonnelCard(
          title: 'DOKTER BERTUGAS',
          icon: LucideIcons.stethoscope,
          iconColor: AppColors.orange,
          badgeBg: const Color(0xFFFFEDD5),
          badgeColor: const Color(0xFFF97316),
          items: schedule.doctorStaff.isNotEmpty
              ? schedule.doctorStaff
              : schedule.doctors
                    .map(
                      (d) => SchedulePersonnelItem(
                        name: d,
                        role: 'DOKTER',
                        specialization: 'Dokter Umum',
                      ),
                    )
                    .toList(),
          avatarBg: const Color(0xFFFFEEDB),
          avatarTextColor: const Color(0xFFD97706),
          emptyText: 'Belum ada dokter yang ditugaskan',
        ),
        const SizedBox(height: 14),
        _buildPersonnelCard(
          title: 'PERAWAT BERTUGAS',
          icon: LucideIcons.heartPulse,
          iconColor: const Color(0xFF059669),
          badgeBg: const Color(0xFFD1FAE5),
          badgeColor: const Color(0xFF059669),
          items: schedule.nurseStaff,
          avatarBg: const Color(0xFFE6F7F0),
          avatarTextColor: const Color(0xFF059669),
          emptyText: 'Belum ada perawat yang ditugaskan',
        ),
        const SizedBox(height: 14),
        _buildCrewCard(schedule),
      ],
    );
  }

  Widget _buildRutePerjalananCard(JadwalPerjalanan schedule) {
    final stops = schedule.stops;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                LucideIcons.mapPin,
                size: 16,
                color: Color(0xFF64748B),
              ),
              const SizedBox(width: 8),
              const Text(
                'RUTE PERJALANAN',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  color: Color(0xFF64748B),
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: () => _editSchedule(context, schedule),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.orangeLt,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.orange.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(
                        LucideIcons.pencilLine,
                        size: 13,
                        color: AppColors.orange,
                      ),
                      SizedBox(width: 5),
                      Text(
                        'Edit Jadwal',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.orange,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (stops.isNotEmpty) ...[
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: stops.length,
              itemBuilder: (context, index) {
                final stop = stops[index];
                final isFirst = index == 0;
                final isLast = index == stops.length - 1;

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isFirst || isLast
                                ? const Color(0xFFEA580C)
                                : const Color(0xFF94A3B8),
                            border: Border.all(
                              color: isFirst || isLast
                                  ? const Color(0xFFFED7AA)
                                  : const Color(0xFFE2E8F0),
                              width: 3,
                            ),
                          ),
                          child: Center(
                            child: Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        if (!isLast)
                          Container(
                            width: 2,
                            height: 48,
                            color: const Color(0xFFE2E8F0),
                          ),
                      ],
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            stop.portName,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.text,
                            ),
                          ),
                          const SizedBox(height: 3),
                          if (isFirst) ...[
                            Text.rich(
                              TextSpan(
                                children: [
                                  const TextSpan(
                                    text: 'Berangkat: ',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.sub,
                                    ),
                                  ),
                                  TextSpan(
                                    text: _formatFullDateTime(
                                      stop.departure ?? schedule.berangkat,
                                      stop.departureTz,
                                    ),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.text,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ] else if (isLast) ...[
                            Text.rich(
                              TextSpan(
                                children: [
                                  const TextSpan(
                                    text: 'Tiba Est: ',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.sub,
                                    ),
                                  ),
                                  TextSpan(
                                    text: _formatFullDateTime(
                                      stop.arrival ?? schedule.tiba,
                                      stop.arrivalTz,
                                    ),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.text,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ] else ...[
                            Wrap(
                              spacing: 12,
                              runSpacing: 4,
                              children: [
                                if (stop.departure != null)
                                  Text.rich(
                                    TextSpan(
                                      children: [
                                        const TextSpan(
                                          text: 'Berangkat: ',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: AppColors.sub,
                                          ),
                                        ),
                                        TextSpan(
                                          text: _formatFullDateTime(
                                            stop.departure,
                                            stop.departureTz,
                                          ),
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.text,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                if (stop.arrival != null)
                                  Text.rich(
                                    TextSpan(
                                      children: [
                                        const TextSpan(
                                          text: 'Tiba Est: ',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: AppColors.sub,
                                          ),
                                        ),
                                        TextSpan(
                                          text: _formatFullDateTime(
                                            stop.arrival,
                                            stop.arrivalTz,
                                          ),
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.text,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 14),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ] else ...[
            // Fallback 2-stop simple display
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFEA580C),
                        border: Border.all(
                          color: const Color(0xFFFED7AA),
                          width: 3,
                        ),
                      ),
                    ),
                    Container(
                      width: 2,
                      height: 48,
                      color: const Color(0xFFE2E8F0),
                    ),
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFEA580C),
                        border: Border.all(
                          color: const Color(0xFFFED7AA),
                          width: 3,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        schedule.pelabuhanAsal,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.text,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text.rich(
                        TextSpan(
                          children: [
                            const TextSpan(
                              text: 'Berangkat: ',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.sub,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            TextSpan(
                              text: _formatFullDateTime(schedule.berangkat),
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.text,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 30),
                      Text(
                        schedule.pelabuhanTujuan,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.text,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text.rich(
                        TextSpan(
                          children: [
                            const TextSpan(
                              text: 'Tiba Est: ',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.sub,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            TextSpan(
                              text: _formatFullDateTime(schedule.tiba),
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.text,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLogistikAwalCard(JadwalPerjalanan schedule) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(LucideIcons.boxes, size: 16, color: Color(0xFF64748B)),
              SizedBox(width: 8),
              Text(
                'LOGISTIK AWAL JADWAL',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFDF0),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFFEF3C7)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(
                            LucideIcons.fuel,
                            size: 16,
                            color: Color(0xFFB45309),
                          ),
                          SizedBox(width: 6),
                          Text(
                            'BBM AWAL',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFB45309),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            schedule.fuelLiters > 0
                                ? '${schedule.fuelLiters}'
                                : '0',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppColors.text,
                            ),
                          ),
                          const SizedBox(width: 5),
                          const Text(
                            'Liter',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppColors.sub,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F7FF),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE0EFFF)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(
                            LucideIcons.droplets,
                            size: 16,
                            color: AppColors.sky,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'AIR AWAL',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.sky,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            schedule.waterLiters > 0
                                ? '${schedule.waterLiters}'
                                : '0',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppColors.text,
                            ),
                          ),
                          const SizedBox(width: 5),
                          const Text(
                            'Liter',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppColors.sub,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPersonnelCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required Color badgeBg,
    required Color badgeColor,
    required List<SchedulePersonnelItem> items,
    required Color avatarBg,
    required Color avatarTextColor,
    required String emptyText,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, size: 16, color: iconColor),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: Color(0xFF334155),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${items.length}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: badgeColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (items.isEmpty)
            Text(
              emptyText,
              style: const TextStyle(fontSize: 12, color: AppColors.sub),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final p = items[index];
                final initials = p.initials.isNotEmpty
                    ? p.initials
                    : _getInitials(p.name);

                return Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: avatarBg,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          initials,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: avatarTextColor,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.name,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.text,
                            ),
                          ),
                          if (p.specialization.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              p.specialization,
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: AppColors.sub,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildCrewCard(JadwalPerjalanan schedule) {
    final items = schedule.crewStaff;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(LucideIcons.anchor, size: 16, color: AppColors.sky),
                  SizedBox(width: 8),
                  Text(
                    'CREW (ABK KAPAL)',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: Color(0xFF334155),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.skyLt,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${items.length}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.sky,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (items.isEmpty)
            const Text(
              'Belum ada data crew kapal',
              style: TextStyle(fontSize: 12, color: AppColors.sub),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final crew = items[index];
                final initials = crew.initials.isNotEmpty
                    ? crew.initials
                    : _getInitials(crew.name);

                return Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        color: AppColors.skyLt,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          initials,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppColors.sky,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            crew.name,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.text,
                            ),
                          ),
                          if (crew.role.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              crew.role,
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: AppColors.sub,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 2: POLI LAYANAN
  // ==========================================
  Widget _buildTabPoliLayanan(JadwalPerjalanan schedule) {
    final clinics = schedule.clinics;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              LucideIcons.building2,
              size: 16,
              color: Color(0xFF64748B),
            ),
            const SizedBox(width: 8),
            const Text(
              'DAFTAR POLI LAYANAN',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
                color: Color(0xFF64748B),
              ),
            ),
            const Spacer(),
            InkWell(
              onTap: () => _editClinics(context, schedule),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppColors.orangeLt,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.orange.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(
                      LucideIcons.pencilLine,
                      size: 13,
                      color: AppColors.orange,
                    ),
                    SizedBox(width: 5),
                    Text(
                      'Edit Poli',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.orange,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (clinics.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                const Icon(
                  LucideIcons.building2,
                  size: 40,
                  color: Color(0xFF94A3B8),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Belum ada Poli Layanan terdaftar',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Poli layanan untuk jadwal ini belum dikonfigurasi.',
                  style: TextStyle(fontSize: 12, color: AppColors.sub),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => _editClinics(context, schedule),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.orange,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                  icon: const Icon(
                    LucideIcons.pencilLine,
                    size: 15,
                    color: Colors.white,
                  ),
                  label: const Text(
                    'Atur Poli Layanan',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: clinics.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final clinic = clinics[index];

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF7ED),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFFED7AA)),
                      ),
                      child: const Icon(
                        LucideIcons.building2,
                        color: Color(0xFFEA580C),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            clinic.name,
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.text,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            clinic.code.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.sub,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${clinic.openTime} – ${clinic.closeTime}',
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFEA580C),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  // ==========================================
  // TAB 3: PERSEDIAAN
  // ==========================================
  Widget _buildTabPersediaan(JadwalPerjalanan schedule) {
    final provisions = schedule.provisions;
    final latest = provisions.isNotEmpty ? provisions.first : null;

    final latestFuel = latest != null
        ? latest.fuelOil
        : schedule.fuelLiters.toDouble();
    final latestWater = latest != null
        ? latest.water
        : schedule.waterLiters.toDouble();
    final latestTime = latest != null ? latest.createdAt : schedule.berangkat;
    final latestLat = latest?.lat;
    final latestLng = latest?.lng;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top Row KPI Cards
        Builder(
          builder: (context) {
            final isWide = MediaQuery.sizeOf(context).width >= 850;
            if (isWide) {
              return Row(
                children: [
                  Expanded(
                    child: _buildKpiCard(
                      title: 'SISA BAHAN BAKAR',
                      icon: LucideIcons.fuel,
                      iconColor: const Color(0xFFB45309),
                      currentValue: latestFuel.toInt(),
                      initialValue: schedule.fuelLiters,
                      unit: 'Liter',
                      isLatest: latest != null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildKpiCard(
                      title: 'SISA AIR BERSIH',
                      icon: LucideIcons.droplets,
                      iconColor: AppColors.sky,
                      currentValue: latestWater.toInt(),
                      initialValue: schedule.waterLiters,
                      unit: 'Liter',
                      isLatest: latest != null,
                      isWater: true,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildUpdateTerakhirCard(
                      time: latestTime,
                      lat: latestLat,
                      lng: latestLng,
                      onAddPressed: () =>
                          _showAddProvisionDialog(context, schedule),
                    ),
                  ),
                ],
              );
            }

            return Column(
              children: [
                _buildKpiCard(
                  title: 'SISA BAHAN BAKAR',
                  icon: LucideIcons.fuel,
                  iconColor: const Color(0xFFB45309),
                  currentValue: latestFuel.toInt(),
                  initialValue: schedule.fuelLiters,
                  unit: 'Liter',
                  isLatest: latest != null,
                ),
                const SizedBox(height: 12),
                _buildKpiCard(
                  title: 'SISA AIR BERSIH',
                  icon: LucideIcons.droplets,
                  iconColor: AppColors.sky,
                  currentValue: latestWater.toInt(),
                  initialValue: schedule.waterLiters,
                  unit: 'Liter',
                  isLatest: latest != null,
                  isWater: true,
                ),
                const SizedBox(height: 12),
                _buildUpdateTerakhirCard(
                  time: latestTime,
                  lat: latestLat,
                  lng: latestLng,
                  onAddPressed: () =>
                      _showAddProvisionDialog(context, schedule),
                ),
              ],
            );
          },
        ),

        const SizedBox(height: 20),

        // Riwayat Pencatatan Sisa Logistik Table
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(LucideIcons.history, size: 16, color: Color(0xFFEA580C)),
                  SizedBox(width: 8),
                  Text(
                    'RIWAYAT PENCATATAN SISA LOGISTIK',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: Color(0xFF334155),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (provisions.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'Belum ada riwayat pencatatan logistik',
                      style: TextStyle(fontSize: 12.5, color: AppColors.sub),
                    ),
                  ),
                )
              else
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columnSpacing: 24,
                    horizontalMargin: 8,
                    headingTextStyle: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF64748B),
                      letterSpacing: 0.4,
                    ),
                    columns: const [
                      DataColumn(label: Text('WAKTU PENCATATAN')),
                      DataColumn(label: Text('SISA BBM')),
                      DataColumn(label: Text('SISA AIR BERSIH')),
                      DataColumn(label: Text('KOORDINAT LOKASI')),
                      DataColumn(label: Text('AKSI')),
                    ],
                    rows: provisions.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final item = entry.value;
                      final isFirst = idx == 0;

                      return DataRow(
                        cells: [
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 7,
                                  height: 7,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isFirst
                                        ? const Color(0xFF10B981)
                                        : const Color(0xFF94A3B8),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _formatFullDateTime(item.createdAt),
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.text,
                                  ),
                                ),
                                if (isFirst) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFD1FAE5),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'TERBARU',
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF059669),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFFBEB),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: const Color(0xFFFEF3C7),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    LucideIcons.fuel,
                                    size: 13,
                                    color: Color(0xFFB45309),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${item.fuelOil.toInt()} Liter',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFFB45309),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0F7FF),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: const Color(0xFFE0EFFF),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    LucideIcons.droplets,
                                    size: 13,
                                    color: AppColors.sky,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${item.water.toInt()} Liter',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.sky,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  LucideIcons.mapPin,
                                  size: 12,
                                  color: Color(0xFF94A3B8),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  (item.lat != null && item.lng != null)
                                      ? '${item.lat!.toStringAsFixed(5)}, ${item.lng!.toStringAsFixed(5)}'
                                      : '—',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    LucideIcons.trash2,
                                    size: 15,
                                    color: Color(0xFF94A3B8),
                                  ),
                                  tooltip: 'Hapus Pencatatan',
                                  onPressed: () =>
                                      _confirmDeleteProvision(context, item.id),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildKpiCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required int currentValue,
    required int initialValue,
    required String unit,
    required bool isLatest,
    bool isWater = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, size: 16, color: iconColor),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                      color: isWater ? AppColors.sky : const Color(0xFFB45309),
                    ),
                  ),
                ],
              ),
              if (isLatest)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: isWater ? AppColors.skyLt : const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Terbaru',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: isWater ? AppColors.sky : const Color(0xFFD97706),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$currentValue',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                unit,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.sub,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Flexible(
                child: Text(
                  'Kapasitas Awal',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '$initialValue L',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUpdateTerakhirCard({
    required DateTime? time,
    required double? lat,
    required double? lng,
    required VoidCallback onAddPressed,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(LucideIcons.history, size: 16, color: Color(0xFF64748B)),
              SizedBox(width: 8),
              Text(
                'UPDATE TERAKHIR',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _formatFullDateTime(time),
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(
                LucideIcons.mapPin,
                size: 12,
                color: Color(0xFF94A3B8),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  (lat != null && lng != null)
                      ? '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}'
                      : '—',
                  style: const TextStyle(fontSize: 12, color: AppColors.sub),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFEA580C),
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: onAddPressed,
              icon: const Icon(LucideIcons.plus, size: 16),
              label: const Text(
                'Catat Sisa Logistik',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddProvisionDialog(
    BuildContext context,
    JadwalPerjalanan schedule,
  ) {
    final provisions = schedule.provisions;
    final latest = provisions.isNotEmpty ? provisions.first : null;
    final num currentFuel = latest != null
        ? latest.fuelOil
        : schedule.fuelLiters;
    final num currentWater = latest != null
        ? latest.water
        : schedule.waterLiters;

    String formatNum(num n) => n % 1 == 0 ? n.toInt().toString() : n.toString();

    final fuelController = TextEditingController();
    final waterController = TextEditingController();
    final latController = TextEditingController();
    final lngController = TextEditingController();
    var isSubmitting = false;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            final enteredFuel = double.tryParse(fuelController.text.trim());
            final isFuelExceeded =
                currentFuel > 0 &&
                enteredFuel != null &&
                enteredFuel > currentFuel;

            final enteredWater = double.tryParse(waterController.text.trim());
            final isWaterExceeded =
                currentWater > 0 &&
                enteredWater != null &&
                enteredWater > currentWater;

            return PopScope(
              canPop: !isSubmitting,
              child: AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                insetPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 24,
                ),
                titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                actionsPadding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                title: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF7ED),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        LucideIcons.fuel,
                        color: Color(0xFFEA580C),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Catat Sisa Logistik',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Perbarui sisa stok BBM & air bersih',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                content: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: SizedBox(
                    width: MediaQuery.sizeOf(dialogCtx).width,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Info Note
                          Container(
                            margin: const EdgeInsets.only(bottom: 14),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Row(
                              children: const [
                                Icon(
                                  LucideIcons.info,
                                  size: 14,
                                  color: Color(0xFF64748B),
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Nilai yang dimasukkan tidak boleh lebih dari sisa logistik saat ini.',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: Color(0xFF475569),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Fuel Field Header with Current Stock Badge
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Sisa Bahan Bakar (BBM)',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF334155),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2.5,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF7ED),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: const Color(0xFFFFEDD5),
                                  ),
                                ),
                                child: Text(
                                  'Saat ini: ${formatNum(currentFuel)} L',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFFEA580C),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: fuelController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'^\d*\.?\d*'),
                              ),
                            ],
                            onChanged: (_) => setDialogState(() {}),
                            decoration: InputDecoration(
                              hintText: '0',
                              hintStyle: const TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 14,
                              ),
                              helperText: isFuelExceeded
                                  ? null
                                  : 'Maksimal ${formatNum(currentFuel)} Liter',
                              helperStyle: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF64748B),
                              ),
                              errorText: isFuelExceeded
                                  ? 'Tidak boleh melebihi sisa BBM saat ini (${formatNum(currentFuel)} L)'
                                  : null,
                              errorStyle: const TextStyle(
                                fontSize: 11,
                                color: AppColors.red,
                              ),
                              prefixIcon: const Icon(
                                LucideIcons.fuel,
                                size: 18,
                                color: Color(0xFFEA580C),
                              ),
                              suffixText: 'Liter',
                              suffixStyle: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF64748B),
                              ),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: isFuelExceeded
                                      ? AppColors.red
                                      : const Color(0xFFE2E8F0),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: isFuelExceeded
                                      ? AppColors.red
                                      : const Color(0xFFE2E8F0),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: isFuelExceeded
                                      ? AppColors.red
                                      : const Color(0xFFEA580C),
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Water Field Header with Current Stock Badge
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Sisa Air Bersih',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF334155),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2.5,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.skyLt,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: const Color(0xFFBAE6FD),
                                  ),
                                ),
                                child: Text(
                                  'Saat ini: ${formatNum(currentWater)} L',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.sky,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: waterController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'^\d*\.?\d*'),
                              ),
                            ],
                            onChanged: (_) => setDialogState(() {}),
                            decoration: InputDecoration(
                              hintText: '0',
                              hintStyle: const TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 14,
                              ),
                              helperText: isWaterExceeded
                                  ? null
                                  : 'Maksimal ${formatNum(currentWater)} Liter',
                              helperStyle: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF64748B),
                              ),
                              errorText: isWaterExceeded
                                  ? 'Tidak boleh melebihi sisa air saat ini (${formatNum(currentWater)} L)'
                                  : null,
                              errorStyle: const TextStyle(
                                fontSize: 11,
                                color: AppColors.red,
                              ),
                              prefixIcon: const Icon(
                                LucideIcons.droplets,
                                size: 18,
                                color: AppColors.sky,
                              ),
                              suffixText: 'Liter',
                              suffixStyle: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF64748B),
                              ),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: isWaterExceeded
                                      ? AppColors.red
                                      : const Color(0xFFE2E8F0),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: isWaterExceeded
                                      ? AppColors.red
                                      : const Color(0xFFE2E8F0),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: isWaterExceeded
                                      ? AppColors.red
                                      : AppColors.sky,
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Optional Coordinates Section
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(
                                      LucideIcons.mapPin,
                                      size: 14,
                                      color: Color(0xFF64748B),
                                    ),
                                    SizedBox(width: 6),
                                    Text(
                                      'Koordinat Posisi (Opsional)',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF475569),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: latController,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF1E293B),
                                        ),
                                        keyboardType:
                                            const TextInputType.numberWithOptions(
                                              decimal: true,
                                              signed: true,
                                            ),
                                        inputFormatters: [
                                          FilteringTextInputFormatter.allow(
                                            RegExp(r'^-?\d*\.?\d*'),
                                          ),
                                        ],
                                        decoration: InputDecoration(
                                          labelText: 'Latitude',
                                          labelStyle: TextStyle(
                                            fontSize: 12,
                                            color: WidgetStateColor.resolveWith(
                                              (states) {
                                                if (states.contains(
                                                  WidgetState.focused,
                                                )) {
                                                  return AppColors.sky;
                                                }
                                                return const Color(0xFF64748B);
                                              },
                                            ),
                                          ),
                                          floatingLabelStyle: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: WidgetStateColor.resolveWith(
                                              (states) {
                                                if (states.contains(
                                                  WidgetState.focused,
                                                )) {
                                                  return AppColors.sky;
                                                }
                                                return const Color(0xFF64748B);
                                              },
                                            ),
                                          ),
                                          hintText: '-6.1751',
                                          hintStyle: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF94A3B8),
                                          ),
                                          filled: true,
                                          fillColor: Colors.white,
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 10,
                                              ),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            borderSide: const BorderSide(
                                              color: Color(0xFFCBD5E1),
                                            ),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            borderSide: const BorderSide(
                                              color: Color(0xFFCBD5E1),
                                            ),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            borderSide: const BorderSide(
                                              color: AppColors.sky,
                                              width: 1.5,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: TextField(
                                        controller: lngController,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF1E293B),
                                        ),
                                        keyboardType:
                                            const TextInputType.numberWithOptions(
                                              decimal: true,
                                              signed: true,
                                            ),
                                        inputFormatters: [
                                          FilteringTextInputFormatter.allow(
                                            RegExp(r'^-?\d*\.?\d*'),
                                          ),
                                        ],
                                        decoration: InputDecoration(
                                          labelText: 'Longitude',
                                          labelStyle: TextStyle(
                                            fontSize: 12,
                                            color: WidgetStateColor.resolveWith(
                                              (states) {
                                                if (states.contains(
                                                  WidgetState.focused,
                                                )) {
                                                  return AppColors.sky;
                                                }
                                                return const Color(0xFF64748B);
                                              },
                                            ),
                                          ),
                                          floatingLabelStyle: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: WidgetStateColor.resolveWith(
                                              (states) {
                                                if (states.contains(
                                                  WidgetState.focused,
                                                )) {
                                                  return AppColors.sky;
                                                }
                                                return const Color(0xFF64748B);
                                              },
                                            ),
                                          ),
                                          hintText: '106.8271',
                                          hintStyle: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF94A3B8),
                                          ),
                                          filled: true,
                                          fillColor: Colors.white,
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 10,
                                              ),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            borderSide: const BorderSide(
                                              color: Color(0xFFCBD5E1),
                                            ),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            borderSide: const BorderSide(
                                              color: Color(0xFFCBD5E1),
                                            ),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            borderSide: const BorderSide(
                                              color: AppColors.sky,
                                              width: 1.5,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                actions: [
                  OutlinedButton(
                    onPressed: isSubmitting
                        ? null
                        : () => Navigator.pop(dialogCtx),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    child: const Text(
                      'Batal',
                      style: TextStyle(
                        color: Color(0xFF475569),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFEA580C),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: isSubmitting
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(LucideIcons.check, size: 16),
                    label: Text(
                      isSubmitting ? 'Menyimpan...' : 'Simpan',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                    onPressed:
                        (isSubmitting || isFuelExceeded || isWaterExceeded)
                        ? null
                        : () async {
                            final fuel =
                                double.tryParse(fuelController.text.trim()) ??
                                0;
                            final water =
                                double.tryParse(waterController.text.trim()) ??
                                0;
                            final lat = double.tryParse(
                              latController.text.trim(),
                            );
                            final lng = double.tryParse(
                              lngController.text.trim(),
                            );

                            if (fuel <= 0 && water <= 0) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Masukkan sisa BBM atau Air yang valid',
                                  ),
                                ),
                              );
                              return;
                            }

                            if (currentFuel > 0 && fuel > currentFuel) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Sisa BBM tidak boleh melebihi sisa saat ini (${formatNum(currentFuel)} Liter)',
                                  ),
                                ),
                              );
                              return;
                            }

                            if (currentWater > 0 && water > currentWater) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Sisa Air tidak boleh melebihi sisa saat ini (${formatNum(currentWater)} Liter)',
                                  ),
                                ),
                              );
                              return;
                            }

                            setDialogState(() {
                              isSubmitting = true;
                            });

                            try {
                              await ref
                                  .read(
                                    tripDetailNotifierProvider(
                                      widget.item,
                                    ).notifier,
                                  )
                                  .addProvision(
                                    scheduleCode: schedule.scheduleCode,
                                    fuelOil: fuel,
                                    water: water,
                                    lat: lat,
                                    lng: lng,
                                  );
                              if (dialogCtx.mounted) {
                                Navigator.pop(dialogCtx);
                              }
                              if (context.mounted) {
                                _showTopRightSuccessToast(
                                  context,
                                  'Sisa logistik berhasil dicatat',
                                );
                              }
                            } catch (e) {
                              if (dialogCtx.mounted) {
                                setDialogState(() {
                                  isSubmitting = false;
                                });
                              }
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Gagal mencatat logistik: $e',
                                    ),
                                    backgroundColor: Colors.red.shade700,
                                  ),
                                );
                              }
                            }
                          },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _confirmDeleteProvision(BuildContext context, String id) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus Catatan Logistik?'),
        content: const Text(
          'Catatan sisa logistik ini akan dihapus secara permanen.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Batal', style: TextStyle(fontSize: 12)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              try {
                await ref
                    .read(tripDetailNotifierProvider(widget.item).notifier)
                    .deleteProvision(id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Catatan logistik berhasil dihapus'),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Gagal menghapus logistik: $e')),
                  );
                }
              }
            },
            child: const Text('Hapus', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 4: KENDALA PERJALANAN
  // ==========================================
  Widget _buildTabKendala(JadwalPerjalanan schedule) {
    final issues = schedule.tripIssues;

    return Column(
      children: [
        if (issues.isNotEmpty)
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: issues.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final issue = issues[index];

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Icon(
                      LucideIcons.triangleAlert,
                      color: Color(0xFFD97706),
                      size: 20,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            issue.description,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF92400E),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                _formatFullDateTime(
                                  issue.occurredAt,
                                  issue.occurredAtTz,
                                ),
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: AppColors.sub,
                                ),
                              ),
                              if (issue.lat != null && issue.lng != null) ...[
                                const SizedBox(width: 8),
                                const Icon(
                                  LucideIcons.mapPin,
                                  size: 11,
                                  color: AppColors.sub,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  '${issue.lat!.toStringAsFixed(5)}, ${issue.lng!.toStringAsFixed(5)}',
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    color: AppColors.sub,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        LucideIcons.trash2,
                        color: Color(0xFFD97706),
                        size: 18,
                      ),
                      tooltip: 'Hapus Kendala',
                      onPressed: () =>
                          _confirmDeleteTripIssue(context, issue.id),
                    ),
                  ],
                ),
              );
            },
          ),
        const SizedBox(height: 14),

        // Dashed "+ Tambah Kendala" Button
        CustomPaint(
          painter: _DashedRoundedBorderPainter(
            color: const Color(0xFFFDBA74),
            strokeWidth: 1.5,
            dashWidth: 6,
            dashSpace: 4,
            radius: 18,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => _showAddTripIssueDialog(context, schedule),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                alignment: Alignment.center,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(LucideIcons.plus, size: 16, color: Color(0xFFEA580C)),
                    SizedBox(width: 6),
                    Text(
                      'Tambah Kendala',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFEA580C),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showAddTripIssueDialog(
    BuildContext context,
    JadwalPerjalanan schedule,
  ) {
    final descController = TextEditingController();
    final latController = TextEditingController();
    final lngController = TextEditingController();
    DateTime selectedTime = DateTime.now();
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (dialogBuilderCtx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 24,
              ),
              titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              actionsPadding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              title: Row(
                children: const [
                  Icon(
                    LucideIcons.triangleAlert,
                    color: Color(0xFFEA580C),
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Tambah Kendala',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: SizedBox(
                  width: MediaQuery.sizeOf(dialogCtx).width,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: descController,
                          maxLines: 2,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: Color(0xFF1E293B),
                          ),
                          decoration: InputDecoration(
                            labelText: 'Deskripsi Kendala',
                            labelStyle: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                            floatingLabelStyle: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFEA580C),
                            ),
                            hintText: 'Contoh: Badai katrina di perairan...',
                            hintStyle: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF94A3B8),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 2,
                            ),
                            leading: const Icon(
                              LucideIcons.calendar,
                              color: Color(0xFFEA580C),
                              size: 16,
                            ),
                            title: const Text(
                              'Waktu Kejadian',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF334155),
                              ),
                            ),
                            subtitle: Text(
                              _formatFullDateTime(selectedTime),
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: AppColors.sub,
                              ),
                            ),
                            trailing: const Icon(
                              LucideIcons.chevronRight,
                              size: 15,
                              color: Color(0xFF94A3B8),
                            ),
                            onTap: () async {
                              final pickedDate = await showDatePicker(
                                context: context,
                                initialDate: selectedTime,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2030),
                              );
                              if (pickedDate != null && context.mounted) {
                                final pickedTime = await showTimePicker(
                                  context: context,
                                  initialTime: TimeOfDay.fromDateTime(
                                    selectedTime,
                                  ),
                                );
                                if (pickedTime != null) {
                                  setDialogState(() {
                                    selectedTime = DateTime(
                                      pickedDate.year,
                                      pickedDate.month,
                                      pickedDate.day,
                                      pickedTime.hour,
                                      pickedTime.minute,
                                    );
                                  });
                                }
                              }
                            },
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: latController,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF1E293B),
                                ),
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                      signed: true,
                                    ),
                                decoration: InputDecoration(
                                  labelText: 'Latitude',
                                  labelStyle: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF64748B),
                                  ),
                                  floatingLabelStyle: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFFEA580C),
                                  ),
                                  hintText: '-6.20880',
                                  hintStyle: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF94A3B8),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: lngController,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF1E293B),
                                ),
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                      signed: true,
                                    ),
                                decoration: InputDecoration(
                                  labelText: 'Longitude',
                                  labelStyle: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF64748B),
                                  ),
                                  floatingLabelStyle: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFFEA580C),
                                  ),
                                  hintText: '106.84560',
                                  hintStyle: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF94A3B8),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Batal', style: TextStyle(fontSize: 12)),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFEA580C),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final desc = descController.text.trim();
                          if (desc.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Deskripsi kendala wajib diisi'),
                              ),
                            );
                            return;
                          }

                          final lat = double.tryParse(
                            latController.text.trim(),
                          );
                          final lng = double.tryParse(
                            lngController.text.trim(),
                          );

                          setDialogState(() {
                            isSubmitting = true;
                          });

                          try {
                            await ref
                                .read(
                                  tripDetailNotifierProvider(
                                    widget.item,
                                  ).notifier,
                                )
                                .addTripIssue(
                                  description: desc,
                                  occurredAt: selectedTime,
                                  scheduleId: schedule.id.isNotEmpty
                                      ? schedule.id
                                      : widget.item.id,
                                  lat: lat,
                                  lng: lng,
                                );

                            if (dialogCtx.mounted) {
                              Navigator.pop(dialogCtx);
                            }

                            if (context.mounted) {
                              _showTopRightSuccessToast(
                                context,
                                'Kendala perjalanan berhasil disimpan',
                              );
                            }
                          } catch (e) {
                            if (dialogCtx.mounted) {
                              setDialogState(() {
                                isSubmitting = false;
                              });
                            }
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Gagal menambahkan kendala: $e',
                                  ),
                                  backgroundColor: Colors.red.shade700,
                                ),
                              );
                            }
                          }
                        },
                  child: isSubmitting
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Simpan',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmDeleteTripIssue(BuildContext context, String id) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus Kendala?'),
        content: const Text(
          'Data kendala perjalanan ini akan dihapus secara permanen.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Batal', style: TextStyle(fontSize: 12)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              try {
                await ref
                    .read(tripDetailNotifierProvider(widget.item).notifier)
                    .deleteTripIssue(id);
                if (context.mounted) {
                  _showTopRightSuccessToast(
                    context,
                    'Kendala perjalanan berhasil dihapus',
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Gagal menghapus kendala: $e'),
                      backgroundColor: Colors.red.shade700,
                    ),
                  );
                }
              }
            },
            child: const Text('Hapus', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

class _DashedRoundedBorderPainter extends CustomPainter {
  _DashedRoundedBorderPainter({
    required this.color,
    this.strokeWidth = 1.2,
    this.dashWidth = 6.0,
    this.dashSpace = 4.0,
    this.radius = 16.0,
  });

  final Color color;
  final double strokeWidth;
  final double dashWidth;
  final double dashSpace;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            strokeWidth / 2,
            strokeWidth / 2,
            size.width - strokeWidth,
            size.height - strokeWidth,
          ),
          Radius.circular(radius),
        ),
      );

    final dashPath = Path();
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        dashPath.addPath(
          metric.extractPath(distance, distance + dashWidth),
          Offset.zero,
        );
        distance += dashWidth + dashSpace;
      }
    }
    canvas.drawPath(dashPath, paint);
  }

  @override
  bool shouldRepaint(covariant _DashedRoundedBorderPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.radius != radius;
  }
}

class _TopRightToast extends StatefulWidget {
  final String message;
  final VoidCallback onDismiss;

  const _TopRightToast({required this.message, required this.onDismiss});

  @override
  State<_TopRightToast> createState() => _TopRightToastState();
}

class _TopRightToastState extends State<_TopRightToast>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.25, -0.25),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _controller.forward();

    _dismissTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        _controller.reverse().then((_) {
          widget.onDismiss();
        });
      }
    });
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    return Positioned(
      top: topPadding + 16,
      right: 16,
      child: Material(
        color: Colors.transparent,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 340),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.green,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    LucideIcons.checkCircle2,
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      widget.message,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      _controller.reverse().then((_) {
                        widget.onDismiss();
                      });
                    },
                    child: const Icon(
                      LucideIcons.x,
                      color: Colors.white70,
                      size: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
