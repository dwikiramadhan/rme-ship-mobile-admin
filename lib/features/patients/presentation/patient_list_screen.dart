import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/widgets/unsynced_badge.dart';
import '../../sync/presentation/unsynced_ids.dart';
import '../../../core/network/api_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_helper.dart';
import '../../../core/widgets/app_shimmer.dart';
import '../../../core/widgets/responsive_master_detail.dart';
import '../../../core/widgets/screen_header.dart';
import '../data/patient_repository.dart';
import '../domain/patient.dart';
import 'patient_detail_screen.dart';

/// Halaman List Pasien (Master Data Pasien)
/// Menampilkan daftar seluruh pasien terdaftar tanpa detail pemeriksaan medis kunjungan.
class PatientListScreen extends ConsumerStatefulWidget {
  const PatientListScreen({super.key, this.onAddPatient});

  final VoidCallback? onAddPatient;

  @override
  ConsumerState<PatientListScreen> createState() => _PatientListScreenState();
}

class _PatientListScreenState extends ConsumerState<PatientListScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _isSearchFocused = false;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _searchFocusNode.addListener(() {
      setState(() => _isSearchFocused = _searchFocusNode.hasFocus);
    });
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    final notifier = ref.read(patientsProvider.notifier);

    if (maxScroll - currentScroll <= 200) {
      if (notifier.hasMore && !notifier.isLoadingMore && !notifier.isLoading) {
        notifier.loadMore();
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final patients = ref.watch(patientsProvider);
    final notifier = ref.read(patientsProvider.notifier);
    final sorted = sortRecent(patients);
    final showLoadingMore = notifier.isLoadingMore;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ScreenHeader(
          title: 'Daftar Pasien',
          trailing: widget.onAddPatient != null
              ? HeaderActionButton(
                  icon: LucideIcons.plus,
                  tooltip: 'Tambah Pasien',
                  onPressed: widget.onAddPatient!,
                )
              : null,
        ),

        // Search Bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            height: 42,
            decoration: BoxDecoration(
              color: _isSearchFocused ? AppColors.card : AppColors.card2,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _isSearchFocused ? AppColors.blue : AppColors.border,
                width: _isSearchFocused ? 1.5 : 1,
              ),
              boxShadow: _isSearchFocused
                  ? [
                      BoxShadow(
                        color: AppColors.blue.withValues(alpha: 0.12),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                const SizedBox(width: 11),
                Icon(
                  LucideIcons.search,
                  size: 16,
                  color: _isSearchFocused ? AppColors.blue : AppColors.sub,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: TextField(
                    focusNode: _searchFocusNode,
                    controller: _searchController,
                    textAlignVertical: TextAlignVertical.center,
                    onChanged: (val) {
                      _searchDebounce?.cancel();
                      _searchDebounce = Timer(
                        const Duration(milliseconds: 350),
                        () {
                          notifier.searchPatients(val);
                        },
                      );
                    },
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.text,
                      letterSpacing: 0,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Cari nama atau NIK pasien...',
                      hintStyle: TextStyle(
                        fontSize: 11,
                        color: AppColors.sub,
                        letterSpacing: 0,
                      ),
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                    ),
                  ),
                ),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _searchController,
                  builder: (context, value, _) {
                    if (value.text.isEmpty) return const SizedBox.shrink();
                    return GestureDetector(
                      onTap: () {
                        _searchController.clear();
                        notifier.searchPatients('');
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 8),
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
                    );
                  },
                ),
              ],
            ),
          ),
        ),

        // List View Content
        Expanded(
          child: RefreshIndicator(
            color: AppColors.blue,
            backgroundColor: AppColors.card,
            onRefresh: () async {
              await notifier.fetchPatients(
                search: _searchController.text.trim().isNotEmpty
                    ? _searchController.text.trim()
                    : null,
              );
            },
            child: notifier.isLoading && sorted.isEmpty
                ? const SkeletonList()
                : sorted.isEmpty
                ? LayoutBuilder(
                    builder: (context, constraints) => SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  LucideIcons.users,
                                  size: 40,
                                  color: AppColors.sub,
                                ),
                                SizedBox(height: 12),
                                Text(
                                  'Tidak ada data pasien ditemukan',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.sub,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final wide = constraints.maxWidth > 700;

                      if (wide) {
                        // Two cards per row, plus one full-width row for the
                        // load-more spinner so it sits centered under the grid.
                        final patientRowCount = (sorted.length + 1) ~/ 2;
                        final rowCount =
                            patientRowCount + (showLoadingMore ? 1 : 0);

                        return ListView.separated(
                          controller: _scrollController,
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          itemCount: rowCount,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, rowIndex) {
                            if (rowIndex >= patientRowCount) {
                              return Container(
                                padding: const EdgeInsets.all(16),
                                alignment: Alignment.center,
                                child: const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.blue,
                                  ),
                                ),
                              );
                            }

                            final firstIndex = rowIndex * 2;
                            final secondIndex = firstIndex + 1;
                            final p1 = sorted[firstIndex];
                            final p2 = secondIndex < sorted.length
                                ? sorted[secondIndex]
                                : null;

                            return IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(
                                    child: _PatientCard(
                                      key: ValueKey(p1.id),
                                      patient: p1,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: p2 != null
                                        ? _PatientCard(
                                            key: ValueKey(p2.id),
                                            patient: p2,
                                          )
                                        : const SizedBox.shrink(),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      }

                      return ListView.separated(
                        controller: _scrollController,
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        itemCount: sorted.length + (showLoadingMore ? 1 : 0),
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          if (index >= sorted.length) {
                            return Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              alignment: Alignment.center,
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.blue,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Memuat lebih banyak...',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.sub,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }
                          final p = sorted[index];
                          return _PatientCard(key: ValueKey(p.id), patient: p);
                        },
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}

/// One patient as a minimal card: identity, a 2×2 grid (NIK, gender, the port
/// the patient was registered at, and who registered them), and the
/// registration time centred in a glass footer along the card's bottom edge.
class _PatientCard extends ConsumerWidget {
  const _PatientCard({super.key, required this.patient});

  final Patient patient;

  static const _border = Color(0xFFE2E8F0);
  static const _sky = Color(0xFF0284C7);
  static const _skyDeep = Color(0xFF0369A1);
  static const _navy = Color(0xFF0C4A6E);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unsynced = ref.watch(
      unsyncedIdsProvider.select(
        (ids) => ids.valueOrNull?.patients.contains(patient.id) ?? false,
      ),
    );

    final displayDate = patient.createdAt != null
        ? formatDateTime(patient.createdAt)
        : (patient.lastVisit != null && patient.lastVisit!.isNotEmpty
              ? formatDateTime(patient.lastVisit)
              : (patient.waktuMasuk.isNotEmpty
                    ? formatDateTime(patient.waktuMasuk)
                    : '-'));

    return Material(
      color: AppColors.card,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: _border),
      ),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => PatientDetailScreen(
                patientId: patient.id,
                initialPatient: patient,
              ),
            ),
          );
        },
        child: DefaultTextStyle.merge(
          style: const TextStyle(letterSpacing: 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            // In the wide grid both cards of a row share the taller one's
            // height; this keeps the footer on the bottom edge.
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        _PatientAvatar(patient: patient),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                patient.nama,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.text,
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                patient.registerNo.isNotEmpty
                                    ? patient.registerNo
                                    : 'No. RM: -',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: patient.registerNo.isNotEmpty
                                      ? _sky
                                      : AppColors.sub,
                                ),
                              ),
                              if (unsynced) ...[
                                const SizedBox(height: 4),
                                const UnsyncedBadge(),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _InfoItem(
                            label: 'NIK',
                            value: patient.nik.isNotEmpty ? patient.nik : '-',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _InfoItem(
                            label: 'Gender',
                            value: patient.jk.label,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _InfoItem(
                            label: 'Pelabuhan',
                            value: patient.createdPortName ?? '-',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _InfoItem(
                            label: 'Dibuat oleh',
                            value: patient.createdByName ?? '-',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFFE0F2FE).withValues(alpha: 0.9),
                      const Color(0xFFF0F9FF).withValues(alpha: 0.55),
                    ],
                  ),
                  border: Border(
                    top: BorderSide(color: Colors.white.withValues(alpha: 0.9)),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(LucideIcons.clock, size: 12, color: _sky),
                    const SizedBox(width: 6),
                    const Text(
                      'Registered',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w400,
                        color: _skyDeep,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        displayDate,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                          color: _navy,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The patient's photo, or their initial on a gender-tinted square.
class _PatientAvatar extends StatelessWidget {
  const _PatientAvatar({required this.patient});

  final Patient patient;

  @override
  Widget build(BuildContext context) {
    final isMale = patient.jk == Gender.l;
    final bg = isMale ? const Color(0xFFEFF6FF) : const Color(0xFFFFF1F2);
    final fg = isMale ? const Color(0xFF2563EB) : const Color(0xFFE11D48);
    final initialText = Text(
      patient.nama.isNotEmpty ? patient.nama[0].toUpperCase() : '?',
      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: fg),
    );
    final photo = patient.photoUrl;

    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: (photo != null && photo.isNotEmpty)
          ? Image.network(
              photo.startsWith('http') ? photo : '${ApiConfig.baseUrl}$photo',
              width: 36,
              height: 36,
              // Width only: forcing both dimensions decoded non-square photos
              // into a square (squashed). This keeps the aspect ratio so
              // BoxFit.cover crops instead.
              cacheWidth: 108,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => initialText,
            )
          : initialText,
    );
  }
}

/// A small upper-case label over its value.
class _InfoItem extends StatelessWidget {
  const _InfoItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
            color: Color(0xFF94A3B8),
          ),
        ),
        const SizedBox(height: 1),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            color: Color(0xFF334155),
          ),
        ),
      ],
    );
  }
}
