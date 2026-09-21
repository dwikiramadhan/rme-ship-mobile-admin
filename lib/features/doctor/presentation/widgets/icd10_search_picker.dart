import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/icd10_api.dart';
import '../../domain/icd10_item.dart';

/// Multiple ICD-10 diagnosis picker with search, badge chips, and multi-select support.
class Icd10MultiSearchPicker extends ConsumerStatefulWidget {
  const Icd10MultiSearchPicker({
    super.key,
    required this.label,
    required this.selectedItems,
    required this.onChanged,
    this.required = false,
    this.hint = 'Pilih atau cari diagnosa ICD-10...',
  });

  final String label;
  final List<Icd10Item> selectedItems;
  final ValueChanged<List<Icd10Item>> onChanged;
  final bool required;
  final String hint;

  @override
  ConsumerState<Icd10MultiSearchPicker> createState() =>
      _Icd10MultiSearchPickerState();
}

class _Icd10MultiSearchPickerState
    extends ConsumerState<Icd10MultiSearchPicker> {
  @override
  void initState() {
    super.initState();
    // Warm up ICD-10 initial data so opening the picker is instantaneous (0ms delay)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(icd10ApiProvider).prefetchInitial(limit: 25);
      }
    });
  }

  void _openSearchSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: false,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _Icd10MultiSearchBottomSheet(
        initialSelected: widget.selectedItems,
        onConfirmed: (items) {
          widget.onChanged(items);
        },
      ),
    );
  }

  void _removeItem(int index) {
    final updated = List<Icd10Item>.from(widget.selectedItems)..removeAt(index);
    widget.onChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.selectedItems.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label with count badge
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text.rich(
              TextSpan(
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                  letterSpacing: 0,
                ),
                children: [
                  TextSpan(text: widget.label),
                  if (widget.required)
                    const TextSpan(
                      text: ' *',
                      style: TextStyle(color: AppColors.red, letterSpacing: 0),
                    ),
                ],
              ),
            ),
            if (count > 0)
              InkWell(
                onTap: () => _openSearchSheet(context),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.blueLt,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        LucideIcons.plus,
                        size: 11,
                        color: AppColors.blue,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '$count Diagnosa',
                        style: const TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.blue,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),

        // Selected items list or empty add button
        if (count == 0)
          InkWell(
            onTap: () => _openSearchSheet(context),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.inputBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Icon(
                    LucideIcons.stethoscope,
                    size: 13,
                    color: AppColors.sub,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.hint,
                      style: const TextStyle(
                        fontSize: 11.0,
                        color: AppColors.sub,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 0,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(
                    LucideIcons.chevronDown,
                    size: 13,
                    color: AppColors.sub,
                  ),
                ],
              ),
            ),
          )
        else ...[
          // List of selected items (Compact & Simple)
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount: count,
            separatorBuilder: (_, _) => const SizedBox(height: 4),
            itemBuilder: (context, index) {
              final item = widget.selectedItems[index];
              final isPrimary = index == 0;

              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4.5,
                ),
                decoration: BoxDecoration(
                  color: isPrimary
                      ? AppColors.blueLt.withValues(alpha: 0.35)
                      : AppColors.card2,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isPrimary
                        ? AppColors.blue.withValues(alpha: 0.25)
                        : AppColors.border,
                    width: 0.8,
                  ),
                ),
                child: Row(
                  children: [
                    // Index tag (Utama / Sekunder)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: isPrimary
                            ? AppColors.blue
                            : AppColors.sub.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        isPrimary ? 'Utama' : 'Sekunder',
                        style: TextStyle(
                          fontSize: 9.0,
                          fontWeight: FontWeight.w600,
                          color: isPrimary ? Colors.white : AppColors.sub,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),

                    // ICD-10 Code
                    if (item.code.isNotEmpty) ...[
                      Text(
                        item.code,
                        style: const TextStyle(
                          fontSize: 10.0,
                          fontWeight: FontWeight.w600,
                          color: AppColors.blue,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(width: 5),
                      const Text(
                        '•',
                        style: TextStyle(
                          fontSize: 10.0,
                          color: AppColors.sub,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(width: 5),
                    ],

                    // Disease Name
                    Expanded(
                      child: Text(
                        item.display,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w400,
                          color: AppColors.text,
                          letterSpacing: 0,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),

                    // Delete button
                    InkWell(
                      onTap: () => _removeItem(index),
                      borderRadius: BorderRadius.circular(4),
                      child: const Padding(
                        padding: EdgeInsets.all(2),
                        child: Icon(
                          LucideIcons.x,
                          size: 12,
                          color: AppColors.sub,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 4),

          // Inline "+ Tambah Diagnosa Lainnya" Button
          Align(
            alignment: Alignment.centerLeft,
            child: InkWell(
              onTap: () => _openSearchSheet(context),
              borderRadius: BorderRadius.circular(4),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 2, horizontal: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.plus, size: 11, color: AppColors.blue),
                    SizedBox(width: 3),
                    Text(
                      'Tambah diagnosa lainnya',
                      style: TextStyle(
                        fontSize: 10.0,
                        fontWeight: FontWeight.w600,
                        color: AppColors.blue,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Bottom Sheet for searching and multi-selecting ICD-10 items.
class _Icd10MultiSearchBottomSheet extends ConsumerStatefulWidget {
  const _Icd10MultiSearchBottomSheet({
    required this.initialSelected,
    required this.onConfirmed,
  });

  final List<Icd10Item> initialSelected;
  final ValueChanged<List<Icd10Item>> onConfirmed;

  @override
  ConsumerState<_Icd10MultiSearchBottomSheet> createState() =>
      _Icd10MultiSearchBottomSheetState();
}

class _Icd10MultiSearchBottomSheetState
    extends ConsumerState<_Icd10MultiSearchBottomSheet> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late List<Icd10Item> _selectedList;
  final Set<String> _selectedCodes = {};
  Timer? _debounceTimer;
  Timer? _initialFetchTimer;
  bool _hasFetchedInitial = false;

  List<Icd10Item> _results = [];
  int _currentPage = 1;
  int _total = 0;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String _currentQuery = '';

  @override
  void initState() {
    super.initState();
    _selectedList = List<Icd10Item>.from(widget.initialSelected);
    _syncSelectedCodes();
    _scrollController.addListener(_onScroll);

    // Open modal first with smooth animation, render loader in content,
    // then fetch data after the bottom sheet transition animation completes.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final modalRoute = ModalRoute.of(context);
      if (modalRoute?.animation != null) {
        if (modalRoute!.animation!.isCompleted) {
          _triggerInitialFetch();
        } else {
          void onAnimationStatusChanged(AnimationStatus status) {
            if (status == AnimationStatus.completed) {
              modalRoute.animation?.removeStatusListener(onAnimationStatusChanged);
              _triggerInitialFetch();
            }
          }

          modalRoute.animation!.addStatusListener(onAnimationStatusChanged);
        }
      }

      // Fallback timer in case the animation status listener doesn't fire
      _initialFetchTimer = Timer(const Duration(milliseconds: 300), () {
        _triggerInitialFetch();
      });
    });
  }

  void _triggerInitialFetch() {
    _initialFetchTimer?.cancel();
    if (_hasFetchedInitial || !mounted) return;
    _hasFetchedInitial = true;

    final cached = Icd10Api.getCachedInitial();
    if (cached != null && cached.data.isNotEmpty) {
      if (mounted) {
        setState(() {
          _results = cached.data;
          _total = cached.total;
          _hasMore = cached.hasMore;
          _loading = false;
        });
      }
      // Re-fetch in background silently without blocking the user
      _fetchPage(1, reset: false, silent: true);
    } else {
      _fetchPage(1, reset: true);
    }
  }

  void _syncSelectedCodes() {
    _selectedCodes
      ..clear()
      ..addAll(
        _selectedList
            .where((s) => s.code.isNotEmpty)
            .map((s) => s.code.toLowerCase().trim()),
      );
  }

  @override
  void dispose() {
    _initialFetchTimer?.cancel();
    _debounceTimer?.cancel();
    _searchController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 150) {
      _loadMore();
    }
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 350), () {
      _fetchPage(1, query: query.trim(), reset: true);
    });
  }

  Future<void> _fetchPage(
    int page, {
    String query = '',
    bool reset = false,
    bool silent = false,
  }) async {
    if (reset) {
      setState(() {
        _loading = !silent;
        _currentPage = 1;
        _hasMore = true;
        _currentQuery = query;
      });
    } else if (silent) {
      // Silent refresh; don't trigger loading spinners
    } else {
      if (_loadingMore || !_hasMore) return;
      setState(() => _loadingMore = true);
    }

    try {
      final api = ref.read(icd10ApiProvider);
      final paginated = await api.fetchIcd10Paginated(
        query: query,
        page: page,
        limit: 25,
      );

      if (!mounted) return;
      setState(() {
        if (reset || silent) {
          _results = paginated.data;
        } else {
          final existingCodes = _results
              .map((i) => i.code.toLowerCase().trim())
              .toSet();
          final newItems = paginated.data
              .where(
                (i) => !existingCodes.contains(i.code.toLowerCase().trim()),
              )
              .toList();
          _results = [..._results, ...newItems];
        }
        _currentPage = paginated.page;
        _total = paginated.total;
        _hasMore = paginated.hasMore;
        _loading = false;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  void _loadMore() {
    if (_loading || _loadingMore || !_hasMore) return;
    _fetchPage(_currentPage + 1, query: _currentQuery);
  }

  bool _isSelected(Icd10Item item) {
    if (item.code.isEmpty) {
      return _selectedList.any(
        (s) => s.display.toLowerCase().trim() == item.display.toLowerCase().trim(),
      );
    }
    return _selectedCodes.contains(item.code.toLowerCase().trim());
  }

  void _toggleItem(Icd10Item item) {
    setState(() {
      final codeKey = item.code.toLowerCase().trim();
      final idx = _selectedList.indexWhere(
        (s) =>
            s.code.toLowerCase().trim() == codeKey &&
            s.code.isNotEmpty,
      );
      if (idx >= 0) {
        _selectedList.removeAt(idx);
        if (codeKey.isNotEmpty) _selectedCodes.remove(codeKey);
      } else {
        _selectedList.add(item);
        if (codeKey.isNotEmpty) _selectedCodes.add(codeKey);
      }
    });
  }

  void _addManualItem(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    setState(() {
      if (!_selectedList.any(
        (s) => s.display.toLowerCase() == trimmed.toLowerCase(),
      )) {
        _selectedList.add(Icd10Item(code: '', display: trimmed));
        _syncSelectedCodes();
      }
      _searchController.clear();
      _fetchPage(1, query: '', reset: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final screenWidth = MediaQuery.sizeOf(context).width;

    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: screenHeight * 0.88,
          maxWidth: screenWidth > 640 ? 580 : double.infinity,
        ),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Header & Search Input
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppColors.orangeLt,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                LucideIcons.stethoscope,
                                size: 16,
                                color: AppColors.orange,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Text(
                                      'Pilih Diagnosa ICD-10',
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.text,
                                        letterSpacing: 0,
                                      ),
                                    ),
                                    if (_total > 0) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 1.5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.blueLt,
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Text(
                                          '$_total Item',
                                          style: const TextStyle(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.blue,
                                            letterSpacing: 0,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const Text(
                                  'Pilih satu atau beberapa diagnosa klinis',
                                  style: TextStyle(
                                    fontSize: 10.0,
                                    color: AppColors.sub,
                                    letterSpacing: 0,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(
                            LucideIcons.x,
                            size: 18,
                            color: AppColors.sub,
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Search input
                    Container(
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppColors.card2,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: TextField(
                        controller: _searchController,
                        autofocus: false,
                        onChanged: _onSearchChanged,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.text,
                          letterSpacing: 0,
                        ),
                        decoration: InputDecoration(
                          hintText:
                              'Cari penyakit / kode (cth: allergic, J30, D69)...',
                          hintStyle: const TextStyle(
                            fontSize: 11.0,
                            color: AppColors.sub,
                            fontWeight: FontWeight.w400,
                            letterSpacing: 0,
                          ),
                          prefixIcon: const Icon(
                            LucideIcons.search,
                            size: 15,
                            color: AppColors.sub,
                          ),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(
                                    LucideIcons.x,
                                    size: 14,
                                    color: AppColors.sub,
                                  ),
                                  onPressed: () {
                                    _searchController.clear();
                                    _fetchPage(1, query: '', reset: true);
                                  },
                                )
                              : null,
                          isDense: true,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 9,
                          ),
                        ),
                      ),
                    ),

                    // Selected items chips preview
                    if (_selectedList.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 26,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _selectedList.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 5),
                          itemBuilder: (context, index) {
                            final item = _selectedList[index];
                            return Container(
                              padding: const EdgeInsets.fromLTRB(7, 2, 3, 2),
                              decoration: BoxDecoration(
                                color: AppColors.blueLt,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: AppColors.blue.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    item.code.isNotEmpty
                                        ? item.code
                                        : item.display,
                                    style: const TextStyle(
                                      fontSize: 10.0,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.blue,
                                      letterSpacing: 0,
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  InkWell(
                                    onTap: () {
                                      setState(() {
                                        _selectedList.removeAt(index);
                                      });
                                    },
                                    borderRadius: BorderRadius.circular(10),
                                    child: const Padding(
                                      padding: EdgeInsets.all(2),
                                      child: Icon(
                                        LucideIcons.x,
                                        size: 11,
                                        color: AppColors.blue,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const Divider(height: 1, color: AppColors.border),

              // 2. Results list with infinite scroll
              Flexible(
                child: _loading
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: AppColors.orange,
                                ),
                              ),
                              SizedBox(height: 14),
                              Text(
                                'Memuat daftar diagnosa ICD-10...',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.sub,
                                  letterSpacing: 0,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _results.isEmpty
                    ? _buildEmptyState()
                    : ListView.separated(
                        controller: _scrollController,
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        // ignore: deprecated_member_use
                        cacheExtent: 600,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        itemCount: _results.length + (_hasMore ? 1 : 0),
                        separatorBuilder: (_, _) =>
                            const Divider(height: 1, color: AppColors.border),
                        itemBuilder: (context, index) {
                          if (index >= _results.length) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 14),
                              child: Center(
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.orange,
                                  ),
                                ),
                              ),
                            );
                          }

                          final item = _results[index];
                          final isSelected = _isSelected(item);

                          return InkWell(
                            onTap: () => _toggleItem(item),
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 8,
                              ),
                              child: Row(
                                children: [
                                  // Checkbox indicator
                                  Container(
                                    width: 18,
                                    height: 18,
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? AppColors.blue
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(5),
                                      border: Border.all(
                                        color: isSelected
                                            ? AppColors.blue
                                            : AppColors.border,
                                        width: 1.4,
                                      ),
                                    ),
                                    child: isSelected
                                        ? const Icon(
                                            LucideIcons.check,
                                            size: 12,
                                            color: Colors.white,
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 8),

                                  // ICD-10 Code badge
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? AppColors.blueLt
                                          : AppColors.card2,
                                      borderRadius: BorderRadius.circular(5),
                                      border: Border.all(
                                        color: isSelected
                                            ? const Color(0x4D2563EB)
                                            : AppColors.border,
                                        width: 0.8,
                                      ),
                                    ),
                                    child: Text(
                                      item.code,
                                      style: TextStyle(
                                        fontSize: 10.0,
                                        fontWeight: FontWeight.w600,
                                        color: isSelected
                                            ? AppColors.blue
                                            : AppColors.text,
                                        letterSpacing: 0,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),

                                  // Disease Name
                                  Expanded(
                                    child: Text(
                                      item.display,
                                      style: TextStyle(
                                        fontSize: 12.0,
                                        fontWeight: isSelected
                                            ? FontWeight.w600
                                            : FontWeight.w400,
                                        color: isSelected
                                            ? AppColors.blue
                                            : AppColors.text,
                                        height: 1.25,
                                        letterSpacing: 0,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),

              // 3. Fallback custom input option at bottom if user typed something
              if (_searchController.text.trim().isNotEmpty)
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: AppColors.border)),
                  ),
                  child: InkWell(
                    onTap: () => _addManualItem(_searchController.text),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.orangeLt.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.orange.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            LucideIcons.plusCircle,
                            size: 13,
                            color: AppColors.orange,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Tambahkan "${_searchController.text.trim()}" sebagai diagnosa manual',
                              style: const TextStyle(
                                fontSize: 11.0,
                                fontWeight: FontWeight.w600,
                                color: AppColors.orange,
                                letterSpacing: 0,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // 4. Sticky Bottom Confirm Bar
              SafeArea(
                top: false,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: AppColors.border)),
                  ),
                  child: Row(
                    children: [
                      if (_selectedList.isNotEmpty)
                        TextButton(
                          onPressed: () {
                            setState(() => _selectedList.clear());
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.sub,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                          ),
                          child: const Text(
                            'Reset',
                            style: TextStyle(fontSize: 11.0, letterSpacing: 0),
                          ),
                        ),
                      const Spacer(),
                      ElevatedButton(
                        onPressed: () {
                          widget.onConfirmed(_selectedList);
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.blue,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 9,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          _selectedList.isEmpty
                              ? 'Tutup'
                              : 'Simpan (${_selectedList.length} Diagnosa)',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: AppColors.card2,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              LucideIcons.searchX,
              size: 22,
              color: AppColors.sub,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Tidak ada kode ICD-10 yang cocok',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: AppColors.text,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Anda dapat mengetik dan menambahkan diagnosa kustom di bawah.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10.5,
              color: AppColors.sub,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

/// Single ICD-10 Search Picker for backward compatibility.
class Icd10SearchPicker extends StatelessWidget {
  const Icd10SearchPicker({
    super.key,
    required this.label,
    required this.selectedCode,
    this.displayLabel,
    required this.onChanged,
    this.onItemSelected,
    this.required = false,
    this.hint = 'Pilih atau cari diagnosa ICD-10...',
  });

  final String label;
  final String selectedCode;
  final String? displayLabel;
  final ValueChanged<String> onChanged;
  final ValueChanged<Icd10Item>? onItemSelected;
  final bool required;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final List<Icd10Item> items = [];
    if (selectedCode.isNotEmpty) {
      items.add(
        Icd10Item(
          code: selectedCode,
          display: displayLabel?.isNotEmpty == true
              ? displayLabel!
              : selectedCode,
        ),
      );
    }

    return Icd10MultiSearchPicker(
      label: label,
      required: required,
      hint: hint,
      selectedItems: items,
      onChanged: (newItems) {
        if (newItems.isNotEmpty) {
          final first = newItems.first;
          onChanged(first.code);
          onItemSelected?.call(first);
        } else {
          onChanged('');
        }
      },
    );
  }
}
