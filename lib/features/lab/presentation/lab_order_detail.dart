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
import '../../patients/domain/lab_parameter.dart';
import '../../patients/domain/lab_test_type.dart';
import '../../patients/domain/medical_history.dart';
import '../../patients/domain/patient.dart';
import '../../patients/domain/vitals.dart';
import '../../doctor/presentation/widgets/doctor_exam_summary.dart';
import '../../patients/presentation/patient_info_card.dart';
import 'widgets/lab_result_table.dart';

/// A test outside the lab result form, typed by the analyst.
class _LabItemForm {
  _LabItemForm({
    String testName = '',
    String testCategory = kLabOtherCategory,
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

/// Client check before sending, worded as the backend's.
const kLabResultRequired =
    'Isi hasil pemeriksaan atau unggah lampiran file hasilnya.';

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

/// Port of the prototype's `LabOrderDetail` — input the result on the lab
/// result form (the requested tests' rows, other rows on demand, tests typed
/// by hand) and/or the result document, and send it back to the doctor.
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

  /// Result per lab result form row (`lab_parameter_id`): text rows by
  /// controller, choice rows by value.
  final Map<String, TextEditingController> _resultCtrls = {};
  final Map<String, String> _choices = {};

  /// Form rows added beyond the requested tests.
  final Set<String> _extraParamIds = {};

  /// "Jam datang sampel" (today), optional.
  TimeOfDay? _sampleTime;
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
      _clearResults();
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

  // The form starts from the requested tests' rows (see build).
  void _initItems(LabOrder? order) {}

  void _clearResults() {
    for (final c in _resultCtrls.values) {
      c.dispose();
    }
    _resultCtrls.clear();
    _choices.clear();
    _extraParamIds.clear();
    _sampleTime = null;
  }

  TextEditingController _resultCtrl(String parameterId) =>
      _resultCtrls.putIfAbsent(parameterId, TextEditingController.new);

  /// What was entered per form row.
  Map<String, String> get _results => {
    for (final e in _resultCtrls.entries) e.key: e.value.text,
    ..._choices,
  };

  void _addItem() {
    setState(() {
      _items.add(_LabItemForm());
    });
  }

  void _addParameter(String id) => setState(() => _extraParamIds.add(id));

  void _removeParameter(String id) => setState(() {
    _extraParamIds.remove(id);
    _resultCtrls.remove(id)?.dispose();
    _choices.remove(id);
  });

  Future<void> _pickSampleTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _sampleTime ?? TimeOfDay.now(),
    );
    if (picked != null) setState(() => _sampleTime = picked);
  }

