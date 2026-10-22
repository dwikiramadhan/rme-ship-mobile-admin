import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../data/schedule_repository.dart';

/// Shown when no ongoing trip gives the harbor of a new visit.
const String noCurrentPortMessage =
    'Tidak ada jadwal perjalanan Ongoing untuk kapal ini, '
    'sehingga pelabuhan tidak dapat ditentukan.';

/// The harbor of a new visit (`port_id`, required by the backend), read
/// from the ongoing trip instead of picked by hand.
class CurrentPortInfo extends ConsumerWidget {
  const CurrentPortInfo({super.key, this.labelFontSize, this.fontSize});

  final double? labelFontSize;
  final double? fontSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final port = ref.watch(currentPortProvider);
    final stop = port.valueOrNull;
    final missing = !port.isLoading && stop == null;

    final String text;
    if (port.isLoading) {
      text = 'Memuat pelabuhan...';
    } else if (port.hasError) {
      text = 'Gagal memuat jadwal perjalanan.';
    } else if (stop == null) {
      text = noCurrentPortMessage;
    } else {
      text = stop.portName;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppFieldLabel(
          label: 'Pelabuhan',
          required: true,
          fontSize: labelFontSize,
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: missing ? AppColors.redLt : AppColors.card2,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Icon(
                LucideIcons.anchor,
                size: 16,
                color: missing ? AppColors.red : AppColors.blue,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: fontSize ?? 12,
                    fontWeight: stop != null
                        ? FontWeight.w600
                        : FontWeight.w400,
                    color: missing ? AppColors.red : AppColors.text,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (stop != null) ...[
          const SizedBox(height: 4),
          const Text(
            'Otomatis dari jadwal perjalanan yang sedang berjalan.',
            style: TextStyle(fontSize: 10.5, color: AppColors.sub),
          ),
        ],
      ],
    );
  }
}
