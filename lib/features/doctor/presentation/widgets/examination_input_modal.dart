import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/circle_icon_button.dart';
import '../../../auth/presentation/auth_controller.dart';
import '../../../patients/data/patient_repository.dart';
import '../../../patients/domain/doctor.dart';
import '../../../patients/domain/lab_order.dart';
import '../../../patients/domain/medical_history.dart';
import '../../../patients/domain/patient.dart';
import '../../../patients/domain/prescription_item.dart';
import '../../domain/icd10_item.dart';
import '../../domain/icd9_item.dart';
import 'icd10_search_picker.dart';
import 'icd9_search_picker.dart';
import 'medicine_search_modal.dart';

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

/// Status kondisi pasien options
const List<String> _kStatusKondisiList = [
  'Stable',
  'Kritis',
  'Monitoring',
];

class _ResepRowData {
  String? obat;
  int jumlah = 1;
  String satuan = 'Tablet';
  String dosis = '3x1';
  String aturanPakai = 'Sesudah makan';
  final TextEditingController customInstruksiCtrl = TextEditingController();

  String get instruksi {
    final base = aturanPakai == 'Input manual'
        ? (customInstruksiCtrl.text.trim().isNotEmpty
            ? customInstruksiCtrl.text.trim()
            : 'Sesuai anjuran')
        : aturanPakai;
    return '$jumlah $satuan ($dosis, $base)';
  }

  void dispose() {
    customInstruksiCtrl.dispose();
  }
}

/// Helper to show the Examination Input Modal
Future<bool?> showExaminationInputModal(
  BuildContext context, {
  required Patient patient,
  required MedicalHistory history,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    useSafeArea: true,
    builder: (ctx) => ExaminationInputModal(
      patient: patient,
      history: history,
    ),
  );
}

class ExaminationInputModal extends ConsumerStatefulWidget {
  const ExaminationInputModal({
    super.key,
    required this.patient,
    required this.history,
  });

  final Patient patient;
  final MedicalHistory history;

  @override
  ConsumerState<ExaminationInputModal> createState() =>
      _ExaminationInputModalState();
}

class _ExaminationInputModalState extends ConsumerState<ExaminationInputModal> {
  final List<Icd10Item> _diagnosaList = [];
  final List<Icd9Item> _tindakanList = [];
  final _tindakanFreetext = TextEditingController();

  // Lab referral
  bool? _needLab;
  String? _jenisLab;
  final _catatanLab = TextEditingController();

  // Prescriptions
  final List<_ResepRowData> _resep = [_ResepRowData()];

  // Status kondisi
  String _statusKondisi = 'Stable';

  bool _saving = false;

  @override
  void dispose() {
    _tindakanFreetext.dispose();
    _catatanLab.dispose();
    for (final r in _resep) {
      r.dispose();
    }
    super.dispose();
  }

