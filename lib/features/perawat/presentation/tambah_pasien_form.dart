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
import '../../patients/data/mock_patient_repository.dart';
import '../../patients/domain/doctor.dart';
import '../../patients/domain/patient.dart';
import '../../patients/domain/vitals.dart';

/// Port of the prototype's `TambahPasienForm` — Perawat's patient intake:
/// identity, keluhan awal, tanda vital, and assigning an on-duty doctor.
class TambahPasienForm extends ConsumerStatefulWidget {
  const TambahPasienForm({super.key, required this.onBack, required this.onSaved});

  final VoidCallback onBack;
  final VoidCallback onSaved;

  @override
  ConsumerState<TambahPasienForm> createState() => _TambahPasienFormState();
}

class _TambahPasienFormState extends ConsumerState<TambahPasienForm> {
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
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    final now = TimeOfDay.now();
    final waktu = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final id = 'Q${100 + Random().nextInt(900)}';

    ref.read(patientsProvider.notifier).addPatient(
          Patient(
            id: id,
            nama: _nama.text.trim(),
            nik: _nik.text.trim(),
            jk: _jk!,
            umur: int.tryParse(_umur.text.trim()) ?? 0,
            alamat: _alamat.text.trim(),
            keluhanUtama: _keluhanUtama.text.trim(),
            durasiKeluhan: _durasiKeluhan.text.trim(),
            lokasiKeluhan: _lokasiKeluhan.text.trim(),
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

    widget.onSaved();
  }

  @override
  Widget build(BuildContext context) {
    final onlineDoctors = kDoctors.where((d) => d.online).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ScreenHeader(
          title: 'Pasien Baru',
          subtitle: 'Input identitas & keluhan awal',
          trailing: CircleIconButton(icon: LucideIcons.x, onPressed: widget.onBack),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth > 640;
                final identity = _identitySection();
                final complaint = _complaintSection(onlineDoctors);
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

  Widget _identitySection() {
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
          value: _dokterId,
          options: [for (final d in kOnlineDoctorOptions()) AppSelectOption(value: d.id, label: '${d.nama} — ${d.spesialisasi} (Online)')],
          onChanged: (v) => setState(() => _dokterId = v),
        ),
      ],
    );
  }

  List<Doctor> kOnlineDoctorOptions() => kDoctors.where((d) => d.online).toList();

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
        const SizedBox(height: 11),
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
          label: 'Simpan & Kirim ke Dokter',
          icon: LucideIcons.check,
          full: true,
          loading: _saving,
          onPressed: _valid && !_saving ? _save : null,
        ),
      ],
    );
  }
}
