import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/icd10_api.dart';
import '../../domain/icd10_item.dart';

class Icd10SearchPicker extends ConsumerStatefulWidget {
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
  ConsumerState<Icd10SearchPicker> createState() => _Icd10SearchPickerState();
}

class _Icd10SearchPickerState extends ConsumerState<Icd10SearchPicker> {
  void _openSearchSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: false,
      backgroundColor: Colors.transparent,
      builder: (_) => _Icd10SearchBottomSheet(
        selectedCode: widget.selectedCode,
        onSelected: (item) {
          widget.onChanged(item.code);
          widget.onItemSelected?.call(item);
        },
        onCustomSelected: (customText) {
          widget.onChanged(customText);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasValue = widget.selectedCode.trim().isNotEmpty;
    final textToShow = widget.displayLabel?.isNotEmpty == true
        ? widget.displayLabel!
        : widget.selectedCode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.text,
            ),
            children: [
              TextSpan(text: widget.label),
              if (widget.required)
                const TextSpan(
                  text: ' *',
                  style: TextStyle(color: AppColors.red),
                ),
            ],
          ),
        ),
        const SizedBox(height: 5),
        InkWell(
          onTap: () => _openSearchSheet(context),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: hasValue
                ? const EdgeInsets.symmetric(horizontal: 10, vertical: 4)
                : const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: hasValue
                    ? AppColors.blue.withValues(alpha: 0.4)
                    : AppColors.border,
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: hasValue ? AppColors.blueLt : AppColors.card2,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    LucideIcons.stethoscope,
                    size: 14,
                    color: hasValue ? AppColors.blue : AppColors.sub,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: hasValue
                      ? Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.blueLt,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                widget.selectedCode,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.blue,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                textToShow.startsWith(
                                      '${widget.selectedCode} - ',
                                    )
                                    ? textToShow.substring(
                                        '${widget.selectedCode} - '.length,
                                      )
                                    : textToShow,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.text,
                                  height: 1.35,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        )
                      : Text(
                          widget.hint,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.sub,
                            height: 1.35,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                ),
                const SizedBox(width: 6),
                if (hasValue)
                  IconButton(
                    icon: const Icon(
                      LucideIcons.x,
                      size: 15,
                      color: AppColors.sub,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    splashRadius: 16,
                    onPressed: () => widget.onChanged(''),
                  )
                else
                  const Icon(
                    LucideIcons.chevronDown,
                    size: 16,
                    color: AppColors.sub,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Icd10SearchBottomSheet extends ConsumerStatefulWidget {
  const _Icd10SearchBottomSheet({
    required this.selectedCode,
    required this.onSelected,
    required this.onCustomSelected,
  });

  final String selectedCode;
  final ValueChanged<Icd10Item> onSelected;
  final ValueChanged<String> onCustomSelected;

  @override
  ConsumerState<_Icd10SearchBottomSheet> createState() =>
      _Icd10SearchBottomSheetState();
}

class _Icd10SearchBottomSheetState
    extends ConsumerState<_Icd10SearchBottomSheet> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;
  bool _loading = false;
  List<Icd10Item> _results = [];
  String _lastQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchIcd10('');
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (query.trim() != _lastQuery) {
        _fetchIcd10(query.trim());
      }
    });
  }

  Future<void> _fetchIcd10(String query) async {
    _lastQuery = query;
    setState(() => _loading = true);

    final api = ref.read(icd10ApiProvider);
    final items = await api.searchIcd10(query: query, page: 1, limit: 30);

    if (mounted) {
      setState(() {
        _results = items;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final screenWidth = MediaQuery.sizeOf(context).width;

    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: screenHeight * 0.85,
          maxWidth: screenWidth > 640 ? 580 : double.infinity,
        ),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Drag handle & Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
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
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: AppColors.orangeLt,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                LucideIcons.stethoscope,
                                size: 18,
                                color: AppColors.orange,
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Pilih Diagnosa ICD-10',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.text,
                                  ),
                                ),
                                Text(
                                  'Cari berdasarkan kode ICD-10 atau nama penyakit',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.sub,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(
                            LucideIcons.x,
                            size: 20,
                            color: AppColors.sub,
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Search input
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.card2,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: TextField(
                        controller: _searchController,
                        autofocus: true,
                        onChanged: _onSearchChanged,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.text,
                        ),
                        decoration: InputDecoration(
                          hintText:
                              'Cari penyakit / kode (cth: allergic, J30, D69)...',
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
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(
                                    LucideIcons.x,
                                    size: 16,
                                    color: AppColors.sub,
                                  ),
                                  onPressed: () {
                                    _searchController.clear();
                                    _fetchIcd10('');
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1, color: AppColors.border),

              // 2. Results list
              Flexible(
                child: _loading
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(40),
                          child: CircularProgressIndicator(
                            color: AppColors.orange,
                          ),
                        ),
                      )
                    : _results.isEmpty
                    ? _buildEmptyState()
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        itemCount: _results.length,
                        separatorBuilder: (_, _) =>
                            const Divider(height: 1, color: AppColors.border),
                        itemBuilder: (context, index) {
                          final item = _results[index];
                          final isSelected =
                              widget.selectedCode.toLowerCase().trim() ==
                              item.code.toLowerCase().trim();

                          return InkWell(
                            onTap: () {
                              widget.onSelected(item);
                              Navigator.pop(context);
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                              child: Row(
                                children: [
                                  // ICD-10 Code badge
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? AppColors.blue
                                          : AppColors.blueLt,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      item.code,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w800,
                                        color: isSelected
                                            ? Colors.white
                                            : AppColors.blue,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Disease Name
                                  Expanded(
                                    child: Text(
                                      item.display,
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: isSelected
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                        color: isSelected
                                            ? AppColors.blue
                                            : AppColors.text,
                                      ),
                                    ),
                                  ),
                                  if (isSelected)
                                    const Icon(
                                      LucideIcons.check,
                                      size: 18,
                                      color: AppColors.blue,
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
                SafeArea(
                  top: false,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(top: BorderSide(color: AppColors.border)),
                    ),
                    child: InkWell(
                      onTap: () {
                        widget.onCustomSelected(_searchController.text.trim());
                        Navigator.pop(context);
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.card2,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              LucideIcons.edit3,
                              size: 15,
                              color: AppColors.orange,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Gunakan "${_searchController.text.trim()}" sebagai diagnosa manual',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.orange,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
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
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(
              color: AppColors.card2,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              LucideIcons.searchX,
              size: 26,
              color: AppColors.sub,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Tidak ada kode ICD-10 yang cocok',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Anda dapat menggunakan tombol di bawah untuk memasukkan diagnosa kustom.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.sub),
          ),
        ],
      ),
    );
  }
}
