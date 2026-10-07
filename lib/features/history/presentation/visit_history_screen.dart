import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_badge.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/responsive_master_detail.dart';
import '../../../core/widgets/status_filter_button.dart';
import '../domain/visit_history.dart';

import '../../auth/domain/user_role.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../patients/data/patient_repository.dart';
import '../../patients/presentation/status_meta.dart';

/// Riwayat Kunjungan (Rekam Medis) — RBAC: Doctor C/R/U ([canEdit] true),
/// Perawat R only ([canEdit] false).
class VisitHistoryScreen extends ConsumerStatefulWidget {
  const VisitHistoryScreen({super.key, required this.canEdit, this.dokterNama = ''});

  final bool canEdit;
  final String dokterNama;

  @override
  ConsumerState<VisitHistoryScreen> createState() => _VisitHistoryScreenState();
}

class _VisitHistoryScreenState extends ConsumerState<VisitHistoryScreen> {
  String _statusFilter = 'SEMUA';

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final user = authState.session?.user;
    final isDoctor = widget.canEdit || user?.role == UserRole.dokter;

    final effectiveDoctorName = widget.dokterNama.trim().isNotEmpty
        ? widget.dokterNama.trim()
        : (user?.name ?? '').trim().isNotEmpty
            ? (user?.name ?? '').trim()
            : 'Dokter Pemeriksa';
    final effectiveDoctorId = user?.id ?? '';

    final activeUserId = user?.id ?? '';

    // Filtered directly from endpoint query parameter (?user_id=...)
    final historyProvider = (isDoctor && activeUserId.isNotEmpty)
        ? medicalHistoryByUserProvider(activeUserId)
        : medicalHistoryProvider;
    final apiHistories = ref.watch(historyProvider);
    final historyNotifier = ref.read(historyProvider.notifier);

    final filteredHistories = apiHistories.where((m) {
      if (_statusFilter == 'SEMUA') return true;
      final status = (m.statusPenanganan ?? '').toLowerCase();
      return status.contains(_statusFilter.toLowerCase());
    }).toList();

    final List<RiwayatKunjungan> riwayat = filteredHistories.map((m) => RiwayatKunjungan(
      id: m.id,
      pasienNama: m.patientName,
      pasienNik: m.patientNik,
      tanggal: DateTime.tryParse(m.createdAt ?? m.date ?? '') ?? DateTime.now(),
      keluhan: m.complaint ?? '',
      diagnosa: m.diagnosis ?? '',
      tindakan: m.treatment ?? '',
      dokterNama: m.doctorName ?? effectiveDoctorName,
      dokterId: m.doctorId ?? effectiveDoctorId,
    )).toList();

    return ResponsiveMasterDetail(
      title: 'Riwayat Kunjungan',
      subtitle: '${riwayat.length} rekam medis',
      searchPlaceholder: 'Cari nama atau NIK pasien...',
      searchTrailing: StatusFilterButton(
        selectedValue: _statusFilter,
        options: riwayatStatusFilterOptions,
        onSelected: (val) {
          setState(() => _statusFilter = val);
          if (val == 'SEMUA') {
            historyNotifier.setStatusPenanganan(null);
          } else {
            historyNotifier.setStatusPenanganan(val);
          }
        },
      ),
      isLoading: historyNotifier.isLoading,
      hasMore: historyNotifier.hasMore,
      isLoadingMore: historyNotifier.isLoadingMore,
      onLoadMore: () => historyNotifier.loadMore(),
      onRefresh: () => historyNotifier.fetchHistory(refresh: true),
      onSearchChanged: (q) => historyNotifier.searchHistory(q),
      trailing: widget.canEdit
          ? HeaderActionButton(
              icon: LucideIcons.plus,
              onPressed: () => _showForm(
                context,
                effectiveDoctorName: effectiveDoctorName,
                effectiveDoctorId: effectiveDoctorId,
              ),
            )
          : null,
      entries: [
        for (int i = 0; i < riwayat.length; i++)
          MasterListEntry(
            id: riwayat[i].id,
            avatarColor: AppColors.purple,
            avatarBg: AppColors.purpleLt,
            initial: riwayat[i].pasienNama.isNotEmpty
                ? riwayat[i].pasienNama[0]
                : '?',
            title: riwayat[i].pasienNama,
            subtitle: '${_fmtDate(riwayat[i].tanggal)} · ${riwayat[i].diagnosa}',
            badge: _historyStatusBadge(filteredHistories[i].statusPenanganan),
          ),
      ],
      detailBuilder: (context, id) {
        final r = riwayat.where((e) => e.id == id).firstOrNull;
        if (r == null) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Text('Detail kunjungan tidak ditemukan.', style: TextStyle(color: AppColors.sub)),
            ),
          );
        }
        return _RiwayatDetail(
          item: r,
          canEdit: widget.canEdit,
          onEdit: () => _showForm(
            context,
            existing: r,
            effectiveDoctorName: effectiveDoctorName,
            effectiveDoctorId: effectiveDoctorId,
          ),
        );
      },
      emptyIcon: LucideIcons.bookOpen,
      emptyTitle: 'Pilih kunjungan',
      emptySubtitle: isDoctor
          ? 'Belum ada rekam medis kunjungan untuk dokter ini.'
          : 'Pilih rekam medis untuk melihat detail kunjungan.',
    );
  }

  void _showForm(
    BuildContext context, {
    RiwayatKunjungan? existing,
    required String effectiveDoctorName,
    String? effectiveDoctorId,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
        child: _RiwayatForm(
          existing: existing,
          onSubmit: ({required pasienNama, required pasienNik, required keluhan, required diagnosa, required tindakan}) {
            final notifier = ref.read(riwayatKunjunganProvider.notifier);
            if (existing == null) {
              notifier.add(
                pasienNama: pasienNama,
                pasienNik: pasienNik,
                keluhan: keluhan,
                diagnosa: diagnosa,
                tindakan: tindakan,
                dokterNama: effectiveDoctorName,
                dokterId: effectiveDoctorId,
              );
            } else {
              notifier.update(existing.id, (r) => r.copyWith(keluhan: keluhan, diagnosa: diagnosa, tindakan: tindakan));
            }
            Navigator.of(sheetContext).pop();
          },
        ),
      ),
    );
  }

  Widget _historyStatusBadge(String? statusPenanganan) {
    final meta = statusMetaFromPenanganan(statusPenanganan);
    return AppBadge(
      label: meta.label,
      color: meta.color,
      background: meta.background,
    );
  }
}

