import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_badge.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/screen_header.dart';
import '../domain/medicine_stock.dart';

/// Stok Obat Kapal — per the RBAC matrix (Ship Web Admin):
/// Pharmacist gets full C/R/U/D ([canManage] true); Doctor & Perawat get
/// read-only ([canManage] false).
class MedicineStockScreen extends ConsumerWidget {
  const MedicineStockScreen({super.key, required this.canManage});

  final bool canManage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stok = ref.watch(stokObatProvider);
    final menipis = stok.where((s) => s.menipis).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ScreenHeader(
          title: 'Stok Obat Kapal',
          subtitle: '${stok.length} jenis obat${menipis > 0 ? ' · $menipis menipis' : ''}',
          trailing: canManage
              ? HeaderAddButton(onPressed: () => _showForm(context, ref))
              : null,
        ),
        Expanded(
          child: stok.isEmpty
              ? const Center(child: Text('Belum ada data stok', style: TextStyle(color: AppColors.sub, fontSize: 13)))
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: stok.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) => _StokTile(
                    item: stok[index],
                    canManage: canManage,
                    onEdit: () => _showForm(context, ref, existing: stok[index]),
                    onDelete: () => _confirmDelete(context, ref, stok[index]),
                  ),
                ),
        ),
      ],
    );
  }

  void _showForm(BuildContext context, WidgetRef ref, {StokObat? existing}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
        child: _StokForm(
          existing: existing,
          onSubmit: ({required nama, required kategori, required satuan, required jumlah, required minimum}) {
            final notifier = ref.read(stokObatProvider.notifier);
            if (existing == null) {
              notifier.add(nama: nama, kategori: kategori, satuan: satuan, jumlah: jumlah, minimum: minimum);
            } else {
              notifier.update(existing.id, (s) => s.copyWith(nama: nama, kategori: kategori, satuan: satuan, jumlah: jumlah, minimum: minimum));
            }
            Navigator.of(sheetContext).pop();
          },
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, StokObat item) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus obat?'),
        content: Text('${item.nama} akan dihapus dari stok kapal.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Batal')),
          TextButton(
            onPressed: () {
              ref.read(stokObatProvider.notifier).remove(item.id);
              Navigator.of(dialogContext).pop();
            },
            child: const Text('Hapus', style: TextStyle(color: AppColors.red)),
          ),
        ],
      ),
    );
  }
}

class HeaderAddButton extends StatelessWidget {
  const HeaderAddButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.blue,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onPressed,
        child: const SizedBox(width: 38, height: 38, child: Icon(LucideIcons.plus, size: 19, color: Colors.white)),
      ),
    );
  }
}

class _StokTile extends StatelessWidget {
  const _StokTile({required this.item, required this.canManage, required this.onEdit, required this.onDelete});

  final StokObat item;
  final bool canManage;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: scheme.onSurface.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: item.menipis ? AppColors.redLt : AppColors.greenLt,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(LucideIcons.pill, size: 19, color: item.menipis ? AppColors.red : AppColors.green),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(item.nama, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: scheme.onSurface)),
                const SizedBox(height: 1),
                Text('${item.kategori} · ${item.jumlah} ${item.satuan}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (item.menipis)
            const AppBadge(label: 'Menipis', color: AppColors.red, background: AppColors.redLt)
          else
            const AppBadge(label: 'Aman', color: AppColors.green, background: AppColors.greenLt),
          if (canManage) ...[
            const SizedBox(width: 4),
            IconButton(
              onPressed: onEdit,
              icon: const Icon(LucideIcons.pencil, size: 16, color: AppColors.sub),
              visualDensity: VisualDensity.compact,
              tooltip: 'Ubah',
            ),
            IconButton(
              onPressed: onDelete,
              icon: const Icon(LucideIcons.trash2, size: 16, color: AppColors.red),
              visualDensity: VisualDensity.compact,
              tooltip: 'Hapus',
            ),
          ],
        ],
      ),
    );
  }
}

class _StokForm extends StatefulWidget {
  const _StokForm({this.existing, required this.onSubmit});

  final StokObat? existing;
  final void Function({required String nama, required String kategori, required String satuan, required int jumlah, required int minimum}) onSubmit;

  @override
  State<_StokForm> createState() => _StokFormState();
}

class _StokFormState extends State<_StokForm> {
  final _formKey = GlobalKey<FormState>();
  late final _nama = TextEditingController(text: widget.existing?.nama);
  late final _kategori = TextEditingController(text: widget.existing?.kategori);
  late final _satuan = TextEditingController(text: widget.existing?.satuan);
  late final _jumlah = TextEditingController(text: widget.existing?.jumlah.toString());
  late final _minimum = TextEditingController(text: widget.existing?.minimum.toString());

  @override
  void dispose() {
    _nama.dispose();
    _kategori.dispose();
    _satuan.dispose();
    _jumlah.dispose();
    _minimum.dispose();
    super.dispose();
  }

  String? _required(String? v) => (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null;

  @override
  Widget build(BuildContext context) {
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
                widget.existing == null ? 'Tambah Obat' : 'Ubah Obat',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.text),
              ),
              const SizedBox(height: 14),
              AppTextField(label: 'Nama Obat', controller: _nama, required: true, validator: _required),
              const SizedBox(height: 10),
              AppTextField(label: 'Kategori', controller: _kategori, required: true, validator: _required),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: AppTextField(label: 'Satuan', controller: _satuan, required: true, validator: _required)),
                  const SizedBox(width: 10),
                  Expanded(child: AppTextField(label: 'Jumlah', controller: _jumlah, required: true, numbersOnly: true, keyboardType: TextInputType.number, validator: _required)),
                  const SizedBox(width: 10),
                  Expanded(child: AppTextField(label: 'Stok Min.', controller: _minimum, required: true, numbersOnly: true, keyboardType: TextInputType.number, validator: _required)),
                ],
              ),
              const SizedBox(height: 16),
              AppButton(
                label: widget.existing == null ? 'Simpan' : 'Simpan Perubahan',
                full: true,
                onPressed: () {
                  if (!_formKey.currentState!.validate()) return;
                  widget.onSubmit(
                    nama: _nama.text.trim(),
                    kategori: _kategori.text.trim(),
                    satuan: _satuan.text.trim(),
                    jumlah: int.tryParse(_jumlah.text) ?? 0,
                    minimum: int.tryParse(_minimum.text) ?? 0,
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

typedef StokObatScreen = MedicineStockScreen;
