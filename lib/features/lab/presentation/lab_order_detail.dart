import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../sync/presentation/sync_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_shimmer.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/vital_tile.dart';
import '../../patients/data/patient_repository.dart';
import '../../patients/domain/clinical_notes.dart';
import '../../patients/domain/lab_order.dart';
import '../../patients/domain/lab_test_type.dart';
import '../../patients/domain/medical_history.dart';
import '../../patients/domain/patient.dart';
import '../../patients/domain/vitals.dart';
import '../../doctor/presentation/widgets/doctor_exam_summary.dart';
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

  /// The picked lab test (master `GET /lab-tests`), or [_otherTest] when the
  /// analyst types the name; '' = none picked yet.
  String labTestId = '';
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

/// Dropdown value for a test that isn't in the master list.
const _otherTest = '__other__';

/// A picked result document.
typedef LabDocument = ({String name, Uint8List bytes, String? path});

/// Picks the lab result document (PDF/JPG/PNG); null when cancelled.
/// Tests swap in a fake.
final labDocumentPickerProvider = Provider<Future<LabDocument?> Function()>(
  (ref) => () async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
    );
    if (file == null) return null;
    return (name: file.name, bytes: await file.readAsBytes(), path: file.path);
  },
);

/// Port of the prototype's `LabOrderDetail` — input the result (the result
/// document, notes, and optional per-test values) and send it back to the
/// requesting doctor.
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
  String? _filePath;
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
      _filePath = null;
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

  // Per-test values are optional: the result document holds the full result.
  void _initItems(LabOrder? order) {}

  void _addItem() {
    setState(() {
      _items.add(_LabItemForm());
    });
  }

  /// Row [index] now reports [labTestId]: name and category from the master.
  void _pickTest(int index, String labTestId, List<LabTestType> tests) {
    final item = _items[index];
    final test = tests.where((t) => t.id == labTestId).firstOrNull;
    setState(() {
      item.labTestId = labTestId;
      item.testNameCtrl.text = test?.name ?? '';
      item.testCategoryCtrl.text = labTestId == _otherTest
          ? kLabOtherCategory
          : (test?.category ?? '');
    });
  }

  void _removeItem(int index) {
    setState(() {
      final removed = _items.removeAt(index);
      removed.dispose();
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.red),
    );
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
      final file = await ref.read(labDocumentPickerProvider)();
      if (file != null) {
        setState(() {
          _filePath = file.path;
          _fileBytes = file.bytes;
          _fileName = file.name;
        });
      }
    } catch (e) {
      debugPrint('⚠️ Error picking file: $e');
    }
  }

  Future<void> _submit(Patient patient) async {
    if (_fileName == null) {
      _showError('Dokumen hasil lab wajib diunggah');
      return;
    }
    bool filled(_LabItemForm it) => [
      it.testNameCtrl,
      it.resultValueCtrl,
      it.unitCtrl,
      it.referenceRangeCtrl,
      it.notesCtrl,
    ].any((c) => c.text.trim().isNotEmpty);
    if (_items.any((it) => filled(it) && it.testNameCtrl.text.trim().isEmpty)) {
      _showError('Pilih pemeriksaan di setiap baris hasil yang diisi');
      return;
    }

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
            filePath: _filePath,
            fileBytes: _fileBytes,
          );
      // Offline: kept in the outbox instead of sent.
      final savedOffline =
          (ref.read(syncServiceProvider)?.status.pending ?? 0) > 0;

      // Refresh lab order list and medical histories
      unawaited(
        ref.read(labOrderHistoryProvider.notifier).fetchHistory(refresh: true),
      );
      unawaited(
        ref.read(medicalHistoryProvider.notifier).fetchHistory(refresh: true),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            savedOffline
                ? 'Hasil lab tersimpan di perangkat dan akan dikirim otomatis ke dokter saat koneksi kembali'
                : 'Hasil pemeriksaan lab berhasil dikirim ke dokter',
          ),
          backgroundColor: savedOffline ? AppColors.yellow : AppColors.green,
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
    final labTests =
        ref.watch(labTestsProvider).valueOrNull ?? const <LabTestType>[];
    // Select only the entries this pane shows so list-wide updates
    // (WS polls, paging) don't rebuild it.
    MedicalHistory? findHistory(List<MedicalHistory> list) =>
        (widget.medRecId != null && widget.medRecId!.isNotEmpty)
        ? list.where((h) => h.id == widget.medRecId).firstOrNull
        : list.where((h) => h.patientId == widget.patientId).firstOrNull;
    final labMatch = ref.watch(labOrderHistoryProvider.select(findHistory));
    final medMatch = ref.watch(medicalHistoryProvider.select(findHistory));
    final medHistory = labMatch ?? medMatch;

    final patient =
        ref.watch(
          patientsProvider.select(
            (patients) =>
                patients.where((p) => p.id == widget.patientId).firstOrNull,
          ),
        ) ??
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

    // The referral saved on the server wins; older records fall back to
    // what can be derived from the visit.
    final order =
        medHistory?.requestedLabOrder ??
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

    // Doctor's examination for the selected record (not whichever visit
    // patientsProvider last loaded), with the lab order resolved above.
    final examPatient = (medHistory?.toPatient() ?? patient).copyWith(
      labOrder: order,
    );
    // A visit still at "Menunggu Lab" is waiting for results by definition.
    final isMenungguLab = effectiveStatus == 'menunggu lab';
    final done = isMedRecSelesai ||
        (!isMenungguLab && order.status == LabOrderStatus.selesai);
    final visitVitals = medHistory?.vitals ?? const Vitals();
    final noteVitals = _VitalValues.fromVitals(visitVitals);
    // Referral saved by the doctor (requested_test / doctor_notes). Its note
    // is shown in the request box, so the other box then only holds vitals.
    final referral = medHistory?.requestedLabOrder;
    final boxNote = referral != null ? '' : order.catatan;
    final showNoteBox = boxNote.isNotEmpty || noteVitals.hasAny;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PatientInfoCard(patient: patient),
        const SizedBox(height: 11),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DoctorExamSummary(
                patient: examPatient,
                examResult: doctorExamResult(medHistory?.notes),
                beforeDiagnosis: (referral != null || showNoteBox)
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (referral != null) _LabRequestBox(order: referral),
                          if (referral != null && showNoteBox)
                            const SizedBox(height: 10),
                          if (showNoteBox)
                            _DoctorNoteBox(
                              note: boxNote,
                              vitals: noteVitals,
                              title: referral != null
                                  ? 'Tanda Vital Pasien'
                                  : 'Catatan Khusus Dokter',
                            ),
                        ],
                      )
                    : null,
              ),
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
                const Text(
                  'Hasil per Pemeriksaan (opsional)',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Hasil lengkap ada di dokumen lampiran. Isi bila ingin mencatat nilai tiap pemeriksaan.',
                  style: TextStyle(fontSize: 10.5, color: AppColors.sub),
                ),
                const SizedBox(height: 8),
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
                              'Pemeriksaan #${i + 1}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.text,
                                letterSpacing: 0.3,
                              ),
                            ),
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
                        _LabTestPicker(
                          tests: labTests,
                          value: _items[i].labTestId,
                          category: _items[i].testCategoryCtrl.text,
                          onChanged: (id) => _pickTest(i, id, labTests),
                        ),
                        if (_items[i].labTestId == _otherTest) ...[
                          const SizedBox(height: 8),
                          AppTextField(
                            label: 'Nama Pemeriksaan',
                            required: true,
                            controller: _items[i].testNameCtrl,
                            labelFontSize: 11,
                            fontSize: 11.5,
                            placeholder: 'cth: Rontgen Thorax',
                            onChanged: (_) => setState(() {}),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 3,
                              child: AppTextField(
                                label: 'Hasil / Nilai Tes',
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
                                capitalizeFirst: false,
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
                          label: 'Catatan (opsional)',
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
                      'Tambah Hasil Pemeriksaan',
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

                const Text.rich(
                  TextSpan(
                    text: 'Dokumen Hasil Lab',
                    children: [
                      TextSpan(
                        text: ' *',
                        style: TextStyle(color: AppColors.red),
                      ),
                    ],
                  ),
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
                                _filePath = null;
                                _fileBytes = null;
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
                  onPressed: (_fileName != null && !_saving)
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

/// Orange "Catatan Khusus Dokter" box: the doctor's note for the lab, with
/// triage vitals rendered as a VitalTile grid.
class _DoctorNoteBox extends StatelessWidget {
  const _DoctorNoteBox({
    required this.note,
    this.vitals = _VitalValues.empty,
    this.title = 'Catatan Khusus Dokter',
  });

  final String note;
  final String title;

  /// The visit's recorded vital signs; fills in what the note doesn't say.
  final _VitalValues vitals;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.orangeLt.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.orange.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.messageSquare, size: 13),
              const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          _DoctorNoteContent(note: note, vitals: vitals),
        ],
      ),
    );
  }
}

