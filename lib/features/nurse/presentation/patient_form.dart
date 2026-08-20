import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_select.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/circle_icon_button.dart';
import '../../patients/data/patient_repository.dart';
import '../../patients/data/wilayah_api.dart';
import '../../patients/domain/doctor.dart';
import '../../patients/domain/patient.dart';
import '../../patients/domain/vitals.dart';

/// Patient intake & edit form with Material UI v3 aesthetics:
/// - DOB datepicker with auto age calculation
/// - Gender dropdown selector
/// - Flexible NIK
/// - Cascading Wilayah (Provinsi -> Kab/Kota -> Kecamatan -> Kelurahan -> Kode Pos) + Manual Free-text Address
/// - Guardian / Wali & Relationship fields
/// - Notes / Keterangan
/// - Searchable Doctor selector
/// - Sticky action button
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
  final _alamat = TextEditingController();
  final _namaWali = TextEditingController();
  final _keterangan = TextEditingController();

  final _keluhanUtama = TextEditingController();
  final _durasiKeluhan = TextEditingController();
  final _lokasiKeluhan = TextEditingController();
  final _td = TextEditingController();
  final _nadi = TextEditingController();
  final _suhu = TextEditingController();
  final _rr = TextEditingController();
  final _spo2 = TextEditingController();

  DateTime? _dob;
  Gender? _jk;
  String? _dokterId;
  String? _hubunganWali;
  bool _saving = false;

  // Wilayah state
  bool _isManualAddress = false;
  List<WilayahProvinsi> _provinsiList = [];
  List<WilayahKabupatenKota> _kabkotaList = [];
  List<WilayahKecamatan> _kecamatanList = [];
  List<WilayahKelurahan> _kelurahanList = [];

  WilayahProvinsi? _selectedProvinsi;
  WilayahKabupatenKota? _selectedKabkota;
  WilayahKecamatan? _selectedKecamatan;
  WilayahKelurahan? _selectedKelurahan;
  bool _loadingWilayah = false;

  final List<String> _hubunganWaliOptions = const [
    'Orang Tua',
    'Suami / Istri',
    'Anak',
    'Saudara Kandung',
    'Keluarga / Kerabat',
    'Rekan Kerja',
    'Lainnya',
  ];

  @override
  void initState() {
    super.initState();
    _initData();
  }

  void _initData() {
    final p = widget.initialPatient;
    if (p != null) {
      _nama.text = p.nama;
      _nik.text = p.nik;
      _alamat.text = p.alamat;
      _namaWali.text = p.namaWali ?? '';
      _hubunganWali = p.hubunganWali;
      _keterangan.text = p.keterangan ?? '';

      _keluhanUtama.text = p.keluhanUtama == 'Pemeriksaan umum' ? '' : p.keluhanUtama;
      _durasiKeluhan.text = p.durasiKeluhan == '-' ? '' : p.durasiKeluhan;
      _lokasiKeluhan.text = p.lokasiKeluhan == '-' ? '' : p.lokasiKeluhan;
      _td.text = p.vitals.tekananDarah;
      _nadi.text = p.vitals.nadi;
      _suhu.text = p.vitals.suhu;
      _rr.text = p.vitals.frekuensiNapas;
      _spo2.text = p.vitals.spo2;
      _jk = p.jk;
      _dokterId = p.assignedDokterId.isNotEmpty ? p.assignedDokterId : null;

      if (p.dob != null && p.dob!.isNotEmpty) {
        _dob = DateTime.tryParse(p.dob!);
      } else if (p.umur > 0) {
        _dob = DateTime(DateTime.now().year - p.umur, 1, 1);
      }
    } else {
      // Default test values for quick testing
      _nama.text = 'Budi Santoso';
      _nik.text = '3171012304950001';
      _dob = DateTime(1995, 4, 23);
      _jk = Gender.l;
      _isManualAddress = false;
      _alamat.text = 'Jl. Pelabuhan Semayang No. 12';
      _namaWali.text = 'Siti Rahmawati';
      _hubunganWali = 'Suami / Istri';
      _keterangan.text = 'Pemeriksaan kesehatan posko kapal';

      _keluhanUtama.text = 'Demam dan sakit kepala sejak kemarin';
      _durasiKeluhan.text = '2 hari';
      _lokasiKeluhan.text = 'Kepala';
      _td.text = '120/80';
      _nadi.text = '80';
      _suhu.text = '37.5';
      _rr.text = '18';
      _spo2.text = '98';
      _dokterId = kDoctors.first.id;
    }

    _loadProvinsi();
  }

  Future<void> _loadProvinsi() async {
    setState(() => _loadingWilayah = true);
    final list = await ref.read(wilayahApiProvider).getProvinsi();
    if (!mounted) return;
    setState(() {
      _provinsiList = list;
      _loadingWilayah = false;
    });

    if (!_isManualAddress && _selectedProvinsi == null && list.isNotEmpty) {
      final defaultProv = list.where((p) => p.namaProvinsi.toLowerCase().contains('kalimantan')).firstOrNull ?? list.first;
      await _onProvinsiChanged(defaultProv);
      if (_kabkotaList.isNotEmpty) {
        await _onKabkotaChanged(_kabkotaList.first);
        if (_kecamatanList.isNotEmpty) {
          await _onKecamatanChanged(_kecamatanList.first);
          if (_kelurahanList.isNotEmpty && mounted) {
            setState(() => _selectedKelurahan = _kelurahanList.first);
          }
        }
      }
    }
  }

  Future<void> _onProvinsiChanged(WilayahProvinsi? prov) async {
    setState(() {
      _selectedProvinsi = prov;
      _selectedKabkota = null;
      _selectedKecamatan = null;
      _selectedKelurahan = null;
      _kabkotaList = [];
      _kecamatanList = [];
      _kelurahanList = [];
    });
    if (prov == null) return;
    final list = await ref.read(wilayahApiProvider).getKabupatenKota(prov.kodeProvinsi);
    if (mounted) {
      setState(() => _kabkotaList = list);
    }
  }

  Future<void> _onKabkotaChanged(WilayahKabupatenKota? kab) async {
    setState(() {
      _selectedKabkota = kab;
      _selectedKecamatan = null;
      _selectedKelurahan = null;
      _kecamatanList = [];
      _kelurahanList = [];
    });
    if (kab == null) return;
    final list = await ref.read(wilayahApiProvider).getKecamatan(kab.kodeKabkota);
    if (mounted) {
      setState(() => _kecamatanList = list);
    }
  }

  Future<void> _onKecamatanChanged(WilayahKecamatan? kec) async {
    setState(() {
      _selectedKecamatan = kec;
      _selectedKelurahan = null;
      _kelurahanList = [];
    });
    if (kec == null) return;
    final list = await ref.read(wilayahApiProvider).getKelurahan(kec.kodeKecamatan);
    if (mounted) {
      setState(() => _kelurahanList = list);
    }
  }

  int _calculateAge(DateTime birthDate) {
    final today = DateTime.now();
    int age = today.year - birthDate.year;
    if (today.month < birthDate.month || (today.month == birthDate.month && today.day < birthDate.day)) {
      age--;
    }
    return age < 0 ? 0 : age;
  }

  Future<void> _selectDob() async {
    final initial = _dob ?? DateTime(1995, 1, 1);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
      helpText: 'PILIH TANGGAL LAHIR',
      confirmText: 'PILIH',
      cancelText: 'BATAL',
    );
    if (picked != null) {
      setState(() => _dob = picked);
    }
  }

  @override
  void dispose() {
    for (final c in [
      _nama,
      _nik,
      _alamat,
      _namaWali,
      _keterangan,
      _keluhanUtama,
      _durasiKeluhan,
      _lokasiKeluhan,
      _td,
      _nadi,
      _suhu,
      _rr,
      _spo2,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _valid =>
      _nama.text.trim().isNotEmpty &&
      _jk != null &&
      _dob != null &&
      _keluhanUtama.text.trim().isNotEmpty &&
      _dokterId != null;

  Future<void> _save() async {
    if (!_valid) return;
    setState(() => _saving = true);

    try {
      final nikValue = _nik.text.trim().isNotEmpty
          ? _nik.text.trim()
          : '3171${DateTime.now().millisecondsSinceEpoch.toString().padRight(12, '0').substring(0, 12)}';

      final dobStr = _dob != null
          ? '${_dob!.year}-${_dob!.month.toString().padLeft(2, '0')}-${_dob!.day.toString().padLeft(2, '0')}'
          : '1995-01-01';

      final umurCalc = _dob != null ? _calculateAge(_dob!) : 0;

      // Construct address string
      String fullAddress = _alamat.text.trim();
      if (!_isManualAddress && _selectedProvinsi != null) {
        final parts = <String>[];
        if (_alamat.text.trim().isNotEmpty) parts.add(_alamat.text.trim());
        if (_selectedKelurahan != null) parts.add('Kel. ${_selectedKelurahan!.namaKelurahan}');
        if (_selectedKecamatan != null) parts.add('Kec. ${_selectedKecamatan!.namaKecamatan}');
        if (_selectedKabkota != null) parts.add(_selectedKabkota!.namaKabkota);
        if (_selectedProvinsi != null) parts.add(_selectedProvinsi!.namaProvinsi);
        if (_selectedKelurahan != null && _selectedKelurahan!.kodePos > 0) parts.add('${_selectedKelurahan!.kodePos}');
        if (parts.isNotEmpty) fullAddress = parts.join(', ');
      }
      if (fullAddress.isEmpty) fullAddress = 'Kalimantan Timur';

      final kodeKel = (!_isManualAddress && _selectedKelurahan != null) ? _selectedKelurahan!.kodeKelurahan : null;
      final kodePosVal = (!_isManualAddress && _selectedKelurahan != null && _selectedKelurahan!.kodePos > 0)
          ? _selectedKelurahan!.kodePos
          : null;

      final p = widget.initialPatient;
      if (p != null) {
        final updatedPatient = p.copyWith(
          nama: _nama.text.trim(),
          nik: nikValue,
          jk: _jk!,
          umur: umurCalc,
          dob: dobStr,
          alamat: fullAddress,
          namaWali: _namaWali.text.trim().isNotEmpty ? _namaWali.text.trim() : null,
          hubunganWali: _hubunganWali,
          keterangan: _keterangan.text.trim().isNotEmpty ? _keterangan.text.trim() : null,
          kodeKelurahan: kodeKel,
          kodePos: kodePosVal,
          keluhanUtama: _keluhanUtama.text.trim().isNotEmpty ? _keluhanUtama.text.trim() : 'Pemeriksaan umum',
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
        final waktu =
            '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
        final id = 'Q${100 + Random().nextInt(900)}';

        await ref.read(patientsProvider.notifier).addPatient(
              Patient(
                id: id,
                nama: _nama.text.trim(),
                nik: nikValue,
                jk: _jk!,
                umur: umurCalc,
                dob: dobStr,
                alamat: fullAddress,
                namaWali: _namaWali.text.trim().isNotEmpty ? _namaWali.text.trim() : null,
                hubunganWali: _hubunganWali,
                keterangan: _keterangan.text.trim().isNotEmpty ? _keterangan.text.trim() : null,
                kodeKelurahan: kodeKel,
                kodePos: kodePosVal,
                keluhanUtama: _keluhanUtama.text.trim().isNotEmpty ? _keluhanUtama.text.trim() : 'Pemeriksaan umum',
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

  void _showDoctorSearchModal(List<Doctor> doctors) {
    showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) => _DoctorSearchModal(
        doctors: doctors,
        selectedId: _dokterId,
        onSelect: (selectedDoctorId) {
          setState(() => _dokterId = selectedDoctorId);
          Navigator.of(modalContext).pop();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final doctorsAsync = ref.watch(doctorsProvider);
    final List<Doctor> doctorList = doctorsAsync.maybeWhen(
      data: (list) => list.isNotEmpty ? list : kDoctors,
      orElse: () => kDoctors,
    );
    if (_dokterId == null && doctorList.isNotEmpty) {
      _dokterId = doctorList.first.id;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Material UI Header with Back Button beside title
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: const BoxDecoration(
            color: AppColors.card,
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              CircleIconButton(
                icon: LucideIcons.arrowLeft,
                onPressed: widget.onBack,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.isEdit ? 'Edit Data Pasien' : 'Pasien Baru',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.isEdit
                          ? 'Perbarui identitas & keluhan klinis'
                          : 'Input identitas & registrasi pasien ke antrian',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.sub,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Scrollable Form Content
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth > 700;
                final leftColumn = Column(
                  children: [
                    _buildDoctorCard(doctorList),
                    const SizedBox(height: 14),
                    _buildIdentityCard(),
                    const SizedBox(height: 14),
                    _buildWilayahCard(),
                    const SizedBox(height: 14),
                    _buildGuardianCard(),
                  ],
                );

                final rightColumn = Column(
                  children: [
                    _buildComplaintAndVitalsCard(),
                  ],
                );

                if (wide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: leftColumn),
                      const SizedBox(width: 14),
                      Expanded(child: rightColumn),
                    ],
                  );
                }

                return Column(
                  children: [
                    leftColumn,
                    const SizedBox(height: 14),
                    rightColumn,
                  ],
                );
              },
            ),
          ),
        ),

        // Sticky Bottom Action Bar
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          decoration: BoxDecoration(
            color: AppColors.card,
            border: const Border(top: BorderSide(color: AppColors.border)),
            boxShadow: [
              BoxShadow(
                color: AppColors.text.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, -3),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: AppButton(
              label: widget.isEdit ? 'Simpan Perubahan' : 'Simpan',
              full: true,
              loading: _saving,
              onPressed: _valid && !_saving ? _save : null,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDoctorCard(List<Doctor> doctors) {
    final selectedDoc = doctors.where((d) => d.id == _dokterId).firstOrNull;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            icon: LucideIcons.stethoscope,
            iconColor: AppColors.blue,
            iconBg: AppColors.blueLt,
            title: 'DOKTER PEMERIKSA',
          ),
          const SizedBox(height: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Text(
                    'Assign ke Dokter',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.sub),
                  ),
                  Text(' *', style: TextStyle(color: AppColors.red, fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () => _showDoctorSearchModal(doctors),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                  decoration: BoxDecoration(
                    color: AppColors.inputBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _dokterId != null ? AppColors.blue.withValues(alpha: 0.5) : AppColors.border,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _dokterId != null ? AppColors.blueLt : AppColors.border.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          LucideIcons.stethoscope,
                          size: 16,
                          color: _dokterId != null ? AppColors.blue : AppColors.sub,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: selectedDoc != null
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    selectedDoc.nama,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.text,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    selectedDoc.spesialisasi,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.sub,
                                    ),
                                  ),
                                ],
                              )
                            : const Text(
                                'Pilih dokter pemeriksa...',
                                style: TextStyle(fontSize: 13, color: AppColors.sub),
                              ),
                      ),
                      const Icon(LucideIcons.chevronDown, size: 16, color: AppColors.sub),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIdentityCard() {
    final dobFormatted = _dob != null
        ? '${_dob!.day.toString().padLeft(2, '0')}/${_dob!.month.toString().padLeft(2, '0')}/${_dob!.year}'
        : 'Pilih Tanggal Lahir';
    final ageText = _dob != null ? '${_calculateAge(_dob!)} tahun' : '';

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            icon: LucideIcons.user,
            iconColor: AppColors.blue,
            iconBg: AppColors.blueLt,
            title: 'IDENTITAS PASIEN',
          ),
          const SizedBox(height: 14),

          // Nama Lengkap
          AppTextField(
            label: 'Nama Lengkap',
            required: true,
            controller: _nama,
            placeholder: 'Nama sesuai identitas KTP/Paspor',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),

          // Tanggal Lahir (DOB) & Jenis Kelamin Dropdown Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tanggal Lahir DatePicker
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Text(
                          'Tanggal Lahir',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.sub),
                        ),
                        Text(' *', style: TextStyle(color: AppColors.red, fontWeight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: _selectDob,
                      child: Container(
                        height: 44,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: AppColors.inputBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            const Icon(LucideIcons.calendar, size: 16, color: AppColors.blue),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                dobFormatted,
                                style: const TextStyle(fontSize: 13, color: AppColors.text, fontWeight: FontWeight.w600),
                              ),
                            ),
                            if (ageText.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.blueLt,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  ageText,
                                  style: const TextStyle(fontSize: 11, color: AppColors.blue, fontWeight: FontWeight.w700),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),

              // Jenis Kelamin Dropdown
              Expanded(
                flex: 3,
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
            ],
          ),
          const SizedBox(height: 12),

          // NIK (Flexible, no 16-digit restriction)
          AppTextField(
            label: 'NIK (Nomor Induk Kependudukan)',
            controller: _nik,
            placeholder: 'Nomor NIK / KTP / Paspor (opsional)',
          ),
        ],
      ),
    );
  }

  Widget _buildWilayahCard() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  _buildSectionHeader(
                    icon: LucideIcons.mapPin,
                    iconColor: AppColors.blue,
                    iconBg: AppColors.blueLt,
                    title: 'ALAMAT & WILAYAH',
                  ),
                  if (_loadingWilayah) ...[
                    const SizedBox(width: 8),
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.blue),
                    ),
                  ],
                ],
              ),
              // Toggle manual free-text
              GestureDetector(
                onTap: () => setState(() => _isManualAddress = !_isManualAddress),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isManualAddress ? LucideIcons.checkSquare : LucideIcons.square,
                      size: 16,
                      color: _isManualAddress ? AppColors.blue : AppColors.sub,
                    ),
                    const SizedBox(width: 5),
                    const Text(
                      'Input Manual',
                      style: TextStyle(fontSize: 11.5, color: AppColors.sub, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          if (!_isManualAddress) ...[
            // Provinsi & Kabupaten Row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: AppSelect<WilayahProvinsi>(
                    label: 'Provinsi',
                    value: _selectedProvinsi,
                    options: [
                      for (final p in _provinsiList)
                        AppSelectOption(value: p, label: p.namaProvinsi),
                    ],
                    onChanged: _onProvinsiChanged,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AppSelect<WilayahKabupatenKota>(
                    label: 'Kabupaten / Kota',
                    value: _selectedKabkota,
                    options: [
                      for (final k in _kabkotaList)
                        AppSelectOption(value: k, label: k.namaKabkota),
                    ],
                    onChanged: _onKabkotaChanged,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Kecamatan & Kelurahan Row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: AppSelect<WilayahKecamatan>(
                    label: 'Kecamatan',
                    value: _selectedKecamatan,
                    options: [
                      for (final k in _kecamatanList)
                        AppSelectOption(value: k, label: k.namaKecamatan),
                    ],
                    onChanged: _onKecamatanChanged,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AppSelect<WilayahKelurahan>(
                    label: 'Kelurahan / Desa',
                    value: _selectedKelurahan,
                    options: [
                      for (final k in _kelurahanList)
                        AppSelectOption(
                          value: k,
                          label: k.kodePos > 0 ? '${k.namaKelurahan} (${k.kodePos})' : k.namaKelurahan,
                        ),
                    ],
                    onChanged: (v) => setState(() => _selectedKelurahan = v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],

          // Detail Alamat Jalan / RT / RW
          AppTextField(
            label: _isManualAddress ? 'Alamat Lengkap (Free-text)' : 'Detail Jalan / RT / RW',
            controller: _alamat,
            placeholder: _isManualAddress
                ? 'Masukkan alamat lengkap jika daerah belum terdaftar...'
                : 'Cth: Jl. Pelabuhan No. 12, RT 03/RW 02',
            maxLines: _isManualAddress ? 2 : 1,
          ),
        ],
      ),
    );
  }

  Widget _buildGuardianCard() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            icon: LucideIcons.users,
            iconColor: AppColors.purple,
            iconBg: AppColors.purpleLt,
            title: 'WALI / PENDAMPING & KETERANGAN',
          ),
          const SizedBox(height: 14),

          // Nama Wali & Hubungan Wali Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: AppTextField(
                  label: 'Nama Wali / Pendamping',
                  controller: _namaWali,
                  placeholder: 'Nama lengkap wali / pendamping',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 3,
                child: AppSelect<String>(
                  label: 'Hubungan dengan Pasien',
                  value: _hubunganWali,
                  options: [
                    for (final h in _hubunganWaliOptions)
                      AppSelectOption(value: h, label: h),
                  ],
                  onChanged: (v) => setState(() => _hubunganWali = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Keterangan Tambahan
          AppTextField(
            label: 'Keterangan Tambahan',
            controller: _keterangan,
            placeholder: 'Catatan tambahan terkait pasien / penerima manfaat...',
            maxLines: 2,
          ),
        ],
      ),
    );
  }

  Widget _buildComplaintAndVitalsCard() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            icon: LucideIcons.stethoscope,
            iconColor: AppColors.orange,
            iconBg: AppColors.orangeLt,
            title: 'KELUHAN AWAL & TANDA VITAL',
          ),
          const SizedBox(height: 14),

          // Keluhan Utama
          AppTextField(
            label: 'Keluhan Utama',
            required: true,
            controller: _keluhanUtama,
            placeholder: 'Apa keluhan atau gejala yang dirasakan pasien?',
            maxLines: 2,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),

          // Durasi & Lokasi Keluhan
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AppTextField(
                  label: 'Durasi Keluhan',
                  controller: _durasiKeluhan,
                  placeholder: 'cth: 2 hari',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppTextField(
                  label: 'Lokasi Keluhan',
                  controller: _lokasiKeluhan,
                  placeholder: 'cth: Dada kiri, Perut',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Divider with Section Subheading for Tanda Vital
          Row(
            children: const [
              Icon(LucideIcons.activity, size: 14, color: AppColors.green),
              SizedBox(width: 6),
              Text(
                'TANDA VITAL',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  color: AppColors.green,
                ),
              ),
              SizedBox(width: 8),
              Expanded(child: Divider(color: AppColors.border, height: 1)),
            ],
          ),
          const SizedBox(height: 12),

          // Vitals Row 1: Tekanan Darah & Nadi
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AppTextField(
                  label: 'Tekanan Darah',
                  controller: _td,
                  placeholder: '120/80 mmHg',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppTextField(
                  label: 'Nadi',
                  controller: _nadi,
                  placeholder: 'x/menit (bpm)',
                  numbersOnly: true,
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Vitals Row 2: Suhu Tubuh & Frekuensi Napas
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AppTextField(
                  label: 'Suhu Tubuh',
                  controller: _suhu,
                  placeholder: '°C (cth: 36.5)',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppTextField(
                  label: 'Frek. Napas',
                  controller: _rr,
                  placeholder: 'x/menit',
                  numbersOnly: true,
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Vitals Row 3: Saturasi Oksigen
          AppTextField(
            label: 'Saturasi Oksigen (SpO₂)',
            controller: _spo2,
            placeholder: '% (cth: 98)',
            numbersOnly: true,
            keyboardType: TextInputType.number,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
  }) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 14, color: iconColor),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
            color: iconColor,
          ),
        ),
      ],
    );
  }
}

