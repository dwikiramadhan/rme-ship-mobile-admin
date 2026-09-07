import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_shimmer.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../patients/data/patient_repository.dart';
import '../../patients/domain/doctor.dart';
import '../../patients/domain/lab_order.dart';
import '../../patients/domain/patient.dart';
import '../../patients/presentation/patient_info_card.dart';

class _LabItemForm {
  _LabItemForm({
    String testName = '',
    String testCategory = 'Kimia Darah',
    String unit = '',
    String referenceRange = '',
    String notes = '',
  }) : testNameCtrl = TextEditingController(text: testName),
       testCategoryCtrl = TextEditingController(text: testCategory),
       unitCtrl = TextEditingController(text: unit),
       referenceRangeCtrl = TextEditingController(text: referenceRange),
       notesCtrl = TextEditingController(text: notes);

  final TextEditingController testNameCtrl;
  final TextEditingController testCategoryCtrl;
  final TextEditingController unitCtrl;
  final TextEditingController referenceRangeCtrl;
  final TextEditingController notesCtrl;

  void dispose() {
    testNameCtrl.dispose();
    testCategoryCtrl.dispose();
    unitCtrl.dispose();
    referenceRangeCtrl.dispose();
    notesCtrl.dispose();
  }
}

/// Port of the prototype's `LabOrderDetail` — input the result (notes +
/// examination items + an optional file attachment) and send it back to the requesting doctor.
class LabOrderDetail extends ConsumerStatefulWidget {
  const LabOrderDetail({super.key, required this.patientId, this.medRecId});

  final String patientId;
  final String? medRecId;

  @override
  ConsumerState<LabOrderDetail> createState() => _LabOrderDetailState();
}

