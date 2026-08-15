import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_badge.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_select.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../patients/data/mock_patient_repository.dart';
import '../../patients/domain/doctor.dart';
import '../../patients/domain/lab_order.dart';
import '../../patients/domain/patient.dart';
import '../../patients/domain/resep_item.dart';
import '../../patients/presentation/patient_info_card.dart';

/// Port of the prototype's `DokterPatientDetail` — diagnosis + multi-drug
/// prescription + optional lab referral. Read-only summary once diagnosed
/// (matching the prototype: a doctor doesn't re-edit a submitted diagnosis).
class DokterPatientDetail extends ConsumerStatefulWidget {
  const DokterPatientDetail({super.key, required this.patientId});

  final String patientId;

  @override
  ConsumerState<DokterPatientDetail> createState() => _DokterPatientDetailState();
}

class _ResepRow {
  String? obat;
  String dosis = '';
  String instruksi = '';
}

class _DokterPatientDetailState extends ConsumerState<DokterPatientDetail> {
  final _diagnosa = TextEditingController();
  final _catatanLab = TextEditingController();
  final List<_ResepRow> _resep = [_ResepRow()];
  bool? _needLab;
  String? _jenisLab;
  bool _saving = false;

  @override
  void dispose() {
    _diagnosa.dispose();
    _catatanLab.dispose();
    super.dispose();
  }

  bool get _valid => _diagnosa.text.trim().isNotEmpty && _resep.any((r) => r.obat != null) && (_needLab != true || _jenisLab != null);

