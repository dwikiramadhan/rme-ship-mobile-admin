import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/screen_header.dart';
import '../data/schedule_api.dart';
import '../data/schedule_repository.dart';
import '../domain/trip_schedule.dart';
import 'widgets/trip_schedule_card.dart';

class TripScheduleScreen extends ConsumerStatefulWidget {
  const TripScheduleScreen({super.key});

  @override
  ConsumerState<TripScheduleScreen> createState() => _TripScheduleScreenState();
}

class _TripScheduleScreenState extends ConsumerState<TripScheduleScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String val) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 400), () {
      ref.read(schedulesNotifierProvider.notifier).setSearch(val);
    });
    setState(() {});
  }

  void _onClearSearch() {
    _debounceTimer?.cancel();
    _searchController.clear();
    ref.read(schedulesNotifierProvider.notifier).setSearch('');
    setState(() {});
  }

  void _onFilterSelected(String status) {
    ref.read(schedulesNotifierProvider.notifier).setStatusFilter(status);
  }

  void _onResetAll() {
    _debounceTimer?.cancel();
    _searchController.clear();
    ref.read(schedulesNotifierProvider.notifier).resetFilters();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final schedulesAsync = ref.watch(schedulesNotifierProvider);
    final schedulesNotifier = ref.watch(schedulesNotifierProvider.notifier);
    final selectedFilter = schedulesNotifier.statusFilter;
    final allJadwal = schedulesAsync.valueOrNull ?? [];

    // Counter from dedicated API endpoint (stable, not affected by pagination/filter)
    final counterAsync = ref.watch(scheduleCounterProvider);
    final counter = counterAsync.valueOrNull ?? const ScheduleCounter();

    final ongoingCount = counter.ongoing;
    final scheduledCount = counter.scheduled;
    final completedCount = counter.completed;
    final cancelledCount = allJadwal.where((j) => j.isCancelled).length;

    final totalCountDisplay = counter.total;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Screen Header
        ScreenHeader(
          title: 'Jadwal Perjalanan',
          subtitle: counterAsync.isLoading && allJadwal.isEmpty
              ? 'Memuat data jadwal...'
              : '$ongoingCount Ongoing · $totalCountDisplay Total Jadwal',
        ),

        Expanded(
          child: RefreshIndicator(
            color: AppColors.orange,
            onRefresh: () async {
              ref.invalidate(scheduleCounterProvider);
              await ref.read(schedulesNotifierProvider.notifier).refresh();
            },
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification is ScrollUpdateNotification) {
                  final metrics = notification.metrics;
                  if (metrics.pixels >= metrics.maxScrollExtent - 200) {
                    ref.read(schedulesNotifierProvider.notifier).loadMore();
                  }
                }
                return false;
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  // Top Metric Cards (M3 Summary Row)
                  Row(
                    children: [
                      Expanded(
                        child: _M3StatPill(
                          icon: LucideIcons.navigation,
                          iconColor: AppColors.blue,
                          bg: AppColors.blueLt,
                          value: '$ongoingCount',
                          label: 'Ongoing',
                          isSelected: selectedFilter == 'Ongoing',
                          onTap: () {
                            _onFilterSelected(
                              selectedFilter == 'Ongoing' ? 'Semua' : 'Ongoing',
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _M3StatPill(
                          icon: LucideIcons.calendarCheck2,
                          iconColor: AppColors.yellow,
                          bg: AppColors.yellowLt,
                          value: '$scheduledCount',
                          label: 'Scheduled',
                          isSelected: selectedFilter == 'Scheduled',
                          onTap: () {
                            _onFilterSelected(
                              selectedFilter == 'Scheduled'
                                  ? 'Semua'
                                  : 'Scheduled',
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _M3StatPill(
                          icon: LucideIcons.checkCircle2,
                          iconColor: AppColors.green,
                          bg: AppColors.greenLt,
                          value: '$completedCount',
                          label: 'Completed',
                          isSelected: selectedFilter == 'Completed',
                          onTap: () {
                            _onFilterSelected(
                              selectedFilter == 'Completed'
                                  ? 'Semua'
                                  : 'Completed',
                            );
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Search Bar (M3 Outlined Search Input)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(40),
                      border: Border.all(color: AppColors.border),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Cari kapal, rute, pelabuhan, dokter...',
                        hintStyle: const TextStyle(
                          fontSize: 12,
                          color: AppColors.sub,
                          fontWeight: FontWeight.w400,
                          letterSpacing: 0,
                        ),
                        prefixIcon: const Icon(
                          LucideIcons.search,
                          size: 18,
                          color: AppColors.sub,
                        ),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(
                                  LucideIcons.x,
                                  size: 16,
                                  color: AppColors.sub,
                                ),
                                onPressed: _onClearSearch,
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(40),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(40),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(40),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 16,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Material 3 Filter Chips Row
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _M3FilterChip(
                          label: 'Semua',
                          isSelected: selectedFilter == 'Semua',
                          onTap: () => _onFilterSelected('Semua'),
                        ),
                        const SizedBox(width: 8),
                        _M3FilterChip(
                          label: 'Ongoing',
                          isSelected: selectedFilter == 'Ongoing',
                          color: AppColors.blue,
                          onTap: () => _onFilterSelected('Ongoing'),
                        ),
                        const SizedBox(width: 8),
                        _M3FilterChip(
                          label: 'Scheduled',
                          isSelected: selectedFilter == 'Scheduled',
                          color: AppColors.yellow,
                          onTap: () => _onFilterSelected('Scheduled'),
                        ),
                        const SizedBox(width: 8),
                        _M3FilterChip(
                          label: 'Completed',
                          isSelected: selectedFilter == 'Completed',
                          color: AppColors.green,
                          onTap: () => _onFilterSelected('Completed'),
                        ),
                        if (cancelledCount > 0 ||
                            selectedFilter == 'Cancelled') ...[
                          const SizedBox(width: 8),
                          _M3FilterChip(
                            label: 'Cancelled',
                            isSelected: selectedFilter == 'Cancelled',
                            color: AppColors.red,
                            onTap: () => _onFilterSelected('Cancelled'),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Schedules Content
                  if (schedulesAsync.isLoading && allJadwal.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 48),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: AppColors.orange,
                        ),
                      ),
                    )
                  else if (schedulesAsync.hasError && allJadwal.isEmpty)
                    _buildErrorState(schedulesAsync.error)
                  else if (allJadwal.isEmpty)
                    _buildEmptyState()
                  else
                    ...allJadwal.map((item) => TripScheduleCard(item: item)),

                  if (schedulesNotifier.isLoadingMore) ...[
                    const SizedBox(height: 16),
                    const Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: AppColors.orange,
                        ),
                      ),
                    ),
                  ] else if (schedulesNotifier.hasMore) ...[
                    const SizedBox(height: 16),
                    Center(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.border),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                        ),
                        onPressed: () => ref
                            .read(schedulesNotifierProvider.notifier)
                            .loadMore(),
                        icon: const Icon(
                          LucideIcons.arrowDownCircle,
                          size: 15,
                          color: AppColors.orange,
                        ),
                        label: const Text(
                          'Muat Lebih Banyak',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.orange,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState(Object? err) {
    return Container(
      padding: const EdgeInsets.all(32),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 32),
          Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.redLt,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.red.withValues(alpha: 0.3)),
            ),
            child: const Icon(
              LucideIcons.alertCircle,
              size: 32,
              color: AppColors.red,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Gagal Memuat Jadwal Perjalanan',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            (err ?? '').toString().replaceAll('Exception:', '').trim(),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, color: AppColors.sub),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.orange,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () =>
                ref.read(schedulesNotifierProvider.notifier).refresh(),
            icon: const Icon(LucideIcons.rotateCcw, size: 16),
            label: const Text('Coba Lagi'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.card2,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border),
            ),
            child: const Icon(
              LucideIcons.searchX,
              size: 28,
              color: AppColors.sub,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Tidak ada jadwal yang sesuai',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Coba ubah kata kunci pencarian atau sesuaikan filter status pelayaran di atas.',
            style: TextStyle(fontSize: 12.5, color: AppColors.sub, height: 1.4),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: _onResetAll,
            icon: const Icon(
              LucideIcons.rotateCcw,
              size: 14,
              color: AppColors.text,
            ),
            label: const Text(
              'Reset Filter',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppColors.text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _M3StatPill extends StatelessWidget {
  const _M3StatPill({
    required this.icon,
    required this.iconColor,
    required this.bg,
    required this.value,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final Color bg;
  final String value;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? bg : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? iconColor : AppColors.border,
              width: isSelected ? 1.5 : 1.0,
            ),
            boxShadow: [
              if (isSelected)
                BoxShadow(
                  color: iconColor.withValues(alpha: 0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                )
              else
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, size: 14, color: iconColor),
                  ),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: isSelected ? iconColor : AppColors.text,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? iconColor : AppColors.sub,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _M3FilterChip extends StatelessWidget {
  const _M3FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.color,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final activeColor = color ?? AppColors.orange;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: isSelected ? activeColor : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? activeColor : AppColors.border,
              width: 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
              color: isSelected ? Colors.white : AppColors.text,
            ),
          ),
        ),
      ),
    );
  }
}
