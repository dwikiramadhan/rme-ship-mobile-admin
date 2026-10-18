import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../doctor/domain/medicine_item.dart';
import '../../doctor/presentation/widgets/medicine_search_modal.dart';
import '../data/ship_medicine_api.dart';

/// How "Tambah Stok Obat" ended.
enum AddStockResult {
  added,

  /// Offline: kept in the outbox, sent once the server is reachable.
  savedOffline,
}

/// Opens "Tambah Stok Obat" for one medicine (the web's "Tambah Satuan").
/// Returns null when closed without adding.
Future<AddStockResult?> showAddStockSheet(
  BuildContext context, {
  required String shipCode,
}) {
  return showModalBottomSheet<AddStockResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => AddStockSheet(shipCode: shipCode),
  );
}

class AddStockSheet extends ConsumerStatefulWidget {
  const AddStockSheet({super.key, required this.shipCode});

  final String shipCode;

  @override
  ConsumerState<AddStockSheet> createState() => _AddStockSheetState();
}

class _AddStockSheetState extends ConsumerState<AddStockSheet> {
  final _quantity = TextEditingController();
  final _notes = TextEditingController();
  MedicineItem? _medicine;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _quantity.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _pickMedicine() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      // Master list: any medicine can be added, also one the ship lacks.
      builder: (ctx) => MedicineSearchModal(
        selectedName: _medicine?.name,
        showStock: false,
        offlineShipCode: widget.shipCode,
        onSelect: (_) {},
        onSelectMedicine: (med) {
          setState(() {
            _medicine = med;
            _error = null;
          });
          Navigator.of(ctx).pop();
        },
      ),
    );
  }

  Future<void> _save() async {
    final medicine = _medicine;
    final quantity = int.tryParse(_quantity.text.trim()) ?? 0;
    if (medicine == null) {
      setState(() => _error = 'Silakan pilih obat terlebih dahulu.');
      return;
    }
    if (quantity <= 0) {
      setState(() => _error = 'Jumlah stok harus lebih besar dari 0.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final savedOffline = await ref
          .read(shipMedicineApiProvider)
          .addStock(
            shipCode: widget.shipCode,
            medicineId: medicine.id.isNotEmpty ? medicine.id : medicine.sku,
            medicineName: medicine.name,
            quantity: quantity,
            notes: _notes.text,
          );
      if (mounted) {
        Navigator.of(context).pop(
          savedOffline ? AddStockResult.savedOffline : AddStockResult.added,
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Gagal menambahkan stok obat: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final medicine = _medicine;
    final unit = (medicine?.unitOfMeasurement.isNotEmpty ?? false)
        ? medicine!.unitOfMeasurement
        : 'Unit';

    return Padding(
      // Keep the fields above the keyboard.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Tambah Stok Obat',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.text,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _saving
                          ? null
                          : () => Navigator.of(context).pop(false),
                      icon: const Icon(LucideIcons.x, size: 18),
                      color: AppColors.sub,
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Medicine
                const AppFieldLabel(
                  label: 'Obat',
                  required: true,
                  fontSize: 11,
                ),
                const SizedBox(height: 6),
                InkWell(
                  onTap: _saving ? null : _pickMedicine,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.inputBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: medicine == null
                              ? const Text(
                                  'Pilih obat...',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.sub,
                                    letterSpacing: 0,
                                  ),
                                )
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      medicine.name,
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w500,
                                        color: AppColors.text,
                                        letterSpacing: 0,
                                      ),
                                    ),
                                    Text(
                                      [
                                        medicine.sku,
                                        medicine.category,
                                      ].where((s) => s.isNotEmpty).join(' · '),
                                      style: const TextStyle(
                                        fontSize: 10.5,
                                        color: AppColors.sub,
                                        letterSpacing: 0,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                        const Icon(
                          LucideIcons.chevronDown,
                          size: 16,
                          color: AppColors.sub,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Quantity added on top of the current stock.
                AppTextField(
                  label: 'Jumlah Ditambahkan ($unit)',
                  required: true,
                  controller: _quantity,
                  numbersOnly: true,
                  keyboardType: TextInputType.number,
                  fontSize: 12,
                  labelFontSize: 11,
                  placeholder: 'cth: 10',
                ),
                const SizedBox(height: 12),

                AppTextField(
                  label: 'Catatan',
                  controller: _notes,
                  maxLines: 2,
                  fontSize: 12,
                  labelFontSize: 11,
                  placeholder: 'cth: Restock dari depo pusat (opsional)',
                ),

                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.red,
                      letterSpacing: 0,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                AppButton(
                  label: 'Tambah Stok',
                  icon: LucideIcons.plus,
                  full: true,
                  loading: _saving,
                  onPressed: _saving ? null : _save,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
