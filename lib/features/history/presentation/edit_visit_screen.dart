import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_select.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/circle_icon_button.dart';
import '../../auth/domain/user_role.dart';
import '../../patients/data/patient_repository.dart';
import '../../patients/domain/doctor.dart';
import '../../patients/domain/medical_history.dart';
import '../../patients/domain/poli.dart';
import '../../schedule/domain/trip_schedule.dart';
import '../../schedule/presentation/widgets/poli_umum_note.dart';
import '../../sync/presentation/sync_providers.dart';

/// Who may edit a visit that still waits for the doctor: the ones who
/// register visits (not the doctor, pharmacy or lab).
bool canEditVisits(UserRole? role) =>
    role == UserRole.perawat || role == UserRole.adminKapal;

bool isWaitingForDoctor(String? statusPenanganan) =>
    statusPenanganan?.trim().toLowerCase() == 'menunggu dokter';

/// Opens [EditVisitScreen] for [record] as its own page; [onSaved] runs
/// after a successful save.
Future<void> openEditVisit(
  BuildContext context,
  MedicalHistory record, {
  VoidCallback? onSaved,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (routeContext) => Scaffold(
        backgroundColor: AppColors.bg,
        body: SafeArea(
          child: EditVisitScreen(
            record: record,
            onBack: () => Navigator.of(routeContext).pop(),
            onSaved: () {
              Navigator.of(routeContext).pop();
              onSaved?.call();
            },
          ),
        ),
      ),
    ),
  );
}

/// Edits a visit that still waits for the doctor: clinic, doctor, complaint
/// and vitals (the nurse's triage). Poli Umum needs no assigned doctor, as
/// when the visit is registered.
class EditVisitScreen extends ConsumerStatefulWidget {
  const EditVisitScreen({
    super.key,
    required this.record,
    required this.onBack,
    required this.onSaved,
  });

  final MedicalHistory record;
  final VoidCallback onBack;
  final VoidCallback onSaved;

  @override
  ConsumerState<EditVisitScreen> createState() => _EditVisitScreenState();
}

class _EditVisitScreenState extends ConsumerState<EditVisitScreen> {
  late final _keluhan = TextEditingController();
  late final _durasi = TextEditingController();
  late final _lokasi = TextEditingController();
  late final _tekananDarah = TextEditingController();
  late final _nadi = TextEditingController();
  late final _suhu = TextEditingController();
  late final _rr = TextEditingController();
  late final _spo2 = TextEditingController();