  void _showMedicineSearch(int index) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => MedicineSearchModal(
        selectedName: _resep[index].obat,
        onSelect: (medName) {
          setState(() => _resep[index].obat = medName);
          Navigator.of(ctx).pop();
        },
      ),
    );
  }

  Future<void> _submit() async {
    if (_diagnosaList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Diagnosa Klinis (ICD-10) wajib dipilih minimal 1!'),
          backgroundColor: AppColors.red,
        ),
      );
      return;
    }

    final validResep = _resep.where((r) => r.obat != null && r.obat!.isNotEmpty).toList();
    if (validResep.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Resep obat pasien wajib diisi minimal 1 item obat!'),
          backgroundColor: AppColors.red,
        ),
      );
      return;
    }

    if (_needLab == true && _jenisLab == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Silakan pilih jenis pemeriksaan laboratorium!'),
          backgroundColor: AppColors.red,
        ),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final authState = ref.read(authControllerProvider);
      final userEmail = authState.session?.user.email.toLowerCase() ?? '';
      final currentShipId = authState.session?.user.shipId;

      final doctorsList = ref.read(doctorsProvider).valueOrNull ?? kDoctors;
      Doctor? matchedDoctor;
      if (userEmail.isNotEmpty) {
        matchedDoctor = doctorsList
            .where((d) => d.email != null && d.email!.toLowerCase() == userEmail)
            .firstOrNull;
      }
      if (matchedDoctor == null && widget.patient.assignedDokterId.isNotEmpty) {
        matchedDoctor = doctorsList
            .where((d) => d.id == widget.patient.assignedDokterId)
            .firstOrNull;
      }
      matchedDoctor ??= doctorsList.isNotEmpty ? doctorsList.first : kDoctors.first;

      final resepItems = [
        for (final r in validResep)
          ResepItem(
            obat: r.obat!,
            dosis: r.dosis,
            instruksi: r.instruksi,
          ),
      ];

      LabOrder? labOrder;
      if (_needLab == true) {
        labOrder = LabOrder(
          id: 'L${100 + resepItems.length + DateTime.now().millisecond}',
          jenis: _jenisLab!,
          catatan: _catatanLab.text.trim(),
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
      final freeText = _tindakanFreetext.text.trim();
      if (freeText.isNotEmpty) allTindakan.add(freeText);
      final tindakanFormatted = allTindakan.join(', ');

      final patientId = widget.patient.id.isNotEmpty
          ? widget.patient.id
          : (widget.history.patientId.isNotEmpty
              ? widget.history.patientId
              : widget.history.id);

      await ref.read(patientsProvider.notifier).submitDiagnosaResep(
            id: patientId,
            diagnosa: diagnosaFormatted,
            tindakan: tindakanFormatted.isNotEmpty ? tindakanFormatted : null,
            resep: resepItems,
            labOrder: labOrder,
            doctorId: matchedDoctor.id,
            shipId: currentShipId,
            statusKondisi: _statusKondisi,
          );

      if (!mounted) return;

      ref.read(medicalHistoryProvider.notifier).fetchHistory(refresh: true);
      ref.read(patientsProvider.notifier).fetchPatients(refresh: true);

      Navigator.of(context).pop(true);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Rekam medis & resep berhasil disimpan ke sistem!'),
          backgroundColor: AppColors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menyimpan rekam medis: $e'),
          backgroundColor: AppColors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);

    return Align(
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
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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
                          child: const Icon(
                            LucideIcons.stethoscope,
                            size: 16,
                            color: AppColors.orange,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Form Input Rekam Medis',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.text,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${widget.patient.nama} • RM: ${widget.patient.registerNo.isNotEmpty ? widget.patient.registerNo : widget.patient.id}',
                              style: const TextStyle(
                                fontSize: 10.5,
                                color: AppColors.sub,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    CircleIconButton(
                      icon: LucideIcons.x,
                      size: 32,
                      background: AppColors.card2,
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
                      // Section 1: Diagnosa Klinis (ICD-10)
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

                      // Section 2: Tindakan Medis (ICD-9-CM)
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
                      const SizedBox(height: 14),

                      // Section 3: Catatan Tambahan
                      const Text(
                        'Catatan Tambahan',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.text,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _tindakanFreetext,
                        maxLines: 2,
                        style: const TextStyle(fontSize: 11.5, color: AppColors.text),
                        decoration: InputDecoration(
                          hintText:
                              'Tuliskan tindakan/prosedur klinis manual jika tidak ada di list ICD-9...',
                          hintStyle: const TextStyle(
                            fontSize: 10.5,
                            color: AppColors.sub,
                          ),
                          filled: true,
                          fillColor: AppColors.inputBg,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: AppColors.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: AppColors.orange),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Section 4: Perlu Pemeriksaan Laboratorium?
                      Row(
                        children: const [
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
                              label: 'Ya, Perlu Rujukan Lab',
                              value: true,
                              icon: LucideIcons.flaskConical,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _labToggleButton(
                              label: 'Tidak Perlu Lab',
                              value: false,
                              icon: LucideIcons.xCircle,
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
                              color: const Color(0xFF0284C7).withValues(alpha: 0.3),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Label: Jenis Pemeriksaan Laboratorium
                              Row(
                                children: const [
                                  Text(
                                    'Jenis Pemeriksaan Laboratorium',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.text,
                                    ),
                                  ),
                                  Text(
                                    ' *',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.red,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 5),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    isExpanded: true,
                                    value: _jenisLab,
                                    hint: const Text(
                                      'Pilih jenis pemeriksaan lab...',
                                      style: TextStyle(
                                        fontSize: 11.0,
                                        color: AppColors.sub,
                                      ),
                                    ),
                                    dropdownColor: Colors.white,
                                    icon: const Icon(
                                      LucideIcons.chevronDown,
                                      size: 14,
                                      color: AppColors.sub,
                                    ),
                                    items: [
                                      for (final j in kJenisLab)
                                        DropdownMenuItem(
                                          value: j,
                                          child: Text(
                                            j,
                                            style: const TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.text,
                                            ),
                                          ),
                                        ),
                                    ],
                                    onChanged: (v) => setState(() => _jenisLab = v),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),

                              // Label: Catatan Khusus untuk Analis Lab
                              const Text(
                                'Catatan Khusus untuk Analis Lab',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.text,
                                ),
                              ),
                              const SizedBox(height: 5),
                              TextField(
                                controller: _catatanLab,
                                maxLines: 2,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: AppColors.text,
                                ),
                                decoration: InputDecoration(
                                  hintText:
                                      'cth: Cek Hemoglobin, Trombosit & Leukosit cito',
                                  hintStyle: const TextStyle(
                                    fontSize: 10.5,
                                    color: AppColors.sub,
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
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),

                      // Section 5: Resep Obat Pasien *
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: const [
                              Icon(
                                LucideIcons.pill,
                                size: 14,
                                color: AppColors.orange,
                              ),
                              SizedBox(width: 7),
                              Text(
                                'Resep Obat Pasien',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.text,
                                ),
                              ),
                              Text(
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
                              vertical: 2.5,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.orangeLt,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: AppColors.orange.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Text(
                              '${_resep.length} Item Obat',
                              style: const TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.orange,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // List of Resep Cards
                      for (int i = 0; i < _resep.length; i++) _buildResepCard(i),

                      // Button: + Tambah Obat Lain
                      InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => setState(() => _resep.add(_ResepRowData())),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.orangeLt.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppColors.orange.withValues(alpha: 0.4),
                              width: 1.0,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(
                                LucideIcons.plus,
                                size: 13,
                                color: AppColors.orange,
                              ),
                              SizedBox(width: 5),
                              Text(
                                'Tambah Obat Lain',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.orange,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Section 6: Status Kondisi Pasien *
                      Row(
                        children: const [
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
                              fontWeight: FontWeight.w700,
                              color: AppColors.text,
                            ),
                          ),
                          Text(
                            ' *',
                            style: TextStyle(
                              color: AppColors.red,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.inputBg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: _statusKondisi,
                            dropdownColor: AppColors.card,
                            icon: const Icon(
                              LucideIcons.chevronDown,
                              size: 14,
                              color: AppColors.sub,
                            ),
                            items: [
                              for (final s in _kStatusKondisiList)
                                DropdownMenuItem(
                                  value: s,
                                  child: Row(
                                    children: [
                                      const Icon(
                                        LucideIcons.activity,
                                        size: 14,
                                        color: AppColors.sub,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        s,
                                        style: const TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.text,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                            onChanged: (v) {
                              if (v != null) {
                                setState(() => _statusKondisi = v);
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Pilih status kondisi pasien: Stable, Kritis, atau Monitoring.',
                        style: TextStyle(
                          fontSize: 9.5,
                          color: AppColors.sub,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Section 7: Action Buttons (Batal & Simpan)
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _saving ? null : () => Navigator.of(context).pop(false),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 11),
                                side: const BorderSide(color: AppColors.border, width: 1.0),
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
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              onPressed: _saving ? null : _submit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.orange,
                                foregroundColor: Colors.white,
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
                                  : const Text(
                                      'Simpan Rekam Medis',
                                      style: TextStyle(
                                        fontSize: 12.0,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                            ),
                          ),
                        ],
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
    );
  }

  Widget _labToggleButton({
    required String label,
    required bool value,
    required IconData icon,
  }) {
    final active = _needLab == value;
    final activeColor = value ? const Color(0xFF0284C7) : const Color(0xFF059669);
    final activeBg = value ? const Color(0xFFF0F9FF) : const Color(0xFFECFDF5);
    final activeBorder = value ? const Color(0xFF0284C7) : const Color(0xFF059669);

    final color = active ? activeColor : AppColors.text;
    final iconColor = active ? activeColor : AppColors.sub;
    final bg = active ? activeBg : Colors.white;
    final border = active ? activeBorder : AppColors.border;

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => setState(() => _needLab = value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: border,
            width: active ? 1.2 : 1.0,
          ),
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
            Icon(icon, size: 13.5, color: iconColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: color,
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
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
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
          // Header: #1 Obat Utama
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                index == 0 ? '#1 Obat Utama' : '#${index + 1} Obat Tambahan',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.orange,
                ),
              ),
              if (_resep.length > 1)
                InkWell(
                  onTap: () => setState(() {
                    final removed = _resep.removeAt(index);
                    removed.dispose();
                  }),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Row(
                      children: const [
                        Icon(LucideIcons.trash2, size: 12, color: AppColors.red),
                        SizedBox(width: 4),
                        Text(
                          'Hapus',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),

          // Row 1: Pilih Nama Obat
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
                      row.obat ?? 'Pilih nama obat...',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: hasMedicine ? AppColors.text : AppColors.sub,
                        fontWeight: hasMedicine ? FontWeight.w600 : FontWeight.w400,
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
          const SizedBox(height: 8),

          // Row 2: Stepper Jumlah (Tablet) + Dosis + Aturan Pakai
          Row(
            children: [
              // Stepper: 1 [▲▼] [Tablet]
              Expanded(
                flex: 5,
                child: Container(
                  height: 34,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Number
                      Text(
                        '${row.jumlah}',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.text,
                        ),
                      ),
                      // Stepper buttons
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          InkWell(
                            onTap: () => setState(() => row.jumlah++),
                            child: const Icon(
                              LucideIcons.chevronUp,
                              size: 11,
                              color: AppColors.sub,
                            ),
                          ),
                          InkWell(
                            onTap: () {
                              if (row.jumlah > 1) {
                                setState(() => row.jumlah--);
                              }
                            },
                            child: const Icon(
                              LucideIcons.chevronDown,
                              size: 11,
                              color: AppColors.sub,
                            ),
                          ),
                        ],
                      ),
                      // Badge Tablet
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: AppColors.orangeLt,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: AppColors.orange.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          row.satuan,
                          style: const TextStyle(
                            fontSize: 9.0,
                            fontWeight: FontWeight.w700,
                            color: AppColors.orange,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),

              // Dropdown Dosis: 3x1
              Expanded(
                flex: 4,
                child: Container(
                  height: 34,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: row.dosis,
                      dropdownColor: Colors.white,
                      icon: const Icon(
                        LucideIcons.chevronDown,
                        size: 12,
                        color: AppColors.sub,
                      ),
                      items: [
                        for (final d in _kDosisList)
                          DropdownMenuItem(
                            value: d,
                            child: Text(
                              d,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.text,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                      onChanged: (v) {
                        if (v != null) setState(() => row.dosis = v);
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),

              // Dropdown Aturan Pakai: Sesudah makan
              Expanded(
                flex: 5,
                child: Container(
                  height: 34,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
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
                                fontWeight: FontWeight.w600,
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
              ),
            ],
          ),

          // Optional Input Manual jika memilih Input manual
          if (row.aturanPakai == 'Input manual') ...[
            const SizedBox(height: 6),
            TextField(
              controller: row.customInstruksiCtrl,
              style: const TextStyle(fontSize: 11, color: AppColors.text),
              decoration: InputDecoration(
                hintText: 'Tuliskan aturan pakai khusus obat...',
                hintStyle: const TextStyle(fontSize: 9.5, color: AppColors.sub),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
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

