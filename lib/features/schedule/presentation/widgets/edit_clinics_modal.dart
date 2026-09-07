import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/schedule_api.dart';
import '../../domain/trip_schedule.dart';

/// Modal dialog specifically for editing Poliklinik Layanan of a Schedule.
/// Uses the schedule update endpoint (PUT /api/v1/schedules/:id) to persist clinic assignments.
class EditClinicsModal extends StatefulWidget {
  const EditClinicsModal({
    super.key,
    required this.schedule,
    required this.onSave,
  });

  final JadwalPerjalanan schedule;
  final Future<void> Function(Map<String, dynamic> body) onSave;

  static Future<void> show(
    BuildContext context, {
    required JadwalPerjalanan schedule,
    required Future<void> Function(Map<String, dynamic> body) onSave,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => EditClinicsModal(
        schedule: schedule,
        onSave: onSave,
      ),
    );
  }

  @override
  State<EditClinicsModal> createState() => _EditClinicsModalState();
}

class _ClinicFormItem {
  _ClinicFormItem({
    required this.id,
    required this.code,
    required this.name,
    required this.isSelected,
    required this.openTime,
    required this.closeTime,
  });

  final String id;
  final String code;
  final String name;
  bool isSelected;
  final TextEditingController openTime;
  final TextEditingController closeTime;
}

class _EditClinicsModalState extends State<EditClinicsModal> {
  late final ScheduleApi _scheduleApi;
  late List<_ClinicFormItem> _clinics;

  bool _isSubmitting = false;
  String? _errorMessage;
  OverlayEntry? _activeErrorToast;

  @override
  void initState() {
    super.initState();
    _scheduleApi = ScheduleApi();

    // Initialize clinics from existing schedule clinics
    _clinics = widget.schedule.clinics.map((c) {
      final poliId = c.poliId.isNotEmpty ? c.poliId : c.id;
      return _ClinicFormItem(
        id: poliId,
        code: c.poliCode,
        name: c.poliName,
        isSelected: true,
        openTime: TextEditingController(
          text: c.openTime.isNotEmpty
              ? c.openTime.replaceAll(':', ' . ')
              : '08 . 00',
        ),
        closeTime: TextEditingController(
          text: c.closeTime.isNotEmpty
              ? c.closeTime.replaceAll(':', ' . ')
              : '18 . 00',
        ),
      );
    }).toList();
  }

  @override
  void dispose() {
    _activeErrorToast?.remove();
    _activeErrorToast = null;
    for (final c in _clinics) {
      c.openTime.dispose();
      c.closeTime.dispose();
    }
    super.dispose();
  }

