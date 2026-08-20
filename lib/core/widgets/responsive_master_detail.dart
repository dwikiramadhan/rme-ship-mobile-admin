import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../responsive/breakpoints.dart';
import '../theme/app_colors.dart';
import 'app_shimmer.dart';
import 'circle_icon_button.dart';
import 'empty_state.dart';
import 'list_item_button.dart';
import 'screen_header.dart';

class MasterListEntry {
  const MasterListEntry({
    required this.id,
    required this.avatarColor,
    required this.avatarBg,
    required this.initial,
    required this.title,
    required this.subtitle,
    this.badge,
    this.detailTitle,
  });

  final String id;
  final Color avatarColor;
  final Color avatarBg;
  final String initial;
  final String title;
  final String subtitle;
  final Widget? badge;

  /// Title shown on the phone detail page's app bar; defaults to [title].
  final String? detailTitle;
}

/// Shared list+detail pattern used by every role's main screen (Antrian,
/// Pasien, Daftar Resep, Daftar Order): a 380px list pane next to a
/// detail pane on tablet (matching the prototype's master-detail layout),
/// collapsing to a single scrollable list with push-navigation to a detail
/// page on phones.
class ResponsiveMasterDetail extends StatefulWidget {
  const ResponsiveMasterDetail({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    required this.entries,
    required this.detailBuilder,
    required this.emptyIcon,
    required this.emptyTitle,
    this.emptySubtitle,
    this.isLoading = false,
    this.onLoadMore,
    this.hasMore = false,
    this.isLoadingMore = false,
    this.onRefresh,
    this.onEntrySelected,
    this.onSearchChanged,
    this.searchPlaceholder,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final List<MasterListEntry> entries;
  final Widget Function(BuildContext context, String id) detailBuilder;
  final IconData emptyIcon;
  final String emptyTitle;
  final String? emptySubtitle;

  final bool isLoading;
  final VoidCallback? onLoadMore;
  final bool hasMore;
  final bool isLoadingMore;
  final Future<void> Function()? onRefresh;
  final void Function(String id)? onEntrySelected;
  final ValueChanged<String>? onSearchChanged;
  final String? searchPlaceholder;

  @override
  State<ResponsiveMasterDetail> createState() => _ResponsiveMasterDetailState();
}

class _ResponsiveMasterDetailState extends State<ResponsiveMasterDetail> {
  String? _selectedId;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _isSearchFocused = false;
  Timer? _searchDebounce;
  bool _internalLoadingMore = false;
  int _lastEntriesCount = 0;

  @override
  void initState() {
    super.initState();
    _lastEntriesCount = widget.entries.length;
    _scrollController.addListener(_onScroll);
    _searchFocusNode.addListener(() {
      if (mounted) setState(() => _isSearchFocused = _searchFocusNode.hasFocus);
    });
  }

  @override
  void didUpdateWidget(covariant ResponsiveMasterDetail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.entries.length != _lastEntriesCount) {
      _lastEntriesCount = widget.entries.length;
      if (_internalLoadingMore) {
        setState(() => _internalLoadingMore = false);
      }
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchFocusNode.dispose();
    _searchController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (widget.onLoadMore != null && widget.hasMore && !widget.isLoadingMore && !_internalLoadingMore) {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 100) {
        setState(() => _internalLoadingMore = true);
        widget.onLoadMore!();
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted && _internalLoadingMore) {
            setState(() => _internalLoadingMore = false);
          }
        });
      }
    }
  }

  void _openPhoneDetail(BuildContext context, MasterListEntry entry) {
    widget.onEntrySelected?.call(entry.id);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: Text(entry.detailTitle ?? entry.title)),
          backgroundColor: AppColors.bg,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: widget.detailBuilder(context, entry.id),
            ),
          ),
        ),
      ),
    );
  }

  Widget _list(BuildContext context, {required bool tablet}) {
    final showLoadingMore = widget.isLoadingMore || _internalLoadingMore;
    final listWidget = widget.isLoading && widget.entries.isEmpty
        ? const SkeletonList()
        : widget.entries.isEmpty
            ? LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('Belum ada data', style: TextStyle(color: AppColors.sub, fontSize: 13)),
                      ),
                    ),
                  ),
                ),
              )
            : ListView.separated(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(12),
                itemCount: widget.entries.length + (showLoadingMore ? 1 : 0),
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  if (index >= widget.entries.length) {
                    return Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2.2, color: AppColors.orange),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Memuat data pasien...',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.sub.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final entry = widget.entries[index];
                  return ListItemButton(
                    active: tablet && _selectedId == entry.id,
                    avatarColor: entry.avatarColor,
                    avatarBg: entry.avatarBg,
                    initial: entry.initial,
                    title: entry.title,
                    subtitle: entry.subtitle,
                    trailing: entry.badge,
                    onTap: () {
                      widget.onEntrySelected?.call(entry.id);
                      if (tablet) {
                        setState(() => _selectedId = entry.id);
                      } else {
                        _openPhoneDetail(context, entry);
                      }
                    },
                  );
                },
              );

    final content = widget.onRefresh != null
        ? RefreshIndicator(
            color: AppColors.blue,
            onRefresh: widget.onRefresh!,
            child: listWidget,
          )
        : listWidget;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ScreenHeader(title: widget.title, subtitle: widget.subtitle, trailing: widget.trailing),
        if (widget.onSearchChanged != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              height: 42,
              decoration: BoxDecoration(
                color: _isSearchFocused ? AppColors.card : AppColors.card2,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _isSearchFocused ? AppColors.orange : AppColors.border,
                  width: _isSearchFocused ? 1.5 : 1,
                ),
                boxShadow: _isSearchFocused
                    ? [
                        BoxShadow(
                          color: AppColors.orange.withValues(alpha: 0.12),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(width: 11),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      LucideIcons.search,
                      key: ValueKey(_isSearchFocused),
                      size: 16,
                      color: _isSearchFocused ? AppColors.orange : AppColors.sub,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: TextField(
                      focusNode: _searchFocusNode,
                      controller: _searchController,
                      textAlignVertical: TextAlignVertical.center,
                      onChanged: (val) {
                        setState(() {});
                        _searchDebounce?.cancel();
                        _searchDebounce = Timer(const Duration(milliseconds: 350), () {
                          widget.onSearchChanged?.call(val);
                        });
                      },
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.text,
                      ),
                      decoration: InputDecoration(
                        hintText: widget.searchPlaceholder ?? 'Cari nama pasien...',
                        hintStyle: const TextStyle(
                          fontSize: 13,
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
                  if (_searchController.text.isNotEmpty) ...[
                    GestureDetector(
                      onTap: () {
                        _searchController.clear();
                        setState(() {});
                        widget.onSearchChanged?.call('');
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: AppColors.sub.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          LucideIcons.x,
                          size: 13,
                          color: AppColors.sub,
                        ),
                      ),
                    ),
                  ] else
                    const SizedBox(width: 6),
                ],
              ),
            ),
          ),
        Expanded(child: content),
      ],
    );
  }


  @override
  Widget build(BuildContext context) {
    final tablet = isTabletLayout(context);

    if (!tablet) {
      return _list(context, tablet: false);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 380,
          child: DecoratedBox(
            decoration: const BoxDecoration(border: Border(right: BorderSide(color: AppColors.border))),
            child: _list(context, tablet: true),
          ),
        ),
        Expanded(
          child: _selectedId != null
              ? SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: widget.detailBuilder(context, _selectedId!),
                )
              : EmptyState(icon: widget.emptyIcon, title: widget.emptyTitle, subtitle: widget.emptySubtitle),
        ),
      ],
    );
  }
}

// Re-export for convenience so screens only need one import for the header
// action button pattern used across roles ("+", refresh, etc.).
class HeaderActionButton extends CircleIconButton {
  const HeaderActionButton({super.key, required super.icon, required super.onPressed})
      : super(background: AppColors.blue, foreground: Colors.white);
}
