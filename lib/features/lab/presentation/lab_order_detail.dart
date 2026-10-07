import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/clean_text_helper.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_shimmer.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../patients/data/patient_repository.dart';
import '../../patients/domain/doctor.dart';
import '../../patients/domain/lab_order.dart';
import '../../patients/domain/patient.dart';
import '../../patients/presentation/patient_info_card.dart';

class _LabItemForm {
  _LabItemForm({
    String testName = '',
    String testCategory = '',
    String resultValue = '',
    String unit = '',
    String referenceRange = '',
    String status = 'Normal',
    String notes = '',
  }) : testNameCtrl = TextEditingController(text: testName),
       testCategoryCtrl = TextEditingController(text: testCategory),
       resultValueCtrl = TextEditingController(text: resultValue),
       unitCtrl = TextEditingController(text: unit),
       referenceRangeCtrl = TextEditingController(text: referenceRange),
       statusCtrl = TextEditingController(text: status),
       notesCtrl = TextEditingController(text: notes);

  final TextEditingController testNameCtrl;
  final TextEditingController testCategoryCtrl;
  final TextEditingController resultValueCtrl;
  final TextEditingController unitCtrl;
  final TextEditingController referenceRangeCtrl;
  final TextEditingController statusCtrl;
  final TextEditingController notesCtrl;

  void dispose() {
    testNameCtrl.dispose();
    testCategoryCtrl.dispose();
    resultValueCtrl.dispose();
    unitCtrl.dispose();
    referenceRangeCtrl.dispose();
    statusCtrl.dispose();
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
  final _conclusionCtrl = TextEditingController();
  final List<_LabItemForm> _items = [];
  PlatformFile? _pickedFile;
  Uint8List? _fileBytes;
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
      _items.clear();
      _generalNotesCtrl.clear();
      _conclusionCtrl.clear();
      _fileName = null;
      _pickedFile = null;
      _fileBytes = null;
      _load();
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    await Future.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;

    final labHistories = ref.read(labOrderHistoryProvider);
    final medHistories = ref.read(medicalHistoryProvider);
    final medHistory = (widget.medRecId != null && widget.medRecId!.isNotEmpty)
        ? (labHistories.where((h) => h.id == widget.medRecId).firstOrNull ??
              medHistories.where((h) => h.id == widget.medRecId).firstOrNull)
        : (labHistories
                  .where((h) => h.patientId == widget.patientId)
                  .firstOrNull ??
              medHistories
                  .where((h) => h.patientId == widget.patientId)
                  .firstOrNull);

    final patients = ref.read(patientsProvider);
    final patient =
        patients.where((p) => p.id == widget.patientId).firstOrNull ??
        medHistory?.toPatient();
    _initItems(patient?.labOrder);

    setState(() => _loading = false);
  }

  void _initItems(LabOrder? order) {
    if (_items.isEmpty) {
      _items.add(_LabItemForm());
    }
  }

  void _addItem() {
    setState(() {
      _items.add(_LabItemForm());
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
    _conclusionCtrl.dispose();
    for (final it in _items) {
      it.dispose();
    }
    super.dispose();
  }

  Future<void> _pickFile() async {
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );
      if (file != null) {
        final bytes = await file.readAsBytes();
        setState(() {
          _pickedFile = file;
          _fileBytes = bytes;
          _fileName = file.name;
        });
      }
    } catch (e) {
      debugPrint('⚠️ Error picking file: $e');
    }
  }

