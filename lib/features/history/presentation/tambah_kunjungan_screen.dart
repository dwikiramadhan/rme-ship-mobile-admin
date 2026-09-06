import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_badge.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_select.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/circle_icon_button.dart';
import '../../auth/domain/user_role.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../environment/presentation/environment_controller.dart';
import '../../nurse/presentation/patient_form.dart';
import '../../patients/data/patient_repository.dart';
import '../../patients/domain/doctor.dart';
import '../../patients/domain/patient.dart';

/// Form Input Kunjungan Baru / Tambah Riwayat Kunjungan
/// Memungkinkan perawat atau dokter mencatat kunjungan rekam medis baru untuk pasien terdaftar:
/// - Pencarian interaktif pasien (Nama, NIK, No RM) + Ringkasan & Ganti Pasien
/// - Dokter Pemeriksa (otomatis dokter login atau pilih dokter kapal)
/// - Poliklinik Tujuan (Poli Umum, Gigi, Mata, dll)
/// - Keluhan Utama, Durasi, dan Lokasi
/// - Tanda-Tanda Vital (TD, Nadi, Suhu, RR, SpO2, BB, TB)
/// - Mengirim POST ke /patients/:id/medical-records dengan status_penanganan "Menunggu Dokter"
///   serta memperbarui tanda vital pasien pada tabel patients.
class TambahKunjunganScreen extends ConsumerStatefulWidget {
  const TambahKunjunganScreen({
    super.key,
    required this.onBack,
    required this.onSaved,
    this.initialPatient,
  });

  final VoidCallback onBack;
  final VoidCallback onSaved;
  final Patient? initialPatient;

  @override
  ConsumerState<TambahKunjunganScreen> createState() =>
      _TambahKunjunganScreenState();
}

typedef TambahRiwayatKunjunganPage = TambahKunjunganScreen;

class _TambahKunjunganScreenState extends ConsumerState<TambahKunjunganScreen> {
  // Selected Patient
  Patient? _selectedPatient;

  // Doctor & Poliklinik
  String? _selectedDoctorId;
  String _poliCode = 'UMUM';

  // Complaint
  final _keluhanUtama = TextEditingController();
  final _durasiKeluhan = TextEditingController();
  final _lokasiKeluhan = TextEditingController();

  // Vitals
  final _sistolik = TextEditingController();
  final _diastolik = TextEditingController();
  final _nadi = TextEditingController();
  final _suhu = TextEditingController();
  final _rr = TextEditingController();
  final _spo2 = TextEditingController();
  final _beratBadan = TextEditingController();
  final _tinggiBadan = TextEditingController();

  // Notes
  final _catatan = TextEditingController();

  bool _saving = false;
  String? _errorMessage;