/// The doctor's lab referral: the requested examination and the note for
/// the analyst (lab_examination.requested_test / doctor_notes).
class _LabRequestBox extends StatelessWidget {
  const _LabRequestBox({required this.order});

  final LabOrder order;

  @override
  Widget build(BuildContext context) {
    final note = order.catatan.trim();
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 11),
      decoration: BoxDecoration(
        color: AppColors.skyLt.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.sky.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(LucideIcons.flaskConical, size: 13, color: AppColors.sky),
              SizedBox(width: 6),
              Text(
                'Permintaan Pemeriksaan Lab',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.sky,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _LabRequestField(label: 'Jenis Pemeriksaan', value: order.jenis),
          if (order.requiresFasting) ...[
            const SizedBox(height: 4),
            const Text(
              'Pasien perlu puasa sebelum pengambilan sampel',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.orange,
              ),
            ),
          ],
          const SizedBox(height: 8),
          _LabRequestField(label: 'Catatan untuk Analis', value: note),
        ],
      ),
    );
  }
}

class _LabRequestField extends StatelessWidget {
  const _LabRequestField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final empty = value.trim().isEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w600,
            color: AppColors.sub,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          empty ? '-' : value.trim(),
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: empty ? FontWeight.w400 : FontWeight.w600,
            color: empty ? AppColors.sub : AppColors.text,
          ),
        ),
      ],
    );
  }
}