  Future<void> _submit(Patient patient) async {
    final validItems = _items
        .where((it) => it.testNameCtrl.text.trim().isNotEmpty)
        .map(
          (it) => {
            'test_name': it.testNameCtrl.text.trim(),
            'test_category': it.testCategoryCtrl.text.trim(),
            'result_value': it.resultValueCtrl.text.trim().isNotEmpty
                ? it.resultValueCtrl.text.trim()
                : it.notesCtrl.text.trim(),
            'unit': it.unitCtrl.text.trim(),
            'reference_range': it.referenceRangeCtrl.text.trim(),
            'status': it.statusCtrl.text.trim().isNotEmpty
                ? it.statusCtrl.text.trim()
                : 'Normal',
            'notes': it.notesCtrl.text.trim().isNotEmpty
                ? it.notesCtrl.text.trim()
                : it.resultValueCtrl.text.trim(),
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

    final labHistories = ref.read(labOrderHistoryProvider);
    final medHistories = ref.read(medicalHistoryProvider);
    final medHistory = (widget.medRecId != null && widget.medRecId!.isNotEmpty)
        ? (labHistories.where((h) => h.id == widget.medRecId).firstOrNull ??
              medHistories.where((h) => h.id == widget.medRecId).firstOrNull)
        : (labHistories
                  .where((h) => h.patientId == widget.patientId)
                  .firstOrNull ??
              medHistories
                  .where((h) => h.patientId == widget.patientId)
                  .firstOrNull);

    final uuidRegex = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );

    // Resolve doctorId: only send if it's a valid UUID and not dummy mock ID.
    // If null/omitted, backend automatically defaults to record.DoctorID.
    final assignedDocId =
        (medHistory?.doctorId != null && medHistory!.doctorId!.isNotEmpty)
        ? medHistory.doctorId!
        : patient.assignedDokterId;

    String? effectiveDoctorId;
    if (assignedDocId.isNotEmpty && uuidRegex.hasMatch(assignedDocId)) {
      effectiveDoctorId = assignedDocId;
    }

    // Do NOT send user.id or dummy UUID as labPersonnelId because
    // lab_examinations.lab_personnel_id references medical_personnel(id), not users(id).
    // Leaving it null allows PostgreSQL to store NULL without violating FK constraints.
    String? effectiveLabPersonnelId;

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
            conclusion: _conclusionCtrl.text.trim(),
            items: validItems,
            fileName: _fileName,
            filePath: _pickedFile?.path,
            fileBytes: _fileBytes,
          );

      // Refresh lab order list and medical histories
      unawaited(
        ref.read(labOrderHistoryProvider.notifier).fetchHistory(refresh: true),
      );
      unawaited(
        ref.read(medicalHistoryProvider.notifier).fetchHistory(refresh: true),
      );

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
    final labHistories = ref.watch(labOrderHistoryProvider);
    final medHistories = ref.watch(medicalHistoryProvider);
    final medHistory = (widget.medRecId != null && widget.medRecId!.isNotEmpty)
        ? (labHistories.where((h) => h.id == widget.medRecId).firstOrNull ??
              medHistories.where((h) => h.id == widget.medRecId).firstOrNull)
        : (labHistories
                  .where((h) => h.patientId == widget.patientId)
                  .firstOrNull ??
              medHistories
                  .where((h) => h.patientId == widget.patientId)
                  .firstOrNull);

    final patients = ref.watch(patientsProvider);
    final patient =
        patients.where((p) => p.id == widget.patientId).firstOrNull ??
        medHistory?.toPatient();

    if (_loading && patient == null) {
      return const SkeletonPatientDetail();
    }
    if (patient == null) {
      return const SkeletonPatientDetail();
    }

    final effectiveStatus =
        (medHistory?.statusPenanganan ??
                medHistory?.status ??
                patient.statusPenanganan ??
                '')
            .trim()
            .toLowerCase();
    final isMedRecSelesai =
        effectiveStatus == 'selesai' || effectiveStatus == 'completed';

    final order =
        patient.labOrder ??
        LabOrder(
          id: medHistory?.id ?? widget.patientId,
          jenis:
              (medHistory?.tindakanDetail != null &&
                  medHistory!.tindakanDetail!.isNotEmpty &&
                  medHistory.tindakanDetail != '—')
              ? medHistory.tindakanDetail!
              : ((medHistory?.treatment != null &&
                        medHistory!.treatment!.isNotEmpty &&
                        medHistory.treatment != '—')
                    ? medHistory.treatment!
                    : 'Pemeriksaan Laboratorium'),
          catatan: medHistory?.notes ?? '',
          status: isMedRecSelesai
              ? LabOrderStatus.selesai
              : LabOrderStatus.baru,
        );

    // Ensure items are initialized if opened freshly
    _initItems(order);

    final doctorsList = ref.watch(doctorsProvider).valueOrNull ?? kDoctors;
    final effectiveDoctorId =
        (medHistory?.doctorId != null && medHistory!.doctorId!.isNotEmpty)
        ? medHistory.doctorId!
        : patient.assignedDokterId;

    Doctor? matchedDoctor;
    if (effectiveDoctorId.isNotEmpty) {
      matchedDoctor = doctorsList
          .where((d) => d.id.toLowerCase() == effectiveDoctorId.toLowerCase())
          .firstOrNull;
    }

    String resolvedDoctorName = CleanTextHelper.cleanName(
      medHistory?.doctorName,
    );
    if (resolvedDoctorName.isEmpty) {
      resolvedDoctorName = CleanTextHelper.cleanName(patient.doctorName);
    }
    if (resolvedDoctorName.isEmpty && matchedDoctor != null) {
      resolvedDoctorName = CleanTextHelper.cleanName(matchedDoctor.nama);
    }
    final doctor = resolvedDoctorName.isNotEmpty ? resolvedDoctorName : '—';
    final done = order.status == LabOrderStatus.selesai || isMedRecSelesai;

    final jenisItems = order.jenis
        .split(RegExp(r'[\n\r,;•]+'))
        .map((s) => s.replaceAll(RegExp(r'^\s*[-*•\d+.\)]\s*'), '').trim())
        .where((s) => s.isNotEmpty)
        .toList();
    final displayJenisItems = jenisItems.isNotEmpty
        ? jenisItems
        : (order.jenis.trim().isNotEmpty
              ? [order.jenis.trim()]
              : const <String>[]);

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
                'Hasil Pemeriksaan Dokter',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.blue,
                ),
              ),
              Text.rich(
                TextSpan(
                  text: 'Diminta oleh ',
                  style: const TextStyle(fontSize: 11.5, color: AppColors.sub),
                  children: [
                    TextSpan(
                      text: doctor,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              if (displayJenisItems.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (int i = 0; i < displayJenisItems.length; i++)
                      Padding(
                        padding: EdgeInsets.only(
                          bottom: i == displayJenisItems.length - 1 ? 0 : 5,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              margin: const EdgeInsets.only(top: 6, right: 8),
                              width: 5,
                              height: 5,
                              decoration: const BoxDecoration(
                                color: AppColors.sky,
                                shape: BoxShape.circle,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                displayJenisItems[i],
                                style: const TextStyle(
                                  fontSize: 12,
                                  // fontWeight: FontWeight.w500,
                                  color: AppColors.text,
                                  height: 1,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                )
              else
                Text(
                  order.jenis.isNotEmpty ? order.jenis : '—',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text,
                  ),
                ),
              const SizedBox(height: 6),
              if (order.catatan.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.orangeLt.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.orange.withValues(alpha: 0.22),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            LucideIcons.messageSquare,
                            size: 13,
                            // color: AppColors.orange,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Catatan Khusus Dokter',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              // color: AppColors.orange,
                              letterSpacing: 0.1,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        order.catatan,
                        style: const TextStyle(
                          fontSize: 11,
                          // fontWeight: FontWeight.w500,
                          color: AppColors.text,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 11),
        AppCard(
          border: Border.all(color: AppColors.orange),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Hasil Pemeriksaan Lab',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.blue,
                    ),
                  ),
                  if (done)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.greenLt,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Selesai',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.green,
                        ),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.skyLt,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${_items.length} parameter',
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: AppColors.skyBlue,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              if (done) ...[
                if (order.hasil?.catatanHasil != null &&
                    order.hasil!.catatanHasil.trim().isNotEmpty) ...[
                  Text(
                    order.hasil!.catatanHasil,
                    style: const TextStyle(fontSize: 12, color: AppColors.text),
                  ),
                  const SizedBox(height: 8),
                ] else if (medHistory?.notes != null &&
                    medHistory!.notes!.trim().isNotEmpty &&
                    !medHistory.notes!.contains('Order Lab:')) ...[
                  Text(
                    medHistory.notes!,
                    style: const TextStyle(fontSize: 12, color: AppColors.text),
                  ),
                  const SizedBox(height: 8),
                ],
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
                if (medHistory?.labExamination?['conclusion']?.toString().trim().isNotEmpty == true) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.skyLt,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Kesimpulan Lab:',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.blue,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          medHistory!.labExamination!['conclusion'].toString(),
                          style: const TextStyle(fontSize: 11.5, color: AppColors.text),
                        ),
                      ],
                    ),
                  ),
                ],
                if ((order.hasil?.fileName?.isNotEmpty == true) ||
                    (medHistory?.labAttachmentUrl?.isNotEmpty == true)) ...[
                  const SizedBox(height: 8),
                  Text(
                    '📎 ${(order.hasil?.fileName?.isNotEmpty == true ? order.hasil!.fileName : medHistory?.labAttachmentUrl) ?? ''}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.sub,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.greenLt,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        LucideIcons.checkCircle2,
                        size: 15,
                        color: AppColors.green,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Pemeriksaan Lab telah selesai & hasil telah dikirim ke dokter',
                          style: TextStyle(
                            color: AppColors.green,
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
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
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Parameter #${i + 1}',
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
                                placeholder: 'cth: Hemoglobin',
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
                                placeholder: 'cth: Hematologi',
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
                              flex: 3,
                              child: AppTextField(
                                label: 'Hasil / Nilai Tes',
                                required: true,
                                controller: _items[i].resultValueCtrl,
                                labelFontSize: 11,
                                fontSize: 11.5,
                                placeholder: 'cth: 14.2',
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: AppTextField(
                                label: 'Satuan',
                                controller: _items[i].unitCtrl,
                                labelFontSize: 11,
                                fontSize: 11.5,
                                placeholder: 'cth: g/dL',
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
                              flex: 3,
                              child: AppTextField(
                                label: 'Nilai Rujukan',
                                controller: _items[i].referenceRangeCtrl,
                                labelFontSize: 11,
                                fontSize: 11.5,
                                placeholder: 'cth: 13.0-17.0',
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: AppTextField(
                                label: 'Status',
                                controller: _items[i].statusCtrl,
                                labelFontSize: 11,
                                fontSize: 11.5,
                                placeholder: 'cth: Normal',
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        AppTextField(
                          label: 'Catatan Parameter (opsional)',
                          controller: _items[i].notesCtrl,
                          labelFontSize: 11,
                          fontSize: 11.5,
                          placeholder:
                              'cth: Sampel darah kapiler',
                          onChanged: (_) => setState(() {}),
                        ),
                      ],
                    ),
                  ),
                ],

                Center(
                  child: TextButton.icon(
                    onPressed: _addItem,
                    icon: const Icon(LucideIcons.plus, size: 14),
                    label: const Text(
                      'Tambah Parameter Pemeriksaan',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.skyBlue,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                AppTextField(
                  label: 'Catatan Umum Pemeriksaan Lab',
                  required: true,
                  controller: _generalNotesCtrl,
                  labelFontSize: 11.5,
                  fontSize: 11,
                  maxLines: 2,
                  placeholder:
                      'cth: Pemeriksaan Darah Rutin',
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 10),

                AppTextField(
                  label: 'Kesimpulan Hasil Lab (opsional)',
                  controller: _conclusionCtrl,
                  labelFontSize: 11.5,
                  fontSize: 11,
                  maxLines: 2,
                  placeholder:
                      'cth: Hb dan Leukosit normal',
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
                          LucideIcons.paperclip,
                          size: 15,
                          color: AppColors.blue,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: InkWell(
                            onTap: _pickFile,
                            child: Text(
                              _fileName ?? 'Unggah hasil scan / PDF',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: _fileName != null
                                    ? AppColors.text
                                    : AppColors.sub,
                              ),
                            ),
                          ),
                        ),
                        if (_fileName != null)
                          InkWell(
                            onTap: () {
                              setState(() {
                                _fileName = null;
                                _pickedFile = null;
                              });
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: const Padding(
                              padding: EdgeInsets.all(4),
                              child: Icon(
                                LucideIcons.x,
                                size: 14,
                                color: AppColors.red,
                              ),
                            ),
                          )
                        else
                          InkWell(
                            onTap: _pickFile,
                            child: const Icon(
                              LucideIcons.upload,
                              size: 14,
                              color: AppColors.sub,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                AppButton(
                  label: 'Kirim Hasil ke Dokter',
                  // icon: LucideIcons.check,
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
