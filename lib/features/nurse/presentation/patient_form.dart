import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_select.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/circle_icon_button.dart';
import '../../../core/widgets/screen_header.dart';
import '../../patients/data/patient_repository.dart';
import '../../patients/domain/doctor.dart';
import '../../patients/domain/patient.dart';
import '../../patients/domain/vitals.dart';

/// Port of the prototype's `PatientForm` — Nurse's patient intake & edit form:
/// identity, keluhan awal, tanda vital, and assigning an on-duty doctor.
class PatientForm extends ConsumerStatefulWidget {
  const PatientForm({
    super.key,
    required this.onBack,
    required this.onSaved,
    this.initialPatient,
  });

  final VoidCallback onBack;
  final VoidCallback onSaved;
  final Patient? initialPatient;

  bool get isEdit => initialPatient != null;

  @override
  ConsumerState<PatientForm> createState() => _PatientFormState();
}

typedef TambahPasienForm = PatientForm;

class _PatientFormState extends ConsumerState<PatientForm> {
  final _nama = TextEditingController();
  final _nik = TextEditingController();
  final _umur = TextEditingController();
  final _alamat = TextEditingController();
  final _keluhanUtama = TextEditingController();
  final _durasiKeluhan = TextEditingController();
  final _lokasiKeluhan = TextEditingController();
  final _td = TextEditingController();
  final _nadi = TextEditingController();
  final _suhu = TextEditingController();
  final _rr = TextEditingController();
  final _spo2 = TextEditingController();