  /// [_sampleTime] today, as sent to the server.
  String? get _sampleReceivedAt {
    final t = _sampleTime;
    if (t == null) return null;
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, t.hour, t.minute)
        .toUtc()
        .toIso8601String();
  }

  bool _filled(_LabItemForm it) => [
    it.testNameCtrl,
    it.resultValueCtrl,
    it.unitCtrl,
    it.referenceRangeCtrl,
    it.notesCtrl,
  ].any((c) => c.text.trim().isNotEmpty);

  /// Something to send: a result on the form or a document.
  bool get _hasResult =>
      _results.values.any((v) => v.trim().isNotEmpty) ||
      _items.any((it) => it.resultValueCtrl.text.trim().isNotEmpty);

  /// Adds a form row that isn't on the form yet.
  void _openParameterSheet(
    List<LabParameter> parameters,
    List<LabParameter> onForm,
  ) {
    final shown = {for (final p in onForm) p.id};
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _LabParameterSearchSheet(
        parameters: [
          for (final p in parameters)
            if (!shown.contains(p.id)) p,
        ],
        onSelect: (id) {
          Navigator.of(sheetContext).pop();
          _addParameter(id);
        },
      ),
    );
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
    for (final c in _resultCtrls.values) {
      c.dispose();
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

  Future<void> _submit(
    Patient patient,
    List<LabParameter> formRows,
    String Function(LabParameter) reference,
  ) async {
    if (_fileName == null && !_hasResult) {
      _showError(kLabResultRequired);
      return;
    }
    if (_items.any((it) => _filled(it) && it.testNameCtrl.text.trim().isEmpty)) {
      _showError('Isi nama pemeriksaan di setiap pemeriksaan lain yang diisi');
      return;
    }

    final formItems = labParameterItems(
      formRows,
      _results,
      reference: reference,
    );
    final otherItems = _items
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
    final validItems = [...formItems, ...otherItems];

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
            sampleReceivedAt: _sampleReceivedAt,
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
    final parameters =
        ref.watch(labParametersProvider).valueOrNull ?? const <LabParameter>[];
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

    // The lab result form: the requested tests' rows, then rows added.
    final requested = requestedParameters(
      parameters,
      requestedLabTestIds(order.jenis, labTests),
    );
    final requestedIds = {for (final p in requested) p.id};
    final formRows = [
      ...requested,
      for (final p in parameters)
        if (_extraParamIds.contains(p.id) && !requestedIds.contains(p.id)) p,
    ];
    final dob =
        DateTime.tryParse(patient.dob ?? '') ??
        (patient.umur > 0
            ? DateTime.now().subtract(Duration(days: patient.umur * 365))
            : null);
    String reference(LabParameter p) =>
        patientReference(p, gender: patient.jk.label, dob: dob);
    final resultItems = (medHistory?.labExaminationItems.isNotEmpty == true)
        ? medHistory!.labExaminationItems
        : (order.hasil?.items ?? const <LabExaminationItem>[]);
    final labExamId = medHistory?.labExamination?['id']?.toString() ?? '';

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
                        '${formRows.length + _items.length} parameter',
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
                if (resultItems.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  LabResultTable(items: resultItems),
                ],
                if (labExamId.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: LabResultPdfButton(labExaminationId: labExamId),
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
                  'Formulir Hasil Pemeriksaan',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Tinggi/Rendah ditandai otomatis dari nilai rujukan pasien. '
                  'Dokumen hasil opsional bila hasil sudah diisi.',
                  style: TextStyle(fontSize: 10.5, color: AppColors.sub),
                ),
                const SizedBox(height: 8),
                _SampleTimeField(
                  time: _sampleTime,
                  onTap: _pickSampleTime,
                  onClear: () => setState(() => _sampleTime = null),
                ),
                const SizedBox(height: 10),
                if (formRows.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Tes yang diminta tidak ada di formulir. Tambahkan '
                      'parameter dari formulir atau ketik pemeriksaan lain.',
                      style: TextStyle(fontSize: 10.5, color: AppColors.sub),
                    ),
                  ),
                for (final (heading, rows) in groupLabParameters(formRows)) ...[
                  _FormHeading(title: heading),
                  for (final p in rows)
                    _ParameterRow(
                      parameter: p,
                      reference: reference(p),
                      controller: p.isSelect ? null : _resultCtrl(p.id),
                      choice: _choices[p.id],
                      onChoice: (v) => setState(() {
                        if (v == null || v.isEmpty) {
                          _choices.remove(p.id);
                        } else {
                          _choices[p.id] = v;
                        }
                      }),
                      onChanged: () => setState(() {}),
                      onRemove: requestedIds.contains(p.id)
                          ? null
                          : () => _removeParameter(p.id),
                    ),
                ],
                for (int i = 0; i < _items.length; i++) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 10, top: 4),
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
                              'Pemeriksaan Lain #${i + 1}',
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
                        AppTextField(
                          label: 'Nama Pemeriksaan',
                          required: true,
                          controller: _items[i].testNameCtrl,
                          labelFontSize: 11,
                          fontSize: 11.5,
                          placeholder: 'cth: Rontgen Thorax',
                          onChanged: (_) => setState(() {}),
                        ),
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
                          placeholder: 'cth: Sampel darah kapiler',
                          onChanged: (_) => setState(() {}),
                        ),
                      ],
                    ),
                  ),
                ],
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 4,
                  children: [
                    TextButton.icon(
                      onPressed: () => _openParameterSheet(parameters, formRows),
                      icon: const Icon(LucideIcons.plus, size: 14),
                      label: const Text(
                        'Tambah parameter lain',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.skyBlue,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _addItem,
                      icon: const Icon(LucideIcons.pencil, size: 14),
                      label: const Text(
                        'Pemeriksaan lain (ketik manual)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.skyBlue,
                      ),
                    ),
                  ],
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
                        text: ' (opsional bila hasil diisi)',
                        style: TextStyle(
                          color: AppColors.sub,
                          fontWeight: FontWeight.w400,
                        ),
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
                  onPressed: (!_saving && (_fileName != null || _hasResult))
                      ? () => _submit(patient, formRows, reference)
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

/// A heading of the lab result form, e.g. "Kimia Klinik / Gula Darah".
class _FormHeading extends StatelessWidget {
  const _FormHeading({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 6, bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.skyLt,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: AppColors.skyBlue,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

/// One row of the lab result form: name, the result (typed, or picked
/// from the row's options), unit, and the patient's reference range.
class _ParameterRow extends StatelessWidget {
  const _ParameterRow({
    required this.parameter,
    required this.reference,
    required this.controller,
    required this.choice,
    required this.onChoice,
    required this.onChanged,
    this.onRemove,
  });

  final LabParameter parameter;
  final String reference;

  /// The result field of a text row; null for a choice row.
  final TextEditingController? controller;
  final String? choice;
  final ValueChanged<String?> onChoice;
  final VoidCallback onChanged;

  /// Set for rows added beyond the requested tests.
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final p = parameter;
    final input = p.isSelect
        ? DropdownButtonFormField<String>(
            key: ValueKey('lab-param-${p.id}'),
            initialValue: choice,
            isExpanded: true,
            hint: const Text(
              'Pilih hasil',
              style: TextStyle(fontSize: 11.5, color: AppColors.sub),
            ),
            style: const TextStyle(fontSize: 11.5, color: AppColors.text),
            decoration: _inputDecoration,
            items: [
              const DropdownMenuItem(value: '', child: Text('-')),
              for (final o in p.options)
                DropdownMenuItem(value: o, child: Text(o)),
            ],
            onChanged: onChoice,
          )
        : TextField(
            key: ValueKey('lab-param-${p.id}'),
            controller: controller,
            onChanged: (_) => onChanged(),
            style: const TextStyle(fontSize: 11.5, color: AppColors.text),
            decoration: _inputDecoration.copyWith(hintText: 'Hasil'),
          );
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.name,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text,
                  ),
                ),
                if (reference.isNotEmpty)
                  Text(
                    'Rujukan: $reference',
                    style: const TextStyle(fontSize: 10, color: AppColors.sub),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(flex: 3, child: input),
          SizedBox(
            width: 56,
            child: Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Text(
                p.unit,
                style: const TextStyle(fontSize: 10.5, color: AppColors.sub),
              ),
            ),
          ),
          if (onRemove != null)
            InkWell(
              onTap: onRemove,
              borderRadius: BorderRadius.circular(6),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(LucideIcons.x, size: 14, color: AppColors.red),
              ),
            ),
        ],
      ),
    );
  }

  static final _inputDecoration = InputDecoration(
    isDense: true,
    filled: true,
    fillColor: Colors.white,
    hintStyle: const TextStyle(fontSize: 11, color: AppColors.sub),
    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: AppColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: AppColors.skyBlue),
    ),
  );
}

