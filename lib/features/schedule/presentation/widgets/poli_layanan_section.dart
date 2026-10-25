import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_card.dart';
import '../../data/schedule_api.dart';
import '../../domain/trip_schedule.dart';
import 'edit_clinics_modal.dart';

/// Opens the clinic editor of [schedule] and saves it (Koordinator).
void editScheduleClinics(
  BuildContext context,
  WidgetRef ref,
  JadwalPerjalanan schedule,
) {
  EditClinicsModal.show(
    context,
    schedule: schedule,
    onSave: (body) async {
      final api = ScheduleApi();
      await api.updateSchedule(schedule.id, body);
      ref.invalidate(scheduleCounterProvider);
      ref.invalidate(assignedTripsProvider);
      await ref.read(schedulesNotifierProvider.notifier).refresh();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Poli layanan berhasil diperbarui'),
            backgroundColor: AppColors.green,
          ),
        );
      }
    },
  );
}

/// "Poli Layanan" of the trip under way: one card with a row per clinic
/// (name, hours, status). With [onEdit] the clinics can be changed
/// (Koordinator); without it the list is read-only.
class PoliLayananSection extends StatelessWidget {
  const PoliLayananSection({
    super.key,
    required this.schedule,
    required this.clinics,
    this.onEdit,
  });

  final JadwalPerjalanan? schedule;
  final List<ScheduleClinicItem> clinics;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final schedule = this.schedule;
    final onEdit = this.onEdit;
    final Widget body;
    if (schedule == null) {
      body = const _EmptyMessage(
        title: 'Tidak ada jadwal pelayaran aktif',
        subtitle:
            'Poli layanan dapat diatur setelah jadwal pelayaran tersedia.',
      );
    } else if (clinics.isEmpty) {
      body = _EmptyMessage(
        title: 'Belum ada Poli Layanan terdaftar',
        subtitle:
            'Poli layanan untuk jadwal pelayaran ini belum dikonfigurasi.',
        action: onEdit == null
            ? null
            : TextButton.icon(
                onPressed: onEdit,
                icon: const Icon(LucideIcons.pencilLine, size: 14),
                label: const Text(
                  'Atur Poli Layanan',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                  ),
                ),
                style: TextButton.styleFrom(foregroundColor: AppColors.orange),
              ),
      );
    } else {
      body = LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= _kTableMinWidth;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (wide) const _TableHeader(),
              for (var i = 0; i < clinics.length; i++)
                _ClinicRow(
                  clinic: clinics[i],
                  wide: wide,
                  first: i == 0,
                  last: i == clinics.length - 1,
                ),
            ],
          );
        },
      );
    }

    return DefaultTextStyle.merge(
      style: const TextStyle(letterSpacing: 0),
      child: AppCard(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                children: [
                  const Text(
                    'Poli Layanan',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                    ),
                  ),
                  if (schedule != null) ...[
                    const SizedBox(width: 8),
                    _CountChip(text: '${clinics.length} poli'),
                  ],
                  const Spacer(),
                  if (schedule != null && onEdit != null)
                    _GhostButton(label: 'Atur Poli', onTap: onEdit),
                ],
              ),
            ),
            body,
          ],
        ),
      ),
    );
  }
}

// Same type scale as the other Koordinator screens: 13 card title, 12.5 body,
// 11 meta, 10.5 column labels (all before the tablet text scale).
const _kBody = TextStyle(
  fontSize: 12.5,
  color: AppColors.text,
  letterSpacing: 0,
);
const _kMeta = TextStyle(fontSize: 11, color: AppColors.sub, letterSpacing: 0);
const _kColumnLabel = TextStyle(
  fontSize: 10.5,
  fontWeight: FontWeight.w600,
  letterSpacing: 0.3,
  color: AppColors.sub,
);

const double _kHoursCol = 200;
const double _kStatusCol = 96;
const double _kColGap = 12;

/// Below this width the hours go under the clinic name.
const double _kTableMinWidth = 520;

class _CountChip extends StatelessWidget {
  const _CountChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      decoration: BoxDecoration(
        color: AppColors.card2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          color: AppColors.sub,
        ),
      ),
    );
  }
}

/// Small grey button ("Atur Poli").
class _GhostButton extends StatelessWidget {
  const _GhostButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                LucideIcons.pencilLine,
                size: 14,
                color: AppColors.sub,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0,
                  color: AppColors.text,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyMessage extends StatelessWidget {
  const _EmptyMessage({
    required this.title,
    required this.subtitle,
    this.action,
  });

  final String title;
  final String subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: _kBody.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(subtitle, textAlign: TextAlign.center, style: _kMeta),
          if (action != null) ...[const SizedBox(height: 8), action!],
        ],
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: AppColors.card2,
        border: Border.symmetric(
          horizontal: BorderSide(color: AppColors.border),
        ),
      ),
      child: const Row(
        children: [
          Expanded(child: Text('POLI', style: _kColumnLabel)),
          SizedBox(width: _kColGap),
          SizedBox(
            width: _kHoursCol,
            child: Text('JAM LAYANAN', style: _kColumnLabel),
          ),
          SizedBox(width: _kColGap),
          SizedBox(
            width: _kStatusCol,
            child: Text('STATUS', style: _kColumnLabel),
          ),
        ],
      ),
    );
  }
}

class _ClinicRow extends StatelessWidget {
  const _ClinicRow({
    required this.clinic,
    required this.wide,
    required this.first,
    required this.last,
  });

  final ScheduleClinicItem clinic;
  final bool wide;
  final bool first;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final name = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          clinic.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _kBody.copyWith(fontWeight: FontWeight.w600),
        ),
        if (clinic.code.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(clinic.code.toUpperCase(), style: _kMeta),
        ],
      ],
    );
    final hours = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(LucideIcons.clock, size: 13, color: AppColors.sub),
        const SizedBox(width: 6),
        Text(clinic.operationalHours, style: _kBody),
      ],
    );
    const status = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Dot(color: AppColors.green),
        SizedBox(width: 6),
        Text(
          'Aktif',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
            color: AppColors.green,
          ),
        ),
      ],
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      decoration: BoxDecoration(
        border: Border(
          top: !wide && first
              ? const BorderSide(color: AppColors.border)
              : BorderSide.none,
          bottom: last
              ? BorderSide.none
              : const BorderSide(color: AppColors.border),
        ),
      ),
      child: wide
          ? Row(
              children: [
                Expanded(child: name),
                const SizedBox(width: _kColGap),
                SizedBox(width: _kHoursCol, child: hours),
                const SizedBox(width: _kColGap),
                const SizedBox(width: _kStatusCol, child: status),
              ],
            )
          : Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [name, const SizedBox(height: 6), hours],
                  ),
                ),
                const SizedBox(width: _kColGap),
                status,
              ],
            ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