class _LabOrderDetailState extends ConsumerState<LabOrderDetail> {
  final _generalNotesCtrl = TextEditingController();
  final List<_LabItemForm> _items = [];
  String? _fileName;
  bool _saving = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant LabOrderDetail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.patientId != widget.patientId ||
        oldWidget.medRecId != widget.medRecId) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    await Future.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;

    final patients = ref.read(patientsProvider);
    final patient = patients.where((p) => p.id == widget.patientId).firstOrNull;
    _initItems(patient?.labOrder);

    setState(() => _loading = false);
  }

  void _initItems(LabOrder? order) {
    if (_items.isNotEmpty) return;
    final jenis = order?.jenis ?? '';
    final defaultCategory = _inferCategory(jenis);
    _items.add(
      _LabItemForm(
        testName: jenis,
        testCategory: defaultCategory,
        unit: _inferUnit(jenis),
        referenceRange: _inferRefRange(jenis),
      ),
    );
    if (_generalNotesCtrl.text.isEmpty) {
      _generalNotesCtrl.text = (order?.catatan.isNotEmpty == true)
          ? order!.catatan
          : (jenis.isNotEmpty ? 'Pemeriksaan $jenis' : '');
    }
  }

  String _inferCategory(String test) {
    final lower = test.toLowerCase();
    if (lower.contains('darah') ||
        lower.contains('leukosit') ||
        lower.contains('hb') ||
        lower.contains('hemat')) {
      return 'Hematologi';
    } else if (lower.contains('urin')) {
      return 'Urinalisis';
    } else if (lower.contains('gula') ||
        lower.contains('glukosa') ||
        lower.contains('kolesterol') ||
        lower.contains('lipid') ||
        lower.contains('asam urat')) {
      return 'Kimia Darah';
    } else if (lower.contains('widal') ||
        lower.contains('antigen') ||
        lower.contains('hiv') ||
        lower.contains('hbsag')) {
      return 'Imunoserologi';
    }
    return 'Kimia Darah';
  }

  String _inferUnit(String test) {
    final lower = test.toLowerCase();
    if (lower.contains('glukosa') ||
        lower.contains('gula') ||
        lower.contains('kolesterol') ||
        lower.contains('asam urat')) {
      return 'mg/dL';
    } else if (lower.contains('hb') || lower.contains('hemoglobin')) {
      return 'g/dL';
    } else if (lower.contains('leukosit') ||
        lower.contains('trombosit') ||
        lower.contains('eritrosit')) {
      return '/µL';
    }
    return '';
  }

  String _inferRefRange(String test) {
    final lower = test.toLowerCase();
    if (lower.contains('glukosa') || lower.contains('gula')) {
      return '< 200';
    } else if (lower.contains('kolesterol')) {
      return '< 200';
    } else if (lower.contains('hb') || lower.contains('hemoglobin')) {
      return '12.0 - 16.0';
    }
    return '';
  }

  void _addItem() {
    setState(() {
      _items.add(
        _LabItemForm(
          testName: '',
          testCategory: 'Kimia Darah',
          unit: 'mg/dL',
          referenceRange: '< 200',
          notes: '',
        ),
      );
    });
  }

  void _removeItem(int index) {
    if (_items.length <= 1) return;
    setState(() {
      final removed = _items.removeAt(index);
      removed.dispose();
    });
  }

  @override
  void dispose() {
    _generalNotesCtrl.dispose();
    for (final it in _items) {
      it.dispose();
    }
    super.dispose();
  }

  Future<void> _pickFile() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
    );
    if (file != null) {
      setState(() => _fileName = file.name);
    }
  }

  Future<void> _submit(Patient patient) async {
    final validItems = _items
        .where((it) => it.testNameCtrl.text.trim().isNotEmpty)
        .map(
          (it) => {
            'test_name': it.testNameCtrl.text.trim(),
            'test_category': it.testCategoryCtrl.text.trim().isNotEmpty
                ? it.testCategoryCtrl.text.trim()
                : 'Kimia Darah',
            'unit': it.unitCtrl.text.trim(),
            'reference_range': it.referenceRangeCtrl.text.trim(),
            'notes': it.notesCtrl.text.trim(),
          },
        )
        .toList();

    if (validItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Harap masukkan minimal 1 nama parameter pemeriksaan lab',
          ),
          backgroundColor: AppColors.red,
        ),
      );
      return;
    }

    final generalNotes = _generalNotesCtrl.text.trim().isNotEmpty
        ? _generalNotesCtrl.text.trim()
        : (patient.labOrder?.catatan.isNotEmpty == true
              ? patient.labOrder!.catatan
              : 'Pemeriksaan ${patient.labOrder?.jenis ?? 'Laboratorium'}');

    // Resolve IDs
    final effectiveMedRecId =
        (widget.medRecId != null && widget.medRecId!.isNotEmpty)
        ? widget.medRecId!
        : ((patient.medicalRecordId != null &&
                  patient.medicalRecordId!.isNotEmpty)
              ? patient.medicalRecordId!
              : patient.id);

    final validDoctorIds = kDoctors.map((d) => d.id).toSet();
    String effectiveDoctorId = '0f3a4534-3385-4305-8932-7154dd8cb35f';
    if (patient.assignedDokterId.isNotEmpty &&
        (validDoctorIds.contains(patient.assignedDokterId) ||
            patient.assignedDokterId.length > 20)) {
      effectiveDoctorId = patient.assignedDokterId;
    }

    final authState = ref.read(authControllerProvider);
    final currentUserId = authState.session?.user.id ?? '';
    final effectiveLabPersonnelId =
        (currentUserId.isNotEmpty && currentUserId.length > 20)
        ? currentUserId
        : '453b5c3a-4390-4ad7-bb09-8840cb8f33cf';

    setState(() => _saving = true);
    try {
      await ref
          .read(patientsProvider.notifier)
          .submitLabExaminations(
            medicalRecordId: effectiveMedRecId,
            patientId: patient.id,
            doctorId: effectiveDoctorId,
            labPersonnelId: effectiveLabPersonnelId,
            notes: generalNotes,
            items: validItems,
            fileName: _fileName,
          );

      // Refresh lab order list
      ref.read(labOrderHistoryProvider.notifier).fetchHistory(refresh: true);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Hasil pemeriksaan lab berhasil dikirim ke dokter'),
          backgroundColor: AppColors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal mengirim hasil lab: $e'),
          backgroundColor: AppColors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final patients = ref.watch(patientsProvider);
    final patient = patients.where((p) => p.id == widget.patientId).firstOrNull;
    if (_loading || patient == null) {
      return const SkeletonPatientDetail();
    }
    final order = patient.labOrder;
    if (order == null) return const SizedBox.shrink();

    // Ensure items are initialized if opened freshly
    _initItems(order);

    final doctor =
        (patient.doctorName != null && patient.doctorName!.isNotEmpty)
        ? patient.doctorName!
        : (kDoctors
                  .where((d) => d.id == patient.assignedDokterId)
                  .map((d) => d.nama)
                  .firstOrNull ??
              '—');
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
              const Text(
                'ORDER PEMERIKSAAN',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.blue,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                order.jenis,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Diminta oleh $doctor',
                style: const TextStyle(fontSize: 11.5, color: AppColors.sub),
              ),
              if (order.catatan.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.card2,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    order.catatan,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.text,
                    ),
                  ),
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'HASIL PEMERIKSAAN',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.blue,
                    ),
                  ),
                  if (!done)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.purpleLt,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${_items.length} parameter',
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.purple,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              if (done) ...[
                Text(
                  order.hasil?.catatanHasil ?? '',
                  style: const TextStyle(fontSize: 12, color: AppColors.text),
                ),
                if (order.hasil?.items != null &&
                    order.hasil!.items.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  const Text(
                    'PARAMETER PEMERIKSAAN',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.sub,
                    ),
                  ),
                  const SizedBox(height: 6),
                  for (final item in order.hasil!.items)
                    Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.card2,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.testName,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.text,
                                  ),
                                ),
                                if (item.testCategory.isNotEmpty)
                                  Text(
                                    item.testCategory,
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      color: AppColors.sub,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                item.notes.isNotEmpty
                                    ? item.notes
                                    : (item.unit.isNotEmpty
                                          ? '- ${item.unit}'
                                          : '—'),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.purple,
                                ),
                              ),
                              if (item.referenceRange.isNotEmpty)
                                Text(
                                  'Rujukan: ${item.referenceRange} ${item.unit}',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: AppColors.sub,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                ],
                if (order.hasil?.fileName != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    '📎 ${order.hasil!.fileName}',
                    style: const TextStyle(fontSize: 11, color: AppColors.sub),
                  ),
                ],
                const SizedBox(height: 10),
                const Text(
                  '✓ Hasil telah dikirim ke dokter',
                  style: TextStyle(
                    color: AppColors.green,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ] else ...[
                // Parameter Form List
                for (int i = 0; i < _items.length; i++) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.card2,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border, width: 1.0),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'PARAMETER #${i + 1}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.text,
                                letterSpacing: 0.3,
                              ),
                            ),
                            if (_items.length > 1)
                              InkWell(
                                onTap: () => _removeItem(i),
                                borderRadius: BorderRadius.circular(6),
                                child: const Padding(
                                  padding: EdgeInsets.all(4),
                                  child: Icon(
                                    LucideIcons.trash2,
                                    size: 14,
                                    color: AppColors.red,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 3,
                              child: AppTextField(
                                label: 'Nama Tes / Parameter',
                                required: true,
                                controller: _items[i].testNameCtrl,
                                labelFontSize: 11,
                                fontSize: 11.5,
                                placeholder: 'cth: Glukosa Sewaktu',
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: AppTextField(
                                label: 'Kategori',
                                controller: _items[i].testCategoryCtrl,
                                labelFontSize: 11,
                                fontSize: 11.5,
                                placeholder: 'cth: Kimia Darah',
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: AppTextField(
                                label: 'Nilai Rujukan',
                                controller: _items[i].referenceRangeCtrl,
                                labelFontSize: 11,
                                fontSize: 11.5,
                                placeholder: 'cth: < 200',
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: AppTextField(
                                label: 'Satuan',
                                controller: _items[i].unitCtrl,
                                labelFontSize: 11,
                                fontSize: 11.5,
                                placeholder: 'cth: mg/dL',
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        AppTextField(
                          label: 'Catatan / Hasil Parameter',
                          controller: _items[i].notesCtrl,
                          labelFontSize: 11,
                          fontSize: 11.5,
                          placeholder:
                              'cth: Hasil: 110 mg/dL / Sampel darah kapiler',
                          onChanged: (_) => setState(() {}),
                        ),
                      ],
                    ),
                  ),
                ],

                OutlinedButton.icon(
                  onPressed: _addItem,
                  icon: const Icon(LucideIcons.plus, size: 14),
                  label: const Text(
                    'Tambah Parameter Pemeriksaan',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.purple,
                    side: const BorderSide(color: AppColors.purple, width: 1.2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                AppTextField(
                  label: 'Catatan Umum Pemeriksaan Lab',
                  required: true,
                  controller: _generalNotesCtrl,
                  labelFontSize: 11.5,
                  fontSize: 12,
                  maxLines: 2,
                  placeholder:
                      'cth: Pemeriksaan gula darah rutin dan profil lipid',
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 11),

                const Text(
                  'Lampiran File (opsional)',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 6),
                Material(
                  color: AppColors.inputBg,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: _pickFile,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border, width: 1.5),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            LucideIcons.upload,
                            size: 15,
                            color: AppColors.blue,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _fileName ?? 'Unggah hasil scan / PDF',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: _fileName != null
                                    ? AppColors.text
                                    : AppColors.sub,
                              ),
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
                  onPressed:
                      (_items.any(
                            (it) => it.testNameCtrl.text.trim().isNotEmpty,
                          ) &&
                          !_saving)
                      ? () => _submit(patient)
                      : null,
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
