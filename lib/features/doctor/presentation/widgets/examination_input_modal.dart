import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/notifications/in_app_notification_manager.dart';
import '../../../../core/notifications/in_app_notification_model.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_select.dart';
import '../../../../core/widgets/circle_icon_button.dart';
import '../../../auth/presentation/auth_controller.dart';
import '../../../patients/data/patient_repository.dart';
import '../../../patients/domain/clinical_notes.dart';
import '../../../patients/domain/doctor.dart';
import '../../../patients/domain/doctor_referral.dart';
import '../../../lab/presentation/widgets/lab_result_table.dart';
import '../../../patients/domain/lab_order.dart';
import '../../../patients/domain/lab_test_type.dart';
import '../../../patients/domain/medical_history.dart';
import '../../../patients/domain/patient.dart';
import '../../../patients/domain/pending_prescription.dart';
import '../../../patients/domain/prescription_item.dart';
import '../../../schedule/data/schedule_repository.dart';
import '../../../sync/presentation/sync_providers.dart';
import '../../data/icd10_api.dart';
import '../../data/icd9_api.dart';
import '../../domain/icd10_item.dart';
import '../../domain/icd9_item.dart';
import 'icd10_search_picker.dart';
import 'icd9_search_picker.dart';
import 'medicine_search_modal.dart';
import '../../../../core/utils/capitalize_first_formatter.dart';
import '../../../patients/presentation/widgets/lab_document_viewer.dart';

/// Dosis options
const List<String> _kDosisList = [
  '1x1',
  '2x1',
  '3x1',
  '4x1',
  '1x2',
  '2x2',
  '1x0.5',
  'Sesuai kebutuhan (PRN)',
];

/// Aturan pakai options
const List<String> _kAturanPakaiList = [
  'Sesudah makan',
  'Sebelum makan',
  'Bersama makan',
  'Sebelum tidur',
  'Input manual',
];

/// Status kondisi pasien: nilai yang disimpan → label untuk dokter
/// ("Stable" ditampilkan "Baik").
const List<(String, String)> _kStatusKondisiList = [
  ('Stable', 'Baik'),
  ('Kritis', 'Kritis'),
  ('Perlu Rujukan', 'Perlu Rujukan'),
  ('Dipulangkan', 'Dipulangkan'),
  ('Rawat Inap', 'Di Rawat Inap'),
];

/// Status yang membuka form rujuk ke dokter lain.
const String _kReferralStatus = 'Perlu Rujukan';

class _ResepRowData {
  String? obat;
  String? sku;
  int? stock;
  String? category;
  String satuan = 'Tablet';
  String aturanPakai = 'Sesudah makan';
  final TextEditingController jumlahCtrl = TextEditingController(text: '1');
  // Dosis bebas diketik; daftar _kDosisList hanya saran.
  final TextEditingController dosisCtrl = TextEditingController(text: '3x1');
  final TextEditingController customInstruksiCtrl = TextEditingController();

  int get jumlah => int.tryParse(jumlahCtrl.text.trim()) ?? 1;

  String get dosis => dosisCtrl.text.trim();

  String get instruksi {
    final base = aturanPakai == 'Input manual'
        ? (customInstruksiCtrl.text.trim().isNotEmpty
              ? customInstruksiCtrl.text.trim()
              : 'Sesuai anjuran')
        : aturanPakai;
    return '$jumlah $satuan ($dosis, $base)';
  }

  void dispose() {
    jumlahCtrl.dispose();
    dosisCtrl.dispose();
    customInstruksiCtrl.dispose();
  }
}

/// Helper to show the Examination Input Modal
Future<bool?> showExaminationInputModal(
  BuildContext context, {
  required Patient patient,
  required MedicalHistory history,
  bool editing = false,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    useSafeArea: true,
    builder: (ctx) => ExaminationInputModal(
      patient: patient,
      history: history,
      editing: editing,
    ),
  );
}

class ExaminationInputModal extends ConsumerStatefulWidget {
  const ExaminationInputModal({
    super.key,
    required this.patient,
    required this.history,
    this.editing = false,
  });

  final Patient patient;
  final MedicalHistory history;

  /// The examining doctor changes their exam while the pharmacy hasn't
  /// dispensed anything: the form starts from the visit, and can't refer
  /// (the backend only takes a referral while the patient is being examined).
  final bool editing;

  @override
  ConsumerState<ExaminationInputModal> createState() =>
      _ExaminationInputModalState();
}

class _ExaminationInputModalState extends ConsumerState<ExaminationInputModal> {
  final List<Icd10Item> _diagnosaList = [];
  final List<Icd9Item> _tindakanList = [];
  final _tindakanFreetext = TextEditingController();

  // Lab referral
  bool _needLab = false;
  // "Tidak" hides the medicine picker; no prescription goes to the pharmacy.
  bool _needMeds = true;
  // Tests ticked from the lab request form (master `GET /lab-tests`).
  final Set<String> _selectedLabIds = {};
  final _labOther = TextEditingController();
  final _catatanLab = TextEditingController();

  // Referral to another doctor on the ongoing trip (not with a lab referral):
  // shown when the condition is "Perlu Rujukan".
  bool get _refers => _statusKondisi == _kReferralStatus;
  String? _referToId;
  final _referReason = TextEditingController();

  // Operation (Major / Minor / null)
  String? _operation;

  // Prescriptions
  final List<_ResepRowData> _resep = [_ResepRowData()];

  /// Medicine the pharmacy already dispensed (while the patient was at the
  /// lab): shown locked, and not sent again.
  final List<ResepItem> _dispensedResep = [];