  void _showTopErrorToast(BuildContext context, String message) {
    _activeErrorToast?.remove();
    _activeErrorToast = null;

    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => Positioned(
        top: MediaQuery.of(ctx).padding.top + 16,
        left: 20,
        right: 20,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFDC2626),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(
                  LucideIcons.alertCircle,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(LucideIcons.x, color: Colors.white, size: 16),
                  onPressed: () {
                    entry.remove();
                    if (_activeErrorToast == entry) _activeErrorToast = null;
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    _activeErrorToast = entry;
    overlay.insert(entry);

    Future.delayed(const Duration(seconds: 4), () {
      if (_activeErrorToast == entry) {
        entry.remove();
        _activeErrorToast = null;
      }
    });
  }

  Future<void> _pickClinicTime(
    _ClinicFormItem clinic, {
    required bool isOpening,
  }) async {
    final currentStr = isOpening ? clinic.openTime.text : clinic.closeTime.text;
    TimeOfDay initial = isOpening
        ? const TimeOfDay(hour: 8, minute: 0)
        : const TimeOfDay(hour: 18, minute: 0);
    final clean = currentStr.replaceAll(' ', '');
    final parts = clean.split(RegExp(r'[:.]'));
    if (parts.length >= 2) {
      final h = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      if (h != null && m != null) {
        initial = TimeOfDay(hour: h, minute: m);
      }
    }

    final res = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );

    if (res != null) {
      final hStr = res.hour.toString().padLeft(2, '0');
      final mStr = res.minute.toString().padLeft(2, '0');
      final formatted = '$hStr . $mStr';
      setState(() {
        if (isOpening) {
          clinic.openTime.text = formatted;
        } else {
          clinic.closeTime.text = formatted;
        }
      });
    }
  }

  void _showPoliklinikPickerModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return _PoliklinikPickerBottomSheet(
          selectedClinics: _clinics
              .map((c) => PoliklinikItem(id: c.id, code: c.code, name: c.name))
              .toList(),
          scheduleApi: _scheduleApi,
          onConfirmed: (selected) {
            setState(() {
              final existingMap = {
                for (final c in _clinics)
                  (c.id.isNotEmpty ? c.id : c.code).toLowerCase(): c,
              };

              final List<_ClinicFormItem> nextList = [];
              for (final item in selected) {
                final key = (item.id.isNotEmpty ? item.id : item.code)
                    .toLowerCase();
                if (existingMap.containsKey(key)) {
                  nextList.add(existingMap[key]!);
                  existingMap.remove(key);
                } else {
                  nextList.add(
                    _ClinicFormItem(
                      id: item.id.isNotEmpty ? item.id : item.code,
                      code: item.code,
                      name: item.name,
                      isSelected: true,
                      openTime: TextEditingController(text: '08 . 00'),
                      closeTime: TextEditingController(text: '18 . 00'),
                    ),
                  );
                }
              }

              for (final unselected in existingMap.values) {
                unselected.openTime.dispose();
                unselected.closeTime.dispose();
              }

              _clinics = nextList;
            });
          },
        );
      },
    );
  }

  String? _formatIsoWithTz(DateTime? dt, String tz) {
    if (dt == null) return null;
    final offsetStr = switch (tz.toUpperCase().trim()) {
      'WITA' => '+08:00',
      'WIT' => '+09:00',
      _ => '+07:00',
    };
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$y-$m-${d}T$h:$min:$s$offsetStr';
  }

  Future<void> _handleSave() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      // Build Stops Payload preserving current stops
      final stopsPayload = <Map<String, dynamic>>[];
      for (var i = 0; i < widget.schedule.stops.length; i++) {
        final s = widget.schedule.stops[i];
        stopsPayload.add({
          'port_id': s.portId.isNotEmpty ? s.portId : s.portCode,
          'arrival': i == 0 ? null : _formatIsoWithTz(s.arrival, s.arrivalTz),
          'departure': i == widget.schedule.stops.length - 1
              ? null
              : _formatIsoWithTz(s.departure, s.departureTz),
          'stop_order': i + 1,
        });
      }

      // Build Clinics Payload from state
      final clinicsPayload = _clinics
          .where((c) => c.isSelected)
          .map(
            (c) => {
              'poliklinik_id': c.id,
              'open_time': c.openTime.text
                  .replaceAll(' ', '')
                  .replaceAll('.', ':'),
              'close_time': c.closeTime.text
                  .replaceAll(' ', '')
                  .replaceAll('.', ':'),
            },
          )
          .toList();

      final effectiveShipId = widget.schedule.shipId.isNotEmpty
          ? widget.schedule.shipId
          : widget.schedule.shipCode;

      final body = <String, dynamic>{
        'ship_id': effectiveShipId,
        'status': widget.schedule.status.isNotEmpty
            ? widget.schedule.status
            : 'Scheduled',
        'doctor_ids': widget.schedule.doctorStaff
            .map((d) => d.id)
            .where((id) => id.isNotEmpty)
            .toList(),
        'nurse_ids': widget.schedule.nurseStaff
            .map((n) => n.id)
            .where((id) => id.isNotEmpty)
            .toList(),
        'crew_ids': widget.schedule.crewStaff
            .map((c) => c.id)
            .where((id) => id.isNotEmpty)
            .toList(),
        'fuel_liters': widget.schedule.fuelLiters,
        'water_liters': widget.schedule.waterLiters,
        'stops': stopsPayload,
        'clinics': clinicsPayload,
      };

      await widget.onSave(body);

      if (mounted) {
        _activeErrorToast?.remove();
        _activeErrorToast = null;
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        final errorMsg = e is ApiException
            ? e.message
            : e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');

        setState(() {
          _isSubmitting = false;
          _errorMessage = errorMsg;
        });

        _showTopErrorToast(context, 'Gagal menyimpan poli: $errorMsg');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 720),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.orangeLt,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      LucideIcons.building2,
                      color: AppColors.orange,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Edit Poli Layanan',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.text,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${widget.schedule.namaKapal} • ${widget.schedule.code}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.sub,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      LucideIcons.x,
                      size: 20,
                      color: AppColors.sub,
                    ),
                    onPressed: _isSubmitting
                        ? null
                        : () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Top Error Banner
            if (_errorMessage != null)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: Row(
                  children: [
                    Icon(
                      LucideIcons.alertCircle,
                      color: const Color(0xFFDC2626),
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: Color(0xFF991B1B),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () => setState(() => _errorMessage = null),
                      child: Icon(
                        LucideIcons.x,
                        size: 16,
                        color: const Color(0xFF991B1B),
                      ),
                    ),
                  ],
                ),
              ),

            // Scrollable Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          LucideIcons.building2,
                          size: 16,
                          color: const Color(0xFF64748B),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'POLIKLINIK TERSEDIA',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF7ED),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${_clinics.length} dipilih',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.orange,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Multi-select picker input
                    InkWell(
                      onTap: _showPoliklinikPickerModal,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              LucideIcons.building2,
                              size: 18,
                              color: const Color(0xFF64748B),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _clinics.isEmpty
                                    ? 'Pilih poliklinik...'
                                    : '${_clinics.length} poliklinik dipilih',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: _clinics.isNotEmpty
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  color: _clinics.isNotEmpty
                                      ? AppColors.text
                                      : const Color(0xFF94A3B8),
                                ),
                              ),
                            ),
                            if (_clinics.isNotEmpty)
                              InkWell(
                                onTap: () {
                                  setState(() {
                                    for (final c in _clinics) {
                                      c.openTime.dispose();
                                      c.closeTime.dispose();
                                    }
                                    _clinics.clear();
                                  });
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  child: Icon(
                                    LucideIcons.x,
                                    size: 16,
                                    color: const Color(0xFF94A3B8),
                                  ),
                                ),
                              ),
                            Icon(
                              LucideIcons.chevronDown,
                              size: 18,
                              color: const Color(0xFF64748B),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    if (_clinics.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          vertical: 32,
                          horizontal: 16,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              LucideIcons.building2,
                              size: 32,
                              color: const Color(0xFF94A3B8),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Belum ada poliklinik yang dipilih',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF475569),
                              ),
                            ),
                            const SizedBox(height: 3),
                            const Text(
                              'Pilih poliklinik di atas untuk mengatur jam operasional pelayanan',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF94A3B8),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      for (final clinic in _clinics) ...[
                        _buildClinicCard(clinic),
                        const SizedBox(height: 10),
                      ],
                  ],
                ),
              ),
            ),

            // Footer Buttons
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                      onPressed: _isSubmitting
                          ? null
                          : () => Navigator.pop(context),
                      child: const Text(
                        'Batal',
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.orange,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                      onPressed: _isSubmitting ? null : _handleSave,
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  LucideIcons.check,
                                  size: 16,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Simpan Perubahan',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClinicCard(_ClinicFormItem clinic) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFB923C), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: const BoxDecoration(
                    color: AppColors.orange,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(
                      LucideIcons.check,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        clinic.name,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.text,
                        ),
                      ),
                      Text(
                        clinic.code.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.sub,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    LucideIcons.trash2,
                    size: 17,
                    color: const Color(0xFF94A3B8),
                  ),
                  onPressed: () {
                    setState(() {
                      clinic.openTime.dispose();
                      clinic.closeTime.dispose();
                      _clinics.remove(clinic);
                    });
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFFFEDD5)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Jam Buka',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      InkWell(
                        onTap: () => _pickClinicTime(clinic, isOpening: true),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                LucideIcons.clock,
                                size: 14,
                                color: const Color(0xFF64748B),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  clinic.openTime.text,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.text,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Jam Tutup',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      InkWell(
                        onTap: () => _pickClinicTime(clinic, isOpening: false),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                LucideIcons.clock,
                                size: 14,
                                color: const Color(0xFF64748B),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  clinic.closeTime.text,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.text,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PoliklinikPickerBottomSheet extends StatefulWidget {
  const _PoliklinikPickerBottomSheet({
    required this.selectedClinics,
    required this.scheduleApi,
    required this.onConfirmed,
  });

  final List<PoliklinikItem> selectedClinics;
  final ScheduleApi scheduleApi;
  final ValueChanged<List<PoliklinikItem>> onConfirmed;

  @override
  State<_PoliklinikPickerBottomSheet> createState() =>
      _PoliklinikPickerBottomSheetState();
}