  Gender? _jk;
  String? _dokterId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.initialPatient;
    if (p != null) {
      _nama.text = p.nama;
      _nik.text = p.nik;
      _umur.text = p.umur > 0 ? p.umur.toString() : '';
      _alamat.text = p.alamat;
      _keluhanUtama.text = p.keluhanUtama;
      _durasiKeluhan.text = p.durasiKeluhan == '-' ? '' : p.durasiKeluhan;
      _lokasiKeluhan.text = p.lokasiKeluhan == '-' ? '' : p.lokasiKeluhan;
      _td.text = p.vitals.tekananDarah;
      _nadi.text = p.vitals.nadi;
      _suhu.text = p.vitals.suhu;
      _rr.text = p.vitals.frekuensiNapas;
      _spo2.text = p.vitals.spo2;
      _jk = p.jk;
      _dokterId = p.assignedDokterId.isNotEmpty ? p.assignedDokterId : null;
    }
  }

  @override
  void dispose() {
    for (final c in [_nama, _nik, _umur, _alamat, _keluhanUtama, _durasiKeluhan, _lokasiKeluhan, _td, _nadi, _suhu, _rr, _spo2]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _valid =>
      _nama.text.trim().isNotEmpty && _jk != null && _umur.text.trim().isNotEmpty && _keluhanUtama.text.trim().isNotEmpty && _dokterId != null;

  Future<void> _save() async {
    if (!_valid) return;
    setState(() => _saving = true);

    try {
      final nikValue = _nik.text.trim().isNotEmpty
          ? _nik.text.trim()
          : '3171${DateTime.now().millisecondsSinceEpoch.toString().padRight(12, '0').substring(0, 12)}';

      final p = widget.initialPatient;
      if (p != null) {
        final updatedPatient = p.copyWith(
          nama: _nama.text.trim(),
          nik: nikValue,
          jk: _jk!,
          umur: int.tryParse(_umur.text.trim()) ?? 0,
          alamat: _alamat.text.trim(),
          keluhanUtama: _keluhanUtama.text.trim(),
          durasiKeluhan: _durasiKeluhan.text.trim().isNotEmpty ? _durasiKeluhan.text.trim() : '-',
          lokasiKeluhan: _lokasiKeluhan.text.trim().isNotEmpty ? _lokasiKeluhan.text.trim() : '-',
          vitals: Vitals(
            tekananDarah: _td.text.trim(),
            nadi: _nadi.text.trim(),
            suhu: _suhu.text.trim(),
            frekuensiNapas: _rr.text.trim(),
            spo2: _spo2.text.trim(),
          ),
          assignedDokterId: _dokterId!,
          updatedAt: DateTime.now(),
        );
        await ref.read(patientsProvider.notifier).updatePatient(updatedPatient);
      } else {
        final now = DateTime.now();
        final waktu = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
        final id = 'Q${100 + Random().nextInt(900)}';

        await ref.read(patientsProvider.notifier).addPatient(
              Patient(
                id: id,
                nama: _nama.text.trim(),
                nik: nikValue,
                jk: _jk!,
                umur: int.tryParse(_umur.text.trim()) ?? 0,
                alamat: _alamat.text.trim(),
                keluhanUtama: _keluhanUtama.text.trim(),
                durasiKeluhan: _durasiKeluhan.text.trim().isNotEmpty ? _durasiKeluhan.text.trim() : '-',
                lokasiKeluhan: _lokasiKeluhan.text.trim().isNotEmpty ? _lokasiKeluhan.text.trim() : '-',
                vitals: Vitals(
                  tekananDarah: _td.text.trim(),
                  nadi: _nadi.text.trim(),
                  suhu: _suhu.text.trim(),
                  frekuensiNapas: _rr.text.trim(),
                  spo2: _spo2.text.trim(),
                ),
                assignedDokterId: _dokterId!,
                waktuMasuk: waktu,
                updatedAt: DateTime.now(),
              ),
            );
      }

      if (!mounted) return;
      setState(() => _saving = false);
      widget.onSaved();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menyimpan data pasien: $e'),
          backgroundColor: AppColors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final doctorsAsync = ref.watch(doctorsProvider);
    final List<Doctor> doctorList = doctorsAsync.maybeWhen(
      data: (list) => list.isNotEmpty ? list : kDoctors,
      orElse: () => kDoctors,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ScreenHeader(
          title: widget.isEdit ? 'Edit Data Pasien' : 'Pasien Baru',
          subtitle: widget.isEdit ? 'Perbarui identitas & keluhan awal' : 'Input identitas & keluhan awal',
          trailing: CircleIconButton(icon: LucideIcons.x, onPressed: widget.onBack),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth > 640;
                final identity = _identitySection(doctorList);
                final complaint = _complaintSection(doctorList);
                if (wide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: identity),
                      const SizedBox(width: 16),
                      Expanded(child: complaint),
                    ],
                  );
                }
                return Column(children: [identity, const SizedBox(height: 16), complaint]);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _identitySection(List<Doctor> doctors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('IDENTITAS PASIEN', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.blue)),
        const SizedBox(height: 11),
        AppTextField(label: 'Nama Lengkap', required: true, controller: _nama, placeholder: 'Nama sesuai identitas', onChanged: (_) => setState(() {})),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AppSelect<Gender>(
                label: 'Jenis Kelamin',
                required: true,
                value: _jk,
                options: const [
                  AppSelectOption(value: Gender.l, label: 'Laki-laki'),
                  AppSelectOption(value: Gender.p, label: 'Perempuan'),
                ],
                onChanged: (v) => setState(() => _jk = v),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: AppTextField(label: 'Umur', required: true, controller: _umur, placeholder: 'Tahun', numbersOnly: true, keyboardType: TextInputType.number, onChanged: (_) => setState(() {})),
            ),
          ],
        ),
        const SizedBox(height: 10),
        AppTextField(label: 'NIK (opsional)', controller: _nik, placeholder: '16 digit NIK', numbersOnly: true, keyboardType: TextInputType.number),
        const SizedBox(height: 10),
        AppTextField(label: 'Alamat', controller: _alamat, placeholder: 'Kota / kabupaten'),
        const SizedBox(height: 10),
        AppSelect<String>(
          label: 'Assign ke Dokter',
          required: true,
          value: (_dokterId != null && doctors.any((d) => d.id == _dokterId))
              ? _dokterId
              : (_dokterId != null
                  ? doctors.where((d) => d.id.toLowerCase() == _dokterId!.toLowerCase() || (d.email != null && d.email!.toLowerCase() == _dokterId!.toLowerCase())).firstOrNull?.id
                  : null),
          options: [
            for (final d in doctors)
              AppSelectOption(
                value: d.id,
                label: '${d.nama} — ${d.spesialisasi}',
              ),
          ],
          onChanged: (v) => setState(() => _dokterId = v),
        ),
      ],
    );
  }


  Widget _complaintSection(List<Doctor> onlineDoctors) {

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('KELUHAN AWAL', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.blue)),
        const SizedBox(height: 11),
        AppTextField(
          label: 'Keluhan Utama',
          required: true,
          controller: _keluhanUtama,
          placeholder: 'Apa yang dikeluhkan pasien?',
          maxLines: 2,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: AppTextField(label: 'Sudah Berapa Lama', controller: _durasiKeluhan, placeholder: 'cth: 2 hari')),
            const SizedBox(width: 10),
            Expanded(child: AppTextField(label: 'Lokasi Keluhan', controller: _lokasiKeluhan, placeholder: 'cth: Dada kiri')),
          ],
        ),
        const SizedBox(height: 14),
        const Text('TANDA VITAL', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.blue)),
        const SizedBox(height: 11r),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: AppTextField(label: 'Tekanan Darah', controller: _td, placeholder: '120/80 mmHg')),
            const SizedBox(width: 10),
            Expanded(child: AppTextField(label: 'Nadi', controller: _nadi, placeholder: 'x/menit', numbersOnly: true, keyboardType: TextInputType.number)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: AppTextField(label: 'Suhu Tubuh', controller: _suhu, placeholder: '°C', keyboardType: const TextInputType.numberWithOptions(decimal: true))),
            const SizedBox(width: 10),
            Expanded(child: AppTextField(label: 'Frek. Napas', controller: _rr, placeholder: 'x/menit', numbersOnly: true, keyboardType: TextInputType.number)),
          ],
        ),
        const SizedBox(height: 10),
        AppTextField(label: 'Saturasi O₂ (SpO₂)', controller: _spo2, placeholder: '%', numbersOnly: true, keyboardType: TextInputType.number),
        const SizedBox(height: 16),
        AppButton(
          label: widget.isEdit ? 'Simpan Perubahan' : 'Simpan & Kirim ke Dokter',
          icon: LucideIcons.check,
          full: true,
          loading: _saving,
          onPressed: _valid && !_saving ? _save : null,
        ),
      ],
    );
  }
}
