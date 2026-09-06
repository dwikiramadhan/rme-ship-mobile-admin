import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_helper.dart';
import '../../../core/widgets/app_card.dart';
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
  bool _internalLoadingMore = false;

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
      if (notifier.hasMore &&
          !notifier.isLoadingMore &&
          !_internalLoadingMore) {
        setState(() => _internalLoadingMore = true);
        notifier.loadMore();
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted && _internalLoadingMore) {
            setState(() => _internalLoadingMore = false);
          }
        });
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
    final showLoadingMore = notifier.isLoadingMore || _internalLoadingMore;

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
              crossAxisAlignment: CrossAxisAlignment.center,
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
                      setState(() {});
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
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Cari nama atau NIK pasien...',
                      hintStyle: TextStyle(
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
                  ),
                ],
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
              await notifier.fetchPatients(refresh: true);
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
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
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
                        return GridView.builder(
                          controller: _scrollController,
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                mainAxisExtent: 156,
                              ),
                          itemCount: sorted.length + (showLoadingMore ? 2 : 0),
                          itemBuilder: (context, index) {
                            if (index >= sorted.length) {
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
                            final p = sorted[index];
                            return _PatientCard(patient: p);
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
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
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
                          return _PatientCard(patient: p);
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

class _PatientCard extends StatelessWidget {
  const _PatientCard({required this.patient});

  final Patient patient;

  @override
  Widget build(BuildContext context) {
    final initial = patient.nama.isNotEmpty
        ? patient.nama[0].toUpperCase()
        : '?';
    final isMale = patient.jk == Gender.l;
    final avatarBg = isMale ? const Color(0xFFEFF6FF) : const Color(0xFFFFF1F2);
    final avatarColor = isMale
        ? const Color(0xFF2563EB)
        : const Color(0xFFE11D48);

    final displayDate =
        patient.lastVisit != null && patient.lastVisit!.isNotEmpty
        ? formatDate(patient.lastVisit)
        : patient.waktuMasuk;

    final hasContactOrPoli =
        (patient.phone != null && patient.phone!.isNotEmpty) ||
        (patient.poliName != null && patient.poliName!.isNotEmpty);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
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
        child: AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Header: Avatar + Nama & Code Pasien (tanpa #)
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Avatar
                  Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: avatarBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      initial,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: avatarColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Nama & Code Pasien (tanpa tanda #)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          patient.nama,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.text,
                          ),
                        ),
                        const SizedBox(height: 2),
                        if (patient.registerNo.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                                width: 0.8,
                              ),
                            ),
                            child: Text(
                              patient.registerNo,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF475569),
                              ),
                            ),
                          )
                        else
                          Text(
                            patient.nik.isNotEmpty ? patient.nik : 'Tanpa NIK',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.sub,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 6),

              // 2. Info Demografi (NIK, Jenis Kelamin, Umur, Golongan Darah) - Sederhana & Bersih
              Wrap(
                spacing: 5,
                runSpacing: 2,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (patient.registerNo.isNotEmpty &&
                      patient.nik.isNotEmpty) ...[
                    Text(
                      patient.nik,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF334155),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Text(
                      '·',
                      style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 11),
                    ),
                  ],
                  Text(
                    '${patient.jk.label}, ${patient.umur} th',
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (patient.bloodType != null &&
                      patient.bloodType!.isNotEmpty &&
                      patient.bloodType != '-') ...[
                    const Text(
                      '·',
                      style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 11),
                    ),
                    Text(
                      'Gol. ${patient.bloodType}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),

              // 3. Info Kontak & Poliklinik (Monokrom sederhana)
              if (hasContactOrPoli) ...[
                const SizedBox(height: 3),
                Row(
                  children: [
                    if (patient.phone != null && patient.phone!.isNotEmpty) ...[
                      const Icon(
                        LucideIcons.phone,
                        size: 11,
                        color: Color(0xFF94A3B8),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        patient.phone!,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    if (patient.phone != null &&
                        patient.phone!.isNotEmpty &&
                        patient.poliName != null &&
                        patient.poliName!.isNotEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6),
                        child: Text(
                          '·',
                          style: TextStyle(
                            color: Color(0xFFCBD5E1),
                            fontSize: 11,
                          ),
                        ),
                      ),
                    if (patient.poliName != null &&
                        patient.poliName!.isNotEmpty) ...[
                      const Icon(
                        LucideIcons.stethoscope,
                        size: 11,
                        color: Color(0xFF94A3B8),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          patient.poliName!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],

              const SizedBox(height: 6),

              // 4. Footer: Alamat & Tanggal Kunjungan Terakhir
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      LucideIcons.mapPin,
                      size: 11,
                      color: Color(0xFF94A3B8),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        patient.alamat.isNotEmpty
                            ? patient.alamat
                            : 'Alamat tidak tercantum',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      LucideIcons.calendarDays,
                      size: 11,
                      color: Color(0xFF94A3B8),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      displayDate,
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
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
