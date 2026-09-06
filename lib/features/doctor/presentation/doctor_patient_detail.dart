import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'dart:async';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_badge.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_select.dart';
import '../../../core/widgets/app_shimmer.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/circle_icon_button.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../patients/data/patient_repository.dart';
import '../../patients/domain/doctor.dart';
import '../../patients/domain/lab_order.dart';
import '../../patients/domain/patient.dart';
import '../../patients/domain/prescription_item.dart';
import '../../patients/presentation/patient_info_card.dart';
import '../../patients/presentation/status_meta.dart';
import '../data/icd10_api.dart';
import '../data/icd9_api.dart';
import '../data/medicines_api.dart';
import '../domain/icd10_item.dart';
import '../domain/icd9_item.dart';
import '../domain/medicine_item.dart';
import 'widgets/icd10_search_picker.dart';
import 'widgets/icd9_search_picker.dart';

/// Port of the prototype's `DoctorPatientDetail` — diagnosis + multi-drug
/// prescription + optional lab referral. Read-only summary once diagnosed
/// (matching the prototype: a doctor doesn't re-edit a submitted diagnosis).
class DoctorPatientDetail extends ConsumerStatefulWidget {
  const DoctorPatientDetail({
    super.key,
    required this.patientId,
    this.initialPatient,
  });

  final String patientId;
  final Patient? initialPatient;

  @override
  ConsumerState<DoctorPatientDetail> createState() =>
      _DoctorPatientDetailState();
}

typedef DokterPatientDetail = DoctorPatientDetail;

const List<String> kDosisList = [
  '1x1',
  '2x1',
  '3x1',
  '4x1',
  '5x1',
  '6x1',
  '7x1',
  '8x1',
  '9x1',
  '10x1',
  'Sesuai kebutuhan (PRN)',
];

const List<String> kAturanPakaiList = [
  'Sesudah makan',
  'Sebelum makan',
  'Bersama makan',
  'Input manual',
];

class _ResepRow {
  String? obat;
  String dosis = '3x1';
  String aturanPakai = 'Sesudah makan';
  final TextEditingController customInstruksiCtrl = TextEditingController();

  String get instruksi {
    if (aturanPakai == 'Input manual') {
      return customInstruksiCtrl.text.trim();
    }
    return aturanPakai;
  }

  void dispose() {
    customInstruksiCtrl.dispose();
  }
}

