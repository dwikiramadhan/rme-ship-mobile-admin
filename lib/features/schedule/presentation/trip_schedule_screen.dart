import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/screen_header.dart';
import '../data/schedule_repository.dart';
import '../domain/trip_schedule.dart';
import 'widgets/trip_schedule_card.dart';

class TripScheduleScreen extends ConsumerStatefulWidget {
  const TripScheduleScreen({super.key});

  @override
  ConsumerState<TripScheduleScreen> createState() => _TripScheduleScreenState();
}

class _TripScheduleScreenState extends ConsumerState<TripScheduleScreen> {
  String _selectedFilter = 'Semua';
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final schedulesAsync = ref.watch(schedulesNotifierProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Screen Header
        schedulesAsync.when(
          data: (allJadwal) {
            final ongoingCount =
                allJadwal.where((j) => j.isOngoing).length;
            return ScreenHeader(
              title: 'Jadwal Perjalanan',
              subtitle:
                  '$ongoingCount Ongoing · ${allJadwal.length} Total Jadwal',
            );
          },
          loading: () => const ScreenHeader(
            title: 'Jadwal Perjalanan',
            subtitle: 'Memuat data jadwal...',
          ),
          error: (_, _) => const ScreenHeader(
            title: 'Jadwal Perjalanan',
            subtitle: 'Gagal memuat jadwal',
          ),
        ),

        Expanded(
          child: schedulesAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.orange),
            ),
            error: (err, _) => RefreshIndicator(
              color: AppColors.orange,
              onRefresh: () async {
                await ref.read(schedulesNotifierProvider.notifier).refresh();
              },
              child: ListView(
                padding: const EdgeInsets.all(32),
                children: [
                  const SizedBox(height: 48),
                  Container(
                    width: 64,
                    height: 64,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.redLt,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.red.withValues(alpha: 0.3),
                      ),
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
                    err.toString().replaceAll('Exception:', '').trim(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.sub,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.orange,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => ref
                          .read(schedulesNotifierProvider.notifier)
                          .refresh(),
                      icon: const Icon(LucideIcons.rotateCcw, size: 16),
                      label: const Text('Coba Lagi'),
                    ),
                  ),
                ],
              ),
            ),
            data: (allJadwal) {
              final ongoingCount =
                  allJadwal.where((j) => j.isOngoing).length;
              final scheduledCount =
                  allJadwal.where((j) => j.isScheduled).length;
              final completedCount =
                  allJadwal.where((j) => j.isCompleted).length;
              final cancelledCount =
                  allJadwal.where((j) => j.isCancelled).length;

              final filtered = allJadwal.where((item) {
                final matchesFilter = switch (_selectedFilter) {
                  'Ongoing' => item.isOngoing,
                  'Scheduled' => item.isScheduled,
                  'Completed' => item.isCompleted,
                  'Cancelled' => item.isCancelled,
                  _ => true,
                };

                if (!matchesFilter) return false;
                if (_searchQuery.trim().isEmpty) return true;

                final query = _searchQuery.toLowerCase().trim();
                return item.namaKapal.toLowerCase().contains(query) ||
                    item.shipCode.toLowerCase().contains(query) ||
                    item.shipType.toLowerCase().contains(query) ||
                    item.pelabuhanAsal.toLowerCase().contains(query) ||
                    item.pelabuhanTujuan.toLowerCase().contains(query) ||
                    item.kodeAsal.toLowerCase().contains(query) ||
                    item.kodeTujuan.toLowerCase().contains(query) ||
                    item.namaDokter.toLowerCase().contains(query);
              }).toList();

              return RefreshIndicator(
                color: AppColors.orange,
                onRefresh: () async {
                  await ref.read(schedulesNotifierProvider.notifier).refresh();
                },
                child: ListView(
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
                            isSelected: _selectedFilter == 'Ongoing',
                            onTap: () {
                              setState(() {
                                _selectedFilter =
                                    _selectedFilter == 'Ongoing'
                                        ? 'Semua'
                                        : 'Ongoing';
                              });
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
                            isSelected: _selectedFilter == 'Scheduled',
                            onTap: () {
                              setState(() {
                                _selectedFilter =
                                    _selectedFilter == 'Scheduled'
                                        ? 'Semua'
                                        : 'Scheduled';
                              });
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
                            isSelected: _selectedFilter == 'Completed',
                            onTap: () {
                              setState(() {
                                _selectedFilter =
                                    _selectedFilter == 'Completed'
                                        ? 'Semua'
                                        : 'Completed';
                              });
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
                        borderRadius: BorderRadius.circular(16),
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
                        onChanged: (val) => setState(() => _searchQuery = val),
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.text,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Cari kapal, rute, pelabuhan, dokter...',
                          hintStyle: const TextStyle(
                            fontSize: 13,
                            color: AppColors.sub,
                            fontWeight: FontWeight.w400,
                          ),
                          prefixIcon: const Icon(
                            LucideIcons.search,
                            size: 18,
                            color: AppColors.sub,
                          ),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(
                                    LucideIcons.x,
                                    size: 16,
                                    color: AppColors.sub,
                                  ),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                )
                              : null,
                          border: InputBorder.none,
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
                            count: allJadwal.length,
                            isSelected: _selectedFilter == 'Semua',
                            onTap: () =>
                                setState(() => _selectedFilter = 'Semua'),
                          ),
                          const SizedBox(width: 8),
                          _M3FilterChip(
                            label: 'Ongoing',
                            count: ongoingCount,
                            isSelected: _selectedFilter == 'Ongoing',
                            color: AppColors.blue,
                            onTap: () =>
                                setState(() => _selectedFilter = 'Ongoing'),
                          ),
                          const SizedBox(width: 8),
                          _M3FilterChip(
                            label: 'Scheduled',
                            count: scheduledCount,
                            isSelected: _selectedFilter == 'Scheduled',
                            color: AppColors.yellow,
                            onTap: () =>
                                setState(() => _selectedFilter = 'Scheduled'),
                          ),
                          const SizedBox(width: 8),
                          _M3FilterChip(
                            label: 'Completed',
                            count: completedCount,
                            isSelected: _selectedFilter == 'Completed',
                            color: AppColors.green,
                            onTap: () =>
                                setState(() => _selectedFilter = 'Completed'),
                          ),
                          if (cancelledCount > 0) ...[
                            const SizedBox(width: 8),
                            _M3FilterChip(
                              label: 'Cancelled',
                              count: cancelledCount,
                              isSelected: _selectedFilter == 'Cancelled',
                              color: AppColors.red,
                              onTap: () =>
                                  setState(() => _selectedFilter = 'Cancelled'),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Schedules List
                    if (filtered.isEmpty)
                      _buildEmptyState()
                    else
                      ...filtered.map((item) => TripScheduleCard(item: item)),
                  ],
                ),
              );
            },
          ),
        ),
      ],
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
            style: TextStyle(
              fontSize: 12.5,
              color: AppColors.sub,
              height: 1.4,
            ),
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
            onPressed: () {
              setState(() {
                _selectedFilter = 'Semua';
                _searchController.clear();
                _searchQuery = '';
              });
            },
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
    required this.count,
    required this.isSelected,
    required this.onTap,
    this.color,
  });

  final String label;
  final int count;
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
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  color: isSelected ? Colors.white : AppColors.text,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.25)
                      : AppColors.card2,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: isSelected ? Colors.white : AppColors.sub,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
