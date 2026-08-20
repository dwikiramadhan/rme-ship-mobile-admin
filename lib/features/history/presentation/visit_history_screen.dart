import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/responsive_master_detail.dart';
import '../domain/visit_history.dart';

/// Riwayat Kunjungan (Rekam Medis) — RBAC: Doctor C/R/U ([canEdit] true),
/// Perawat R only ([canEdit] false).
class VisitHistoryScreen extends ConsumerWidget {
  const VisitHistoryScreen({super.key, required this.canEdit, this.dokterNama = ''});

  final bool canEdit;
  final String dokterNama;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final riwayat = [...ref.watch(riwayatKunjunganProvider)]..sort((a, b) => b.tanggal.compareTo(a.tanggal));

    return ResponsiveMasterDetail(
      title: 'Riwayat Kunjungan',
      subtitle: '${riwayat.length} rekam medis',
      trailing: canEdit
          ? HeaderActionButton(icon: LucideIcons.plus, onPressed: () => _showForm(context, ref))
          : null,
      entries: [
        for (final r in riwayat)
          MasterListEntry(
            id: r.id,
            avatarColor: AppColors.purple,
            avatarBg: AppColors.purpleLt,
            initial: r.pasienNama.isNotEmpty ? r.pasienNama[0] : '?',
            title: r.pasienNama,
            subtitle: '${_fmtDate(r.tanggal)} · ${r.diagnosa}',
          ),
      ],
      detailBuilder: (context, id) {
        final list = ref.watch(riwayatKunjunganProvider);
        final r = list.where((e) => e.id == id).firstOrNull;
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
          canEdit: canEdit,
          onEdit: () => _showForm(context, ref, existing: r),
        );
      },
      emptyIcon: LucideIcons.bookOpen,
      emptyTitle: 'Pilih kunjungan',
      emptySubtitle: 'Pilih rekam medis untuk melihat detail kunjungan.',
    );
  }

  void _showForm(BuildContext context, WidgetRef ref, {RiwayatKunjungan? existing}) {
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
                dokterNama: dokterNama,
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

class _RiwayatForm extends StatefulWidget {
  const _RiwayatForm({this.existing, required this.onSubmit});

  final RiwayatKunjungan? existing;
  final void Function({
    required String pasienNama,
    required String pasienNik,
    required String keluhan,
    required String diagnosa,
    required String tindakan,
  }) onSubmit;

  @override
  State<_RiwayatForm> createState() => _RiwayatFormState();
}

class _RiwayatFormState extends State<_RiwayatForm> {
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
