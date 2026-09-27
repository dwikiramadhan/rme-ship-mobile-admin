import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/network/api_config.dart';
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
              await notifier.fetchPatients(
                refresh: true,
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
                        final totalItems =
                            sorted.length + (showLoadingMore ? 1 : 0);
                        final rowCount = (totalItems + 1) ~/ 2;

                        return ListView.separated(
                          controller: _scrollController,
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          itemCount: rowCount,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, rowIndex) {
                            final firstIndex = rowIndex * 2;
                            final secondIndex = firstIndex + 1;

                            final isFirstLoading = firstIndex >= sorted.length;
                            final isSecondLoading =
                                secondIndex >= sorted.length && showLoadingMore;

                            final p1 = firstIndex < sorted.length
                                ? sorted[firstIndex]
                                : null;
                            final p2 = secondIndex < sorted.length
                                ? sorted[secondIndex]
                                : null;

                            return IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(
                                    child: isFirstLoading
                                        ? Container(
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
                                          )
                                        : (p1 != null
                                              ? _PatientCard(
                                                  key: ValueKey(p1.id),
                                                  patient: p1,
                                                )
                                              : const SizedBox.shrink()),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: isSecondLoading
                                        ? Container(
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
                                          )
                                        : (p2 != null
                                              ? _PatientCard(
                                                  key: ValueKey(p2.id),
                                                  patient: p2,
                                                )
                                              : const SizedBox.shrink()),
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

class _PatientCard extends StatelessWidget {
  const _PatientCard({super.key, required this.patient});

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

    final displayDate = patient.createdAt != null
        ? formatDateTime(patient.createdAt)
        : (patient.lastVisit != null && patient.lastVisit!.isNotEmpty
              ? formatDateTime(patient.lastVisit)
              : (patient.waktuMasuk.isNotEmpty
                    ? formatDateTime(patient.waktuMasuk)
                    : '-'));

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
              // 1. Header: Avatar + Nama & Code Pasien (tanpa #) + Tanggal Created At di Kanan Atas
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                    clipBehavior: Clip.antiAlias,
                    child:
                        (patient.photoUrl != null &&
                            patient.photoUrl!.isNotEmpty)
                        ? Image.network(
                            patient.photoUrl!.startsWith('http')
                                ? patient.photoUrl!
                                : '${ApiConfig.baseUrl}${patient.photoUrl}',
                            width: 38,
                            height: 38,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Text(
                              initial,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: avatarColor,
                              ),
                            ),
                          )
                        : Text(
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
                              color: const Color(0xFFE0F2FE),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              patient.registerNo,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF0284C7),
                              ),
                            ),
                          )
                        else
                          const Text(
                            'No. RM: -',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10.5,
                              color: AppColors.sub,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Tanggal Created At (Kanan Atas)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Registered',
                          style: TextStyle(
                            fontSize: 10,
                            color: Color(0xFF94A3B8),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          displayDate,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF374151),
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 6),

              // 2. Info 2 Kolom (NIK, Gender, Umur, Phone, Alamat, Poli)
              // Baris 1: NIK & Gender
              Row(
                children: [
                  Expanded(
                    child: _buildColItem(
                      icon: LucideIcons.creditCard,
                      label: 'NIK',
                      value: patient.nik.isNotEmpty ? patient.nik : '-',
                      labelWidth: 24,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildColItem(
                      icon: LucideIcons.user,
                      label: 'Gender',
                      value: patient.jk.label.isNotEmpty
                          ? patient.jk.label
                          : '-',
                      labelWidth: 42,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),

              // Baris 2: Umur & Phone
              Row(
                children: [
                  Expanded(
                    child: _buildColItem(
                      icon: LucideIcons.calendar,
                      label: 'Umur',
                      value: patient.umur > 0
                          ? '${patient.umur} th'
                          : (patient.dob != null && patient.dob!.isNotEmpty
                                ? '${patient.umur} th'
                                : '-'),
                      labelWidth: 32,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildColItem(
                      icon: LucideIcons.phone,
                      label: 'Phone',
                      value:
                          (patient.phone != null && patient.phone!.isNotEmpty)
                          ? patient.phone!
                          : '-',
                      labelWidth: 36,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),

              // Baris 3: Alamat & Poli (atau Alamat Full-width)
              if (patient.poliName != null && patient.poliName!.isNotEmpty)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildColItem(
                        icon: LucideIcons.mapPin,
                        label: 'Alamat',
                        value: _extractKabKotaProvinsi(patient.alamat),
                        labelWidth: 40,
                        maxLines: 2,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildColItem(
                        icon: LucideIcons.stethoscope,
                        label: 'Poli',
                        value: patient.poliName!,
                        labelWidth: 26,
                        maxLines: 2,
                      ),
                    ),
                  ],
                )
              else
                _buildColItem(
                  icon: LucideIcons.mapPin,
                  label: 'Alamat',
                  value: _extractKabKotaProvinsi(patient.alamat),
                  labelWidth: 42,
                  maxLines: 2,
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _extractKabKotaProvinsi(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty || trimmed == '-') return '-';

    // Split by comma
    final parts = trimmed
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    if (parts.isEmpty) return '-';

    // Remove postal code if present at the end (5 digits)
    if (parts.length > 1 && RegExp(r'^\d{5}$').hasMatch(parts.last)) {
      parts.removeLast();
    }

    // Filter out street/RT/RW, Kelurahan, Kecamatan
    final candidates = parts.where((p) {
      final lower = p.toLowerCase();
      if (lower.startsWith('jl.') ||
          lower.startsWith('jl ') ||
          lower.startsWith('jalan ') ||
          lower.startsWith('gang ') ||
          lower.startsWith('rt ') ||
          lower.startsWith('rw ') ||
          lower.startsWith('kel.') ||
          lower.startsWith('kel ') ||
          lower.startsWith('kelurahan ') ||
          lower.startsWith('desa ') ||
          lower.startsWith('kec.') ||
          lower.startsWith('kec ') ||
          lower.startsWith('kecamatan ')) {
        return false;
      }
      return true;
    }).toList();

    if (candidates.isEmpty) {
      return _toTitleCase(parts.last);
    }

    if (candidates.length == 1) {
      return _toTitleCase(candidates.first);
    }

    // If 2 or more candidates, take the last two (which represent Kab/Kota and Provinsi)
    final kabKota = _toTitleCase(candidates[candidates.length - 2]);
    final provinsi = _toTitleCase(candidates.last);
    return '$kabKota, $provinsi';
  }

  String _toTitleCase(String text) {
    final clean = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (clean.isEmpty) return clean;
    if (clean == clean.toUpperCase() && clean.length > 2) {
      return clean
          .split(' ')
          .map((w) {
            if (w.isEmpty) return w;
            return w[0].toUpperCase() + w.substring(1).toLowerCase();
          })
          .join(' ');
    }
    return clean;
  }

  Widget _buildColItem({
    required IconData icon,
    required String label,
    required String value,
    double? labelWidth,
    int maxLines = 1,
  }) {
    return Row(
      crossAxisAlignment: maxLines > 1
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        Padding(
          padding: EdgeInsets.only(top: maxLines > 1 ? 1.5 : 0),
          child: Icon(icon, size: 11, color: const Color(0xFF94A3B8)),
        ),
        const SizedBox(width: 4),
        if (labelWidth != null)
          SizedBox(
            width: labelWidth,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 10.5,
                color: Color(0xFF6B7280),
                fontWeight: FontWeight.w400,
                letterSpacing: 0,
              ),
            ),
          )
        else
          Text(
            label,
            style: const TextStyle(
              fontSize: 10.5,
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w500,
              letterSpacing: 0,
            ),
          ),
        const SizedBox(width: 3),
        Expanded(
          child: Text(
            value,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Color(0xFF374151),
              letterSpacing: 0,
            ),
          ),
        ),
      ],
    );
  }
}