  static const _poliOptions = [
    AppSelectOption(value: 'UMUM', label: 'Poli Umum'),
    AppSelectOption(value: 'GIGI', label: 'Poli Gigi'),
    AppSelectOption(value: 'MATA', label: 'Poli Mata'),
    AppSelectOption(value: 'ANAK', label: 'Poli Anak'),
    AppSelectOption(value: 'KANDUNGAN', label: 'Poli Kandungan'),
    AppSelectOption(value: 'BEDAH', label: 'Poli Bedah'),
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialPatient != null) {
      _selectedPatient = widget.initialPatient;
      _populateFromPatient(widget.initialPatient!);
    }
  }

  void _populateFromPatient(Patient p) {
    if (p.vitals.tekananDarah.isNotEmpty) {
      final parts = p.vitals.tekananDarah.split('/');
      if (parts.isNotEmpty) _sistolik.text = parts[0].trim();
      if (parts.length > 1) _diastolik.text = parts[1].trim();
    }
    if (p.vitals.nadi.isNotEmpty) _nadi.text = p.vitals.nadi;
    if (p.vitals.suhu.isNotEmpty) _suhu.text = p.vitals.suhu;
    if (p.vitals.frekuensiNapas.isNotEmpty) _rr.text = p.vitals.frekuensiNapas;
    if (p.vitals.spo2.isNotEmpty) _spo2.text = p.vitals.spo2;
    if (p.assignedDokterId.isNotEmpty) _selectedDoctorId = p.assignedDokterId;
  }

  @override
  void dispose() {
    _keluhanUtama.dispose();
    _durasiKeluhan.dispose();
    _lokasiKeluhan.dispose();

    _sistolik.dispose();
    _diastolik.dispose();
    _nadi.dispose();
    _suhu.dispose();
    _rr.dispose();
    _spo2.dispose();
    _beratBadan.dispose();
    _tinggiBadan.dispose();
    _catatan.dispose();
    super.dispose();
  }

  void _showPatientModal() {
    showModalBottomSheet<Patient>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) => PatientSearchModal(
        selectedId: _selectedPatient?.id,
        onSelect: (patient) {
          setState(() {
            _selectedPatient = patient;
            _populateFromPatient(patient);
          });
          Navigator.of(modalContext).pop();
        },
      ),
    );
  }

  void _showDoctorModal(List<Doctor> doctors) {
    showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) => DoctorSearchModal(
        doctors: doctors,
        selectedId: _selectedDoctorId,
        onSelect: (id) {
          setState(() => _selectedDoctorId = id);
          Navigator.of(modalContext).pop();
        },
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _errorMessage = null);

    if (_selectedPatient == null) {
      setState(
        () => _errorMessage = 'Silakan cari & pilih pasien terlebih dahulu.',
      );
      return;
    }

    if (_keluhanUtama.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Keluhan utama wajib diisi.');
      return;
    }

    final doctorsAsync = ref.read(doctorsProvider);
    final doctorList = doctorsAsync.maybeWhen(
      data: (list) => list.isNotEmpty ? list : kDoctors,
      orElse: () => kDoctors,
    );
    final effectiveDoctorId =
        (_selectedDoctorId != null && _selectedDoctorId!.isNotEmpty)
        ? _selectedDoctorId!
        : (doctorList.isNotEmpty
              ? doctorList.first.id
              : '0f3a4534-3385-4305-8932-7154dd8cb35f');

    // Ambil ship code & ship id dari local storage (bayan_rme.active_environment_code & bayan_rme.active_environment_ship_id)
    String? activeEnvCode;
    String? activeEnvShipId;
    try {
      final envStorage = ref.read(environmentStorageProvider);
      activeEnvCode = await envStorage.getCode();
      activeEnvShipId = await envStorage.getShipId();
    } catch (_) {
      // Fallback
    }
    if (activeEnvCode == null || activeEnvCode.trim().isEmpty) {
      activeEnvCode = ref.read(activeEnvironmentCodeProvider);
    }
    if (activeEnvShipId == null || activeEnvShipId.trim().isEmpty) {
      activeEnvShipId = ref.read(activeEnvironmentShipIdProvider);
    }

    final effectiveShipId =
        (activeEnvShipId != null && activeEnvShipId.trim().isNotEmpty)
        ? activeEnvShipId.trim()
        : (_selectedPatient?.serviceShipCode ??
              '3a7ff982-e187-49f8-a34e-95f775afda61');
    final effectiveShipCode =
        (activeEnvCode != null && activeEnvCode.trim().isNotEmpty)
        ? activeEnvCode.trim()
        : (_selectedPatient?.serviceShipCode ?? effectiveShipId);
    const effectivePortId =
        '85bc4ed2-2a82-44dc-b831-eb99a5165575'; // Pelabuhan default

    // Parse Vitals
    final sys = int.tryParse(_sistolik.text.trim());
    final dia = int.tryParse(_diastolik.text.trim());
    String bp = '';
    if (sys != null && dia != null) {
      bp = '$sys/$dia';
    } else if (_sistolik.text.trim().isNotEmpty) {
      bp = _sistolik.text.trim();
    }

    final hr = int.tryParse(_nadi.text.trim());
    final temp = double.tryParse(_suhu.text.trim().replaceAll(',', '.'));
    final rr = int.tryParse(_rr.text.trim());
    final spo2 = double.tryParse(_spo2.text.trim().replaceAll(',', '.'));
    final weight = double.tryParse(
      _beratBadan.text.trim().replaceAll(',', '.'),
    );
    final height = double.tryParse(
      _tinggiBadan.text.trim().replaceAll(',', '.'),
    );

    // Form complaint with duration & location if provided
    final complaintParts = <String>[_keluhanUtama.text.trim()];
    if (_durasiKeluhan.text.trim().isNotEmpty) {
      complaintParts.add('Durasi: ${_durasiKeluhan.text.trim()}');
    }
    if (_lokasiKeluhan.text.trim().isNotEmpty) {
      complaintParts.add('Lokasi: ${_lokasiKeluhan.text.trim()}');
    }
    final fullComplaint = complaintParts.join(' • ');

    final dateStr = DateTime.now().toIso8601String().split('T').first;

    final recordBody = <String, dynamic>{
      'doctor_id': effectiveDoctorId,
      'ship_id': effectiveShipId,
      'ship_code': effectiveShipCode,
      'port_id': effectivePortId,
      'poli_code': _poliCode,
      'date': dateStr,
      'complaint': fullComplaint,
      'diagnosis': 'Pemeriksaan Awal',
      'treatment': 'Menunggu Pemeriksaan Dokter',
      'notes': _catatan.text.trim().isNotEmpty
          ? _catatan.text.trim()
          : 'Pendaftaran kunjungan poli $_poliCode',
      'status': 'Stable',
      'status_penanganan': 'Menunggu Dokter',
    };
    if (sys != null) recordBody['systolic'] = sys;
    if (dia != null) recordBody['diastolic'] = dia;
    if (bp.isNotEmpty) recordBody['blood_pressure'] = bp;
    if (hr != null) recordBody['heart_rate'] = hr;
    if (temp != null) recordBody['temperature'] = temp;
    if (rr != null) recordBody['respiratory_rate'] = rr;
    if (spo2 != null) recordBody['oxygen_saturation'] = spo2;
    if (weight != null) recordBody['weight_kg'] = weight;
    if (height != null) recordBody['height_cm'] = height;

    final vitalsData = <String, dynamic>{};
    if (bp.isNotEmpty) vitalsData['tekanan_darah'] = bp;
    if (sys != null) vitalsData['systolic'] = sys;
    if (dia != null) vitalsData['diastolic'] = dia;
    if (hr != null) vitalsData['nadi'] = hr.toString();
    if (temp != null) vitalsData['suhu'] = temp.toString();
    if (rr != null) vitalsData['frekuensi_napas'] = rr.toString();
    if (spo2 != null) vitalsData['spo2'] = spo2.toString();

    final patientUpdates = <String, dynamic>{
      'status_penanganan': 'Menunggu Dokter',
      'doctor_id': effectiveDoctorId,
      'ship_id': effectiveShipId,
      'ship_code': effectiveShipCode,
      'service_ship_code': effectiveShipCode,
      'keluhan_utama': _keluhanUtama.text.trim(),
      if (_durasiKeluhan.text.trim().isNotEmpty)
        'durasi_keluhan': _durasiKeluhan.text.trim(),
      if (_lokasiKeluhan.text.trim().isNotEmpty)
        'lokasi_keluhan': _lokasiKeluhan.text.trim(),
      'vitals': vitalsData,
    };

    setState(() => _saving = true);
    try {
      await ref
          .read(patientsProvider.notifier)
          .addKunjungan(
            patientId: _selectedPatient!.id,
            recordData: recordBody,
            patientUpdates: patientUpdates,
          );

      // Refresh riwayat kunjungan
      ref.read(medicalHistoryProvider.notifier).fetchHistory(refresh: true);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Kunjungan berhasil ditambahkan untuk ${_selectedPatient!.nama} (Status: Menunggu Dokter)',
            ),
            backgroundColor: AppColors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        widget.onSaved();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _errorMessage = 'Gagal menyimpan kunjungan: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final currentUser = authState.session?.user;
    final isCurrentUserDoctor = currentUser?.role == UserRole.dokter;

    final doctorsAsync = ref.watch(doctorsProvider);
    final doctorList = doctorsAsync.maybeWhen(
      data: (list) => list.isNotEmpty ? list : kDoctors,
      orElse: () => kDoctors,
    );

    // If current user is doctor and doctor not yet selected, pre-fill doctor
    if (_selectedDoctorId == null &&
        isCurrentUserDoctor &&
        doctorList.isNotEmpty) {
      final myDoctor = doctorList
          .where(
            (d) =>
                d.id == currentUser?.id ||
                d.nama.toLowerCase().contains(
                  currentUser?.name.toLowerCase() ?? '',
                ) ||
                d.email?.toLowerCase() == currentUser?.email.toLowerCase(),
          )
          .firstOrNull;
      _selectedDoctorId = myDoctor?.id ?? doctorList.first.id;
    } else if (_selectedDoctorId == null && doctorList.isNotEmpty) {
      _selectedDoctorId = doctorList.first.id;
    }

    final selectedDoctor =
        doctorList.where((d) => d.id == _selectedDoctorId).firstOrNull ??
        (doctorList.isNotEmpty ? doctorList.first : null);

    final theme = Theme.of(context);
    final compactTheme = theme.copyWith(
      inputDecorationTheme: theme.inputDecorationTheme.copyWith(
        contentPadding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        hintStyle: const TextStyle(color: AppColors.sub, fontSize: 10.5),
        isDense: true,
      ),
    );

    return Theme(
      data: compactTheme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // App Header with back button
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: AppColors.card,
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                CircleIconButton(
                  icon: LucideIcons.arrowLeft,
                  onPressed: widget.onBack,
                  size: 34,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Text(
                        'Input Kunjungan Baru',
                        style: TextStyle(
                          fontSize: 13.0,
                          fontWeight: FontWeight.w800,
                          color: AppColors.text,
                        ),
                      ),
                      SizedBox(height: 1.5),
                      Text(
                        'Pencatatan rekam medis & pemeriksaan triage kunjungan pasien',
                        style: TextStyle(
                          fontSize: 9.5,
                          color: AppColors.sub,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

        // Error message banner if any
        if (_errorMessage != null)
          Container(
            color: AppColors.redLt,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                const Icon(
                  LucideIcons.alertCircle,
                  size: 16,
                  color: AppColors.red,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.red,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() => _errorMessage = null),
                  child: const Icon(
                    LucideIcons.x,
                    size: 14,
                    color: AppColors.red,
                  ),
                ),
              ],
            ),
          ),

        // Scrollable Form Body
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth > 850;

                final leftColumn = Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildPatientSelectionCard(),
                    const SizedBox(height: 14),
                    _buildDoctorAndPoliCard(
                      selectedDoctor,
                      doctorList,
                      isCurrentUserDoctor,
                    ),
                  ],
                );

                final rightColumn = Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildComplaintCard(),
                    const SizedBox(height: 14),
                    _buildVitalsCard(),
                    const SizedBox(height: 14),
                    _buildNotesCard(),
                  ],
                );

                if (wide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 5, child: leftColumn),
                      const SizedBox(width: 14),
                      Expanded(flex: 5, child: rightColumn),
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

        // Bottom Action Bar
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
              label: 'Simpan Kunjungan',
              icon: LucideIcons.check,
              full: true,
              loading: _saving,
              onPressed: _saving ? null : _save,
            ),
          ),
        ),
      ],
    ),
  );
}

  // ==========================================
  // Section: Pilih Pasien
  // ==========================================
  Widget _buildPatientSelectionCard() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.blueLt,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  LucideIcons.userCheck,
                  size: 16,
                  color: AppColors.blue,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Pilih Pasien',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
              ),
              if (_selectedPatient != null)
                const AppBadge(
                  label: 'Terpilih',
                  color: AppColors.green,
                  background: AppColors.greenLt,
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Selector field styled after "Assign ke Dokter"
          const AppFieldLabel(
            label: 'Nama Pasien / No. RM',
            required: true,
            fontSize: 10.5,
          ),
          const SizedBox(height: 5),
          GestureDetector(
            onTap: _showPatientModal,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              decoration: BoxDecoration(
                color: AppColors.inputBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _selectedPatient != null
                      ? AppColors.blue.withValues(alpha: 0.5)
                      : AppColors.border,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _selectedPatient != null
                          ? AppColors.blueLt
                          : AppColors.border.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      LucideIcons.user,
                      size: 16,
                      color: _selectedPatient != null
                          ? AppColors.blue
                          : AppColors.sub,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _selectedPatient != null
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _selectedPatient!.nama,
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.text,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${_selectedPatient!.registerNo.isNotEmpty ? _selectedPatient!.registerNo : "-"} • NIK: ${_selectedPatient!.nik}',
                                style: const TextStyle(
                                  fontSize: 9.0,
                                  color: AppColors.sub,
                                ),
                              ),
                            ],
                          )
                        : const Text(
                            'Pilih pasien...',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: AppColors.sub,
                            ),
                          ),
                  ),
                  const Icon(
                    LucideIcons.chevronDown,
                    size: 16,
                    color: AppColors.sub,
                  ),
                ],
              ),
            ),
          ),

          // Detail card when patient is selected
          if (_selectedPatient != null) ...[
            const SizedBox(height: 12),
            _buildSelectedPatientSummary(_selectedPatient!),
          ],
        ],
      ),
    );
  }

  Widget _buildSelectedPatientSummary(Patient p) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.blueLt.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.blue.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.blue,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Text(
                  p.nama.isNotEmpty ? p.nama[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.nama,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.card,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Text(
                            p.registerNo.isNotEmpty ? p.registerNo : 'RM: -',
                            style: const TextStyle(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.blue,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'NIK: ${p.nik}',
                          style: const TextStyle(
                            fontSize: 9.0,
                            color: AppColors.sub,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 10),

          // Demographics Grid
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              _infoPill('Gender', p.jk.label),
              _infoPill('Umur', '${p.umur} thn'),
              _infoPill('Gol. Darah', p.bloodType ?? '-'),
              if (p.phone != null && p.phone!.isNotEmpty && p.phone != '-')
                _infoPill('No. Telp', p.phone!),
              if (p.namaWali != null &&
                  p.namaWali!.isNotEmpty &&
                  p.namaWali != '-')
                _infoPill('Wali', p.namaWali!),
            ],
          ),

          if (p.alamat.isNotEmpty && p.alamat != '-') ...[
            const SizedBox(height: 8),
            Text(
              'Alamat: ${p.alamat}',
              style: const TextStyle(fontSize: 9.0, color: AppColors.sub),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: AppButton(
              label: 'Ganti Pasien',
              icon: LucideIcons.refreshCw,
              small: true,
              variant: AppButtonVariant.ghost,
              onPressed: _showPatientModal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoPill(String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label: ',
          style: const TextStyle(fontSize: 9.0, color: AppColors.sub),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 9.0,
            fontWeight: FontWeight.w700,
            color: AppColors.text,
          ),
        ),
      ],
    );
  }

  // ==========================================
  // Section: Poliklinik & Dokter Pemeriksa
  // ==========================================
  Widget _buildDoctorAndPoliCard(
    Doctor? selectedDoctor,
    List<Doctor> doctorList,
    bool isCurrentUserDoctor,
  ) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.blueLt,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  LucideIcons.stethoscope,
                  size: 16,
                  color: AppColors.blue,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Poliklinik & Dokter Pemeriksa',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Dropdown Poliklinik
          AppSelect<String>(
            label: 'Poliklinik Tujuan',
            required: true,
            value: _poliCode,
            options: _poliOptions,
            fontSize: 11.0,
            labelFontSize: 10.5,
            onChanged: (val) {
              if (val != null) setState(() => _poliCode = val);
            },
          ),
          const SizedBox(height: 14),

          // Dokter Pemeriksa Selector
          const AppFieldLabel(
            label: 'Dokter Pemeriksa',
            required: true,
            fontSize: 10.5,
          ),
          const SizedBox(height: 5),
          InkWell(
            onTap: () => _showDoctorModal(doctorList),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.card2,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.blueLt,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      LucideIcons.user,
                      size: 18,
                      color: AppColors.blue,
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
                                selectedDoctor?.nama ?? 'Pilih Dokter...',
                                style: const TextStyle(
                                  fontSize: 11.0,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.text,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isCurrentUserDoctor &&
                                selectedDoctor?.id == _selectedDoctorId)
                              Container(
                                margin: const EdgeInsets.only(left: 6),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 1.5,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.greenLt,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'Akun Anda',
                                  style: TextStyle(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.green,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          selectedDoctor != null
                              ? '${selectedDoctor.spesialisasi} • ${selectedDoctor.availability ?? (selectedDoctor.online ? "Online" : "Offline")}'
                              : 'Klik untuk memilih dokter dari armada kapal',
                          style: const TextStyle(
                            fontSize: 9.0,
                            color: AppColors.sub,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    LucideIcons.chevronRight,
                    size: 16,
                    color: AppColors.sub,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // Section: Keluhan & Durasi/Lokasi
  // ==========================================
  Widget _buildComplaintCard() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.orangeLt,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  LucideIcons.alertCircle,
                  size: 16,
                  color: AppColors.orange,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Keluhan Pasien',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Keluhan Utama (Wajib)
          AppTextField(
            label: 'Keluhan Utama',
            required: true,
            controller: _keluhanUtama,
            maxLines: 2,
            fontSize: 11.0,
            labelFontSize: 10.5,
            placeholder: 'Contoh: Demam sejak 2 hari, pusing dan lemas',
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: AppTextField(
                  label: 'Durasi Keluhan',
                  controller: _durasiKeluhan,
                  fontSize: 11.0,
                  labelFontSize: 10.5,
                  placeholder: 'Contoh: 2 hari',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppTextField(
                  label: 'Lokasi Keluhan',
                  controller: _lokasiKeluhan,
                  fontSize: 11.0,
                  labelFontSize: 10.5,
                  placeholder: 'Contoh: Kepala, perut',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // Section: Tanda-Tanda Vital
  // ==========================================
  Widget _buildVitalsCard() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.greenLt,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  LucideIcons.activity,
                  size: 16,
                  color: AppColors.green,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Tanda-Tanda Vital (Triage)',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Tekanan Darah (Sistolik & Diastolik)
          const AppFieldLabel(
            label: 'Tekanan Darah (TD) - mmHg',
            fontSize: 10.5,
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _sistolik,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(fontSize: 10.5, color: AppColors.text),
                  decoration: const InputDecoration(
                    hintText: 'Sistolik (120)',
                    hintStyle: TextStyle(fontSize: 9.5, color: AppColors.sub),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  '/',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.sub,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                child: TextField(
                  controller: _diastolik,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(fontSize: 10.5, color: AppColors.text),
                  decoration: const InputDecoration(
                    hintText: 'Diastolik (80)',
                    hintStyle: TextStyle(fontSize: 9.5, color: AppColors.sub),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Nadi & Suhu
          Row(
            children: [
              Expanded(
                child: AppTextField(
                  label: 'Denyut Nadi (bpm)',
                  controller: _nadi,
                  numbersOnly: true,
                  keyboardType: TextInputType.number,
                  fontSize: 11.0,
                  labelFontSize: 10.5,
                  placeholder: 'Contoh: 78',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppTextField(
                  label: 'Suhu Tubuh (°C)',
                  controller: _suhu,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  fontSize: 11.0,
                  labelFontSize: 10.5,
                  placeholder: 'Contoh: 37.8',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // RR & SpO2
          Row(
            children: [
              Expanded(
                child: AppTextField(
                  label: 'Laju Napas / RR (x/mnt)',
                  controller: _rr,
                  numbersOnly: true,
                  keyboardType: TextInputType.number,
                  fontSize: 11.0,
                  labelFontSize: 10.5,
                  placeholder: 'Contoh: 18',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppTextField(
                  label: 'SpO2 (%)',
                  controller: _spo2,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  fontSize: 11.0,
                  labelFontSize: 10.5,
                  placeholder: 'Contoh: 98.5',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // BB & TB
          Row(
            children: [
              Expanded(
                child: AppTextField(
                  label: 'Berat Badan (kg)',
                  controller: _beratBadan,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  fontSize: 11.0,
                  labelFontSize: 10.5,
                  placeholder: 'Contoh: 65.0',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppTextField(
                  label: 'Tinggi Badan (cm)',
                  controller: _tinggiBadan,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  fontSize: 11.0,
                  labelFontSize: 10.5,
                  placeholder: 'Contoh: 170.0',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // Section: Catatan Tambahan
  // ==========================================
  Widget _buildNotesCard() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.purpleLt,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  LucideIcons.fileText,
                  size: 16,
                  color: AppColors.purple,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Catatan / Anjuran (Opsional)',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          AppTextField(
            label: 'Catatan Kunjungan',
            controller: _catatan,
            maxLines: 2,
            fontSize: 11.0,
            labelFontSize: 10.5,
            placeholder:
                'Contoh: Pasien dianjurkan banyak minum air putih & istirahat',
          ),
        ],
      ),
    );
  }
}

/// Material UI Searchable Modal for Patient selection (mimics DoctorSearchModal)
class PatientSearchModal extends ConsumerStatefulWidget {
  const PatientSearchModal({
    super.key,
    required this.selectedId,
    required this.onSelect,
  });

  final String? selectedId;
  final ValueChanged<Patient> onSelect;

  @override
  ConsumerState<PatientSearchModal> createState() => _PatientSearchModalState();
}

class _PatientSearchModalState extends ConsumerState<PatientSearchModal> {
  final _searchController = TextEditingController();
  String _search = '';
  Timer? _searchDebounce;
  List<Patient> _apiSearchResults = [];
  bool _isSearchingApi = false;

  @override
  void dispose() {
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    setState(() => _search = query);
    _searchDebounce?.cancel();
    if (query.trim().length >= 2) {
      _searchDebounce = Timer(const Duration(milliseconds: 300), () async {
        if (!mounted) return;
        setState(() => _isSearchingApi = true);
        try {
          final res = await ref
              .read(patientApiProvider)
              .getPatients(search: query.trim(), limit: 15);
          if (mounted) {
            setState(() {
              _apiSearchResults = res;
              _isSearchingApi = false;
            });
          }
        } catch (_) {
          if (mounted) setState(() => _isSearchingApi = false);
        }
      });
    } else {
      setState(() {
        _apiSearchResults = [];
        _isSearchingApi = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final localPatients = ref.watch(patientsProvider);
    final query = _search.trim().toLowerCase();

    List<Patient> displayList = [];
    if (query.isEmpty) {
      displayList = localPatients;
    } else {
      final localFiltered = localPatients
          .where(
            (p) =>
                p.nama.toLowerCase().contains(query) ||
                p.nik.contains(query) ||
                p.registerNo.toLowerCase().contains(query),
          )
          .toList();
      final seenIds = localFiltered.map((e) => e.id).toSet();
      displayList = [
        ...localFiltered,
        ..._apiSearchResults.where((p) => !seenIds.contains(p.id)),
      ];
    }

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
                  'Pilih Pasien',
                  style: TextStyle(
                    fontSize: 12.0,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text,
                  ),
                ),
                CircleIconButton(
                  icon: LucideIcons.x,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),

          // Search Input Bar (Matches DoctorSearchModal)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.inputBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                children: [
                  const Icon(
                    LucideIcons.search,
                    size: 15,
                    color: AppColors.sub,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      textAlignVertical: TextAlignVertical.center,
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: AppColors.text,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Cari nama pasien, NIK, atau No. RM...',
                        hintStyle: TextStyle(
                          fontSize: 10.0,
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
                  if (_search.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        _searchController.clear();
                        _onSearchChanged('');
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: AppColors.sub.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          LucideIcons.x,
                          size: 11,
                          color: AppColors.sub,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          if (_isSearchingApi)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: SizedBox(
                height: 2,
                child: LinearProgressIndicator(
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.blue),
                ),
              ),
            ),

          // Patient List
          Flexible(
            child: displayList.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Text(
                      _isSearchingApi
                          ? 'Mencari data pasien...'
                          : 'Pasien tidak ditemukan.',
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: AppColors.sub,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    itemCount: displayList.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final p = displayList[index];
                      final isSelected = p.id == widget.selectedId;

                      return GestureDetector(
                        onTap: () => widget.onSelect(p),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.blueLt.withValues(alpha: 0.6)
                                : AppColors.card2,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.blue
                                  : AppColors.border,
                              width: isSelected ? 1.5 : 1.0,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.blue
                                      : AppColors.blueLt,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  p.nama.isNotEmpty
                                      ? p.nama[0].toUpperCase()
                                      : 'P',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: isSelected
                                        ? Colors.white
                                        : AppColors.blue,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      p.nama,
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                        color: isSelected
                                            ? AppColors.blue
                                            : AppColors.text,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 4,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.card,
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                            border: Border.all(
                                              color: AppColors.border,
                                            ),
                                          ),
                                          child: Text(
                                            p.registerNo.isNotEmpty
                                                ? p.registerNo
                                                : 'RM: -',
                                            style: const TextStyle(
                                              fontSize: 8.5,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.blue,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          'NIK: ${p.nik}',
                                          style: const TextStyle(
                                            fontSize: 8.5,
                                            color: AppColors.sub,
                                          ),
                                        ),
                                        Text(
                                          '• ${p.jk.label} • ${p.umur} thn',
                                          style: const TextStyle(
                                            fontSize: 8.5,
                                            color: AppColors.sub,
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
        ],
      ),
    );
  }
}