  // Status kondisi
  String _statusKondisi = 'Stable';

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final rawOp =
        widget.history.operation ??
        widget.history.rawJson['operation'] ??
        widget.history.rawJson['Operation'];
    if (rawOp is String && rawOp.isNotEmpty) {
      _operation = rawOp;
    }
    if (_isFollowUp || _referredFrom != null || widget.editing) {
      _prefillFromVisit();
    }
    _prefillPrescriptions();
    // Warm up ICD-10 and ICD-9 caches eagerly so pickers open with 0ms delay
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(icd10ApiProvider).prefetchInitial();
        ref.read(icd9ApiProvider).prefetchInitial();
      }
    });
  }

  /// Back from the lab: the doctor continues the earlier exam.
  bool get _isFollowUp => widget.history.isLabFollowUp;

  /// Referred by another doctor: their latest referral.
  DoctorReferral? get _referredFrom =>
      referralsOf(widget.history.rawJson).lastOrNull;

  void _setNeedLab(bool value) => setState(() => _needLab = value);
  void _setNeedMeds(bool value) => setState(() => _needMeds = value);

  // When referring the doctor can still fill in the exam and diagnosis
  // (optional) and order a lab: the patient goes to the lab first, and the
  // result goes to the referred doctor.
  void _setStatusKondisi(String value) =>
      setState(() => _statusKondisi = value);

  /// Fills the form with what the doctor already recorded for this visit
  /// (diagnoses, procedures, condition), so continuing after the lab doesn't
  /// start from an empty form.
  void _prefillFromVisit() {
    final h = widget.history;
    final raw = h.rawJson;

    List<(String, String)> icdList(dynamic list) => [
      if (list is List)
        for (final e in list)
          if (e is Map && '${e['code'] ?? ''}'.trim().isNotEmpty)
            (
              '${e['code']}'.trim(),
              '${e['display'] ?? e['name'] ?? e['code']}'.trim(),
            ),
    ];

    _diagnosaList.addAll([
      for (final (code, display) in icdList(raw['diagnoses']))
        Icd10Item(code: code, display: display),
    ]);
    if (_diagnosaList.isEmpty) {
      for (final code in (h.diagnosis ?? '').split(',')) {
        final c = code.trim();
        if (c.isNotEmpty && c != '-' && c != '—') {
          _diagnosaList.add(Icd10Item(code: c, display: c));
        }
      }
    }
    _tindakanList.addAll([
      for (final (code, display) in icdList(raw['procedures']))
        Icd9Item(code: code, display: display),
    ]);

    // "Perlu Rujukan" isn't carried over: the doctor it was referred to
    // doesn't refer again by default.
    final status = (h.status ?? '').trim();
    if (status != _kReferralStatus &&
        _kStatusKondisiList.any((s) => s.$1 == status)) {
      _statusKondisi = status;
    }
  }

  /// The visit's prescription so far (e.g. given with a lab referral): what
  /// the pharmacy dispensed is locked, the rest can still be changed.
  void _prefillPrescriptions() {
    final prescriptions = widget.history.rawJson['prescriptions'];
    if (prescriptions is List && prescriptions.isNotEmpty) {
      final rows = <_ResepRowData>[];
      for (final p in prescriptions) {
        if (p is! Map) continue;
        if (isDispensedPrescription(p)) {
          _dispensedResep.add(ResepItem.fromJson(Map<String, dynamic>.from(p)));
          continue;
        }
        final medicine = p['medicine'] is Map ? p['medicine'] as Map : const {};
        final name = '${medicine['name'] ?? p['name'] ?? p['sku'] ?? ''}'
            .trim();
        if (name.isEmpty) continue;
        final row = _ResepRowData()
          ..obat = name
          ..sku = p['sku']?.toString();
        final unit = '${medicine['unit'] ?? ''}'.trim();
        if (unit.isNotEmpty) row.satuan = unit;
        final dosage = '${p['dosage'] ?? ''}'.trim();
        if (dosage.isNotEmpty) row.dosisCtrl.text = dosage;
        row.jumlahCtrl.text = '${p['quantity'] ?? 1}';
        final instructions = '${p['instructions'] ?? ''}'.trim();
        if (_kAturanPakaiList.contains(instructions)) {
          row.aturanPakai = instructions;
        } else if (instructions.isNotEmpty) {
          row.aturanPakai = 'Input manual';
          row.customInstruksiCtrl.text = instructions;
        }
        rows.add(row);
      }
      if (rows.isNotEmpty) {
        for (final r in _resep) {
          r.dispose();
        }
        _resep
          ..clear()
          ..addAll(rows);
      }
    }
  }

  @override
  void dispose() {
    _tindakanFreetext.dispose();
    _catatanLab.dispose();
    _labOther.dispose();
    _referReason.dispose();
    for (final r in _resep) {
      r.dispose();
    }
    super.dispose();
  }

  void _showMedicineSearch(int index) {
    final user = ref.read(authControllerProvider).session?.user;
    final effectiveShipCode = widget.patient.serviceShipCode?.isNotEmpty == true
        ? widget.patient.serviceShipCode!
        : (widget.history.shipCode?.isNotEmpty == true
              ? widget.history.shipCode!
              : (user?.shipCode?.isNotEmpty == true
                    ? user!.shipCode!
                    : (user?.shipId ?? '')));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => MedicineSearchModal(
        shipCode: effectiveShipCode,
        selectedName: _resep[index].obat,
        onSelect: (medName) {
          setState(() => _resep[index].obat = medName);
          Navigator.of(ctx).pop();
        },
        onSelectMedicine: (med) {
          setState(() {
            _resep[index].obat = med.name;
            _resep[index].sku = med.sku;
            _resep[index].stock = med.stock;
            _resep[index].category = med.category;
            if (med.unitOfMeasurement.isNotEmpty) {
              _resep[index].satuan = med.unitOfMeasurement;
            }
          });
          Navigator.of(ctx).pop();
        },
      ),
    );
  }

  /// The required fields still empty; "Simpan" stays disabled until they're
  /// filled in.
  List<String> get _missingFields => [
    // A doctor referral doesn't need the exam filled in; an edit adds to the
    // exam already saved.
    if (!_refers && !widget.editing && _tindakanFreetext.text.trim().isEmpty)
      'Hasil Pemeriksaan',
    if (!_refers && _diagnosaList.isEmpty) 'Diagnosa Klinis (ICD-10)',
    if (_needMeds && !_resep.any((r) => (r.obat ?? '').isNotEmpty))
      'Obat (atau pilih Tidak Perlu Obat)',
    if (_needLab && _selectedLabIds.isEmpty && _labOther.text.trim().isEmpty)
      'Jenis Pemeriksaan Lab',
    if (_refers && (_referToId ?? '').isEmpty) 'Dokter Tujuan Rujukan',
    if (_refers && _referReason.text.trim().isEmpty) 'Alasan Rujukan',
  ];

  /// Shown in the banner at the top of the app: a SnackBar would sit behind
  /// this sheet.
  void _showError(String title, String message) {
    ref
        .read(inAppNotificationProvider.notifier)
        .showNotification(
          InAppNotificationItem(
            id: 'exam_error_${DateTime.now().millisecondsSinceEpoch}',
            title: title,
            message: message,
            type: InAppNotificationType.warning,
          ),
        );
  }

  Future<void> _submit() async {
    if (_missingFields.isNotEmpty) return;

    final validResep = _needMeds
        ? _resep.where((r) => r.obat != null && r.obat!.isNotEmpty).toList()
        : <_ResepRowData>[];

    final patientId = widget.patient.id.isNotEmpty
        ? widget.patient.id
        : (widget.history.patientId.isNotEmpty
              ? widget.history.patientId
              : widget.history.rawJson['patient_id']?.toString() ?? '');

    final recordId = widget.history.id.isNotEmpty
        ? widget.history.id
        : (widget.history.rawJson['id']?.toString() ?? '');

    if (patientId.isEmpty || recordId.isEmpty) {
      _showError(
        'Gagal Menyimpan Rekam Medis',
        'ID Pasien atau ID Rekam Medis tidak valid.',
      );
      return;
    }

    final labTests = [
      for (final t in ref.read(labTestsProvider).valueOrNull ?? <LabTestType>[])
        if (_selectedLabIds.contains(t.id)) t,
    ];
    final requestedTest = buildRequestedTest(labTests, _labOther.text);

    setState(() => _saving = true);

    try {
      final resepItems = [
        for (final r in validResep)
          ResepItem(obat: r.obat!, dosis: r.dosis, instruksi: r.instruksi),
      ];

      LabOrder? labOrder;
      if (_needLab == true) {
        labOrder = LabOrder(
          id: 'L${100 + resepItems.length + DateTime.now().millisecond}',
          jenis: requestedTest,
          catatan: _catatanLab.text.trim(),
          requiresFasting: labTests.any((t) => t.requiresFasting),
        );
      }

      final diagnosaFormatted = _diagnosaList
          .map((d) => d.code.isNotEmpty ? d.code : d.display)
          .where((s) => s.isNotEmpty)
          .join(', ');

      final List<String> allTindakan = [];
      for (final d in _tindakanList) {
        final val = d.code.isNotEmpty ? d.code : d.display;
        if (val.isNotEmpty) allTindakan.add(val);
      }
      final tindakanFormatted = allTindakan.join(', ');

      final noteText = _tindakanFreetext.text.trim();
      // The lab comes first (also when referring: the result goes to the
      // referred doctor). No referral, lab, or new medicine: the visit is done
      // (it doesn't go to the pharmacy queue).
      final statusPenanganan = _needLab
          ? 'Menunggu Lab'
          : _refers
          ? 'Menunggu Dokter'
          : validResep.isNotEmpty
          ? 'Menunggu Obat'
          : 'Selesai';

      final prescriptionsPayload = [
        for (final r in validResep)
          {
            'sku': (r.sku != null && r.sku!.isNotEmpty)
                ? r.sku!
                : (r.obat ?? ''),
            'quantity': r.jumlah,
            'dosage': r.dosis,
            'instructions': r.aturanPakai == 'Input manual'
                ? (r.customInstruksiCtrl.text.trim().isNotEmpty
                      ? r.customInstruksiCtrl.text.trim()
                      : 'Sesuai anjuran')
                : r.aturanPakai,
          },
      ];

      final body = <String, dynamic>{
        // A referral leaves out what is empty, so the exam and prescription
        // already on the visit aren't cleared.
        if (!_refers || diagnosaFormatted.isNotEmpty)
          'diagnosis': diagnosaFormatted,
        if (!_refers || tindakanFormatted.isNotEmpty)
          'treatment': tindakanFormatted,
        if (_operation != null && _operation!.isNotEmpty)
          'operation': _operation,
        if (!_refers || noteText.isNotEmpty) 'note': noteText,
        'status': _statusKondisi,
        'status_penanganan': statusPenanganan,
        if (!_refers || prescriptionsPayload.isNotEmpty)
          'prescriptions': prescriptionsPayload,
        // Saved by the backend as a Pending lab order for the analyst.
        if (labOrder != null) 'lab_order': labOrderRequestJson(labOrder),
        // The other doctor takes the visit over (after the lab, if ordered).
        if (_refers)
          'referral': referralRequestJson(
            toDoctorId: _referToId!,
            reason: _referReason.text,
          ),
      };

      await ref
          .read(patientsProvider.notifier)
          .patchMedicalRecord(
            patientId: patientId,
            recordId: recordId,
            body: body,
            resep: body.containsKey('prescriptions') ? resepItems : null,
            labOrder: labOrder,
          );

      if (!mounted) return;
      // Offline: kept in the outbox instead of sent.
      final savedOffline =
          (ref.read(syncServiceProvider)?.status.pending ?? 0) > 0;

      final currentUserId =
          ref.read(authControllerProvider).session?.user.id ?? '';

      // Immediately update local state in history providers so list status updates instantly
      ref
          .read(medicalHistoryProvider.notifier)
          .updateHistoryStatus(
            recordId: recordId,
            patientId: patientId,
            statusPenanganan: statusPenanganan,
            diagnosis: diagnosaFormatted,
            treatment: tindakanFormatted,
            notes: body.containsKey('note') ? noteText : null,
          );
      if (currentUserId.isNotEmpty) {
        ref
            .read(medicalHistoryByUserProvider(currentUserId).notifier)
            .updateHistoryStatus(
              recordId: recordId,
              patientId: patientId,
              statusPenanganan: statusPenanganan,
              diagnosis: diagnosaFormatted,
              treatment: tindakanFormatted,
              notes: body.containsKey('note') ? noteText : null,
            );
      }

      ref.read(notificationsProvider.notifier).markDoctorSeen(recordId);
      ref.read(patientsProvider.notifier).markDilihatDokter(patientId);

      // Refresh data from API for both all-history and doctor-specific history
      unawaited(
        ref.read(medicalHistoryProvider.notifier).fetchHistory(refresh: true),
      );
      // Only refresh lists that already exist; reading them here would
      // create them and fire an extra initial fetch on top of the refresh.
      if (currentUserId.isNotEmpty &&
          ref.exists(medicalHistoryByUserProvider(currentUserId))) {
        unawaited(
          ref
              .read(medicalHistoryByUserProvider(currentUserId).notifier)
              .fetchHistory(refresh: true),
        );
      }
      if (ref.exists(pharmacyPrescriptionHistoryProvider)) {
        unawaited(
          ref
              .read(pharmacyPrescriptionHistoryProvider.notifier)
              .fetchHistory(refresh: true),
        );
      }
      unawaited(ref.read(patientsProvider.notifier).fetchPatients());
      unawaited(
        ref.read(notificationsProvider.notifier).fetchRecentNotifications(),
      );

      Navigator.of(context).pop(true);

      ref
          .read(inAppNotificationProvider.notifier)
          .showNotification(
            InAppNotificationItem(
              id: 'success_save_${DateTime.now().millisecondsSinceEpoch}',
              title: savedOffline
                  ? 'Rekam Medis Tersimpan Offline'
                  : 'Rekam Medis Berhasil Disimpan',
              message: savedOffline
                  ? 'Pemeriksaan ${widget.patient.nama} tersimpan di perangkat dan akan dikirim otomatis saat koneksi kembali.'
                  : _refers
                  ? 'Pemeriksaan ${widget.patient.nama} tersimpan dan pasien dirujuk ke dokter tujuan.'
                  : 'Data pemeriksaan klinis dan resep untuk ${widget.patient.nama} berhasil disimpan ke sistem.',
              type: savedOffline
                  ? InAppNotificationType.warning
                  : InAppNotificationType.success,
              patientId: patientId,
            ),
          );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showError('Gagal Menyimpan Rekam Medis', '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);

    return DefaultTextStyle.merge(
      style: const TextStyle(letterSpacing: 0),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 780,
            maxHeight: mediaQuery.size.height * 0.92,
          ),
          child: Container(
            decoration: const BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 20,
                  offset: Offset(0, -4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. Drag Handle
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // 2. Header
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: AppColors.orangeLt,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              _isFollowUp
                                  ? LucideIcons.flaskConical
                                  : LucideIcons.stethoscope,
                              size: 16,
                              color: AppColors.orange,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.editing
                                    ? 'Edit Rekam Medis'
                                    : _isFollowUp
                                    ? 'Lanjutan Pemeriksaan (Setelah Lab)'
                                    : 'Form Input Rekam Medis',
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.text,
                                  letterSpacing: 0,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${widget.patient.nama} • RM: ${widget.patient.registerNo.isNotEmpty ? widget.patient.registerNo : widget.patient.id}',
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  color: AppColors.sub,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 0,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      CircleIconButton(
                        icon: LucideIcons.x,
                        size: 32,
                        foreground: AppColors.sub,
                        onPressed: () => Navigator.of(context).pop(false),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: AppColors.border),

                // 3. Scrollable Form Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.only(
                      left: 20,
                      right: 20,
                      top: 18,
                      bottom: mediaQuery.viewInsets.bottom + 20,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Lab results the doctor is continuing from.
                        if (_isFollowUp) ...[
                          _LabResultSummary(history: widget.history),
                          const SizedBox(height: 16),
                        ],
                        if (_referredFrom case final referral?) ...[
                          _ReferredFromCard(
                            referral: referral,
                            previousExam: doctorExamResult(
                              widget.history.notes,
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Section 1: Hasil Pemeriksaan *
                        Text.rich(
                          TextSpan(
                            text: 'Hasil Pemeriksaan',
                            children: [
                              TextSpan(
                                text: _refers || widget.editing
                                    ? ' (Opsional)'
                                    : ' *',
                                style: TextStyle(
                                  color: _refers || widget.editing
                                      ? AppColors.sub
                                      : AppColors.red,
                                ),
                              ),
                            ],
                          ),
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.text,
                            letterSpacing: 0,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _tindakanFreetext,
                          textCapitalization: freeTextCapitalization,
                          inputFormatters: freeTextFormatters,
                          maxLines: 2,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: AppColors.text,
                            letterSpacing: 0,
                          ),
                          decoration: InputDecoration(
                            hintText: widget.editing
                                ? 'Tambahan hasil pemeriksaan (opsional)...'
                                : 'Tuliskan hasil pemeriksaan fisik / temuan klinis pasien...',
                            hintStyle: const TextStyle(
                              fontSize: 10.5,
                              color: AppColors.sub,
                              letterSpacing: 0,
                            ),
                            filled: true,
                            fillColor: AppColors.inputBg,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                color: AppColors.border,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                color: AppColors.orange,
                              ),
                            ),
                          ),
                        ),
                        if (widget.editing &&
                            doctorExamResult(
                              widget.history.notes,
                            ).isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Tersimpan: ${doctorExamResult(widget.history.notes)}',
                            style: const TextStyle(
                              fontSize: 10.5,
                              color: AppColors.sub,
                              letterSpacing: 0,
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),

                        // Section 2: Diagnosa Klinis (ICD-10)
                        Icd10MultiSearchPicker(
                          label: 'Diagnosa Klinis (ICD-10 / Nama Penyakit)',
                          required: !_refers,
                          selectedItems: _diagnosaList,
                          onChanged: (items) {
                            setState(() {
                              _diagnosaList
                                ..clear()
                                ..addAll(items);
                            });
                          },
                        ),
                        const SizedBox(height: 16),

                        // Section 3: Tindakan Medis (ICD-9-CM)
                        Icd9MultiSearchPicker(
                          label: 'Tindakan Medis (ICD-9-CM / Prosedur)',
                          selectedItems: _tindakanList,
                          hint:
                              'Pilih atau cari tindakan ICD-9-CM (opsional)...',
                          onChanged: (items) {
                            setState(() {
                              _tindakanList
                                ..clear()
                                ..addAll(items);
                            });
                          },
                        ),
                        const SizedBox(height: 14),

                        // Section: Operation (Opsional)
                        Row(
                          children: [
                            const Icon(
                              LucideIcons.scissors,
                              size: 14,
                              color: Color(0xFF0D9488),
                            ),
                            const SizedBox(width: 7),
                            const Text(
                              'Operation',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.text,
                                letterSpacing: 0,
                              ),
                            ),
                            const SizedBox(width: 5),
                            const Text(
                              '(Opsional)',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w400,
                                color: AppColors.sub,
                                letterSpacing: 0,
                              ),
                            ),
                            if (_operation != null) ...[
                              const Spacer(),
                              GestureDetector(
                                onTap: () => setState(() => _operation = null),
                                child: const Row(
                                  children: [
                                    Icon(
                                      LucideIcons.x,
                                      size: 12,
                                      color: AppColors.red,
                                    ),
                                    SizedBox(width: 3),
                                    Text(
                                      'Reset',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w500,
                                        color: AppColors.red,
                                        letterSpacing: 0,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _operationToggleButton(
                                label: 'Major',
                                value: 'Major',
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _operationToggleButton(
                                label: 'Minor',
                                value: 'Minor',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Section 4: Perlu Pemeriksaan Laboratorium?
                        const Row(
                          children: [
                            Icon(
                              LucideIcons.flaskConical,
                              size: 14,
                              color: Color(0xFF0284C7),
                            ),
                            SizedBox(width: 7),
                            Text(
                              'Perlu Pemeriksaan Laboratorium?',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.text,
                                letterSpacing: 0,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _choiceButton(
                                label: 'Tidak Perlu Lab',
                                active: !_needLab,
                                onTap: () => _setNeedLab(false),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _choiceButton(
                                label: 'Ya, Perlu Rujukan Lab',
                                active: _needLab,
                                onTap: () => _setNeedLab(true),
                              ),
                            ),
                          ],
                        ),

                        if (_needLab == true) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0F9FF),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: const Color(
                                  0xFF0284C7,
                                ).withValues(alpha: 0.3),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Label: Jenis Pemeriksaan Laboratorium
                                const Row(
                                  children: [
                                    Text(
                                      'Jenis Pemeriksaan Laboratorium',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.text,
                                        letterSpacing: 0,
                                      ),
                                    ),
                                    Text(
                                      ' *',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.red,
                                        letterSpacing: 0,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 5),
                                _LabTestChecklist(
                                  tests: ref.watch(labTestsProvider),
                                  selectedIds: _selectedLabIds,
                                  otherController: _labOther,
                                  onToggle: (id) => setState(() {
                                    if (!_selectedLabIds.remove(id)) {
                                      _selectedLabIds.add(id);
                                    }
                                  }),
                                ),
                                const SizedBox(height: 10),

                                // Label: Catatan Khusus untuk Analis Lab
                                const Text(
                                  'Catatan Khusus untuk Analis Lab',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.text,
                                    letterSpacing: 0,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                TextField(
                                  controller: _catatanLab,
                                  textCapitalization: freeTextCapitalization,
                                  inputFormatters: freeTextFormatters,
                                  maxLines: 2,
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    color: AppColors.text,
                                    letterSpacing: 0,
                                  ),
                                  decoration: InputDecoration(
                                    hintText:
                                        'cth: Cek Hemoglobin, Trombosit & Leukosit cito',
                                    hintStyle: const TextStyle(
                                      fontSize: 10.5,
                                      color: AppColors.sub,
                                      letterSpacing: 0,
                                    ),
                                    filled: true,
                                    fillColor: Colors.white,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 8,
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(
                                        color: AppColors.border,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(
                                        color: Color(0xFF0284C7),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _refers
                                      ? 'Resep obat di bawah langsung diproses farmasi tanpa menunggu hasil lab. Hasil lab dikirim ke dokter tujuan rujukan.'
                                      : 'Resep obat di bawah langsung diproses farmasi tanpa menunggu hasil lab.',
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    color: AppColors.sub,
                                    letterSpacing: 0,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 18),

                        // Section 5: Perlu Resep Obat? ("Tidak" hides the picker)
                        ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Row(
                                children: [
                                  Icon(
                                    LucideIcons.pill,
                                    size: 14,
                                    color: AppColors.orange,
                                  ),
                                  SizedBox(width: 7),
                                  Text(
                                    'Perlu Resep Obat?',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.text,
                                      letterSpacing: 0,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2.5,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.orangeLt,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${_dispensedResep.length + (_needMeds ? _resep.length : 0)} Item Obat',
                                  style: const TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.sub,
                                    letterSpacing: 0,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: _choiceButton(
                                  label: 'Tidak Perlu Obat',
                                  active: !_needMeds,
                                  onTap: () => _setNeedMeds(false),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _choiceButton(
                                  label: 'Ya, Perlu Obat',
                                  active: _needMeds,
                                  onTap: () => _setNeedMeds(true),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          for (final item in _dispensedResep)
                            _DispensedResepCard(item: item),

                          // List of Resep Cards
                          if (_needMeds)
                            for (int i = 0; i < _resep.length; i++)
                              _buildResepCard(i),

                          // Button: + Tambah Obat Lainnya (Simple inline link)
                          if (_needMeds)
                            Align(
                              alignment: Alignment.centerLeft,
                              child: InkWell(
                                onTap: () =>
                                    setState(() => _resep.add(_ResepRowData())),
                                borderRadius: BorderRadius.circular(4),
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(
                                    vertical: 2,
                                    horizontal: 2,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        LucideIcons.plus,
                                        size: 11,
                                        color: AppColors.orange,
                                      ),
                                      SizedBox(width: 3),
                                      Text(
                                        'Tambah obat lainnya',
                                        style: TextStyle(
                                          fontSize: 10.0,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.orange,
                                          letterSpacing: 0,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          const SizedBox(height: 18),
                        ],

                        // Status Kondisi Pasien (paling bawah, selalu tampil):
                        // "Perlu Rujukan" membuka form rujuk ke dokter lain.
                        const Row(
                          children: [
                            Icon(
                              LucideIcons.activity,
                              size: 14,
                              color: AppColors.orange,
                            ),
                            SizedBox(width: 7),
                            Text(
                              'Status Kondisi Pasien',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.text,
                                letterSpacing: 0,
                              ),
                            ),
                            Text(
                              ' *',
                              style: TextStyle(
                                color: AppColors.red,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Container(
                          // Dense button + 6px padding: about 36px high, like
                          // the other compact fields (default is 48px).
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.inputBg,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              isExpanded: true,
                              isDense: true,
                              value: _statusKondisi,
                              dropdownColor: AppColors.card,
                              icon: const Icon(
                                LucideIcons.chevronDown,
                                size: 14,
                                color: AppColors.sub,
                              ),
                              items: [
                                for (final (value, label)
                                    in _kStatusKondisiList)
                                  if (!widget.editing ||
                                      value != _kReferralStatus)
                                    DropdownMenuItem(
                                      value: value,
                                      child: Text(
                                        label,
                                        style: const TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w400,
                                          color: AppColors.text,
                                          letterSpacing: 0,
                                        ),
                                      ),
                                    ),
                              ],
                              onChanged: (v) {
                                if (v != null) _setStatusKondisi(v);
                              },
                            ),
                          ),
                        ),
                        if (_refers) ...[
                          const SizedBox(height: 10),
                          _DoctorReferralFields(
                            doctors: ref
                                .watch(tripDoctorsProvider)
                                .whenData(
                                  (d) => referralCandidates(
                                    d,
                                    widget.history.doctorId,
                                    userId: ref
                                        .watch(authControllerProvider)
                                        .session
                                        ?.user
                                        .id,
                                  ),
                                ),
                            selectedId: _referToId,
                            onSelect: (id) => setState(() => _referToId = id),
                            reasonController: _referReason,
                            withLab: _needLab,
                          ),
                        ],
                        const SizedBox(height: 20),

                        // Section 7: Action Buttons (Batal & Simpan)
                        // Rebuilt as the required text fields are typed in.
                        ListenableBuilder(
                          listenable: Listenable.merge([
                            _tindakanFreetext,
                            _labOther,
                            _referReason,
                          ]),
                          builder: (context, _) => _buildActions(),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActions() {
    final missing = _missingFields;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (missing.isNotEmpty) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(LucideIcons.info, size: 14, color: AppColors.sub),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Lengkapi dulu: ${missing.join(', ')}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.sub,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _saving
                    ? null
                    : () => Navigator.of(context).pop(false),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  side: const BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
                child: const Text(
                  'Batal',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: _saving || missing.isNotEmpty ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.orange,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.orange.withValues(
                    alpha: 0.4,
                  ),
                  disabledForegroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(100),
                  ),
                  elevation: 0.5,
                ),
                child: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        widget.editing
                            ? 'Simpan Perubahan'
                            : _refers
                            ? 'Simpan & Rujuk ke Dokter'
                            : _isFollowUp && !_needLab && _needMeds
                            ? 'Simpan & Kirim ke Farmasi'
                            : 'Simpan Rekam Medis',
                        style: const TextStyle(
                          fontSize: 12.0,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          letterSpacing: 0,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _operationToggleButton({
    required String label,
    required String value,
  }) {
    final active = _operation == value;
    final activeColor = value == 'Major'
        ? const Color(0xFFDC2626)
        : const Color(0xFF2563EB);
    final activeBg = value == 'Major'
        ? const Color(0xFFFEF2F2)
        : const Color(0xFFEFF6FF);
    final activeBorder = activeColor;

    final color = active ? activeColor : AppColors.text;
    final bg = active ? activeBg : Colors.white;
    final border = active ? activeBorder : AppColors.border;

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () {
        setState(() {
          // Toggle off if clicked while already selected
          _operation = (_operation == value) ? null : value;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: border),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: activeColor.withValues(alpha: 0.08),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: active ? FontWeight.w500 : FontWeight.w400,
                color: color,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _choiceButton({
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    // Both choices use the same blue when selected.
    const activeColor = Color(0xFF0284C7);
    const activeBg = Color(0xFFF0F9FF);

    final color = active ? activeColor : AppColors.text;
    final bg = active ? activeBg : Colors.white;
    final border = active ? activeColor : AppColors.border;

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: border),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: activeColor.withValues(alpha: 0.08),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: active ? FontWeight.w500 : FontWeight.w400,
                color: color,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResepCard(int index) {
    final row = _resep[index];
    final hasMedicine = row.obat != null && row.obat!.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: hasMedicine
              ? AppColors.orange.withValues(alpha: 0.4)
              : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: #1 Obat Utama + Hapus
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 18,
                    height: 18,
                    alignment: Alignment.center,
                    // Outlined number: orange ring, no fill.
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.orange),
                    ),
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.orange,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    index == 0 ? 'Obat Utama' : 'Obat Tambahan #${index + 1}',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
              if (_resep.length > 1)
                InkWell(
                  onTap: () => setState(() {
                    final removed = _resep.removeAt(index);
                    removed.dispose();
                  }),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Row(
                      children: [
                        Icon(
                          LucideIcons.trash2,
                          size: 12,
                          color: AppColors.red,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Hapus',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.red,
                            letterSpacing: 0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),

          // Field 1: Nama Obat
          const Row(
            children: [
              Text(
                'Nama Obat',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                  letterSpacing: 0,
                ),
              ),
              Text(
                ' *',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.red,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          GestureDetector(
            onTap: () => _showMedicineSearch(index),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: hasMedicine
                      ? AppColors.orange.withValues(alpha: 0.5)
                      : AppColors.border,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    LucideIcons.pill,
                    size: 13,
                    color: hasMedicine ? AppColors.orange : AppColors.sub,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      row.obat ?? 'Cari & pilih obat dari stok kapal...',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: hasMedicine ? AppColors.text : AppColors.sub,
                        fontWeight: hasMedicine
                            ? FontWeight.w600
                            : FontWeight.w400,
                        letterSpacing: 0,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(
                    LucideIcons.chevronDown,
                    size: 13,
                    color: AppColors.sub,
                  ),
                ],
              ),
            ),
          ),
          if (hasMedicine &&
              (row.stock != null ||
                  (row.category != null && row.category!.isNotEmpty))) ...[
            const SizedBox(height: 5),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                if (row.stock != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: (row.stock! > 0)
                          ? const Color(0xFFECFDF5)
                          : const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: (row.stock! > 0)
                            ? const Color(0xFFA7F3D0)
                            : const Color(0xFFFECACA),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          LucideIcons.package,
                          size: 10,
                          color: (row.stock! > 0)
                              ? const Color(0xFF059669)
                              : AppColors.red,
                        ),
                        const SizedBox(width: 3.5),
                        Text(
                          'Stok: ${row.stock} ${row.satuan}',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                            color: (row.stock! > 0)
                                ? const Color(0xFF059669)
                                : AppColors.red,
                            letterSpacing: 0,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (row.category != null && row.category!.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Text(
                      row.category!,
                      style: const TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w500,
                        color: AppColors.sub,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 10),

          // Fields 2, 3, 4: Qty, Dosis, Aturan Pakai in one row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Kolom 1: Qty
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Qty (${row.satuan.isNotEmpty ? row.satuan : 'Pcs'})',
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text,
                        letterSpacing: 0,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 5),
                    SizedBox(
                      height: 36,
                      child: Row(
                        children: [
                          // Minus button (-)
                          InkWell(
                            borderRadius: BorderRadius.circular(4),
                            onTap: () {
                              final cur =
                                  int.tryParse(row.jumlahCtrl.text.trim()) ?? 1;
                              if (cur > 1) {
                                row.jumlahCtrl.text = (cur - 1).toString();
                                setState(() {});
                              }
                            },
                            child: const Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 5,
                              ),
                              // Slightly thicker stroke than the default.
                              child: Icon(
                                LucideIcons.minus500,
                                size: 15,
                                color: AppColors.sub,
                              ),
                            ),
                          ),
                          // Input Angka (tanpa border radius, border color, dan background)
                          Expanded(
                            child: TextField(
                              controller: row.jumlahCtrl,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              textAlign: TextAlign.center,
                              cursorColor: AppColors.orange,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppColors.text,
                                letterSpacing: 0,
                              ),
                              decoration: const InputDecoration(
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                hintText: '1',
                                hintStyle: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.sub,
                                  fontWeight: FontWeight.normal,
                                  letterSpacing: 0,
                                ),
                              ),
                            ),
                          ),
                          // Plus button (+)
                          InkWell(
                            borderRadius: BorderRadius.circular(4),
                            onTap: () {
                              final cur =
                                  int.tryParse(row.jumlahCtrl.text.trim()) ?? 1;
                              row.jumlahCtrl.text = (cur + 1).toString();
                              setState(() {});
                            },
                            child: const Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 5,
                              ),
                              // Slightly thicker stroke than the default.
                              child: Icon(
                                LucideIcons.plus500,
                                size: 15,
                                color: AppColors.orange,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Kolom 2: Dosis
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Dosis',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 5),
                    // Ketik bebas, atau pilih saran dari tombol panah.
                    Container(
                      height: 36,
                      padding: const EdgeInsets.only(left: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: row.dosisCtrl,
                              maxLength: 100,
                              cursorColor: AppColors.orange,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.text,
                                letterSpacing: 0,
                              ),
                              decoration: const InputDecoration(
                                isDense: true,
                                counterText: '',
                                contentPadding: EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                hintText: 'mis. 3x1',
                                hintStyle: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.sub,
                                  letterSpacing: 0,
                                ),
                              ),
                            ),
                          ),
                          PopupMenuButton<String>(
                            tooltip: 'Pilih dosis',
                            padding: EdgeInsets.zero,
                            iconSize: 12,
                            color: Colors.white,
                            icon: const Icon(
                              LucideIcons.chevronDown,
                              size: 12,
                              color: AppColors.sub,
                            ),
                            onSelected: (d) =>
                                setState(() => row.dosisCtrl.text = d),
                            itemBuilder: (_) => [
                              for (final d in _kDosisList)
                                PopupMenuItem(
                                  value: d,
                                  height: 36,
                                  child: Text(
                                    d,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.text,
                                      letterSpacing: 0,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Kolom 3: Aturan Pakai
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Aturan Pakai',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Container(
                      height: 36,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: row.aturanPakai,
                          dropdownColor: Colors.white,
                          icon: const Icon(
                            LucideIcons.chevronDown,
                            size: 12,
                            color: AppColors.sub,
                          ),
                          items: [
                            for (final a in _kAturanPakaiList)
                              DropdownMenuItem(
                                value: a,
                                child: Text(
                                  a,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.text,
                                    fontWeight: FontWeight.w400,
                                    letterSpacing: 0,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: (v) {
                            if (v != null) setState(() => row.aturanPakai = v);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Optional Input Manual jika memilih Input manual
          if (row.aturanPakai == 'Input manual') ...[
            const SizedBox(height: 8),
            const Text(
              'Aturan Pakai Khusus',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: AppColors.text,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 4),
            TextField(
              controller: row.customInstruksiCtrl,
              textCapitalization: freeTextCapitalization,
              inputFormatters: freeTextFormatters,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.text,
                letterSpacing: 0,
              ),
              decoration: InputDecoration(
                hintText: 'Tuliskan aturan pakai khusus obat...',
                hintStyle: const TextStyle(
                  fontSize: 10,
                  color: AppColors.sub,
                  letterSpacing: 0,
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.orange),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Read-only summary of this visit's lab results, shown at the top of the
/// form when the doctor continues after the lab.
class _LabResultSummary extends StatelessWidget {
  const _LabResultSummary({required this.history});

  final MedicalHistory history;

  @override
  Widget build(BuildContext context) {
    final exam = history.labExamination ?? const <String, dynamic>{};
    final items = [
      if (exam['items'] is List)
        for (final it in exam['items'] as List)
          if (it is Map)
            LabExaminationItem.fromJson(Map<String, dynamic>.from(it)),
    ];
    final attachment = '${exam['attachment_url'] ?? ''}'.trim();
    final examId = '${exam['id'] ?? ''}'.trim();
    final requested = history.requestedLabOrder?.jenis ?? '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.skyLt.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.sky.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                LucideIcons.flaskConical,
                size: 14,
                color: AppColors.sky,
              ),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Hasil Pemeriksaan Lab',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.sky,
                  ),
                ),
              ),
              if (attachment.isNotEmpty)
                TextButton.icon(
                  onPressed: () => showLabDocumentDialog(context, attachment),
                  icon: const Icon(LucideIcons.eye, size: 13),
                  label: const Text(
                    'Lihat Dokumen',
                    style: TextStyle(fontSize: 11.5),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.sky,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
            ],
          ),
          if (requested.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              requested,
              style: const TextStyle(fontSize: 11.5, color: AppColors.sub),
            ),
          ],
          if (items.isNotEmpty) ...[
            const SizedBox(height: 8),
            LabResultTable(items: items),
          ] else if (attachment.isNotEmpty) ...[
            const SizedBox(height: 6),
            const Text(
              'Hasil terlampir dalam dokumen.',
              style: TextStyle(fontSize: 11.5, color: AppColors.sub),
            ),
          ],
          if (examId.isNotEmpty &&
              (items.isNotEmpty || attachment.isNotEmpty)) ...[
            const SizedBox(height: 8),
            LabResultPdfButton(labExaminationId: examId),
          ],
        ],
      ),
    );
  }
}

/// A medicine the pharmacy already dispensed: shown, but no longer editable.
class _DispensedResepCard extends StatelessWidget {
  const _DispensedResepCard({required this.item});

  final ResepItem item;

  @override
  Widget build(BuildContext context) {
    final details = [
      if (item.jumlah != null) '${item.jumlah} ${item.satuan ?? ''}'.trim(),
      item.dosis,
      item.instruksi,
    ].where((s) => s.isNotEmpty).join(' · ');
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.greenLt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.green.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.obat,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text,
                    letterSpacing: 0,
                  ),
                ),
                if (details.isNotEmpty)
                  Text(
                    details,
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: AppColors.sub,
                      letterSpacing: 0,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'Sudah diserahkan farmasi',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.green,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

/// The lab request form: tests ticked per category, a free "Lain-lain", and
/// a warning when a ticked test needs the patient to fast.
class _LabTestChecklist extends StatelessWidget {
  const _LabTestChecklist({
    required this.tests,
    required this.selectedIds,
    required this.otherController,
    required this.onToggle,
  });

  final AsyncValue<List<LabTestType>> tests;
  final Set<String> selectedIds;
  final TextEditingController otherController;
  final ValueChanged<String> onToggle;

  static const _categoryStyle = TextStyle(
    fontSize: 10.5,
    fontWeight: FontWeight.w700,
    color: Color(0xFF0284C7),
    letterSpacing: 0,
  );

  @override
  Widget build(BuildContext context) {
    final list = tests.valueOrNull ?? const <LabTestType>[];
    final fasting = [
      for (final t in list)
        if (t.requiresFasting && selectedIds.contains(t.id)) t.name,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (tests.isLoading)
          const Text(
            'Memuat jenis pemeriksaan...',
            style: TextStyle(fontSize: 11, color: AppColors.sub),
          )
        else if (list.isEmpty)
          const Text(
            'Daftar pemeriksaan belum tersimpan di perangkat. Isi di "Lain-lain".',
            style: TextStyle(fontSize: 11, color: AppColors.sub),
          ),
        for (final (category, items) in groupLabTests(list)) ...[
          const SizedBox(height: 6),
          Text(category, style: _categoryStyle),
          for (final t in items)
            InkWell(
              onTap: () => onToggle(t.id),
              child: Row(
                children: [
                  SizedBox(
                    width: 32,
                    height: 30,
                    child: Checkbox(
                      value: selectedIds.contains(t.id),
                      onChanged: (_) => onToggle(t.id),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      t.name,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.text,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                  if (t.requiresFasting)
                    const Text(
                      'Puasa',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.orange,
                        letterSpacing: 0,
                      ),
                    ),
                ],
              ),
            ),
        ],
        const SizedBox(height: 8),
        const Text(kLabOtherCategory, style: _categoryStyle),
        const SizedBox(height: 4),
        TextField(
          controller: otherController,
          style: const TextStyle(fontSize: 11.5, letterSpacing: 0),
          decoration: InputDecoration(
            hintText: 'Pemeriksaan lain yang tidak ada di daftar',
            hintStyle: const TextStyle(fontSize: 10.5, color: AppColors.sub),
            isDense: true,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 9,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF0284C7)),
            ),
          ),
        ),
        if (fasting.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Pasien perlu puasa sebelum pengambilan sampel (${fasting.join(', ')}).',
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: AppColors.orange,
              letterSpacing: 0,
            ),
          ),
        ],
      ],
    );
  }
}

/// The referral that brought the patient to this doctor, and what the
/// referring doctor found.
class _ReferredFromCard extends StatelessWidget {
  const _ReferredFromCard({required this.referral, required this.previousExam});

  final DoctorReferral referral;
  final String previousExam;

  @override
  Widget build(BuildContext context) {
    const blue = Color(0xFF0284C7);
    const textStyle = TextStyle(
      fontSize: 11.5,
      color: AppColors.text,
      letterSpacing: 0,
    );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F9FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: blue.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.userPlus, size: 14, color: blue),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  'Dirujuk dari ${referral.fromName}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: blue,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text('Alasan rujukan: ${referral.reason}', style: textStyle),
          if (previousExam.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Hasil pemeriksaan sebelumnya: $previousExam',
              style: textStyle,
            ),
          ],
        ],
      ),
    );
  }
}

/// The doctor to refer to (from the ongoing trip) and why.
class _DoctorReferralFields extends StatelessWidget {
  const _DoctorReferralFields({
    required this.doctors,
    required this.selectedId,
    required this.onSelect,
    required this.reasonController,
    this.withLab = false,
  });

  final AsyncValue<List<Doctor>> doctors;
  final String? selectedId;
  final ValueChanged<String?> onSelect;
  final TextEditingController reasonController;

  /// A lab is ordered too: the patient sees the lab before the other doctor.
  final bool withLab;

  @override
  Widget build(BuildContext context) {
    const blue = Color(0xFF0284C7);
    const noteStyle = TextStyle(
      fontSize: 10.5,
      color: AppColors.sub,
      letterSpacing: 0,
    );
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F9FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: blue.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(LucideIcons.userPlus, size: 14, color: blue),
              SizedBox(width: 7),
              Text(
                'Rujuk ke Dokter Lain',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          doctors.when(
            loading: () => const Text(
              'Memuat dokter di jadwal perjalanan...',
              style: noteStyle,
            ),
            error: (_, _) => const Text(
              'Dokter di jadwal perjalanan tidak dapat dimuat.',
              style: TextStyle(fontSize: 11, color: AppColors.red),
            ),
            data: (list) => list.isEmpty
                ? const Text(
                    'Tidak ada dokter lain di jadwal perjalanan Ongoing kapal ini.',
                    style: TextStyle(fontSize: 11, color: AppColors.orange),
                  )
                : AppSelect<String>(
                    label: 'Dokter Tujuan',
                    required: true,
                    hint: 'Pilih dokter tujuan',
                    fontSize: 11.5,
                    labelFontSize: 11.5,
                    value: list.any((d) => d.id == selectedId)
                        ? selectedId
                        : null,
                    options: [
                      for (final d in list)
                        AppSelectOption(
                          value: d.id,
                          label: d.spesialisasi.isNotEmpty
                              ? '${d.nama} — ${d.spesialisasi}'
                              : d.nama,
                        ),
                    ],
                    onChanged: onSelect,
                  ),
          ),
          const SizedBox(height: 10),
          const Text.rich(
            TextSpan(
              text: 'Alasan Rujukan',
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
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 5),
          TextField(
            controller: reasonController,
            maxLines: 2,
            maxLength: 1000,
            style: const TextStyle(
              fontSize: 11.5,
              color: AppColors.text,
              letterSpacing: 0,
            ),
            decoration: InputDecoration(
              hintText: 'cth: Perlu penanganan dokter spesialis',
              hintStyle: noteStyle,
              counterText: '',
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 8,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: blue),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            withLab
                ? 'Pasien diperiksa lab dulu; setelah hasil lab dikirim, pasien masuk antrean dokter tujuan. Form pemeriksaan tidak wajib diisi.'
                : 'Pasien kembali berstatus Menunggu Dokter dan ditangani dokter tujuan. Form pemeriksaan tidak wajib diisi.',
            style: noteStyle,
          ),
        ],
      ),
    );
  }
}