class _PoliklinikPickerBottomSheetState
    extends State<_PoliklinikPickerBottomSheet> {
  late final ScrollController _scrollController;
  late final TextEditingController _searchController;
  Timer? _debounceTimer;

  late List<PoliklinikItem> _selectedItems;
  List<PoliklinikItem> _items = [];
  int _page = 1;
  bool _loading = false;
  bool _loadingMore = false;
  bool _hasMore = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _selectedItems = List.from(widget.selectedClinics);
    _scrollController = ScrollController()..addListener(_onScroll);
    _searchController = TextEditingController();
    _fetchPage(1, reset: true);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 80) {
      _loadMore();
    }
  }

  void _loadMore() {
    if (_loading || _loadingMore || !_hasMore) return;
    _fetchPage(_page + 1, query: _searchQuery, reset: false);
  }

  void _onSearchChanged(String val) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _fetchPage(1, query: val.trim(), reset: true);
    });
  }

  Future<void> _fetchPage(
    int page, {
    String query = '',
    bool reset = false,
  }) async {
    if (reset) {
      setState(() {
        _loading = true;
        _page = 1;
        _hasMore = true;
        _searchQuery = query;
      });
    } else {
      if (_loadingMore || !_hasMore) return;
      setState(() => _loadingMore = true);
    }

    try {
      final res = await widget.scheduleApi.getPoliklinik(
        page: page,
        limit: 10,
        search: query.isNotEmpty ? query : null,
      );

      if (!mounted) return;
      setState(() {
        if (reset) {
          _items = res.items;
        } else {
          final existingIds = _items.map((c) => c.id.toLowerCase()).toSet();
          final newItems = res.items
              .where((c) => !existingIds.contains(c.id.toLowerCase()))
              .toList();
          _items.addAll(newItems);
        }
        _page = res.page;
        _hasMore = res.hasMore;
        _loading = false;
        _loadingMore = false;
      });
    } catch (e) {
      debugPrint('_PoliklinikPickerBottomSheet _fetchPage error: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  bool _isItemSelected(PoliklinikItem item) {
    return _selectedItems.any(
      (c) =>
          c.id.toLowerCase() == item.id.toLowerCase() ||
          c.code.toLowerCase() == item.code.toLowerCase(),
    );
  }

  void _toggleItem(PoliklinikItem item) {
    setState(() {
      final index = _selectedItems.indexWhere(
        (c) =>
            c.id.toLowerCase() == item.id.toLowerCase() ||
            c.code.toLowerCase() == item.code.toLowerCase(),
      );
      if (index >= 0) {
        _selectedItems.removeAt(index);
      } else {
        _selectedItems.add(item);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final displayedItems = List<PoliklinikItem>.from(_items);
    for (final selected in _selectedItems) {
      final exists = displayedItems.any(
        (p) =>
            p.id.toLowerCase() == selected.id.toLowerCase() ||
            p.code.toLowerCase() == selected.code.toLowerCase(),
      );
      if (!exists) {
        displayedItems.insert(0, selected);
      }
    }

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        child: Column(
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      LucideIcons.building2,
                      size: 16,
                      color: AppColors.orange,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Pilih Poliklinik',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(LucideIcons.x, size: 18),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.border),

            // Search Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Cari poliklinik...',
                  prefixIcon: Icon(LucideIcons.search, size: 16),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                ),
              ),
            ),

            // Item List
            Expanded(
              child: _loading && displayedItems.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : displayedItems.isEmpty
                      ? const Center(
                          child: Text(
                            'Tidak ada poliklinik ditemukan',
                            style: TextStyle(color: AppColors.sub),
                          ),
                        )
                      : ListView.separated(
                          controller: _scrollController,
                          itemCount:
                              displayedItems.length + (_loadingMore ? 1 : 0),
                          separatorBuilder: (context, index) =>
                              const Divider(height: 1, indent: 56),
                          itemBuilder: (context, index) {
                            if (index >= displayedItems.length) {
                              return const Padding(
                                padding: EdgeInsets.all(12),
                                child: Center(
                                  child: SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),
                              );
                            }

                            final item = displayedItems[index];
                            final selected = _isItemSelected(item);

                            return ListTile(
                              onTap: () => _toggleItem(item),
                              leading: Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: selected
                                        ? AppColors.orange
                                        : const Color(0xFFCBD5E1),
                                    width: 1.5,
                                  ),
                                  color: selected
                                      ? AppColors.orange
                                      : Colors.white,
                                ),
                                child: selected
                                    ? const Icon(
                                        Icons.check,
                                        size: 15,
                                        color: Colors.white,
                                      )
                                    : null,
                              ),
                              title: Text(
                                item.name,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: selected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: AppColors.text,
                                ),
                              ),
                              subtitle: Text(
                                item.code.toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.sub,
                                ),
                              ),
                            );
                          },
                        ),
            ),

            // Bottom Action
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Batal'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.orange,
                      ),
                      onPressed: () {
                        widget.onConfirmed(_selectedItems);
                        Navigator.pop(context);
                      },
                      child: Text(
                        'Pilih (${_selectedItems.length})',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
