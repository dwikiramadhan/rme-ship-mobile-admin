import 'package:flutter/material.dart';

import '../responsive/breakpoints.dart';
import '../theme/app_colors.dart';
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
/// Pasien Saya, Daftar Resep, Daftar Order): a 380px list pane next to a
/// detail pane on tablet (matching the prototype's master-detail layout),
/// collapsing to a single scrollable list with push-navigation to a detail
/// page on phones.
class ResponsiveMasterDetail extends StatefulWidget {
  const ResponsiveMasterDetail({
    super.key,
    required this.title,
    required this.subtitle,
    this.trailing,
    required this.entries,
    required this.detailBuilder,
    required this.emptyIcon,
    required this.emptyTitle,
    this.emptySubtitle,
  });

  final String title;
  final String subtitle;
  final Widget? trailing;
  final List<MasterListEntry> entries;
  final Widget Function(BuildContext context, String id) detailBuilder;
  final IconData emptyIcon;
  final String emptyTitle;
  final String? emptySubtitle;

  @override
  State<ResponsiveMasterDetail> createState() => _ResponsiveMasterDetailState();
}

class _ResponsiveMasterDetailState extends State<ResponsiveMasterDetail> {
  String? _selectedId;

  void _openPhoneDetail(BuildContext context, MasterListEntry entry) {
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ScreenHeader(title: widget.title, subtitle: widget.subtitle, trailing: widget.trailing),
        Expanded(
          child: widget.entries.isEmpty
              ? const Center(
                  child: Text('Belum ada data', style: TextStyle(color: AppColors.sub, fontSize: 13)),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: widget.entries.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
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
                        if (tablet) {
                          setState(() => _selectedId = entry.id);
                        } else {
                          _openPhoneDetail(context, entry);
                        }
                      },
                    );
                  },
                ),
        ),
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