/// Material UI Searchable Modal for Doctor selection
class _DoctorSearchModal extends StatefulWidget {
  const _DoctorSearchModal({
    required this.doctors,
    required this.selectedId,
    required this.onSelect,
  });

  final List<Doctor> doctors;
  final String? selectedId;
  final ValueChanged<String> onSelect;

  @override
  State<_DoctorSearchModal> createState() => _DoctorSearchModalState();
}

class _DoctorSearchModalState extends State<_DoctorSearchModal> {
  final _searchController = TextEditingController();
  String _search = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.trim().toLowerCase();
    final filtered = widget.doctors.where((d) {
      if (query.isEmpty) return true;
      final nameMatches = d.nama.toLowerCase().contains(query);
      final specMatches = d.spesialisasi.toLowerCase().contains(query);
      return nameMatches || specMatches;
    }).toList();

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
                const Text(
                  'Pilih Dokter',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.text),
                ),
                CircleIconButton(
                  icon: LucideIcons.x,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),

          // Search Input Bar (Natural Typography & Spacing)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.inputBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                children: [
                  const Icon(LucideIcons.search, size: 16, color: AppColors.sub),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: (v) => setState(() => _search = v),
                      textAlignVertical: TextAlignVertical.center,
                      style: const TextStyle(fontSize: 13, color: AppColors.text),
                      decoration: const InputDecoration(
                        hintText: 'Cari nama dokter atau spesialisasi...',
                        hintStyle: TextStyle(fontSize: 13, color: AppColors.sub),
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                      ),
                    ),
                  ),
                  if (_search.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        _searchController.clear();
                        setState(() => _search = '');
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

          // Doctor List
          Flexible(
            child: filtered.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Text(
                      'Dokter tidak ditemukan.',
                      style: TextStyle(fontSize: 13, color: AppColors.sub),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final doc = filtered[index];
                      final isSelected = doc.id == widget.selectedId;

                      return GestureDetector(
                        onTap: () => widget.onSelect(doc.id),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.blueLt.withValues(alpha: 0.6) : AppColors.card2,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? AppColors.blue : AppColors.border,
                              width: isSelected ? 1.5 : 1.0,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: isSelected ? AppColors.blue : AppColors.blueLt,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  doc.nama.isNotEmpty ? doc.nama[0] : 'D',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: isSelected ? Colors.white : AppColors.blue,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      doc.nama,
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w700,
                                        color: isSelected ? AppColors.blue : AppColors.text,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppColors.card,
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: AppColors.border),
                                          ),
                                          child: Text(
                                            doc.spesialisasi,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: AppColors.sub,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                const Icon(
                                  LucideIcons.check,
                                  size: 18,
                                  color: AppColors.blue,
                                ),
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
}
