import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/screen_header.dart';
import '../../profile/presentation/profile_screen.dart';
import '../../schedule/domain/trip_schedule.dart';
import '../../schedule/presentation/widgets/poli_layanan_section.dart';
import '../../schedule/presentation/widgets/trip_schedule_card.dart';
import '../../shell/presentation/nav_item.dart';
import '../../shell/presentation/role_shell.dart';
import '../../stock_adjustment/presentation/stock_adjustment_form.dart';
import '../../stock_adjustment/presentation/stock_adjustment_report_view.dart';

/// Koordinator home: the clinic schedule of the trip they're assigned to
/// (moved here from Perawat), their trips (view only), and the medicine stock
/// adjustments of that trip's ship with their report.
class KoordinatorHomeScreen extends ConsumerStatefulWidget {
  const KoordinatorHomeScreen({super.key, required this.koordinatorName});

  final String koordinatorName;

  @override
  ConsumerState<KoordinatorHomeScreen> createState() =>
      _KoordinatorHomeScreenState();
}

class _KoordinatorHomeScreenState extends ConsumerState<KoordinatorHomeScreen> {
  String _tab = 'beranda';

  static const _tabs = [
    ShellNavItem(
      key: 'beranda',
      label: 'Beranda',
      icon: LucideIcons.layoutGrid,
    ),
    ShellNavItem(
      key: 'jadwal',
      label: 'Jadwal',
      icon: LucideIcons.calendarDays,
    ),
    ShellNavItem(
      key: 'adjustment',
      label: 'Adjustment',
      icon: LucideIcons.packageCheck,
    ),
    ShellNavItem(key: 'laporan', label: 'Laporan', icon: LucideIcons.fileText),
    ShellNavItem(key: 'profil', label: 'Profil', icon: LucideIcons.user),
  ];

  @override
  Widget build(BuildContext context) {
    final Widget content = switch (_tab) {
      'beranda' => _KoordinatorDashboard(
        onNavigate: (tab) => setState(() => _tab = tab),
      ),
      'jadwal' => const _AssignedTrips(),
      'adjustment' => const StockAdjustmentForm(),
      'laporan' => const StockAdjustmentReportView(),
      _ => ProfileScreen(name: widget.koordinatorName, role: 'Koordinator'),
    };

    return RoleShell(
      items: _tabs,
      activeKey: _tab,
      onChange: (key) => setState(() => _tab = key),
      child: content,
    );
  }
}