  late String _poliCode;
  String? _doctorId;
  bool _saving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final r = widget.record;
    // "Demam • Durasi: 2 hari • Lokasi: Kepala", as the visit was saved.
    final rest = <String>[];
    for (final part in (r.complaint ?? '').split(' • ')) {
      final p = part.trim();
      if (p.startsWith('Durasi: ')) {
        _durasi.text = p.substring(8).trim();
      } else if (p.startsWith('Lokasi: ')) {
        _lokasi.text = p.substring(8).trim();
      } else if (p.isNotEmpty) {
        rest.add(p);
      }
    }
    _keluhan.text = rest.join(' • ');
    _poliCode = (r.poliCode?.isNotEmpty ?? false) ? r.poliCode! : poliUmumCode;
    _doctorId = (r.doctorId?.isNotEmpty ?? false) ? r.doctorId : null;
    _tekananDarah.text =
        r.bloodPressure ??
        (r.systolic != null && r.diastolic != null
            ? '${r.systolic}/${r.diastolic}'
            : '');
    _nadi.text = r.heartRate?.toString() ?? '';
    _suhu.text = r.temperature?.toString() ?? '';
    _rr.text = r.respiratoryRate?.toString() ?? '';
    _spo2.text = r.oxygenSaturation?.toString() ?? '';
  }

  @override
  void dispose() {
    for (final c in [
      _keluhan,
      _durasi,
      _lokasi,
      _tekananDarah,
      _nadi,
      _suhu,
      _rr,
      _spo2,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Map<String, dynamic> _body() {
    num? number(TextEditingController c, {bool integer = false}) {
      final v = num.tryParse(c.text.trim().replaceAll(',', '.'));
      if (v == null) return null;
      return integer ? v.round() : v;
    }

    final complaint = [
      _keluhan.text.trim(),
      if (_durasi.text.trim().isNotEmpty) 'Durasi: ${_durasi.text.trim()}',
      if (_lokasi.text.trim().isNotEmpty) 'Lokasi: ${_lokasi.text.trim()}',
    ].join(' • ');
    final bp = _tekananDarah.text.trim();
    final bpParts = bp.split('/');
    final body = <String, dynamic>{
      'poli_code': _poliCode,
      // Poli Umum: no doctor; the first one to examine takes the visit.
      'doctor_id': isPoliUmum(_poliCode) ? '' : _doctorId,
      'complaint': complaint,
      if (bp.isNotEmpty) 'blood_pressure': bp,
      if (bpParts.length == 2 && int.tryParse(bpParts[0].trim()) != null)
        'systolic': int.parse(bpParts[0].trim()),
      if (bpParts.length == 2 && int.tryParse(bpParts[1].trim()) != null)
        'diastolic': int.parse(bpParts[1].trim()),
    };
    final vitals = {
      'heart_rate': number(_nadi, integer: true),
      'temperature': number(_suhu),
      'respiratory_rate': number(_rr, integer: true),
      'oxygen_saturation': number(_spo2),
    };
    vitals.forEach((key, value) {
      if (value != null) body[key] = value;
    });
    return body;
  }

  Future<void> _save() async {
    setState(() => _errorMessage = null);
    if (_keluhan.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Keluhan utama wajib diisi.');
      return;
    }
    if (!isPoliUmum(_poliCode) && _doctorId == null) {
      setState(() => _errorMessage = 'Dokter pemeriksa wajib dipilih.');
      return;
    }

    setState(() => _saving = true);
    try {
      await ref
          .read(patientsProvider.notifier)
          .updateVisit(
            patientId: widget.record.patientId,
            recordId: widget.record.id,
            body: _body(),
          );
      unawaited(
        ref.read(medicalHistoryProvider.notifier).fetchHistory(refresh: true),
      );
      if (!mounted) return;
      final savedOffline =
          (ref.read(syncServiceProvider)?.status.pending ?? 0) > 0;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            savedOffline
                ? 'Perubahan kunjungan tersimpan di perangkat (offline). '
                      'Akan dikirim otomatis saat koneksi kembali.'
                : 'Kunjungan ${widget.record.patientName} berhasil diperbarui.',
          ),
          backgroundColor: AppColors.green,
        ),
      );
      widget.onSaved();
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _errorMessage = 'Gagal menyimpan perubahan kunjungan: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final poliOptions =
        ref.watch(poliklinikOptionsProvider).valueOrNull ?? defaultPoliklinik;
    final doctorsAsync = ref.watch(tripDoctorsProvider);
    final doctors = [...doctorsAsync.valueOrNull ?? const <Doctor>[]];
    // The assigned doctor stays selectable even if no longer on the trip.
    final assigned = widget.record.doctorId;
    if (assigned != null &&
        assigned.isNotEmpty &&
        !doctors.any((d) => d.id == assigned)) {
      doctors.insert(
        0,
        Doctor(
          id: assigned,
          nama: widget.record.doctorName ?? 'Dokter saat ini',
          spesialisasi: '',
          online: true,
        ),
      );
    }
    final poliUmum = isPoliUmum(_poliCode);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
                  children: [
                    const Text(
                      'Edit Kunjungan',
                      style: TextStyle(
                        fontSize: 14.0,
                        fontWeight: FontWeight.w800,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${widget.record.patientName} · masih Menunggu Dokter',
                      style: const TextStyle(
                        fontSize: 11.0,
                        color: AppColors.sub,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (_errorMessage != null)
          Container(
            color: AppColors.redLt,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Text(
              _errorMessage!,
              style: const TextStyle(fontSize: 12, color: AppColors.red),
            ),
          ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppSelect<String>(
                        labelFontSize: 11,
                        fontSize: 12,
                        label: 'Poliklinik Tujuan',
                        required: true,
                        value: _poliCode,
                        options: [
                          if (!poliOptions.any((p) => p.code == _poliCode))
                            AppSelectOption(
                              value: _poliCode,
                              label: widget.record.poliName ?? _poliCode,
                            ),
                          for (final poli in poliOptions)
                            AppSelectOption(value: poli.code, label: poli.name),
                        ],
                        onChanged: (v) {
                          if (v != null) setState(() => _poliCode = v);
                        },
                      ),
                      const SizedBox(height: 14),
                      if (poliUmum)
                        PoliUmumDoctorsNote(
                          doctorCount: doctors.length,
                          loading: doctorsAsync.isLoading,
                        )
                      else ...[
                        AppSelect<String>(
                          labelFontSize: 11,
                          fontSize: 12,
                          label: 'Dokter Pemeriksa',
                          required: true,
                          value: _doctorId,
                          hint: doctorsAsync.isLoading
                              ? 'Memuat dokter...'
                              : 'Pilih dokter dari jadwal Ongoing',
                          options: [
                            for (final d in doctors)
                              AppSelectOption(value: d.id, label: d.nama),
                          ],
                          onChanged: (v) => setState(() => _doctorId = v),
                        ),
                        if (!doctorsAsync.isLoading && doctors.isEmpty) ...[
                          const SizedBox(height: 6),
                          const Text(
                            noTripDoctorsMessage,
                            style: TextStyle(
                              fontSize: 10.5,
                              color: AppColors.red,
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppTextField(
                        labelFontSize: 11,
                        fontSize: 12,
                        label: 'Keluhan Utama',
                        required: true,
                        controller: _keluhan,
                        maxLines: 2,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: AppTextField(
                              labelFontSize: 11,
                              fontSize: 12,
                              label: 'Durasi Keluhan',
                              controller: _durasi,
                              placeholder: 'Contoh: 2 hari',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: AppTextField(
                              labelFontSize: 11,
                              fontSize: 12,
                              label: 'Lokasi Keluhan',
                              controller: _lokasi,
                              placeholder: 'Contoh: Kepala',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: AppTextField(
                              labelFontSize: 11,
                              fontSize: 12,
                              label: 'Tekanan Darah',
                              controller: _tekananDarah,
                              placeholder: '120/80',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: AppTextField(
                              labelFontSize: 11,
                              fontSize: 12,
                              label: 'Nadi (x/menit)',
                              controller: _nadi,
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: AppTextField(
                              labelFontSize: 11,
                              fontSize: 12,
                              label: 'Suhu (°C)',
                              controller: _suhu,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: AppTextField(
                              labelFontSize: 11,
                              fontSize: 12,
                              label: 'Napas (x/menit)',
                              controller: _rr,
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: AppTextField(
                              labelFontSize: 11,
                              fontSize: 12,
                              label: 'SpO₂ (%)',
                              controller: _spo2,
                              keyboardType: TextInputType.number,
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
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: AppColors.card,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: SafeArea(
            top: false,
            child: AppButton(
              label: 'Simpan Perubahan',
              icon: LucideIcons.check,
              full: true,
              loading: _saving,
              onPressed: _saving ? null : _save,
            ),
          ),
        ),
      ],
    );
  }
}