/// "Jam datang sampel": when the lab received the sample (today).
class _SampleTimeField extends StatelessWidget {
  const _SampleTimeField({
    required this.time,
    required this.onTap,
    required this.onClear,
  });

  final TimeOfDay? time;
  final VoidCallback onTap;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final t = time;
    final label = t == null
        ? 'Pilih jam (opsional)'
        : '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    return Row(
      children: [
        const Text(
          'Jam Datang Sampel',
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: AppColors.text,
          ),
        ),
        const SizedBox(width: 10),
        OutlinedButton.icon(
          onPressed: onTap,
          icon: const Icon(LucideIcons.clock, size: 13),
          label: Text(label, style: const TextStyle(fontSize: 11.5)),
          style: OutlinedButton.styleFrom(
            foregroundColor: t == null ? AppColors.sub : AppColors.text,
            side: const BorderSide(color: AppColors.border),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
        if (t != null)
          IconButton(
            onPressed: onClear,
            icon: const Icon(LucideIcons.x, size: 14, color: AppColors.red),
            visualDensity: VisualDensity.compact,
          ),
      ],
    );
  }
}

/// Bottom sheet: search the lab result form rows not on the form yet, by
/// name or heading.
class _LabParameterSearchSheet extends StatefulWidget {
  const _LabParameterSearchSheet({
    required this.parameters,
    required this.onSelect,
  });

  final List<LabParameter> parameters;
  final ValueChanged<String> onSelect;

  @override
  State<_LabParameterSearchSheet> createState() =>
      _LabParameterSearchSheetState();
}

class _LabParameterSearchSheetState extends State<_LabParameterSearchSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final groups = groupLabParameters(
      filterLabParameters(widget.parameters, _query),
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
              'Tambah Parameter Pemeriksaan',
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
                hintText: 'Cari parameter atau bagian...',
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
                      'Parameter tidak ditemukan',
                      style: TextStyle(fontSize: 12, color: AppColors.sub),
                    ),
                  ),
                for (final (heading, items) in groups) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 4),
                    child: Text(
                      heading,
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.skyBlue,
                      ),
                    ),
                  ),
                  for (final p in items)
                    InkWell(
                      onTap: () => widget.onSelect(p.id),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 11,
                        ),
                        child: Text(
                          p.name,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.text,
                          ),
                        ),
                      ),
                    ),
                ],
                const SizedBox(height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
