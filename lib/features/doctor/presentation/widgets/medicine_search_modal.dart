import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_shimmer.dart';
import '../../../../core/widgets/circle_icon_button.dart';
import '../../data/medicines_api.dart';
import '../../domain/medicine_item.dart';

/// Material UI Searchable Modal for Medicine selection with Infinite Scroll (Load Scroll)
class MedicineSearchModal extends ConsumerStatefulWidget {
  const MedicineSearchModal({
    super.key,
    required this.selectedName,
    required this.onSelect,
  });

  final String? selectedName;
  final ValueChanged<String> onSelect;

  @override
  ConsumerState<MedicineSearchModal> createState() =>
      _MedicineSearchModalState();
}

class _MedicineSearchModalState extends ConsumerState<MedicineSearchModal> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _debounce;

  List<MedicineItem> _medicines = [];
  int _currentPage = 1;
  int _totalPages = 1;
  int _total = 0;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String _currentQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchPage(1, reset: true);
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 150) {
      _loadMore();
    }
  }

  Future<void> _fetchPage(int page,
      {String query = '', bool reset = false}) async {
    if (reset) {
      setState(() {
        _isLoading = true;
        _currentPage = 1;
        _hasMore = true;
        _currentQuery = query;
      });
    } else {
      if (_isLoadingMore || !_hasMore) return;
      setState(() => _isLoadingMore = true);
    }

    try {
      final api = ref.read(medicinesApiProvider);
      final res = await api.fetchMedicines(
        query: query,
        page: page,
        limit: 10,
      );

      if (!mounted) return;
      setState(() {
        if (reset) {
          _medicines = res.data;
        } else {
          final existingIds = _medicines.map((m) => m.id).toSet();
          final newItems =
              res.data.where((m) => !existingIds.contains(m.id)).toList();
          _medicines = [..._medicines, ...newItems];
        }
        _currentPage = res.page;
        _totalPages = res.totalPages;
        _total = res.total;
        _hasMore = _currentPage < _totalPages;
        _isLoading = false;
        _isLoadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  void _loadMore() {
    if (_isLoading || _isLoadingMore || !_hasMore) return;
    _fetchPage(_currentPage + 1, query: _currentQuery);
  }

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _fetchPage(1, query: v.trim(), reset: true);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Text(
                      'Pilih Nama Obat',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                    if (_total > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.blueLt,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '$_total Item',
                          style: const TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.blue,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                CircleIconButton(
                  icon: LucideIcons.x,
                  size: 32,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),

          // Search Input Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            child: Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: AppColors.inputBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Icon(
                    LucideIcons.search,
                    size: 14,
                    color: AppColors.sub,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.text,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Cari nama obat atau SKU...',
                        hintStyle: TextStyle(
                          fontSize: 11.5,
                          color: AppColors.sub,
                        ),
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                      ),
                    ),
                  ),
                  if (query.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        _searchController.clear();
                        _fetchPage(1, query: '', reset: true);
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: AppColors.sub.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          LucideIcons.x,
                          size: 12,
                          color: AppColors.sub,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Medicine List / Loading / Empty
          Expanded(
            child: _isLoading
                ? _buildLoadingShimmer()
                : _medicines.isEmpty
                    ? _buildEmptyState(query)
                    : ListView.separated(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        itemCount: _medicines.length + (_hasMore ? 1 : 0),
                        separatorBuilder: (_, _) => const SizedBox(height: 6),
                        itemBuilder: (context, i) {
                          if (i >= _medicines.length) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 14),
                              child: Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.blue,
                                  ),
                                ),
                              ),
                            );
                          }

                          final med = _medicines[i];
                          final isSelected = med.name == widget.selectedName;

                          return InkWell(
                            onTap: () => widget.onSelect(med.name),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 11,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.blueLt
                                    : AppColors.card2,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.blue.withValues(alpha: 0.5)
                                      : AppColors.border,
                                ),
                              ),
                              child: Row(
                                children: [
                                  if (med.sku.isNotEmpty) ...[
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 5,
                                        vertical: 1.5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? AppColors.card
                                            : AppColors.inputBg,
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color: isSelected
                                              ? AppColors.blue
                                                  .withValues(alpha: 0.3)
                                              : AppColors.border,
                                        ),
                                      ),
                                      child: Text(
                                        med.sku,
                                        style: TextStyle(
                                          fontSize: 9.0,
                                          fontWeight: FontWeight.w700,
                                          color: isSelected
                                              ? AppColors.blue
                                              : AppColors.sub,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                  ],
                                  Expanded(
                                    child: Text(
                                      med.name,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: isSelected
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                        color: isSelected
                                            ? AppColors.blue
                                            : AppColors.text,
                                      ),
                                    ),
                                  ),
                                  if (med.unitOfMeasurement.isNotEmpty ||
                                      med.category.isNotEmpty) ...[
                                    const SizedBox(width: 6),
                                    Text(
                                      med.unitOfMeasurement.isNotEmpty &&
                                              med.category.isNotEmpty
                                          ? '${med.category} • ${med.unitOfMeasurement}'
                                          : (med.category.isNotEmpty
                                              ? med.category
                                              : med.unitOfMeasurement),
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        color: isSelected
                                            ? AppColors.blue.withValues(alpha: 0.7)
                                            : AppColors.sub,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                  if (isSelected) ...[
                                    const SizedBox(width: 8),
                                    const Icon(
                                      LucideIcons.check,
                                      size: 16,
                                      color: AppColors.blue,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildLoadingShimmer() {
    return AppShimmer(
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        itemCount: 8,
        separatorBuilder: (_, _) => const SizedBox(height: 6),
        itemBuilder: (_, _) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: AppColors.card2,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: const [
              SkeletonBox(width: 46, height: 16, borderRadius: 4),
              SizedBox(width: 8),
              Expanded(
                child: SkeletonBox(height: 14, borderRadius: 4),
              ),
              SizedBox(width: 10),
              SkeletonBox(width: 60, height: 12, borderRadius: 3),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String query) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.pill, size: 36, color: AppColors.sub),
            const SizedBox(height: 10),
            const Text(
              'Obat tidak ditemukan',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              query.isNotEmpty
                  ? 'Tidak ada obat dengan kata kunci "$query"'
                  : 'Daftar obat kosong di master farmasi',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: AppColors.sub),
            ),
          ],
        ),
      ),
    );
  }
}