String _fmtDate(DateTime d) {
  return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

typedef RiwayatKunjunganScreen = VisitHistoryScreen;

class _RiwayatDetail extends StatelessWidget {
  const _RiwayatDetail({required this.item, required this.canEdit, required this.onEdit});

  final RiwayatKunjungan item;
  final bool canEdit;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(item.pasienNama, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.text)),
              ),
              if (canEdit)
                AppButton(label: 'Ubah', small: true, variant: AppButtonVariant.ghost, icon: LucideIcons.pencil, onPressed: onEdit),
            ],
          ),
          const SizedBox(height: 2),
          Text('NIK ${item.pasienNik} · ${_fmtDate(item.tanggal)}', style: const TextStyle(fontSize: 12, color: AppColors.sub)),
          const Divider(height: 24),
          _Field(label: 'Keluhan', value: item.keluhan),
          const SizedBox(height: 12),
          _Field(label: 'Diagnosa', value: item.diagnosa),
          const SizedBox(height: 12),
          _Field(label: 'Tindakan / Terapi', value: item.tindakan),
          const SizedBox(height: 12),
          _Field(label: 'Dokter Pemeriksa', value: item.dokterNama),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.sub)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 13.5, color: AppColors.text)),
      ],
    );
  }
}

class RiwayatFormModal extends StatefulWidget {
  const RiwayatFormModal({super.key, this.existing, required this.onSubmit});

  final RiwayatKunjungan? existing;
  final void Function({
    required String pasienNama,
    required String pasienNik,
    required String keluhan,
    required String diagnosa,
    required String tindakan,
  }) onSubmit;

  @override
  State<RiwayatFormModal> createState() => _RiwayatFormModalState();
}

typedef _RiwayatForm = RiwayatFormModal;

class _RiwayatFormModalState extends State<RiwayatFormModal> {
  final _formKey = GlobalKey<FormState>();
  late final _nama = TextEditingController(text: widget.existing?.pasienNama);
  late final _nik = TextEditingController(text: widget.existing?.pasienNik);
  late final _keluhan = TextEditingController(text: widget.existing?.keluhan);
  late final _diagnosa = TextEditingController(text: widget.existing?.diagnosa);
  late final _tindakan = TextEditingController(text: widget.existing?.tindakan);

  @override
  void dispose() {
    _nama.dispose();
    _nik.dispose();
    _keluhan.dispose();
    _diagnosa.dispose();
    _tindakan.dispose();
    super.dispose();
  }

  String? _required(String? v) => (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null;

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                editing ? 'Ubah Rekam Medis' : 'Input Rekam Medis Baru',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.text),
              ),
              const SizedBox(height: 14),
              if (!editing) ...[
                AppTextField(label: 'Nama Pasien', controller: _nama, required: true, validator: _required),
                const SizedBox(height: 10),
                AppTextField(label: 'NIK', controller: _nik, required: true, numbersOnly: true, keyboardType: TextInputType.number, validator: _required),
                const SizedBox(height: 10),
              ],
              AppTextField(label: 'Keluhan', controller: _keluhan, required: true, maxLines: 2, validator: _required),
              const SizedBox(height: 10),
              AppTextField(label: 'Diagnosa', controller: _diagnosa, required: true, validator: _required),
              const SizedBox(height: 10),
              AppTextField(label: 'Tindakan / Terapi', controller: _tindakan, required: true, maxLines: 2, validator: _required),
              const SizedBox(height: 16),
              AppButton(
                label: editing ? 'Simpan Perubahan' : 'Simpan',
                full: true,
                onPressed: () {
                  if (!_formKey.currentState!.validate()) return;
                  widget.onSubmit(
                    pasienNama: _nama.text.trim(),
                    pasienNik: _nik.text.trim(),
                    keluhan: _keluhan.text.trim(),
                    diagnosa: _diagnosa.text.trim(),
                    tindakan: _tindakan.text.trim(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
