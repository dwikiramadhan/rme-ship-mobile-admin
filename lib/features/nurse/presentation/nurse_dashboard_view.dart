import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/screen_header.dart';
import '../../patients/data/patient_repository.dart';
import '../../patients/domain/patient.dart';
import '../../schedule/domain/trip_schedule.dart';

class NurseDashboardView extends ConsumerStatefulWidget {
  const NurseDashboardView({
    super.key,
    required this.nurseName,
    required this.onNavigateToTab,
  });

  final String nurseName;
  final ValueChanged<String> onNavigateToTab;

  @override
  ConsumerState<NurseDashboardView> createState() => _NurseDashboardViewState();
}

class _NurseDashboardViewState extends ConsumerState<NurseDashboardView> {
  JadwalPerjalanan? _findActiveVoyage(List<JadwalPerjalanan> list) {
    for (final j in list) {
      if (j.isOngoing) return j;
    }
    return list.firstOrNull;
  }

  static final _dateSeparator = RegExp(r'[/ -]');

  bool _isToday(dynamic dateValue, DateTime now) {
    if (dateValue == null) return false;
    if (dateValue is DateTime) {
      final local = dateValue.toLocal();
      return local.year == now.year &&
          local.month == now.month &&
          local.day == now.day;
    }
    if (dateValue is String) {
      final trimmed = dateValue.trim();
      if (trimmed.isEmpty || trimmed == '-') return false;
      final parsed = DateTime.tryParse(trimmed);
      if (parsed != null) {
        final local = parsed.toLocal();
        return local.year == now.year &&
            local.month == now.month &&
            local.day == now.day;
      }
      final parts = trimmed.split(_dateSeparator);
      if (parts.length >= 3) {
        final d = int.tryParse(parts[0]);
        final m = int.tryParse(parts[1]);
        final y = int.tryParse(parts[2]);
        if (d != null && m != null && y != null && y > 1000) {
          return d == now.day && m == now.month && y == now.year;
        }
        final y2 = int.tryParse(parts[0]);
        final m2 = int.tryParse(parts[1]);
        final d2 = int.tryParse(parts[2]);
        if (d2 != null && m2 != null && y2 != null && y2 > 1000) {
          return d2 == now.day && m2 == now.month && y2 == now.year;
        }
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final patients = ref.watch(patientsProvider);
    final histories = ref.watch(medicalHistoryProvider);
    final schedules = ref.watch(jadwalPerjalananProvider);

    // Active Voyage: Prefer Ongoing, fallback to first schedule
    final activeVoyage = _findActiveVoyage(schedules);

    // Read the clock once per build instead of once per date check.
    final now = DateTime.now();
    bool isToday(dynamic dateValue) => _isToday(dateValue, now);

    // 1. Kunjungan Hari Ini: Riwayat kunjungan yang tercatat hari ini
    final todayVisits = histories.where((h) {
      return isToday(h.createdAt) || isToday(h.date) || isToday(h.updatedAt);
    }).toList();
    final todayVisitCount = todayVisits.length;

    final todayVisitPatientIds = todayVisits
        .map((h) => h.patientId)
        .where((id) => id.isNotEmpty)
        .toSet();
    final todayVisitPatientNiks = todayVisits
        .map((h) => h.patientNik)
        .where((nik) => nik.isNotEmpty)
        .toSet();

    // 2. Pasien Hari Ini: Pasien yang terdaftar hari ini atau tercatat memiliki kunjungan/update hari ini
    final todayPatients = patients.where((p) {
      final isCreatedToday = isToday(p.createdAt) || isToday(p.waktuMasuk);
      final isLastVisitToday = isToday(p.lastVisit);
      final hasVisitToday =
          todayVisitPatientIds.contains(p.id) ||
          (p.nik.isNotEmpty && todayVisitPatientNiks.contains(p.nik));
      return isCreatedToday || isLastVisitToday || hasVisitToday;
    }).toList();

    final allTodayPatientIds = <String>{
      ...todayVisitPatientIds,
      ...todayPatients.map((p) => p.id).where((id) => id.isNotEmpty),
    };
    final todayPatientCount = allTodayPatientIds.isNotEmpty
        ? allTodayPatientIds.length
        : todayPatients.length;

    // 3. Menunggu Hari Ini: Status Menunggu Dokter dan aktif / terdaftar hari ini
    final todayWaitingCount = patients.where((p) {
      if (p.status != PatientStatus.menungguDokter) return false;
      final isCreatedToday = isToday(p.createdAt) || isToday(p.waktuMasuk);
      final isUpdatedToday = isToday(p.updatedAt);
      final isLastVisitToday = isToday(p.lastVisit);
      final hasVisitToday =
          todayVisitPatientIds.contains(p.id) ||
          (p.nik.isNotEmpty && todayVisitPatientNiks.contains(p.nik));
      return isCreatedToday ||
          isUpdatedToday ||
          isLastVisitToday ||
          hasVisitToday;
    }).length;

    final clinics = activeVoyage?.clinics ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ScreenHeader(
          title: 'Dashboard',
          subtitle: 'Ringkasan operasional medis hari ini',
        ),
        Expanded(
          child: Stack(
            children: [
              // Soft colour glows behind the glass tiles.
              const Positioned(
                left: -120,
                top: -160,
                child: _Glow(size: 520, color: Color(0xFFFB923C), alpha: 0.16),
              ),
              const Positioned(
                left: 420,
                top: -200,
                child: _Glow(size: 620, color: Color(0xFF38BDF8), alpha: 0.16),
              ),
              Positioned.fill(
                child: RefreshIndicator(
                  color: AppColors.orange,
                  onRefresh: () async {
                    ref.invalidate(scheduleCounterProvider);
                    await Future.wait([
                      ref.read(patientsProvider.notifier).fetchPatients(),
                      ref
                          .read(medicalHistoryProvider.notifier)
                          .fetchHistory(refresh: true),
                      ref.read(schedulesNotifierProvider.notifier).refresh(),
                    ]);
                  },
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _SummaryTiles(
                        tiles: [
                          _StatTile(
                            icon: LucideIcons.users,
                            color: AppColors.orange,
                            value: '$todayPatientCount',
                            label: 'Pasien hari ini',
                            onTap: () => widget.onNavigateToTab('pasien'),
                          ),
                          _StatTile(
                            icon: LucideIcons.clock,
                            color: AppColors.yellow,
                            value: '$todayWaitingCount',
                            label: 'Menunggu hari ini',
                            onTap: () => widget.onNavigateToTab('pasien'),
                          ),
                          _StatTile(
                            icon: LucideIcons.bookOpen,
                            color: AppColors.green,
                            value: '$todayVisitCount',
                            label: 'Kunjungan hari ini',
                            onTap: () => widget.onNavigateToTab('riwayat'),
                          ),
                          _StatTile(
                            icon: LucideIcons.building2,
                            color: AppColors.purple,
                            value: '${clinics.length}',
                            label: 'Poli layanan',
                          ),
                        ],
                      ),
                      if (activeVoyage != null) ...[
                        const SizedBox(height: 14),
                        _VoyageCard(voyage: activeVoyage),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// Sky-blue glass palette, shared with the Koordinator's "Posisi kapal".
const _sky = Color(0xFF0284C7);
const _skyLight = Color(0xFF38BDF8);
const _skyDeep = Color(0xFF0369A1);
const _navy = Color(0xFF0C4A6E);

/// A blurred colour spot drawn behind glass.
class _Glow extends StatelessWidget {
  const _Glow({required this.size, required this.color, required this.alpha});

  final double size;
  final Color color;
  final double alpha;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: alpha),
              color.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}

/// The four counters: one row on tablet, 2×2 on a phone.
class _SummaryTiles extends StatelessWidget {
  const _SummaryTiles({required this.tiles});

  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) {
    const gap = 12.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 640) {
          return Row(
            children: [
              for (var i = 0; i < tiles.length; i++) ...[
                if (i > 0) const SizedBox(width: gap),
                Expanded(child: tiles[i]),
              ],
            ],
          );
        }
        return Column(
          children: [
            for (var i = 0; i < tiles.length; i += 2) ...[
              if (i > 0) const SizedBox(height: gap),
              Row(
                children: [
                  Expanded(child: tiles[i]),
                  const SizedBox(width: gap),
                  Expanded(
                    child: i + 1 < tiles.length
                        ? tiles[i + 1]
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}

/// Glass counter: label + small icon on top, the number below.
class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
    this.onTap,
  });

  final IconData icon;
  final Color color;
  final String value;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(16);
    return Container(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: Colors.white.withValues(alpha: 0.95)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.82),
                Colors.white.withValues(alpha: 0.55),
              ],
            ),
          ),
          child: InkWell(
            onTap: onTap,
            child: Stack(
              children: [
                Positioned(
                  right: -30,
                  top: -40,
                  child: _Glow(size: 120, color: color, alpha: 0.14),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0,
                                color: AppColors.sub,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.95),
                              ),
                            ),
                            child: Icon(icon, size: 14, color: color),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        value,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0,
                          height: 1.2,
                          color: AppColors.text,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The trip under way as a sky-blue glass card: ship, its status as the
/// schedule gives it, where the ship is now and the route.
class _VoyageCard extends StatelessWidget {
  const _VoyageCard({required this.voyage});

  final JadwalPerjalanan voyage;

  @override
  Widget build(BuildContext context) {
    final ongoing = voyage.isOngoing;
    final status = voyage.status.trim().isEmpty ? '-' : voyage.status.trim();
    final here = ongoing ? voyage.currentStop(DateTime.now()) : null;
    final statusColor = ongoing
        ? const Color(0xFF047857)
        : const Color(0xFF374151);
    final dotColor = ongoing
        ? const Color(0xFF10B981)
        : const Color(0xFF94A3B8);

    final location = _InfoCell(
      icon: LucideIcons.anchor,
      label: 'Lokasi saat ini',
      highlighted: true,
      child: Text(
        here == null || here.portName.isEmpty ? '-' : here.portName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: _kCellValue,
      ),
    );
    final route = _InfoCell(
      icon: LucideIcons.route,
      label: 'Rute',
      child: Text.rich(
        TextSpan(
          style: _kCellValue,
          children: [
            TextSpan(text: voyage.pelabuhanAsal),
            const TextSpan(
              text: '  →  ',
              style: TextStyle(fontWeight: FontWeight.w600, color: _skyLight),
            ),
            TextSpan(text: voyage.pelabuhanTujuan),
          ],
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _sky.withValues(alpha: 0.22)),
        boxShadow: [
          BoxShadow(
            color: _sky.withValues(alpha: 0.12),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(17),
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFFE0F2FE).withValues(alpha: 0.95),
                      const Color(0xFFF0F9FF).withValues(alpha: 0.85),
                      Colors.white.withValues(alpha: 0.72),
                    ],
                    stops: const [0, 0.55, 1],
                  ),
                ),
              ),
            ),
            const Positioned(
              right: -60,
              top: -110,
              child: _Glow(size: 300, color: _skyLight, alpha: 0.30),
            ),
            const Positioned(
              right: 300,
              bottom: -140,
              child: _Glow(size: 260, color: Color(0xFF0EA5E9), alpha: 0.14),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: Container(
                height: 1,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const _GradientIcon(icon: LucideIcons.ship, size: 40),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              voyage.namaKapal,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0,
                                color: _navy,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              voyage.shipCode.isNotEmpty
                                  ? voyage.shipCode
                                  : 'Kapal RS',
                              style: const TextStyle(
                                fontSize: 11,
                                letterSpacing: 0,
                                color: _skyDeep,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      _GlassChip(
                        dotColor: dotColor,
                        textColor: statusColor,
                        text: status,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      if (!ongoing) return route;
                      if (constraints.maxWidth >= 560) {
                        return Row(
                          children: [
                            Expanded(flex: 10, child: location),
                            const SizedBox(width: 10),
                            Expanded(flex: 14, child: route),
                          ],
                        );
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [location, const SizedBox(height: 10), route],
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const _kCellValue = TextStyle(
  fontSize: 13,
  fontWeight: FontWeight.w700,
  letterSpacing: 0,
  color: _navy,
);

/// Sky-blue gradient square with a white icon.
class _GradientIcon extends StatelessWidget {
  const _GradientIcon({required this.icon, required this.size});

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.3),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_skyLight, _sky],
        ),
        boxShadow: [
          BoxShadow(
            color: _sky.withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(icon, size: size / 2, color: Colors.white),
    );
  }
}

class _GlassChip extends StatelessWidget {
  const _GlassChip({
    required this.dotColor,
    required this.textColor,
    required this.text,
  });

  final Color dotColor;
  final Color textColor;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.95)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: dotColor.withValues(alpha: 0.18),
                  spreadRadius: 3,
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}

/// A small glass panel inside the voyage card: icon, uppercase label and a
/// value.
class _InfoCell extends StatelessWidget {
  const _InfoCell({
    required this.icon,
    required this.label,
    required this.child,
    this.highlighted = false,
  });

  final IconData icon;
  final String label;
  final Widget child;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.95)),
      ),
      child: Row(
        children: [
          if (highlighted)
            _GradientIcon(icon: icon, size: 30)
          else
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: _sky.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, size: 15, color: _sky),
            ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                    color: _skyDeep,
                  ),
                ),
                const SizedBox(height: 1),
                child,
              ],
            ),
          ),
        ],
      ),
    );
  }
}
