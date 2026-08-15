import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../patients/data/mock_patient_repository.dart';
import '../../patients/domain/doctor.dart';
import '../../patients/domain/lab_order.dart';
import '../../patients/presentation/patient_info_card.dart';

/// Port of the prototype's `LabOrderDetail` — input the result (notes + an
/// optional file attachment) and send it back to the requesting doctor.
class LabOrderDetail extends ConsumerStatefulWidget {
  const LabOrderDetail({super.key, required this.patientId});

  final String patientId;

  @override
  ConsumerState<LabOrderDetail> createState() => _LabOrderDetailState();
}

class _LabOrderDetailState extends ConsumerState<LabOrderDetail> {
  final _catatanHasil = TextEditingController();
  String? _fileName;
  bool _saving = false;

  @override
  void dispose() {
    _catatanHasil.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final file = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png']);
    if (file != null) {
      setState(() => _fileName = file.name);
    }
  }

  Future<void> _submit(String patientId) async {
    if (_catatanHasil.text.trim().isEmpty) return;
    setState(() => _saving = true);
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    ref.read(patientsProvider.notifier).submitLabHasil(id: patientId, catatanHasil: _catatanHasil.text.trim(), fileName: _fileName);
    setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final patients = ref.watch(patientsProvider);
    final patient = patients.firstWhere((p) => p.id == widget.patientId);
    final order = patient.labOrder;
    if (order == null) return const SizedBox.shrink();

    final doctor = kDoctors.where((d) => d.id == patient.assignedDokterId).map((d) => d.nama).firstOrNull ?? '—';
    final done = order.status == LabOrderStatus.selesai;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PatientInfoCard(patient: patient),
        const SizedBox(height: 11),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('ORDER PEMERIKSAAN', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.blue)),
              const SizedBox(height: 10),
              Text(order.jenis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.text)),
              const SizedBox(height: 6),
              Text('Diminta oleh $doctor', style: const TextStyle(fontSize: 12.5, color: AppColors.sub)),
              if (order.catatan.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
                  decoration: BoxDecoration(color: AppColors.card2, borderRadius: BorderRadius.circular(10)),
                  child: Text(order.catatan, style: const TextStyle(fontSize: 12.5, color: AppColors.text)),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 11),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('HASIL PEMERIKSAAN', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.blue)),
              const SizedBox(height: 10),
              if (done) ...[
                Text(order.hasil?.catatanHasil ?? '', style: const TextStyle(fontSize: 13, color: AppColors.text)),
                if (order.hasil?.fileName != null) ...[
                  const SizedBox(height: 8),
                  Text('📎 ${order.hasil!.fileName}', style: const TextStyle(fontSize: 12, color: AppColors.sub)),
                ],
                const SizedBox(height: 10),
                const Text('✓ Hasil telah dikirim ke dokter', style: TextStyle(color: AppColors.green, fontWeight: FontWeight.w700, fontSize: 13)),
              ] else ...[
                AppTextField(
                  label: 'Catatan / Nilai Hasil',
                  required: true,
                  controller: _catatanHasil,
                  maxLines: 4,
                  placeholder: 'cth: Hb 11.2 g/dL, Leukosit 9.800/µL, Trombosit 260.000/µL',
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 11),
                const Text('Lampiran File (opsional)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text)),
                const SizedBox(height: 6),
                Material(
                  color: AppColors.inputBg,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: _pickFile,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border, width: 1.5)),
                      child: Row(
                        children: [
                          const Icon(LucideIcons.upload, size: 16, color: AppColors.blue),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              _fileName ?? 'Unggah hasil scan / PDF',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _fileName != null ? AppColors.text : AppColors.sub),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                AppButton(
                  label: 'Kirim Hasil ke Dokter',
                  icon: LucideIcons.check,
                  full: true,
                  loading: _saving,
                  loadingLabel: 'Mengirim...',
                  onPressed: (_catatanHasil.text.trim().isNotEmpty && !_saving) ? () => _submit(patient.id) : null,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