/// Vital signs pulled out of a triage-style note such as
/// "[Triage] Durasi: 2 hari | TD: 120/80 | Nadi: 80 | Suhu: 36.5 | RR: 20 | SpO2: 98".
/// Same format the repository writes and `Patient` parses.
class _ParsedDoctorNote {
  const _ParsedDoctorNote({
    required this.td,
    required this.nadi,
    required this.suhu,
    required this.rr,
    required this.spo2,
    required this.otherParts,
  });

  factory _ParsedDoctorNote.parse(String note) {
    var td = '', nadi = '', suhu = '', rr = '', spo2 = '';
    final otherParts = <String>[];

    String valueAfter(String part, List<String> prefixes) {
      for (final prefix in prefixes) {
        if (part.startsWith(prefix)) return part.substring(prefix.length).trim();
      }
      return '';
    }

    for (final rawPart in note.split('|')) {
      final part = rawPart.replaceFirst('[Triage]', '').trim();
      if (part.isEmpty) continue;
      if (part.startsWith('TD:')) {
        td = valueAfter(part, ['TD:']);
      } else if (part.startsWith('Nadi:') || part.startsWith('HR:')) {
        nadi = valueAfter(part, ['Nadi:', 'HR:']);
      } else if (part.startsWith('Suhu:') || part.startsWith('Temp:')) {
        suhu = valueAfter(part, ['Suhu:', 'Temp:']);
      } else if (part.startsWith('RR:')) {
        rr = valueAfter(part, ['RR:']);
      } else if (part.startsWith('SpO2:')) {
        spo2 = valueAfter(part, ['SpO2:']);
      } else {
        otherParts.add(part);
      }
    }

    return _ParsedDoctorNote(
      td: td,
      nadi: nadi,
      suhu: suhu,
      rr: rr,
      spo2: spo2,
      otherParts: otherParts,
    );
  }