class _KoordinatorDashboard extends ConsumerWidget {
  const _KoordinatorDashboard({required this.onNavigate});

  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripAsync = ref.watch(assignedTripProvider);
    final trip = tripAsync.valueOrNull;
    final port = ref.watch(currentPortProvider).valueOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ScreenHeader(
          title: 'Beranda',
          subtitle: 'Jadwal poli & stok obat kapal',
        ),
        Expanded(
          child: RefreshIndicator(
            color: AppColors.orange,
            onRefresh: () async => ref.refresh(assignedTripsProvider.future),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                if (tripAsync.isLoading && trip == null)
                  const Center(
                    child: CircularProgressIndicator(color: AppColors.orange),
                  )
                else if (tripAsync.hasError && trip == null)
                  _InfoRow(
                    icon: LucideIcons.alertCircle,
                    text: 'Gagal memuat jadwal: ${tripAsync.error}',
                  )
                else if (trip != null) ...[
                  TripScheduleCard(
                    item: trip,
                    readOnly: true,
                    canEditClinics: true,
                  ),
                  if (trip.isOngoing)
                    _ShipPositionCard(portName: port?.portName ?? '-'),
                ] else
                  const _InfoRow(
                    icon: LucideIcons.ship,
                    text: notAssignedMessage,
                  ),
                const SizedBox(height: 14),
                PoliLayananSection(
                  schedule: trip,
                  clinics: trip?.clinics ?? const [],
                  onEdit: trip == null || !trip.clinicsEditable
                      ? null
                      : () => editScheduleClinics(context, ref, trip),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _ShortcutCard(
                        icon: LucideIcons.packageCheck,
                        label: 'Adjustment Stok',
                        onTap: () => onNavigate('adjustment'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ShortcutCard(
                        icon: LucideIcons.fileText,
                        label: 'Laporan Adjustment',
                        onTap: () => onNavigate('laporan'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Shown when the Koordinator isn't on any trip.
const notAssignedMessage =
    'Anda belum ditugaskan di jadwal perjalanan mana pun.';

/// "Jadwal": only the trips the Koordinator is assigned to; the clinics can
/// be changed on the ones not yet finished.
class _AssignedTrips extends ConsumerWidget {
  const _AssignedTrips();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripsAsync = ref.watch(assignedTripsProvider);
    final trips = tripsAsync.valueOrNull ?? const <JadwalPerjalanan>[];
    final ongoing = trips.where((t) => t.isOngoing).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ScreenHeader(
          title: 'Jadwal Perjalanan',
          subtitle: '$ongoing Ongoing · ${trips.length} jadwal ditugaskan',
        ),
        Expanded(
          child: RefreshIndicator(
            color: AppColors.orange,
            onRefresh: () async => ref.refresh(assignedTripsProvider.future),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                if (tripsAsync.isLoading && trips.isEmpty)
                  const Center(
                    child: CircularProgressIndicator(color: AppColors.orange),
                  )
                else if (tripsAsync.hasError && trips.isEmpty)
                  _InfoRow(
                    icon: LucideIcons.alertCircle,
                    text: 'Gagal memuat jadwal: ${tripsAsync.error}',
                  )
                else if (trips.isEmpty)
                  const _InfoRow(
                    icon: LucideIcons.ship,
                    text: notAssignedMessage,
                  )
                else
                  for (final trip in trips)
                    TripScheduleCard(
                      item: trip,
                      readOnly: true,
                      canEditClinics: true,
                    ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.sub),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 12.5, color: AppColors.sub),
          ),
        ),
      ],
    );
  }
}

/// "Posisi kapal": the harbor the ship is at, highlighted as a light-blue
/// glass bar so it stands out on the dashboard.
class _ShipPositionCard extends StatelessWidget {
  const _ShipPositionCard({required this.portName});

  final String portName;

  static const _sky = Color(0xFF0284C7);
  static const _skyLight = Color(0xFF38BDF8);
  static const _skyDeep = Color(0xFF0369A1);
  static const _navy = Color(0xFF0C4A6E);

  @override
  Widget build(BuildContext context) {
    Widget glow(double size, Color color) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
      ),
    );

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _sky.withValues(alpha: 0.22)),
        boxShadow: [
          BoxShadow(
            color: _sky.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: Stack(
          children: [
            // Glass: a light sky gradient with soft glows behind the content.
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFFE0F2FE).withValues(alpha: 0.95),
                      const Color(0xFFF0F9FF).withValues(alpha: 0.85),
                      Colors.white.withValues(alpha: 0.7),
                    ],
                    stops: const [0, 0.55, 1],
                  ),
                ),
              ),
            ),
            Positioned(
              right: -40,
              top: -70,
              child: glow(220, _skyLight.withValues(alpha: 0.28)),
            ),
            Positioned(
              right: 180,
              bottom: -90,
              child: glow(200, const Color(0xFF0EA5E9).withValues(alpha: 0.16)),
            ),
            // Top highlight of the glass edge.
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
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
                    child: const Icon(
                      LucideIcons.anchor,
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'POSISI KAPAL',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3,
                            color: _skyDeep,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          portName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0,
                            color: _navy,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: const Color(0xFF0EA5E9),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFF0EA5E9,
                                ).withValues(alpha: 0.18),
                                spreadRadius: 3,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'Kapal sedang di sini',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0,
                            color: _skyDeep,
                          ),
                        ),
                      ],
                    ),
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

class _ShortcutCard extends StatelessWidget {
  const _ShortcutCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: AppColors.orange),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