  Future<void> _submit(Patient patient) async {
    if (!_valid) return;
    setState(() => _saving = true);
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    final resepItems = [
      for (final r in _resep)
        if (r.obat != null) ResepItem(obat: r.obat!, dosis: r.dosis, instruksi: r.instruksi),
    ];
    LabOrder? labOrder = patient.labOrder;
    if (_needLab == true) {
      labOrder = LabOrder(id: 'L${100 + resepItems.length + DateTime.now().millisecond}', jenis: _jenisLab!, catatan: _catatanLab.text.trim());
    }

    ref.read(patientsProvider.notifier).submitDiagnosaResep(
          id: patient.id,
          diagnosa: _diagnosa.text.trim(),
          resep: resepItems,
          labOrder: labOrder,
        );
    setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final patients = ref.watch(patientsProvider);
    final patient = patients.firstWhere((p) => p.id == widget.patientId);
    final alreadyDiagnosed = patient.diagnosa != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PatientInfoCard(patient: patient),
        const SizedBox(height: 11),
        AppCard(
          child: alreadyDiagnosed ? _readOnlySummary(patient) : _form(patient),
        ),
      ],
    );
  }

  Widget _readOnlySummary(Patient p) {
    final resepStatusLabel = switch (p.resepStatus) {
      ResepStatus.selesai => 'Selesai',
      ResepStatus.diproses => 'Diproses Apotek',
      _ => 'Baru — menunggu apotek',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('DIAGNOSA & RESEP', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.blue)),
        const SizedBox(height: 10),
        const Text('Diagnosa', style: TextStyle(fontSize: 11.5, color: AppColors.sub, fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(p.diagnosa ?? '', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.text)),
        const SizedBox(height: 10),
        Text('Resep ($resepStatusLabel)', style: const TextStyle(fontSize: 11.5, color: AppColors.sub, fontWeight: FontWeight.w600)),
        const SizedBox(height: 5),
        for (final r in p.resep)
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
            decoration: BoxDecoration(color: AppColors.card2, borderRadius: BorderRadius.circular(10)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.text, fontFamily: 'PlusJakartaSans'),
                    children: [TextSpan(text: r.obat), TextSpan(text: ' · ${r.dosis}', style: const TextStyle(fontWeight: FontWeight.w500, color: AppColors.sub))],
                  ),
                ),
                const SizedBox(height: 2),
                Text(r.instruksi, style: const TextStyle(fontSize: 11.5, color: AppColors.sub)),
              ],
            ),
          ),
        if (p.labOrder != null) ...[
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.only(top: 10),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Pemeriksaan Lab: ${p.labOrder!.jenis}', style: const TextStyle(fontSize: 11.5, color: AppColors.sub, fontWeight: FontWeight.w600)),
                const SizedBox(height: 5),
                if (p.labOrder!.status == LabOrderStatus.selesai)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(color: AppColors.greenLt, borderRadius: BorderRadius.circular(10)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Hasil tersedia', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.green)),
                        const SizedBox(height: 4),
                        Text(p.labOrder!.hasil?.catatanHasil ?? '', style: const TextStyle(fontSize: 12.5, color: AppColors.text)),
                        if (p.labOrder!.hasil?.fileName != null) ...[
                          const SizedBox(height: 4),
                          Text('📎 ${p.labOrder!.hasil!.fileName}', style: const TextStyle(fontSize: 11.5, color: AppColors.sub)),
                        ],
                      ],
                    ),
                  )
                else
                  const AppBadge(label: 'Menunggu hasil dari Lab', color: AppColors.purple, background: AppColors.purpleLt),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _form(Patient patient) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('DIAGNOSA & RESEP', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.blue)),
        const SizedBox(height: 11),
        AppTextField(label: 'Diagnosa', required: true, controller: _diagnosa, maxLines: 2, placeholder: 'cth: Hipertensi Stage 1 (I10)', onChanged: (_) => setState(() {})),
        const SizedBox(height: 11),
        const Text('Resep Obat', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text)),
        const SizedBox(height: 6),
        for (int i = 0; i < _resep.length; i++) _resepRow(i),
        TextButton(
          onPressed: () => setState(() => _resep.add(_ResepRow())),
          style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
          child: const Text('+ Tambah obat', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.blue)),
        ),
        const SizedBox(height: 11),
        const Text('Perlu pemeriksaan Lab?', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text)),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(child: _labToggleButton('Ya', true)),
            const SizedBox(width: 8),
            Expanded(child: _labToggleButton('Tidak', false)),
          ],
        ),
        if (_needLab == true) ...[
          const SizedBox(height: 11),
          AppSelect<String>(
            label: 'Jenis Pemeriksaan',
            required: true,
            value: _jenisLab,
            options: [for (final j in kJenisLab) AppSelectOption(value: j, label: j)],
            onChanged: (v) => setState(() => _jenisLab = v),
          ),
          const SizedBox(height: 11),
          AppTextField(label: 'Catatan untuk Lab', controller: _catatanLab, maxLines: 2, placeholder: 'cth: Cek Hb & leukosit'),
        ],
        const SizedBox(height: 14),
        AppButton(
          label: 'Simpan Diagnosa & Resep',
          icon: LucideIcons.check,
          full: true,
          loading: _saving,
          onPressed: _valid && !_saving ? () => _submit(patient) : null,
        ),
      ],
    );
  }

  Widget _labToggleButton(String label, bool value) {
    final active = _needLab == value;
    return OutlinedButton(
      onPressed: () => setState(() => _needLab = value),
      style: OutlinedButton.styleFrom(
        backgroundColor: active ? AppColors.blueLt : AppColors.inputBg,
        foregroundColor: active ? AppColors.blue : AppColors.sub,
        side: BorderSide(color: active ? AppColors.blue : AppColors.border, width: 1.5),
        padding: const EdgeInsets.symmetric(vertical: 9),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
    );
  }

  Widget _resepRow(int index) {
    final row = _resep[index];
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            flex: 2,
            child: AppSelect<String>(
              label: index == 0 ? 'Obat' : '',
              value: row.obat,
              options: [for (final o in kObatList) AppSelectOption(value: o, label: o)],
              onChanged: (v) => setState(() => row.obat = v),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: AppTextField(
              label: index == 0 ? 'Dosis' : '',
              placeholder: '1x1',
              onChanged: (v) => row.dosis = v,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: 2,
            child: AppTextField(
              label: index == 0 ? 'Instruksi' : '',
              placeholder: 'Setelah makan',
              onChanged: (v) => row.instruksi = v,
            ),
          ),
          if (_resep.length > 1) ...[
            const SizedBox(width: 6),
            Material(
              color: AppColors.redLt,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => setState(() => _resep.removeAt(index)),
                child: const SizedBox(width: 36, height: 38, child: Icon(LucideIcons.trash2, size: 14, color: AppColors.red)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