  final String td;
  final String nadi;
  final String suhu;
  final String rr;
  final String spo2;
  final List<String> otherParts;

  bool get hasVitals => [td, nadi, suhu, rr, spo2].any((v) => v.isNotEmpty);
}

/// Body of the "Catatan Khusus Dokter" box: vital signs as the same
/// VitalTile grid used on the doctor's medical-history detail, followed by the
/// rest of the note. Notes without vitals render as plain text, as before.
class _DoctorNoteContent extends StatelessWidget {
  const _DoctorNoteContent({required this.note, this.vitals = _VitalValues.empty});

  final String note;
  final _VitalValues vitals;

  static const _textStyle = TextStyle(
    fontSize: 11,
    color: AppColors.text,
    height: 1.3,
  );

  @override
  Widget build(BuildContext context) {
    final parsed = _ParsedDoctorNote.parse(note);
    // Values written in the note win; the visit's recorded vitals fill gaps.
    String pick(String fromNote, String recorded) =>
        fromNote.isNotEmpty ? fromNote : recorded;
    final td = pick(parsed.td, vitals.td);
    final nadi = pick(parsed.nadi, vitals.nadi);
    final suhu = pick(parsed.suhu, vitals.suhu);
    final rr = pick(parsed.rr, vitals.rr);
    final spo2 = pick(parsed.spo2, vitals.spo2);
    final hasVitals = [td, nadi, suhu, rr, spo2].any((v) => v.isNotEmpty);
    if (!hasVitals) {
      return Text(note, style: _textStyle);
    }
    final rest = parsed.hasVitals ? parsed.otherParts.join(' · ') : note.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            // Same breakpoints/spacing as the doctor's vitals grid.
            final w = constraints.maxWidth;
            final int crossAxisCount = w >= 700 ? 5 : (w >= 440 ? 3 : 2);
            final double childAspectRatio =
                w >= 700 ? 2.1 : (w >= 440 ? 2.6 : 2.5);

            return GridView.count(
              padding: EdgeInsets.zero,
              crossAxisCount: crossAxisCount,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: childAspectRatio,
              children: [
                VitalTile(
                  icon: LucideIcons.heart,
                  label: 'Tekanan Darah',
                  value: td,
                  unit: 'mmHg',
                  color: AppColors.red,
                ),
                VitalTile(
                  icon: LucideIcons.activity,
                  label: 'Nadi',
                  value: nadi,
                  unit: 'bpm',
                  color: AppColors.blue,
                ),
                VitalTile(
                  icon: LucideIcons.thermometer,
                  label: 'Suhu Tubuh',
                  value: suhu,
                  unit: '°C',
                  color: AppColors.yellow,
                ),
                VitalTile(
                  icon: LucideIcons.activity,
                  label: 'Frek. Napas',
                  value: rr,
                  unit: 'x/mnt',
                  color: AppColors.purple,
                ),
                VitalTile(
                  icon: LucideIcons.droplet,
                  label: 'SpO₂',
                  value: spo2,
                  unit: '%',
                  color: AppColors.green,
                ),
              ],
            );
          },
        ),
        if (rest.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(rest, style: _textStyle),
        ],
      ],
    );
  }
}

/// Display strings for the five vital signs (empty when not recorded).
class _VitalValues {
  const _VitalValues({
    this.td = '',
    this.nadi = '',
    this.suhu = '',
    this.rr = '',
    this.spo2 = '',
  });

  static const empty = _VitalValues();

  factory _VitalValues.fromVitals(Vitals v) {
    String number(num? n) =>
        n == null ? '' : (n % 1 == 0 ? n.toInt().toString() : n.toString());
    String text(String s, num? fallback) =>
        s.trim().isNotEmpty ? s.trim() : number(fallback);
    return _VitalValues(
      td: v.tekananDarah.trim(),
      nadi: text(v.nadi, v.heartRate),
      suhu: text(v.suhu, v.temperature),
      rr: text(v.frekuensiNapas, v.respiratoryRate),
      spo2: text(v.spo2, v.oxygenSaturation),
    );
  }

