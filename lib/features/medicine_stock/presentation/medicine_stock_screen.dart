import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/clean_text_helper.dart';
import '../../../core/utils/date_helper.dart';
import '../../../core/widgets/app_badge.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/screen_header.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/ship_medicine_history.dart';
import '../domain/ship_medicine_stock.dart';
import 'medicine_stock_controller.dart';

/// Stok & Inventaris Obat Kapal
/// Memiliki 2 TAB:
/// 1. Inventaris Obat (/api/v1/ship-medicines/stocks/:ship_code)
/// 2. Riwayat Transaksi Obat (/api/v1/ship-medicines/history)
/// Keduanya mendukung server-side search dan server-side scroll pagination.
class MedicineStockScreen extends ConsumerStatefulWidget {
  const MedicineStockScreen({
    super.key,
    required this.canManage,
    this.shipCode,
  });

  final bool canManage;
  final String? shipCode;

  @override
  ConsumerState<MedicineStockScreen> createState() =>
      _MedicineStockScreenState();
}

class _MedicineStockScreenState extends ConsumerState<MedicineStockScreen> {
  int _selectedTabIndex = 0;
  final _stockScrollController = ScrollController();
  final _historyScrollController = ScrollController();

  final _stockSearchController = TextEditingController();
  final _historySearchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _stockScrollController.addListener(_onStockScroll);
    _historyScrollController.addListener(_onHistoryScroll);
  }

  @override
  void dispose() {
    _stockScrollController.removeListener(_onStockScroll);
    _stockScrollController.dispose();
    _historyScrollController.removeListener(_onHistoryScroll);
    _historyScrollController.dispose();
    _stockSearchController.dispose();
    _historySearchController.dispose();
    super.dispose();
  }

  String _resolveShipCode({bool isWatching = true}) {
    if (widget.shipCode != null && widget.shipCode!.trim().isNotEmpty) {
      return widget.shipCode!.trim();
    }
    final storageShipCode = isWatching
        ? ref.watch(localStorageShipCodeProvider).valueOrNull
        : ref.read(localStorageShipCodeProvider).valueOrNull;
    if (storageShipCode != null && storageShipCode.trim().isNotEmpty) {
      return storageShipCode.trim();
    }
    final sessionUser = isWatching
        ? ref.watch(authControllerProvider).session?.user
        : ref.read(authControllerProvider).session?.user;
    if (sessionUser?.shipCode != null &&
        sessionUser!.shipCode!.trim().isNotEmpty) {
      return sessionUser.shipCode!.trim();
    }
    return sessionUser?.shipId?.trim() ?? '';
  }

  void _onStockScroll() {
    if (!_stockScrollController.hasClients) return;
    final pos = _stockScrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 250) {
      final code = _resolveShipCode(isWatching: false);
      if (code.isNotEmpty) {
        ref.read(shipMedicineStockProvider(code).notifier).loadMore();
      }
    }
  }

  void _checkAndLoadMoreIfUnderfilled() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_selectedTabIndex != 0) return;
      final code = _resolveShipCode(isWatching: false);
      if (code.isEmpty) return;
      final stockState = ref.read(shipMedicineStockProvider(code));
      if (!stockState.hasMore ||
          stockState.isLoading ||
          stockState.isLoadingMore) {
        return;
      }
      if (_stockScrollController.hasClients) {
        final position = _stockScrollController.position;
        if (position.maxScrollExtent <= 80) {
          ref.read(shipMedicineStockProvider(code).notifier).loadMore();
        }
      }
    });
  }

  void _onHistoryScroll() {
    if (_historyScrollController.position.pixels >=
        _historyScrollController.position.maxScrollExtent - 200) {
      final code = _resolveShipCode(isWatching: false);
      ref.read(shipMedicineHistoryProvider(code).notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveShipCode = _resolveShipCode();
    final stockState = ref.watch(shipMedicineStockProvider(effectiveShipCode));
    final historyState = ref.watch(
      shipMedicineHistoryProvider(effectiveShipCode),
    );

    ref.listen<ShipMedicineStockState>(
      shipMedicineStockProvider(effectiveShipCode),
      (previous, next) {
        if (next.items.length != previous?.items.length && next.hasMore) {
          _checkAndLoadMoreIfUnderfilled();
        }
      },
    );

    if (stockState.items.isNotEmpty &&
        stockState.hasMore &&
        !stockState.isLoading &&
        !stockState.isLoadingMore) {
      _checkAndLoadMoreIfUnderfilled();
    }

    final isStockTab = _selectedTabIndex == 0;
    final subtitle = isStockTab
        ? (stockState.isLoading
              ? 'Memuat data inventaris...'
              : '${stockState.total} jenis obat')
        : (historyState.isLoading
              ? 'Memuat riwayat transaksi...'
              : '${historyState.total} transaksi tercatat');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ScreenHeader(title: 'Stok & Transaksi Obat', subtitle: subtitle),
        _buildTabBar(),
        Expanded(
          child: IndexedStack(
            index: _selectedTabIndex,
            children: [
              _buildInventarisTab(effectiveShipCode, stockState),
              _buildHistoryTab(effectiveShipCode, historyState),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTabBar() {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final outerBg = isDark ? const Color(0xFF0B132B) : const Color(0xFFF1F5F9);
    final outerBorder = isDark ? const Color(0xFF1E293B) : AppColors.border;

    final activePillBg = isDark ? const Color(0xFF16253B) : Colors.white;
    final activePillBorder = isDark
        ? const Color(0xFF243B5A)
        : AppColors.border;

    return Container(
      color: scheme.surface,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: outerBg,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: outerBorder, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildTabItem(
              index: 0,
              icon: LucideIcons.package2,
              label: 'Inventaris Obat',
              activeBg: activePillBg,
              activeBorder: activePillBorder,
            ),
            const SizedBox(width: 4),
            _buildTabItem(
              index: 1,
              icon: LucideIcons.history,
              label: 'Riwayat Tambah Obat',
              activeBg: activePillBg,
              activeBorder: activePillBorder,
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
    required Color activeBg,
    required Color activeBorder,
  }) {
    final isSelected = _selectedTabIndex == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final fgColor = isSelected
        ? AppColors.orange
        : (isDark ? const Color(0xFF94A3B8) : AppColors.sub);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (_selectedTabIndex != index) {
          setState(() => _selectedTabIndex = index);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? activeBg : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? activeBorder : Colors.transparent,
            width: 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: fgColor),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: fgColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // TAB 1: INVENTARIS OBAT
  // ==========================================

  Widget _buildInventarisTab(String shipCode, ShipMedicineStockState state) {
    if (shipCode.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.orangeLt,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  LucideIcons.ship,
                  color: AppColors.orange,
                  size: 28,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Kode Kapal Tidak Ditemukan',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              const Text(
                'Akun Anda belum terasosiasi dengan kode kapal tertentu.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: AppColors.sub),
              ),
            ],
          ),
        ),
      );
    }

    final notifier = ref.read(shipMedicineStockProvider(shipCode).notifier);

    return Column(
      children: [
        _buildSearchBar(
          controller: _stockSearchController,
          hintText: 'Cari nama obat atau SKU...',
          onChanged: notifier.onSearchChanged,
          onClear: () {
            _stockSearchController.clear();
            notifier.onSearchChanged('');
          },
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => notifier.loadInitial(refresh: true),
            color: AppColors.blue,
            child: _buildStockContent(state, notifier),
          ),
        ),
      ],
    );
  }

  Widget _buildStockContent(
    ShipMedicineStockState state,
    ShipMedicineStockNotifier notifier,
  ) {
    if (state.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.blue),
      );
    }

    if (state.errorMessage != null && state.items.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 40),
          Center(
            child: Column(
              children: [
                const Icon(
                  LucideIcons.alertCircle,
                  size: 40,
                  color: AppColors.red,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Gagal memuat inventaris obat',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  state.errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.sub, fontSize: 12),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => notifier.loadInitial(),
                  icon: const Icon(LucideIcons.refreshCw, size: 14),
                  label: const Text('Coba Lagi'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    if (state.items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 60),
          EmptyState(
            icon: LucideIcons.packageOpen,
            title: 'Belum Ada Data Inventaris',
            subtitle: 'Data obat kapal tidak ditemukan atau belum ditambahkan.',
          ),
        ],
      );
    }

    final rowCount = (state.items.length / 3).ceil();

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.pixels >=
            notification.metrics.maxScrollExtent - 250) {
          final code = _resolveShipCode(isWatching: false);
          if (code.isNotEmpty) {
            ref.read(shipMedicineStockProvider(code).notifier).loadMore();
          }
        }
        return false;
      },
      child: CustomScrollView(
        controller: _stockScrollController,
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 16),
            sliver: SliverList.separated(
              itemCount: rowCount,
              separatorBuilder: (_, _) => const SizedBox(height: 6),
              itemBuilder: (context, rowIndex) {
                final i1 = rowIndex * 3;
                final i2 = i1 + 1;
                final i3 = i1 + 2;

                final item1 = state.items[i1];
                final item2 = i2 < state.items.length ? state.items[i2] : null;
                final item3 = i3 < state.items.length ? state.items[i3] : null;

                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: _StockItemCard(item: item1)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: item2 != null
                            ? _StockItemCard(item: item2)
                            : const SizedBox.shrink(),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: item3 != null
                            ? _StockItemCard(item: item3)
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              child: Center(
                child: state.isLoadingMore
                    ? const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.blue,
                            ),
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Memuat data obat...',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.sub,
                            ),
                          ),
                        ],
                      )
                    : state.hasMore
                    ? OutlinedButton.icon(
                        onPressed: () {
                          final code = _resolveShipCode(isWatching: false);
                          if (code.isNotEmpty) {
                            ref
                                .read(shipMedicineStockProvider(code).notifier)
                                .loadMore();
                          }
                        },
                        icon: const Icon(LucideIcons.chevronDown, size: 14),
                        label: Text(
                          'Muat Lebih Banyak (${state.items.length} dari ${state.total})',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.blue,
                          side: BorderSide(
                            color: AppColors.blue.withValues(alpha: 0.3),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      )
                    : (state.items.isNotEmpty
                          ? Text(
                              'Semua ${state.total} jenis obat telah dimuat',
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: AppColors.sub,
                              ),
                            )
                          : const SizedBox.shrink()),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 2: RIWAYAT TRANSAKSI OBAT
  // ==========================================

  Widget _buildHistoryTab(String shipCode, ShipMedicineHistoryState state) {
    final notifier = ref.read(shipMedicineHistoryProvider(shipCode).notifier);

    return Column(
      children: [
        _buildSearchBar(
          controller: _historySearchController,
          hintText: 'Cari riwayat SKU atau catatan...',
          onChanged: notifier.onSearchChanged,
          onClear: () {
            _historySearchController.clear();
            notifier.onSearchChanged('');
          },
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => notifier.loadInitial(refresh: true),
            color: AppColors.blue,
            child: _buildHistoryContent(state, notifier),
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryContent(
    ShipMedicineHistoryState state,
    ShipMedicineHistoryNotifier notifier,
  ) {
    if (state.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.blue),
      );
    }

    if (state.errorMessage != null && state.items.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 40),
          Center(
            child: Column(
              children: [
                const Icon(
                  LucideIcons.alertCircle,
                  size: 40,
                  color: AppColors.red,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Gagal memuat riwayat transaksi',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  state.errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.sub, fontSize: 12),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => notifier.loadInitial(),
                  icon: const Icon(LucideIcons.refreshCw, size: 14),
                  label: const Text('Coba Lagi'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    if (state.items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 60),
          EmptyState(
            icon: LucideIcons.clipboardList,
            title: 'Belum Ada Riwayat Transaksi',
            subtitle: 'Riwayat transaksi obat kapal akan tercatat di sini.',
          ),
        ],
      );
    }

    final itemCount = state.items.length + (state.isLoadingMore ? 1 : 0);

    return ListView.separated(
      controller: _historyScrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
      itemCount: itemCount,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        if (index >= state.items.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: AppColors.blue,
                ),
              ),
            ),
          );
        }

        final item = state.items[index];
        return _HistoryItemCard(item: item);
      },
    );
  }

  // ==========================================
  // SHARED SEARCH BAR
  // ==========================================

  Widget _buildSearchBar({
    required TextEditingController controller,
    required String hintText,
    required ValueChanged<String> onChanged,
    required VoidCallback onClear,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
      color: scheme.surface,
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, value, _) {
          return TextField(
            controller: controller,
            onChanged: onChanged,
            style: TextStyle(
              fontSize: 12.5,
              color: scheme.onSurface,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              isDense: true,
              hintText: hintText,
              hintStyle: const TextStyle(fontSize: 12, color: AppColors.sub),
              prefixIcon: const Icon(
                LucideIcons.search,
                size: 15,
                color: AppColors.sub,
              ),
              prefixIconConstraints: const BoxConstraints(
                minWidth: 38,
                minHeight: 36,
              ),
              suffixIcon: value.text.isNotEmpty
                  ? IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 34,
                        minHeight: 32,
                      ),
                      icon: const Icon(
                        LucideIcons.x,
                        size: 14,
                        color: AppColors.sub,
                      ),
                      onPressed: onClear,
                    )
                  : null,
              filled: true,
              fillColor: AppColors.inputBg,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 8,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.blue, width: 1.2),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ==========================================
// ITEM CARD: INVENTARIS OBAT
// ==========================================

class _StockItemCard extends StatelessWidget {
  const _StockItemCard({required this.item});

  final ShipMedicineStock item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final Color statusColor;
    final Color statusBg;
    final String statusLabel;

    if (item.isOutOfStock) {
      statusColor = AppColors.red;
      statusBg = AppColors.redLt;
      statusLabel = 'Habis';
    } else if (item.isLowStock) {
      statusColor = AppColors.orange;
      statusBg = AppColors.orangeLt;
      statusLabel = 'Menipis';
    } else {
      statusColor = AppColors.green;
      statusBg = AppColors.greenLt;
      statusLabel = 'Tersedia';
    }

    final unitLabel = item.unitOfMeasurement.isNotEmpty
        ? item.unitOfMeasurement
        : 'unit';
    final formattedUpdated = formatDateTime(item.lastUpdate, fallback: '-');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: scheme.onSurface.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // KIRI: Nama, Code & Type dalam satu row
          Expanded(
            flex: 11,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  CleanTextHelper.cleanName(
                    item.medicineName.isNotEmpty
                        ? item.medicineName
                        : item.medicineSku,
                    fallback: 'Obat',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    if (item.medicineSku.isNotEmpty) ...[
                      Flexible(
                        child: Text(
                          CleanTextHelper.cleanCode(item.medicineSku),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF7E8B9B),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                    ],
                    if (item.category.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1.5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF4F8),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          item.category,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),

          // KANAN: Status & Jumlah dalam satu row, di bawahnya Tanggal Diperbaharui
          Expanded(
            flex: 9,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (item.stock > 0) ...[
                      Flexible(
                        child: Text(
                          '${item.stock} $unitLabel',
                          textAlign: TextAlign.end,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: statusColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                    ],
                    AppBadge(
                      label: statusLabel,
                      color: statusColor,
                      background: statusBg,
                      fontSize: 10,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1.5,
                      ),
                    ),
                  ],
                ),
                if (!item.isOutOfStock &&
                    formattedUpdated.isNotEmpty &&
                    formattedUpdated != '-') ...[
                  const SizedBox(height: 3),
                  Text(
                    formattedUpdated,
                    textAlign: TextAlign.end,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 9.5,
                      color: AppColors.sub,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// ITEM CARD: RIWAYAT TRANSAKSI OBAT
// ==========================================

class _HistoryItemCard extends StatelessWidget {
  const _HistoryItemCard({required this.item});

  final ShipMedicineHistory item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final formattedTime = formatDateTime(item.createdAt, fallback: '-');
    final unit = item.unitOfMeasurement.isNotEmpty
        ? ' ${item.unitOfMeasurement}'
        : '';

    final isPositive = item.quantity >= 0;
    final qtyText = '${isPositive ? "+" : ""}${item.quantity}$unit';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: scheme.onSurface.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Waktu input & Jumlah
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(LucideIcons.clock, size: 13, color: AppColors.sub),
                  const SizedBox(width: 5),
                  Text(
                    formattedTime,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.sub,
                    ),
                  ),
                ],
              ),
              AppBadge(
                label: qtyText,
                color: isPositive ? AppColors.green : AppColors.red,
                background: isPositive ? AppColors.greenLt : AppColors.redLt,
                fontSize: 10.5,
                padding: const EdgeInsets.symmetric(
                  horizontal: 7.5,
                  vertical: 2.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Nama Obat, Code, Type
          Text(
            CleanTextHelper.cleanName(item.medicineName, fallback: 'Obat'),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 3.5),
          Row(
            children: [
              if (item.medicineSku.isNotEmpty) ...[
                Text(
                  CleanTextHelper.cleanCode(item.medicineSku),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF7E8B9B),
                  ),
                ),
                const SizedBox(width: 7),
              ],
              if (item.medicineCategory.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 1.5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF4F8),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    item.medicineCategory,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF475569),
                    ),
                  ),
                ),
              ],
            ],
          ),

          // Catatan
          if (item.notes.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.inputBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    LucideIcons.fileText,
                    size: 13,
                    color: AppColors.sub,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      item.notes,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: scheme.onSurfaceVariant,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 10),
          const Divider(height: 1, thickness: 0.8),
          const SizedBox(height: 8),

          // Diinput oleh
          Row(
            children: [
              const Icon(
                LucideIcons.userCheck,
                size: 13,
                color: AppColors.blue,
              ),
              const SizedBox(width: 5),
              const Text(
                'Diinput oleh: ',
                style: TextStyle(fontSize: 11.5, color: AppColors.sub),
              ),
              Expanded(
                child: Text(
                  CleanTextHelper.cleanName(item.userName, fallback: '-'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

typedef StokObatScreen = MedicineStockScreen;
