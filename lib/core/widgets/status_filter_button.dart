import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_colors.dart';

class StatusFilterOption {
  const StatusFilterOption({
    required this.value,
    required this.label,
    required this.color,
  });

  final String value;
  final String label;
  final Color color;
}

const List<StatusFilterOption> labStatusFilterOptions = [
  StatusFilterOption(
    value: 'SEMUA',
    label: 'Semua Status',
    color: AppColors.orange,
  ),
  StatusFilterOption(
    value: 'Menunggu Lab',
    label: 'Menunggu Lab',
    color: AppColors.yellow,
  ),
  StatusFilterOption(
    value: 'Selesai',
    label: 'Selesai',
    color: AppColors.green,
  ),
];

const List<StatusFilterOption> riwayatStatusFilterOptions = [
  StatusFilterOption(
    value: 'SEMUA',
    label: 'Semua Status',
    color: AppColors.orange,
  ),
  StatusFilterOption(
    value: 'Menunggu Dokter',
    label: 'Menunggu Dokter',
    color: AppColors.orange,
  ),
  StatusFilterOption(
    value: 'Menunggu Lab',
    label: 'Menunggu Lab',
    color: Color(0xFF0284C7),
  ),
  StatusFilterOption(
    value: 'Menunggu Obat',
    label: 'Menunggu Obat',
    color: AppColors.yellow,
  ),
  StatusFilterOption(
    value: 'Selesai',
    label: 'Selesai',
    color: AppColors.green,
  ),
];

/// A compact, reusable filter button designed to be placed in the search row
/// (e.g. as [ResponsiveMasterDetail.searchTrailing]).
class StatusFilterButton extends StatelessWidget {
  const StatusFilterButton({
    super.key,
    required this.selectedValue,
    required this.options,
    required this.onSelected,
    this.allValue = 'SEMUA',
    this.tooltip = 'Filter Status Penanganan',
  });

  final String selectedValue;
  final List<StatusFilterOption> options;
  final ValueChanged<String> onSelected;
  final String allValue;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final isFiltered = selectedValue != allValue;

    return PopupMenuButton<String>(
      tooltip: tooltip,
      initialValue: selectedValue,
      onSelected: onSelected,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      color: Colors.white,
      elevation: 3,
      itemBuilder: (context) => [
        for (final opt in options)
          PopupMenuItem<String>(
            value: opt.value,
            child: Row(
              children: [
                Icon(
                  selectedValue == opt.value
                      ? LucideIcons.check
                      : LucideIcons.circle,
                  size: 15,
                  color: selectedValue == opt.value
                      ? opt.color
                      : AppColors.sub.withValues(alpha: 0.4),
                ),
                const SizedBox(width: 8),
                Text(
                  opt.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.normal,
                    color: selectedValue == opt.value
                        ? opt.color
                        : AppColors.text,
                  ),
                ),
              ],
            ),
          ),
      ],
      child: Container(
        width: 42,
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isFiltered ? AppColors.orangeLt : AppColors.card2,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isFiltered ? AppColors.orange : AppColors.border,
            width: isFiltered ? 1.5 : 1,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              LucideIcons.filter,
              size: 17,
              color: isFiltered ? AppColors.orange : AppColors.sub,
            ),
            if (isFiltered)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: AppColors.orange,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