class _DoctorPatientDetailState extends ConsumerState<DoctorPatientDetail> {
  final List<Icd10Item> _diagnosaList = [];
  final List<Icd9Item> _tindakanList = [];
  final _tindakanFreetext = TextEditingController();
  final _catatanLab = TextEditingController();
  final List<_ResepRow> _resep = [_ResepRow()];
  bool? _needLab;
  String? _jenisLab;
  bool _saving = false;
  bool _loading = true;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  @override
  void didUpdateWidget(covariant DoctorPatientDetail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.patientId != widget.patientId) {
      _loadDetail();
    }
  }

  Future<void> _loadDetail() async {
    setState(() => _loading = true);
    await Future.wait([
      ref.read(patientsProvider.notifier).fetchPatientDetail(widget.patientId),
      Future.delayed(const Duration(milliseconds: 250)),
    ]);
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _tindakanFreetext.dispose();
    _catatanLab.dispose();
    for (final r in _resep) {
      r.dispose();
    }
    super.dispose();
  }

  bool get _valid =>
      _diagnosaList.isNotEmpty &&
      _resep.any(
        (r) =>
            r.obat != null &&
            (r.aturanPakai != 'Input manual' ||
                r.customInstruksiCtrl.text.trim().isNotEmpty),
      ) &&
      (_needLab != true || _jenisLab != null);

  Future<void> _submit(Patient patient) async {
    if (!_valid) return;
    setState(() => _saving = true);

    final resepItems = [
      for (final r in _resep)
        if (r.obat != null)
          ResepItem(obat: r.obat!, dosis: r.dosis, instruksi: r.instruksi),
    ];
    LabOrder? labOrder = patient.labOrder;
    if (_needLab == true) {
      labOrder = LabOrder(
        id: 'L${100 + resepItems.length + DateTime.now().millisecond}',
        jenis: _jenisLab!,
        catatan: _catatanLab.text.trim(),
      );
    }

    try {
      final authState = ref.read(authControllerProvider);
      final userEmail = authState.session?.user.email.toLowerCase() ?? '';

      final doctorsList = ref.read(doctorsProvider).valueOrNull ?? kDoctors;
      Doctor? matchedDoctor;
      if (userEmail.isNotEmpty) {
        matchedDoctor = doctorsList
            .where(
              (d) => d.email != null && d.email!.toLowerCase() == userEmail,
            )
            .firstOrNull;
      }
      if (matchedDoctor == null && patient.assignedDokterId.isNotEmpty) {
        matchedDoctor = doctorsList
            .where((d) => d.id == patient.assignedDokterId)
            .firstOrNull;
      }
      matchedDoctor ??= doctorsList.isNotEmpty
          ? doctorsList.first
          : kDoctors.first;

      final currentShipId = authState.session?.user.shipId;

      final diagnosaFormatted = _diagnosaList
          .map((d) => d.code.isNotEmpty ? d.code : d.display)
          .where((s) => s.isNotEmpty)
          .join(', ');

      final List<String> allTindakan = [];
      for (final d in _tindakanList) {
        final val = d.code.isNotEmpty ? d.code : d.display;
        if (val.isNotEmpty) {
          allTindakan.add(val);
        }
      }
      final freeText = _tindakanFreetext.text.trim();
      if (freeText.isNotEmpty) {
        allTindakan.add(freeText);
      }
      final tindakanFormatted = allTindakan.join(', ');

      await ref
          .read(patientsProvider.notifier)
          .submitDiagnosaResep(
            id: patient.id,
            diagnosa: diagnosaFormatted,
            tindakan: tindakanFormatted.isNotEmpty ? tindakanFormatted : null,
            resep: resepItems,
            labOrder: labOrder,
            doctorId: matchedDoctor.id,
            shipId: currentShipId,
          );

      if (!mounted) return;
      setState(() {
        _saving = false;
        _isEditing = false;
      });
      ref.read(medicalHistoryProvider.notifier).fetchHistory(refresh: true);
      ref.read(patientsProvider.notifier).fetchPatients(refresh: true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Diagnosa & resep berhasil disimpan ke rekam medis!'),
          backgroundColor: AppColors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menyimpan diagnosa: $e'),
          backgroundColor: AppColors.red,
        ),
      );
    }
  }

  void _prepareEditFromPatient(Patient p) {
    if (_diagnosaList.isEmpty && p.diagnosa != null && p.diagnosa!.isNotEmpty) {
      final split = p.diagnosa!.split(',');
      for (final s in split) {
        final trimmed = s.trim();
        if (trimmed.isNotEmpty) {
          final parts = trimmed.split(' - ');
          final code = parts[0].trim();
          final desc =
              parts.length > 1 ? parts.sublist(1).join(' - ').trim() : code;
          _diagnosaList.add(Icd10Item(code: code, display: desc));
        }
      }
    }
    if (_tindakanFreetext.text.isEmpty && p.tindakan != null) {
      _tindakanFreetext.text = p.tindakan!;
    }
    if (p.resep.isNotEmpty &&
        (_resep.length == 1 && _resep.first.obat == null)) {
      _resep.clear();
      for (final r in p.resep) {
        final row = _ResepRow();
        row.obat = r.obat;
        row.dosis = r.dosis;
        if (kAturanPakaiList.contains(r.instruksi)) {
          row.aturanPakai = r.instruksi;
        } else {
          row.aturanPakai = 'Input manual';
          row.customInstruksiCtrl.text = r.instruksi;
        }
        _resep.add(row);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final patients = ref.watch(patientsProvider);
    final patient =
        patients.where((p) => p.id == widget.patientId).firstOrNull ??
            widget.initialPatient;
    if (_loading && patient == null) {
      return const SkeletonPatientDetail();
    }
    if (patient == null) {
      return const SkeletonPatientDetail();
    }
    final alreadyDiagnosed = !_isEditing &&
        (patient.diagnosa != null && patient.diagnosa!.trim().isNotEmpty);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PatientInfoCard(patient: patient),
        const SizedBox(height: 14),
        alreadyDiagnosed
            ? AppCard(child: _readOnlySummary(patient))
            : _form(patient),
      ],
    );
  }

  Widget _readOnlySummary(Patient p) {
    final meta = statusMeta(p);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.orangeLt,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    LucideIcons.stethoscope,
                    size: 15,
                    color: AppColors.orange,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'HASIL PEMERIKSAAN & RESEP',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.orange,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                AppBadge(
                  label: meta.label,
                  color: meta.color,
                  background: meta.background,
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _isEditing = true;
                      _prepareEditFromPatient(p);
                    });
                  },
                  icon: const Icon(LucideIcons.pencil, size: 12),
                  label: const Text(
                    'Ubah',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    visualDensity: VisualDensity.compact,
                    foregroundColor: AppColors.blue,
                    side: const BorderSide(color: AppColors.blue),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [const Color(0xFFEFF6FF), AppColors.card2],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(10),
            border: const Border(
              left: BorderSide(color: Color(0xFF0284C7), width: 3.5),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'DIAGNOSA KLINIS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.sub,
                ),
              ),
              const SizedBox(height: 5),
              _DiagnosaDisplay(diagnosa: p.diagnosa),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [const Color(0xFFF0FDFA), AppColors.card2],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(10),
            border: const Border(
              left: BorderSide(color: Color(0xFF0D9488), width: 3.5),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'TINDAKAN / PROSEDUR (ICD-9-CM)',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.sub,
                ),
              ),
              const SizedBox(height: 5),
              _TindakanDisplay(tindakan: p.tindakan),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (p.resep.isNotEmpty) ...[
          Row(
            children: [
              const Icon(LucideIcons.pill, size: 14, color: AppColors.sub),
              const SizedBox(width: 6),
              const Text(
                'Resep Obat',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
              const Spacer(),
              Text(
                '${p.resep.length} item obat',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.sub,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final r in p.resep)
            Container(
              margin: const EdgeInsets.only(bottom: 7),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: AppColors.card2,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: AppColors.yellowLt,
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: const Icon(
                      LucideIcons.pill,
                      size: 13,
                      color: AppColors.yellow,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                r.obat,
                                style: const TextStyle(
                                  fontSize: 12,
                                  // fontWeight: FontWeight.w700,
                                  color: AppColors.text,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.card,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Text(
                                r.dosis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.orange,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (r.instruksi.trim().isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              const Icon(
                                LucideIcons.clock,
                                size: 11.5,
                                color: AppColors.sub,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  r.instruksi,
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    color: AppColors.sub,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (r.penggantian != null) ...[
                          const SizedBox(height: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.yellowLt,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Penggantian: ${r.penggantian!.dari} (${r.penggantian!.alasan})',
                              style: const TextStyle(
                                fontSize: 10.5,
                                color: AppColors.yellow,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
        if (p.labOrder != null) ...[
          const SizedBox(height: 8),
          const Divider(height: 16, thickness: 1, color: AppColors.border),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(
                LucideIcons.flaskConical,
                size: 14,
                color: AppColors.purple,
              ),
              const SizedBox(width: 6),
              Text(
                'Pemeriksaan Lab: ${p.labOrder!.jenis}',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (p.labOrder!.status == LabOrderStatus.selesai)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.greenLt,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.green.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        LucideIcons.checkCircle2,
                        size: 14,
                        color: AppColors.green,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Hasil Lab Selesai',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    p.labOrder!.hasil?.catatanHasil ?? '',
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.text,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (p.labOrder!.hasil?.fileName != null) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            LucideIcons.paperclip,
                            size: 12,
                            color: AppColors.sub,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            p.labOrder!.hasil!.fileName!,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.text,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: AppColors.purpleLt,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.purple.withValues(alpha: 0.25),
                ),
              ),
              child: const Row(
                children: [
                  Icon(LucideIcons.clock, size: 14, color: AppColors.purple),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Menunggu hasil analisis dari Laboratorium...',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.purple,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }

  Widget _form(Patient patient) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.blue.withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.blue.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_isEditing)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: const BoxDecoration(
                color: Color(0xFFEFF6FF),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                border: Border(bottom: BorderSide(color: Color(0xFFBFDBFE))),
              ),
              child: Row(
                children: [
                  const Icon(LucideIcons.pencil, size: 14, color: AppColors.blue),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Mode Ubah Rekam Medis (Diagnosa & Resep)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.blue,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () => setState(() => _isEditing = false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: const Text(
                        'Batal',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.sub,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          // Section Header with Highlight and Wajib Diisi Tag
          Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.blueLt,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        LucideIcons.stethoscope,
                        size: 18,
                        color: AppColors.blue,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'INPUT DIAGNOSA & RESEP',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppColors.text,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Tindakan klinis dokter pemeriksa',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.sub,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.redLt,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: AppColors.red.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(
                        LucideIcons.alertCircle,
                        size: 12,
                        color: AppColors.red,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Wajib Diisi',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.red,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: AppColors.border),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Diagnosa Klinis (ICD-10 Dropdown / Multi Search)
                Icd10MultiSearchPicker(
                  label: 'Diagnosa Klinis (ICD-10 / Nama Penyakit)',
                  required: true,
                  selectedItems: _diagnosaList,
                  hint: 'Pilih atau cari diagnosa ICD-10...',
                  onChanged: (items) {
                    setState(() {
                      _diagnosaList
                        ..clear()
                        ..addAll(items);
                    });
                  },
                ),
                const SizedBox(height: 16),

                // 2. Tindakan Medis (ICD-9-CM Dropdown / Multi Search)
                Icd9MultiSearchPicker(
                  label: 'Tindakan Medis (ICD-9-CM / Prosedur)',
                  required: false,
                  selectedItems: _tindakanList,
                  hint: 'Pilih atau cari tindakan ICD-9-CM (opsional)...',
                  onChanged: (items) {
                    setState(() {
                      _tindakanList
                        ..clear()
                        ..addAll(items);
                    });
                  },
                ),
                const SizedBox(height: 10),
                AppTextField(
                  label: 'Catatan Tambahan',
                  controller: _tindakanFreetext,
                  maxLines: 2,
                  placeholder:
                      'Tuliskan tindakan/prosedur klinis manual jika tidak ada di list ICD-9...',
                ),
                const SizedBox(height: 18),

                // 3. Lab Referral Section
                Row(
                  children: const [
                    Icon(
                      LucideIcons.flaskConical,
                      size: 15,
                      color: AppColors.purple,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Perlu Pemeriksaan Laboratorium?',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _labToggleButton(
                        'Ya, Perlu Rujukan Lab',
                        true,
                        LucideIcons.flaskConical,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _labToggleButton(
                        'Tidak Perlu Lab',
                        false,
                        LucideIcons.xCircle,
                      ),
                    ),
                  ],
                ),

                if (_needLab == true) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.purpleLt.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.purple.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppSelect<String>(
                          label: 'Jenis Pemeriksaan Laboratorium',
                          required: true,
                          value: _jenisLab,
                          options: [
                            for (final j in kJenisLab)
                              AppSelectOption(value: j, label: j),
                          ],
                          onChanged: (v) => setState(() => _jenisLab = v),
                        ),
                        const SizedBox(height: 10),
                        AppTextField(
                          label: 'Catatan Khusus untuk Analis Lab',
                          controller: _catatanLab,
                          maxLines: 2,
                          placeholder:
                              'cth: Cek Hemoglobin, Trombosit & Leukosit cito',
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 18),

                // 4. Resep Obat Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          LucideIcons.pill,
                          size: 15,
                          color: AppColors.blue,
                        ),
                        SizedBox(width: 6),
                        const Text(
                          'Resep Obat Pasien',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.text,
                          ),
                        ),
                        const Text(
                          ' *',
                          style: TextStyle(
                            color: AppColors.red,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.blueLt,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${_resep.length} Item Obat',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.blue,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Medication Rows (Cards)
                for (int i = 0; i < _resep.length; i++) _resepCard(i),

                // Add Drug Button
                InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => setState(() => _resep.add(_ResepRow())),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.blueLt.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(
                        color: AppColors.blue.withValues(alpha: 0.3),
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(
                          LucideIcons.plusCircle,
                          size: 15,
                          color: AppColors.blue,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Tambah Obat Lain',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.blue,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // 5. Save Button
                AppButton(
                  label: 'Simpan Diagnosa & Resep',
                  full: true,
                  loading: _saving,
                  onPressed: _valid && !_saving ? () => _submit(patient) : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _labToggleButton(String label, bool value, IconData icon) {
    final active = _needLab == value;
    final color = value ? AppColors.purple : AppColors.sub;
    final activeBg = value
        ? AppColors.purpleLt
        : AppColors.border.withValues(alpha: 0.3);

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => setState(() => _needLab = value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: active ? activeBg : AppColors.inputBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active ? color : AppColors.border,
            width: active ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 15, color: active ? color : AppColors.sub),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                color: active ? color : AppColors.sub,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _resepCard(int index) {
    final row = _resep[index];
    final hasMedicine = row.obat != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.card2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: hasMedicine
              ? AppColors.blue.withValues(alpha: 0.3)
              : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Index & Delete Action
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1.5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.blueLt,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '#${index + 1}',
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.blue,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    index == 0 ? 'Obat Utama' : 'Obat Tambahan #${index + 1}',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                    ),
                  ),
                ],
              ),
              if (_resep.length > 1)
                InkWell(
                  borderRadius: BorderRadius.circular(4),
                  onTap: () => setState(() {
                    final removed = _resep.removeAt(index);
                    removed.dispose();
                  }),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(
                          LucideIcons.trash2,
                          size: 12,
                          color: AppColors.red,
                        ),
                        SizedBox(width: 3),
                        Text(
                          'Hapus',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),

          // Selector Nama Obat (Compact)
          GestureDetector(
            onTap: () => _showMedicineSearchModal(index),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: hasMedicine
                      ? AppColors.blue.withValues(alpha: 0.4)
                      : AppColors.border,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    LucideIcons.pill,
                    size: 13,
                    color: hasMedicine ? AppColors.blue : AppColors.sub,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      row.obat ?? 'Pilih nama obat...',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: hasMedicine ? AppColors.text : AppColors.sub,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
          const SizedBox(height: 6),

          // Dosis & Aturan Pakai in one row (Centered)
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Dosis Dropdown
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: row.dosis,
                      isDense: true,
                      alignment: AlignmentDirectional.center,
                      icon: const Icon(
                        LucideIcons.chevronDown,
                        size: 13,
                        color: AppColors.sub,
                      ),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.text,
                      ),
                      items: [
                        for (final d in kDosisList)
                          DropdownMenuItem<String>(
                            value: d,
                            alignment: AlignmentDirectional.center,
                            child: Text(
                              d,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                      ],
                      onChanged: (v) => setState(() => row.dosis = v ?? '1x1'),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),

              // Aturan Pakai Dropdown
              Expanded(
                flex: 3,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: row.aturanPakai,
                      isDense: true,
                      alignment: AlignmentDirectional.center,
                      icon: const Icon(
                        LucideIcons.chevronDown,
                        size: 13,
                        color: AppColors.sub,
                      ),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.text,
                      ),
                      items: [
                        for (final a in kAturanPakaiList)
                          DropdownMenuItem<String>(
                            value: a,
                            alignment: AlignmentDirectional.center,
                            child: Text(
                              a,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (v) => setState(
                        () => row.aturanPakai = v ?? 'Sesudah makan',
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Custom Instruction (if 'Input manual')
          if (row.aturanPakai == 'Input manual') ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: TextField(
                controller: row.customInstruksiCtrl,
                style: const TextStyle(fontSize: 12, color: AppColors.text),
                decoration: const InputDecoration(
                  hintText: 'cth: 2 sendok takar sebelum tidur malam',
                  hintStyle: TextStyle(fontSize: 11.5, color: AppColors.sub),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 7),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showMedicineSearchModal(int index) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _MedicineSearchModal(
        selectedName: _resep[index].obat,
        onSelect: (med) {
          setState(() => _resep[index].obat = med);
          Navigator.of(ctx).pop();
        },
      ),
    );
  }
}

/// Material UI Searchable Modal for Medicine selection with Infinite Scroll (Load Scroll)
class _MedicineSearchModal extends ConsumerStatefulWidget {
  const _MedicineSearchModal({
    required this.selectedName,
    required this.onSelect,
  });

  final String? selectedName;
  final ValueChanged<String> onSelect;

  @override
  ConsumerState<_MedicineSearchModal> createState() =>
      _MedicineSearchModalState();
}

class _MedicineSearchModalState extends ConsumerState<_MedicineSearchModal> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _debounce;

  List<MedicineItem> _medicines = [];
  int _currentPage = 1;
  int _totalPages = 1;
  int _total = 0;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String _currentQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchPage(1, reset: true);
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 150) {
      _loadMore();
    }
  }

  Future<void> _fetchPage(int page,
      {String query = '', bool reset = false}) async {
    if (reset) {
      setState(() {
        _isLoading = true;
        _currentPage = 1;
        _hasMore = true;
        _currentQuery = query;
      });
    } else {
      if (_isLoadingMore || !_hasMore) return;
      setState(() => _isLoadingMore = true);
    }

    try {
      final api = ref.read(medicinesApiProvider);
      final res = await api.fetchMedicines(
        query: query,
        page: page,
        limit: 10,
      );

      if (!mounted) return;
      setState(() {
        if (reset) {
          _medicines = res.data;
        } else {
          final existingIds = _medicines.map((m) => m.id).toSet();
          final newItems =
              res.data.where((m) => !existingIds.contains(m.id)).toList();
          _medicines = [..._medicines, ...newItems];
        }
        _currentPage = res.page;
        _totalPages = res.totalPages;
        _total = res.total;
        _hasMore = _currentPage < _totalPages;
        _isLoading = false;
        _isLoadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  void _loadMore() {
    if (_isLoading || _isLoadingMore || !_hasMore) return;
    _fetchPage(_currentPage + 1, query: _currentQuery);
  }

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _fetchPage(1, query: v.trim(), reset: true);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Text(
                      'Pilih Nama Obat',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.text,
                      ),
                    ),
                    if (_total > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.blueLt,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '$_total Item',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.blue,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                CircleIconButton(
                  icon: LucideIcons.x,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),

          // Search Input Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: Container(
              height: 42,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.inputBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Icon(
                    LucideIcons.search,
                    size: 16,
                    color: AppColors.sub,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.text,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Cari nama obat atau SKU...',
                        hintStyle: TextStyle(
                          fontSize: 13,
                          color: AppColors.sub,
                        ),
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                      ),
                    ),
                  ),
                  if (query.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        _searchController.clear();
                        _fetchPage(1, query: '', reset: true);
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: AppColors.sub.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          LucideIcons.x,
                          size: 12,
                          color: AppColors.sub,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Medicine List / Loading / Empty
          Expanded(
            child: _isLoading
                ? _buildLoadingShimmer()
                : _medicines.isEmpty
                    ? _buildEmptyState(query)
                    : ListView.separated(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        itemCount: _medicines.length + (_hasMore ? 1 : 0),
                        separatorBuilder: (_, _) => const SizedBox(height: 6),
                        itemBuilder: (context, i) {
                          if (i >= _medicines.length) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 14),
                              child: Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.blue,
                                  ),
                                ),
                              ),
                            );
                          }

                          final med = _medicines[i];
                          final isSelected = med.name == widget.selectedName;

                          return InkWell(
                            onTap: () => widget.onSelect(med.name),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 11,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.blueLt
                                    : AppColors.card2,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.blue.withValues(alpha: 0.5)
                                      : AppColors.border,
                                ),
                              ),
                              child: Row(
                                children: [
                                  if (med.sku.isNotEmpty) ...[
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 5.5,
                                        vertical: 1.5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? AppColors.card
                                            : AppColors.inputBg,
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color: isSelected
                                              ? AppColors.blue
                                                  .withValues(alpha: 0.3)
                                              : AppColors.border,
                                        ),
                                      ),
                                      child: Text(
                                        med.sku,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: isSelected
                                              ? AppColors.blue
                                              : AppColors.sub,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  Expanded(
                                    child: Text(
                                      med.name,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: isSelected
                                            ? FontWeight.w800
                                            : FontWeight.w600,
                                        color: isSelected
                                            ? AppColors.blue
                                            : AppColors.text,
                                      ),
                                    ),
                                  ),
                                  if (med.unitOfMeasurement.isNotEmpty ||
                                      med.category.isNotEmpty) ...[
                                    const SizedBox(width: 8),
                                    Text(
                                      med.unitOfMeasurement.isNotEmpty &&
                                              med.category.isNotEmpty
                                          ? '${med.unitOfMeasurement} • ${med.category}'
                                          : (med.unitOfMeasurement.isNotEmpty
                                              ? med.unitOfMeasurement
                                              : med.category),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isSelected
                                            ? AppColors.blue
                                                .withValues(alpha: 0.8)
                                            : AppColors.sub,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                  if (isSelected) ...[
                                    const SizedBox(width: 8),
                                    const Icon(
                                      LucideIcons.check,
                                      size: 16,
                                      color: AppColors.blue,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildLoadingShimmer() {
    return AppShimmer(
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        itemCount: 8,
        separatorBuilder: (_, _) => const SizedBox(height: 6),
        itemBuilder: (_, _) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: AppColors.card2,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: const [
              SkeletonBox(width: 46, height: 16, borderRadius: 4),
              SizedBox(width: 8),
              Expanded(
                child: SkeletonBox(height: 14, borderRadius: 4),
              ),
              SizedBox(width: 10),
              SkeletonBox(width: 60, height: 12, borderRadius: 3),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String query) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.pill, size: 36, color: AppColors.sub),
            const SizedBox(height: 10),
            const Text(
              'Obat tidak ditemukan',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Periksa kata kunci pencarian atau gunakan input manual',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.sub),
            ),
            if (query.isNotEmpty) ...[
              const SizedBox(height: 14),
              InkWell(
                onTap: () => widget.onSelect(query),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.blueLt,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.blue.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(LucideIcons.plus,
                          size: 14, color: AppColors.blue),
                      const SizedBox(width: 6),
                      Text(
                        'Gunakan "$query"',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.blue,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DiagnosaDisplay extends ConsumerWidget {
  const _DiagnosaDisplay({this.diagnosa});

  final String? diagnosa;

  List<String> _parseItems(String text) {
    if (text.isEmpty || text == '—' || text == '-') return [];
    if (text.contains('\n')) {
      return text
          .split('\n')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }
    if (text.contains(';')) {
      return text
          .split(';')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }
    if (text.contains(',')) {
      return text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }
    return [text.trim()];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = diagnosa?.trim() ?? '';
    final items = _parseItems(text);

    if (items.isEmpty) {
      return const Text(
        '—',
        style: TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
          color: AppColors.text,
        ),
      );
    }

    if (items.length == 1) {
      return _DiagnosaSingleItem(rawText: items.first);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(height: 7),
          _DiagnosaSingleItem(
            rawText: items[i],
            tag: i == 0 ? 'Utama' : 'Sekunder',
          ),
        ],
      ],
    );
  }
}

class _DiagnosaSingleItem extends ConsumerWidget {
  const _DiagnosaSingleItem({required this.rawText, this.tag});

  final String rawText;
  final String? tag;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (rawText.contains(' - ')) {
      final parts = rawText.split(' - ');
      final code = parts.first.trim();
      final name = parts.sublist(1).join(' - ').trim();
      return _buildRow(code, name);
    }

    final asyncLookup = ref.watch(icd10LookupProvider(rawText));

    return asyncLookup.when(
      data: (item) {
        if (item != null) {
          return _buildRow(item.code, item.display);
        }
        return _buildRow('', rawText);
      },
      loading: () => _buildRow(
        rawText.contains(' ') ? '' : rawText,
        rawText.contains(' ') ? rawText : 'Memuat diagnosa ($rawText)...',
      ),
      error: (_, _) => _buildRow(
        rawText.contains(' ') ? '' : rawText,
        rawText,
      ),
    );
  }

  Widget _buildRow(String code, String name) {
    final hasCode = code.isNotEmpty;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (tag != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5.5, vertical: 2),
            decoration: BoxDecoration(
              color: tag == 'Utama' ? AppColors.blueLt : AppColors.card2,
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              tag!,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                color: tag == 'Utama' ? AppColors.blue : AppColors.sub,
              ),
            ),
          ),
          const SizedBox(width: 6),
        ],
        if (hasCode) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
            decoration: BoxDecoration(
              color: const Color(0xFFE0F2FE),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: const Color(0xFF0284C7).withValues(alpha: 0.25),
                width: 0.8,
              ),
            ),
            child: Text(
              code,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0284C7),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Text(
            name,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.text,
            ),
          ),
        ),
      ],
    );
  }
}

class _TindakanDisplay extends ConsumerWidget {
  const _TindakanDisplay({this.tindakan});

  final String? tindakan;

  List<String> _parseItems(String text) {
    if (text.isEmpty || text == '—' || text == '-') return [];
    if (text.contains('\n')) {
      return text
          .split('\n')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }
    if (text.contains(';')) {
      return text
          .split(';')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }
    if (text.contains(',')) {
      return text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }
    return [text.trim()];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = tindakan?.trim() ?? '';
    final items = _parseItems(text);

    if (items.isEmpty) {
      return const Text(
        '—',
        style: TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
          color: AppColors.text,
        ),
      );
    }

    if (items.length == 1) {
      return _TindakanSingleItem(rawText: items.first);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(height: 7),
          _TindakanSingleItem(rawText: items[i], indexStr: '#${i + 1}'),
        ],
      ],
    );
  }
}

class _TindakanSingleItem extends ConsumerWidget {
  const _TindakanSingleItem({required this.rawText, this.indexStr});

  final String rawText;
  final String? indexStr;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (rawText.contains(' - ')) {
      final parts = rawText.split(' - ');
      final code = parts.first.trim();
      final name = parts.sublist(1).join(' - ').trim();
      return _buildRow(code, name);
    }

    final asyncLookup = ref.watch(icd9LookupProvider(rawText));

    return asyncLookup.when(
      data: (item) {
        if (item != null) {
          return _buildRow(item.code, item.display);
        }
        return _buildRow('', rawText);
      },
      loading: () => _buildRow(
        rawText.contains(' ') ? '' : rawText,
        rawText.contains(' ') ? rawText : 'Memuat tindakan ($rawText)...',
      ),
      error: (_, _) => _buildRow(
        rawText.contains(' ') ? '' : rawText,
        rawText,
      ),
    );
  }

  Widget _buildRow(String code, String name) {
    final hasCode = code.isNotEmpty;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (indexStr != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5.5, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFCCFBF1),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              indexStr!,
              style: const TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F766E),
              ),
            ),
          ),
          const SizedBox(width: 6),
        ],
        if (hasCode) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDFA),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: const Color(0xFF0D9488).withValues(alpha: 0.3),
                width: 0.8,
              ),
            ),
            child: Text(
              code,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F766E),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Text(
            name,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.text,
            ),
          ),
        ),
      ],
    );
  }
}