  final String td;
  final String nadi;
  final String suhu;
  final String rr;
  final String spo2;

  bool get hasAny => [td, nadi, suhu, rr, spo2].any((v) => v.isNotEmpty);
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

/// "Jenis Pemeriksaan": opens [_LabTestSearchSheet] to search the master lab
/// tests (or pick "Lainnya" for one that isn't listed). The category follows
/// the picked test.
class _LabTestPicker extends StatelessWidget {
  const _LabTestPicker({
    required this.tests,
    required this.value,
    required this.category,
    required this.onChanged,
  });

  final List<LabTestType> tests;
  final String value;
  final String category;
  final ValueChanged<String> onChanged;

  void _open(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _LabTestSearchSheet(
        tests: tests,
        selectedId: value,
        onSelect: (id) {
          Navigator.of(sheetContext).pop();
          onChanged(id);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selected = tests.where((t) => t.id == value).firstOrNull;
    final label = value == _otherTest
        ? 'Lainnya (ketik manual)'
        : (selected?.name ?? '');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text.rich(
          TextSpan(
            text: 'Jenis Pemeriksaan',
            children: [
              TextSpan(
                text: ' *',
                style: TextStyle(color: AppColors.red),
              ),
            ],
          ),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.text,
          ),
        ),
        const SizedBox(height: 5),
        InkWell(
          onTap: () => _open(context),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label.isEmpty ? 'Pilih pemeriksaan...' : label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: label.isEmpty ? AppColors.sub : AppColors.text,
                    ),
                  ),
                ),
                const Icon(
                  LucideIcons.chevronDown,
                  size: 14,
                  color: AppColors.sub,
                ),
              ],
            ),
          ),
        ),
        if (value.isNotEmpty && value != _otherTest) ...[
          const SizedBox(height: 4),
          Text(
            'Kategori: ${category.isEmpty ? '-' : category}',
            style: const TextStyle(fontSize: 10.5, color: AppColors.sub),
          ),
        ],
      ],
    );
  }
}

/// Bottom sheet: search the lab tests by name or category, listed under
/// their category, plus "Lainnya (ketik manual)".
class _LabTestSearchSheet extends StatefulWidget {
  const _LabTestSearchSheet({
    required this.tests,
    required this.selectedId,
    required this.onSelect,
  });

  final List<LabTestType> tests;
  final String selectedId;
  final ValueChanged<String> onSelect;

  @override
  State<_LabTestSearchSheet> createState() => _LabTestSearchSheetState();
}

class _LabTestSearchSheetState extends State<_LabTestSearchSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final groups = groupLabTests(filterLabTests(widget.tests, _query));
    Widget option(String id, String label) => InkWell(
      onTap: () => widget.onSelect(id),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
        color: id == widget.selectedId ? AppColors.skyLt : null,
        child: Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.text),
        ),
      ),
    );

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: const BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(18, 16, 18, 8),
            child: Text(
              'Pilih Jenis Pemeriksaan',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.text,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            child: TextField(
              autofocus: true,
              onChanged: (v) => setState(() => _query = v),
              style: const TextStyle(fontSize: 12),
              decoration: InputDecoration(
                hintText: 'Cari pemeriksaan atau kategori...',
                hintStyle: const TextStyle(fontSize: 11.5, color: AppColors.sub),
                prefixIcon: const Icon(
                  LucideIcons.search,
                  size: 16,
                  color: AppColors.sub,
                ),
                isDense: true,
                filled: true,
                fillColor: AppColors.inputBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
              ),
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                if (groups.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(18),
                    child: Text(
                      'Pemeriksaan tidak ditemukan',
                      style: TextStyle(fontSize: 12, color: AppColors.sub),
                    ),
                  ),
                for (final (category, items) in groups) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 4),
                    child: Text(
                      category,
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.skyBlue,
                      ),
                    ),
                  ),
                  for (final t in items) option(t.id, t.name),
                ],
                const Divider(height: 1, color: AppColors.border),
                option(_otherTest, 'Lainnya (ketik manual)'),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
