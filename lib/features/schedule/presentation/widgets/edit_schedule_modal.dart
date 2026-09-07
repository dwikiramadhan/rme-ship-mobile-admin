import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/schedule_api.dart';
import '../../domain/trip_schedule.dart';

class EditScheduleModal extends StatefulWidget {
  const EditScheduleModal({
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
      builder: (ctx) => EditScheduleModal(schedule: schedule, onSave: onSave),
    );
  }

  @override
  State<EditScheduleModal> createState() => _EditScheduleModalState();
}

class _EditScheduleModalState extends State<EditScheduleModal> {
  late String _status;
  late List<_StopFormItem> _stops;

  // Selected Personnel & Crew
  late List<SchedulePersonnelItem> _selectedDoctors;
  late List<SchedulePersonnelItem> _selectedNurses;
  late List<ScheduleCrewItem> _selectedCrews;

  // Logistics
  late final TextEditingController _fuelController;
  late final TextEditingController _waterController;

  bool _isSubmitting = false;
  String? _errorMessage;
  OverlayEntry? _activeErrorToast;

  // Ports API & Prefetched Ports
  late final ScheduleApi _scheduleApi;
  List<PortItem> _ports = [];

  @override
  void initState() {
    super.initState();
    _scheduleApi = ScheduleApi();
    _fetchInitialPorts();
    final s = widget.schedule;
    _status = s.status.isNotEmpty ? s.status : 'Scheduled';

    // Build Stops
    if (s.stops.isNotEmpty) {
      _stops = s.stops
          .map(
            (stop) => _StopFormItem(
              portId: stop.portId,
              portCode: stop.portCode,
              portName: stop.portName,
              departure: stop.departure,
              arrival: stop.arrival,
              departureTz: stop.departureTz,
              arrivalTz: stop.arrivalTz,
            ),
          )
          .toList();
    } else {
      _stops = [
        _StopFormItem(
          portId: '',
          portCode: s.kodeAsal,
          portName: s.pelabuhanAsal.isNotEmpty
              ? s.pelabuhanAsal
              : 'Pilih Pelabuhan Asal',
          departure: s.berangkat,
          departureTz: 'WIB',
        ),
        _StopFormItem(
          portId: '',
          portCode: s.kodeTujuan,
          portName: s.pelabuhanTujuan.isNotEmpty
              ? s.pelabuhanTujuan
              : 'Pilih Pelabuhan Tujuan',
          arrival: s.tiba,
          arrivalTz: 'WIT',
        ),
      ];
    }

    // Doctors
    if (s.doctorStaff.isNotEmpty) {
      _selectedDoctors = List.from(s.doctorStaff);
    } else if (s.doctors.isNotEmpty) {
      _selectedDoctors = s.doctors
          .map(
            (d) => SchedulePersonnelItem(
              name: d,
              role: 'DOKTER',
              specialization: 'Dokter Umum',
            ),
          )
          .toList();
    } else {
      _selectedDoctors = [];
    }

    // Nurses
    if (s.nurseStaff.isNotEmpty) {
      _selectedNurses = List.from(s.nurseStaff);
    } else {
      _selectedNurses = [];
    }

    // Crews
    if (s.crewStaff.isNotEmpty) {
      _selectedCrews = List.from(s.crewStaff);
    } else {
      _selectedCrews = [];
    }

    // Logistics
    _fuelController = TextEditingController(text: s.fuelLiters.toString());
    _waterController = TextEditingController(text: s.waterLiters.toString());
  }

  @override
  void dispose() {
    _activeErrorToast?.remove();
    _activeErrorToast = null;
    _fuelController.dispose();
    _waterController.dispose();
    super.dispose();
  }

  void _showTopErrorToast(BuildContext context, String message) {
    _activeErrorToast?.remove();
    _activeErrorToast = null;

    final overlay = Overlay.of(context, rootOverlay: true);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (ctx) => _TopErrorToast(
        message: message,
        onDismiss: () {
          if (entry.mounted) {
            entry.remove();
            if (_activeErrorToast == entry) {
              _activeErrorToast = null;
            }
          }
        },
      ),
    );

    _activeErrorToast = entry;
    overlay.insert(entry);
  }

  Future<void> _fetchInitialPorts() async {
    try {
      final res = await _scheduleApi.getPorts(page: 1, limit: 100);
      if (!mounted) return;
      if (res.items.isNotEmpty) {
        setState(() {
          _ports = res.items;
          _resolveMissingPortIds();
        });
      }
    } catch (e) {
      debugPrint('EditScheduleModal _fetchInitialPorts error: $e');
    }
  }

  void _resolveMissingPortIds() {
    for (final s in _stops) {
      if (s.portId.isEmpty) {
        for (final p in _ports) {
          final codeMatch = s.portCode.isNotEmpty &&
              p.code.toLowerCase().trim() == s.portCode.toLowerCase().trim();
          final nameMatch = s.portName.isNotEmpty &&
              p.name.toLowerCase().trim() == s.portName.toLowerCase().trim();
          if (codeMatch || nameMatch) {
            s.portId = p.id;
            break;
          }
        }
      }
    }
  }

  String _formatDateTimeDisplay(DateTime? dt) {
    if (dt == null) return '—';
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final y = dt.year;
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$d / $m / $y , $h . $min';
  }

  Future<DateTime?> _pickDateTime(
    BuildContext context,
    DateTime? initial,
  ) async {
    final now = DateTime.now();
    final base = initial ?? now;
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.orange,
              onPrimary: Colors.white,
              onSurface: AppColors.text,
            ),
          ),
          child: child!,
        );
      },
    );
    if (pickedDate == null || !context.mounted) return null;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.orange,
              onPrimary: Colors.white,
              onSurface: AppColors.text,
            ),
          ),
          child: child!,
        );
      },
    );
    if (pickedTime == null) return null;

    return DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );
  }

  void _addIntermediateStop() {
    setState(() {
      final insertIndex = _stops.length > 1 ? _stops.length - 1 : _stops.length;
      final usedCodes = _stops
          .map((s) => s.portCode.toLowerCase().trim())
          .toSet();
      final usedNames = _stops
          .map((s) => s.portName.toLowerCase().trim())
          .toSet();

      PortItem? portCandidate;
      for (final p in _ports) {
        final c = (p.code.isNotEmpty ? p.code : p.id).toLowerCase().trim();
        final n = p.name.toLowerCase().trim();
        if (!usedCodes.contains(c) && !usedNames.contains(n)) {
          portCandidate = p;
          break;
        }
      }
      final prevDeparture = _stops.isNotEmpty ? _stops.first.departure : null;
      final arrivalTime =
          prevDeparture?.add(const Duration(days: 2)) ?? DateTime.now();
      final departureTime = arrivalTime.add(const Duration(hours: 4));

      _stops.insert(
        insertIndex,
        _StopFormItem(
          portId: portCandidate?.id ?? '',
          portCode: portCandidate != null
              ? (portCandidate.code.isNotEmpty
                    ? portCandidate.code
                    : portCandidate.id)
              : '',
          portName: portCandidate != null
              ? portCandidate.name
              : 'Pilih Pelabuhan Singgah',
          arrival: arrivalTime,
          departure: departureTime,
          arrivalTz: 'WITA',
          departureTz: 'WITA',
        ),
      );
    });
  }

  void _removeStop(int index) {
    if (_stops.length <= 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Rute minimal harus memiliki asal dan tujuan'),
        ),
      );
      return;
    }
    setState(() {
      _stops.removeAt(index);
    });
  }

  static String? formatIsoWithTz(DateTime? dt, String tz) {
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

  String? _formatIsoWithTz(DateTime? dt, String tz) => formatIsoWithTz(dt, tz);

  Future<void> _handleSave() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final fuelNum = double.tryParse(_fuelController.text.trim()) ?? 0;
      final waterNum = double.tryParse(_waterController.text.trim()) ?? 0;

      // Build Stops Payload
      final stopsPayload = <Map<String, dynamic>>[];
      for (var i = 0; i < _stops.length; i++) {
        final s = _stops[i];
        String effectivePortId = s.portId;
        if (effectivePortId.isEmpty) {
          for (final p in _ports) {
            if ((s.portCode.isNotEmpty &&
                    p.code.toLowerCase().trim() ==
                        s.portCode.toLowerCase().trim()) ||
                (s.portName.isNotEmpty &&
                    p.name.toLowerCase().trim() ==
                        s.portName.toLowerCase().trim())) {
              effectivePortId = p.id;
              s.portId = p.id;
              break;
            }
          }
        }

        if (effectivePortId.isEmpty) {
          effectivePortId = s.portCode;
        }

        stopsPayload.add({
          'port_id': effectivePortId,
          'arrival': i == 0 ? null : _formatIsoWithTz(s.arrival, s.arrivalTz),
          'departure': i == _stops.length - 1
              ? null
              : _formatIsoWithTz(s.departure, s.departureTz),
          'stop_order': i + 1,
        });
      }

      // Preserve existing Clinics from schedule
      final clinicsPayload = widget.schedule.clinics
          .map(
            (c) => {
              'poliklinik_id': c.poliId.isNotEmpty ? c.poliId : c.id,
              'open_time': c.openTime.isNotEmpty ? c.openTime : '08:00',
              'close_time': c.closeTime.isNotEmpty ? c.closeTime : '18:00',
            },
          )
          .toList();

      final effectiveShipId = widget.schedule.shipId.isNotEmpty
          ? widget.schedule.shipId
          : widget.schedule.shipCode;

      final body = <String, dynamic>{
        'ship_id': effectiveShipId,
        'status': _status,
        'doctor_ids': _selectedDoctors
            .map((d) => d.id)
            .where((id) => id.isNotEmpty)
            .toList(),
        'nurse_ids': _selectedNurses
            .map((n) => n.id)
            .where((id) => id.isNotEmpty)
            .toList(),
        'crew_ids': _selectedCrews
            .map((c) => c.id)
            .where((id) => id.isNotEmpty)
            .toList(),
        'fuel_liters': fuelNum.toInt(),
        'water_liters': waterNum.toInt(),
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

        _showTopErrorToast(context, 'Gagal menyimpan: $errorMsg');
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
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 880),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(
            children: [
              // Modal Header
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppColors.border)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.orangeLt,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        LucideIcons.pencilLine,
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
                            'Edit Jadwal Perjalanan',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.text,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.schedule.namaKapal,
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
                      icon: const Icon(
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

              // Top Error Banner inside Modal
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
                      const Icon(
                        LucideIcons.alertCircle,
                        color: Color(0xFFDC2626),
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
                      GestureDetector(
                        onTap: () => setState(() => _errorMessage = null),
                        child: const Icon(
                          LucideIcons.x,
                          color: Color(0xFF991B1B),
                          size: 16,
                        ),
                      ),
                    ],
                  ),
                ),

              // Scrollable Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. STATUS
                      _buildStatusSection(),
                      const SizedBox(height: 16),

                      // 2. RUTE PELABUHAN
                      _buildRouteSection(),
                      const SizedBox(height: 16),

                      // 3. DOKTER BERTUGAS
                      _buildDoctorsSection(),
                      const SizedBox(height: 16),

                      // 4. PERAWAT BERTUGAS
                      _buildNursesSection(),
                      const SizedBox(height: 16),

                      // 5. ABK KAPAL (CREW)
                      _buildCrewSection(),
                      const SizedBox(height: 16),

                      // 6. BAHAN BAKAR & AIR BERSIH
                      _buildLogisticsSection(),
                    ],
                  ),
                ),
              ),

              // Footer Buttons
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: AppColors.border)),
                  color: Colors.white,
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(46),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                        ),
                        onPressed: _isSubmitting
                            ? null
                            : () => Navigator.pop(context),
                        child: const Text(
                          'Batal',
                          style: TextStyle(
                            color: Color(0xFF475569),
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      flex: 3,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.orange,
                          minimumSize: const Size.fromHeight(46),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _isSubmitting ? null : _handleSave,
                        child: _isSubmitting
                            ? Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  ),
                                  SizedBox(width: 10),
                                  Text(
                                    'Menyimpan...',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              )
                            : const Text(
                                'Simpan',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // SECTION BUILDERS
  // ==========================================

  Widget _buildStatusSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            Text(
              'STATUS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
                color: Color(0xFF64748B),
              ),
            ),
            SizedBox(width: 4),
            Text(
              '*',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _status,
              isExpanded: true,
              isDense: true,
              icon: const Icon(
                LucideIcons.chevronDown,
                size: 16,
                color: Color(0xFF94A3B8),
              ),
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.text,
                fontWeight: FontWeight.w500,
              ),
              items: const [
                DropdownMenuItem(value: 'Scheduled', child: Text('Scheduled')),
                DropdownMenuItem(value: 'Ongoing', child: Text('Ongoing')),
                DropdownMenuItem(value: 'Completed', child: Text('Completed')),
                DropdownMenuItem(value: 'Cancelled', child: Text('Cancelled')),
              ],
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _status = val;
                  });
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRouteSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(LucideIcons.mapPin, size: 16, color: Color(0xFF64748B)),
            const SizedBox(width: 8),
            const Text(
              'RUTE PELABUHAN',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(width: 4),
            const Text(
              '*',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            InkWell(
              onTap: _addIntermediateStop,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppColors.orangeLt,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(LucideIcons.plus, size: 14, color: AppColors.orange),
                    SizedBox(width: 4),
                    Text(
                      'Tambah Singgah',
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
          ],
        ),
        const SizedBox(height: 14),

        // Timeline items
        for (var i = 0; i < _stops.length; i++) _buildStopRow(i),
      ],
    );
  }

  Widget _buildStopRow(int index) {
    final stop = _stops[index];
    final isFirst = index == 0;
    final isLast = index == _stops.length - 1;
    final isIntermediate = !isFirst && !isLast;
    final isOdd = index.isOdd;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Number badge & continuous vertical line
          SizedBox(
            width: 32,
            child: Column(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isFirst || isLast
                        ? AppColors.orange
                        : const Color(0xFFE2E8F0),
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: isFirst || isLast
                            ? Colors.white
                            : const Color(0xFF475569),
                      ),
                    ),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Center(
                      child: Container(
                        width: 1,
                        color: const Color(0xFFCBD5E1),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 14),

          // Stop Card
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isOdd ? const Color(0xFFF8FAFC) : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isOdd
                        ? const Color(0xFFCBD5E1)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Port Selector Row
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => _showPortPickerModal(index),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              height: 38,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                              decoration: BoxDecoration(
                                color: isOdd
                                    ? Colors.white
                                    : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    LucideIcons.anchor,
                                    size: 15,
                                    color: Color(0xFF0284C7),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      stop.portName.isNotEmpty
                                          ? stop.portName
                                          : (stop.portCode.isNotEmpty
                                                ? stop.portCode
                                                : 'Pilih Pelabuhan'),
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        color: AppColors.text,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const Icon(
                                    LucideIcons.chevronDown,
                                    size: 16,
                                    color: Color(0xFF94A3B8),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        if (isIntermediate) ...[
                          const SizedBox(width: 8),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            icon: const Icon(
                              LucideIcons.x,
                              size: 18,
                              color: Color(0xFF94A3B8),
                            ),
                            onPressed: () => _removeStop(index),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Intermediate: TIBA and BERANGKAT in ONE ROW
                    if (isIntermediate) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left: TIBA
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: const [
                                    Text(
                                      'TIBA',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                    SizedBox(width: 3),
                                    Text(
                                      '*',
                                      style: TextStyle(
                                        color: Colors.red,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 5),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildDateField(
                                        value: stop.arrival,
                                        onTap: () async {
                                          final res = await _pickDateTime(
                                            context,
                                            stop.arrival,
                                          );
                                          if (res != null) {
                                            setState(() => stop.arrival = res);
                                          }
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    _buildTzSelector(
                                      value: stop.arrivalTz,
                                      onChanged: (val) =>
                                          setState(() => stop.arrivalTz = val),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Right: BERANGKAT
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: const [
                                    Text(
                                      'BERANGKAT',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                    SizedBox(width: 3),
                                    Text(
                                      '*',
                                      style: TextStyle(
                                        color: Colors.red,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 5),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildDateField(
                                        value: stop.departure,
                                        onTap: () async {
                                          final res = await _pickDateTime(
                                            context,
                                            stop.departure,
                                          );
                                          if (res != null) {
                                            setState(
                                              () => stop.departure = res,
                                            );
                                          }
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    _buildTzSelector(
                                      value: stop.departureTz,
                                      onChanged: (val) => setState(
                                        () => stop.departureTz = val,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ] else if (isFirst) ...[
                      // First stop: BERANGKAT only
                      Row(
                        children: const [
                          Text(
                            'BERANGKAT',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          SizedBox(width: 3),
                          Text(
                            '*',
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Expanded(
                            child: _buildDateField(
                              value: stop.departure,
                              onTap: () async {
                                final res = await _pickDateTime(
                                  context,
                                  stop.departure,
                                );
                                if (res != null) {
                                  setState(() => stop.departure = res);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          _buildTzSelector(
                            value: stop.departureTz,
                            onChanged: (val) =>
                                setState(() => stop.departureTz = val),
                          ),
                        ],
                      ),
                    ] else if (isLast) ...[
                      // Last stop: TIBA only
                      Row(
                        children: const [
                          Text(
                            'TIBA',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          SizedBox(width: 3),
                          Text(
                            '*',
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Expanded(
                            child: _buildDateField(
                              value: stop.arrival,
                              onTap: () async {
                                final res = await _pickDateTime(
                                  context,
                                  stop.arrival,
                                );
                                if (res != null) {
                                  setState(() => stop.arrival = res);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          _buildTzSelector(
                            value: stop.arrivalTz,
                            onChanged: (val) =>
                                setState(() => stop.arrivalTz = val),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateField({
    required DateTime? value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _formatDateTimeDisplay(value),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.text,
                ),
              ),
            ),
            const Icon(
              LucideIcons.calendar,
              size: 14,
              color: Color(0xFF94A3B8),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTzSelector({
    required String value,
    required ValueChanged<String> onChanged,
  }) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      alignment: Alignment.center,
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isDense: true,
          icon: const Padding(
            padding: EdgeInsets.only(left: 4),
            child: Icon(
              LucideIcons.chevronDown,
              size: 14,
              color: Color(0xFF94A3B8),
            ),
          ),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.text,
          ),
          items: const [
            DropdownMenuItem(value: 'WIB', child: Text('WIB')),
            DropdownMenuItem(value: 'WITA', child: Text('WITA')),
            DropdownMenuItem(value: 'WIT', child: Text('WIT')),
          ],
          onChanged: (val) {
            if (val != null) onChanged(val);
          },
        ),
      ),
    );
  }

  Widget _buildDoctorsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              LucideIcons.stethoscope,
              size: 16,
              color: Color(0xFFF97316),
            ),
            const SizedBox(width: 8),
            const Text(
              'DOKTER BERTUGAS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(width: 4),
            const Text(
              '*',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            _buildCountBadge(
              '${_selectedDoctors.length} dipilih',
              const Color(0xFFFFF7ED),
              AppColors.orange,
            ),
          ],
        ),
        const SizedBox(height: 6),
        _buildMultiSelectInput(
          icon: LucideIcons.stethoscope,
          placeholder: 'Pilih dokter...',
          displayText: '',
          onTap: () => _showDoctorPickerModal(),
          onClear: () => setState(() => _selectedDoctors.clear()),
        ),
        if (_selectedDoctors.isNotEmpty) ...[
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final doc in _selectedDoctors)
                _buildChip(
                  initials: doc.initials,
                  label: doc.name,
                  avatarBg: AppColors.orange,
                  chipBg: const Color(0xFFFFF7ED),
                  borderColor: const Color(0xFFFFEDD5),
                  onDelete: () => setState(() => _selectedDoctors.remove(doc)),
                ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildNursesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(LucideIcons.user, size: 16, color: Color(0xFF059669)),
            const SizedBox(width: 8),
            const Text(
              'PERAWAT BERTUGAS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
                color: Color(0xFF64748B),
              ),
            ),
            const Spacer(),
            _buildCountBadge(
              '${_selectedNurses.length} dipilih',
              const Color(0xFFECFDF5),
              const Color(0xFF059669),
            ),
          ],
        ),
        const SizedBox(height: 6),
        _buildMultiSelectInput(
          icon: LucideIcons.user,
          placeholder: 'Pilih perawat...',
          displayText: '',
          onTap: () => _showNursePickerModal(),
          onClear: () => setState(() => _selectedNurses.clear()),
        ),
        if (_selectedNurses.isNotEmpty) ...[
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final nurse in _selectedNurses)
                _buildChip(
                  initials: nurse.initials,
                  label: nurse.name,
                  avatarBg: const Color(0xFF059669),
                  chipBg: const Color(0xFFECFDF5),
                  borderColor: const Color(0xFFD1FAE5),
                  onDelete: () => setState(() => _selectedNurses.remove(nurse)),
                ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildCrewSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(LucideIcons.anchor, size: 16, color: Color(0xFF0284C7)),
            const SizedBox(width: 8),
            const Text(
              'ABK KAPAL (CREW)',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
                color: Color(0xFF64748B),
              ),
            ),
            const Spacer(),
            _buildCountBadge(
              '${_selectedCrews.length} dipilih',
              const Color(0xFFE0F2FE),
              const Color(0xFF0284C7),
            ),
          ],
        ),
        const SizedBox(height: 6),
        _buildMultiSelectInput(
          icon: LucideIcons.anchor,
          placeholder: 'Pilih ABK kapal...',
          displayText: '',
          onTap: () => _showCrewPickerModal(),
          onClear: () => setState(() => _selectedCrews.clear()),
        ),
        if (_selectedCrews.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final crew in _selectedCrews)
                _buildChip(
                  initials: crew.initials,
                  label: crew.name,
                  avatarBg: const Color(0xFF0284C7),
                  chipBg: const Color(0xFFE0F2FE),
                  borderColor: const Color(0xFFBAE6FD),
                  onDelete: () => setState(() => _selectedCrews.remove(crew)),
                ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildLogisticsSection() {
    return Row(
      children: [
        // Bahan Bakar
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(LucideIcons.fuel, size: 15, color: AppColors.orange),
                  SizedBox(width: 6),
                  Text(
                    'BAHAN BAKAR',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Container(
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _fuelController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.text,
                        ),
                        decoration: const InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      margin: const EdgeInsets.only(right: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: const Text(
                        'Liter',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 14),

        // Air Bersih
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(
                    LucideIcons.droplets,
                    size: 15,
                    color: Color(0xFF0284C7),
                  ),
                  SizedBox(width: 6),
                  Text(
                    'AIR BERSIH',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Container(
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _waterController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.text,
                        ),
                        decoration: const InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      margin: const EdgeInsets.only(right: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: const Text(
                        'Liter',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w600,
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
    );
  }

  // ==========================================
  // SHARED PICKERS & HELPERS

  Widget _buildMultiSelectInput({
    required IconData icon,
    required String placeholder,
    required String displayText,
    required VoidCallback onTap,
    required VoidCallback onClear,
  }) {
    final hasValue = displayText.isNotEmpty;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 15, color: const Color(0xFF94A3B8)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                hasValue ? displayText : placeholder,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: hasValue ? FontWeight.w600 : FontWeight.w400,
                  color: hasValue ? AppColors.text : const Color(0xFF94A3B8),
                ),
              ),
            ),
            if (hasValue)
              GestureDetector(
                onTap: onClear,
                child: const Padding(
                  padding: EdgeInsets.only(right: 6),
                  child: Icon(
                    LucideIcons.x,
                    size: 14,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ),
            const Icon(
              LucideIcons.chevronDown,
              size: 15,
              color: Color(0xFF94A3B8),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip({
    required String initials,
    required String label,
    required Color avatarBg,
    required Color chipBg,
    required Color borderColor,
    required VoidCallback onDelete,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 3, 8, 3),
      decoration: BoxDecoration(
        color: chipBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 10,
            backgroundColor: avatarBg,
            child: Text(
              initials,
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.text,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onDelete,
            child: const Icon(
              LucideIcons.x,
              size: 12,
              color: Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCountBadge(String text, Color bg, Color textCol) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: textCol,
        ),
      ),
    );
  }

  void _showDoctorPickerModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return _PersonnelPickerBottomSheet(
          title: 'Pilih Dokter Bertugas',
          personnelType: 'Doctor',
          selectedPersonnel: _selectedDoctors,
          scheduleApi: _scheduleApi,
          accentColor: AppColors.orange,
          accentBgColor: const Color(0xFFFFF7ED),
          icon: LucideIcons.stethoscope,
          onConfirmed: (selected) {
            setState(() {
              _selectedDoctors = selected;
            });
          },
        );
      },
    );
  }

  void _showNursePickerModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return _PersonnelPickerBottomSheet(
          title: 'Pilih Perawat Bertugas',
          personnelType: 'Perawat',
          selectedPersonnel: _selectedNurses,
          scheduleApi: _scheduleApi,
          accentColor: const Color(0xFF059669),
          accentBgColor: const Color(0xFFECFDF5),
          icon: LucideIcons.user,
          onConfirmed: (selected) {
            setState(() {
              _selectedNurses = selected;
            });
          },
        );
      },
    );
  }

  void _showCrewPickerModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return _CrewPickerBottomSheet(
          selectedCrews: _selectedCrews,
          scheduleApi: _scheduleApi,
          onConfirmed: (selected) {
            setState(() {
              _selectedCrews = selected;
            });
          },
        );
      },
    );
  }

  void _showPortPickerModal(int index) {
    final stop = _stops[index];

    final disabledPortCodes = <String>{};
    final disabledPortNames = <String>{};
    for (var i = 0; i < _stops.length; i++) {
      if (i != index) {
        if (_stops[i].portCode.isNotEmpty) {
          disabledPortCodes.add(_stops[i].portCode.toLowerCase().trim());
        }
        if (_stops[i].portName.isNotEmpty) {
          disabledPortNames.add(_stops[i].portName.toLowerCase().trim());
        }
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return _PortPickerBottomSheet(
          selectedPortId: stop.portId,
          selectedPortCode: stop.portCode,
          selectedPortName: stop.portName,
          disabledPortCodes: disabledPortCodes,
          disabledPortNames: disabledPortNames,
          scheduleApi: _scheduleApi,
          initialPorts: _ports,
          onSelected: (port) {
            setState(() {
              stop.portId = port.id;
              stop.portName = port.name;
              stop.portCode = port.code.isNotEmpty ? port.code : port.id;
              if (!_ports.any((p) => p.id == port.id)) {
                _ports.add(port);
              }
            });
          },
        );
      },
    );
  }
}

class _PortPickerBottomSheet extends StatefulWidget {
  const _PortPickerBottomSheet({
    this.selectedPortId = '',
    required this.selectedPortCode,
    required this.selectedPortName,
    required this.disabledPortCodes,
    required this.disabledPortNames,
    required this.scheduleApi,
    required this.initialPorts,
    required this.onSelected,
  });

  final String selectedPortId;
  final String selectedPortCode;
  final String selectedPortName;
  final Set<String> disabledPortCodes;
  final Set<String> disabledPortNames;
  final ScheduleApi scheduleApi;
  final List<PortItem> initialPorts;
  final ValueChanged<PortItem> onSelected;

  @override
  State<_PortPickerBottomSheet> createState() => _PortPickerBottomSheetState();
}

class _PortPickerBottomSheetState extends State<_PortPickerBottomSheet> {
  late final ScrollController _scrollController;
  late final TextEditingController _searchController;
  Timer? _debounceTimer;

  late List<PortItem> _items;
  int _page = 1;
  bool _loading = false;
  bool _loadingMore = false;
  bool _hasMore = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _items = List.from(widget.initialPorts);
    _scrollController = ScrollController()..addListener(_onScroll);
    _searchController = TextEditingController();

    if (_items.isEmpty) {
      _fetchPage(1, reset: true);
    } else {
      _page = (_items.length / 10).ceil();
    }
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
      final res = await widget.scheduleApi.getPorts(
        page: page,
        limit: 10,
        search: query.isNotEmpty ? query : null,
      );

      if (!mounted) return;
      setState(() {
        if (reset) {
          _items = res.items;
        } else {
          final existing = _items
              .map(
                (p) =>
                    (p.code.isNotEmpty ? p.code : p.name).toLowerCase().trim(),
              )
              .toSet();
          final newItems = res.items
              .where(
                (p) => !existing.contains(
                  (p.code.isNotEmpty ? p.code : p.name).toLowerCase().trim(),
                ),
              )
              .toList();
          _items.addAll(newItems);
        }
        _page = res.page;
        _hasMore = res.hasMore;
        _loading = false;
        _loadingMore = false;
      });
    } catch (e) {
      debugPrint('_PortPickerBottomSheet _fetchPage error: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayedItems = List<PortItem>.from(_items);
    if (widget.selectedPortName.isNotEmpty &&
        !displayedItems.any(
          (p) =>
              (widget.selectedPortId.isNotEmpty && p.id == widget.selectedPortId) ||
              p.name == widget.selectedPortName ||
              (p.code.isNotEmpty && p.code == widget.selectedPortCode),
        )) {
      displayedItems.insert(
        0,
        PortItem(
          id: widget.selectedPortId.isNotEmpty
              ? widget.selectedPortId
              : widget.selectedPortCode,
          code: widget.selectedPortCode,
          name: widget.selectedPortName,
        ),
      );
    }

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0F2FE),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      LucideIcons.anchor,
                      size: 18,
                      color: Color(0xFF0284C7),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Pilih Pelabuhan',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.text,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Gulir ke bawah untuk memuat pelabuhan lainnya',
                          style: TextStyle(fontSize: 12, color: AppColors.sub),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      LucideIcons.x,
                      size: 20,
                      color: AppColors.sub,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.text,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: 'Cari pelabuhan...',
                    hintStyle: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF94A3B8),
                    ),
                    prefixIcon: const Icon(
                      LucideIcons.search,
                      size: 16,
                      color: Color(0xFF94A3B8),
                    ),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? GestureDetector(
                            onTap: () {
                              _searchController.clear();
                              _fetchPage(1, query: '', reset: true);
                            },
                            child: const Icon(
                              LucideIcons.x,
                              size: 16,
                              color: Color(0xFF94A3B8),
                            ),
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // List of Ports with Infinite Scroll
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.orange,
                      ),
                    )
                  : displayedItems.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Tidak ada pelabuhan ditemukan',
                          style: TextStyle(fontSize: 13, color: AppColors.sub),
                        ),
                      ),
                    )
                  : ListView.separated(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      itemCount:
                          displayedItems.length +
                          (_loadingMore || _hasMore ? 1 : 0),
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1, color: Color(0xFFF1F5F9)),
                      itemBuilder: (ctx, idx) {
                        if (idx >= displayedItems.length) {
                          if (_loadingMore) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Center(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.orange,
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Memuat pelabuhan lainnya...',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          } else {
                            return const SizedBox(height: 20);
                          }
                        }

                        final port = displayedItems[idx];
                        final portCodeLower = port.code.toLowerCase().trim();
                        final portIdLower = port.id.toLowerCase().trim();
                        final portNameLower = port.name.toLowerCase().trim();

                        final isSelected =
                            (widget.selectedPortCode.isNotEmpty &&
                                (portCodeLower ==
                                        widget.selectedPortCode
                                            .toLowerCase()
                                            .trim() ||
                                    portIdLower ==
                                        widget.selectedPortCode
                                            .toLowerCase()
                                            .trim())) ||
                            (portNameLower ==
                                widget.selectedPortName.toLowerCase().trim());

                        final isDisabled =
                            !isSelected &&
                            ((portCodeLower.isNotEmpty &&
                                    widget.disabledPortCodes.contains(
                                      portCodeLower,
                                    )) ||
                                (portIdLower.isNotEmpty &&
                                    widget.disabledPortCodes.contains(
                                      portIdLower,
                                    )) ||
                                widget.disabledPortNames.contains(
                                  portNameLower,
                                ));

                        return InkWell(
                          onTap: isDisabled
                              ? null
                              : () {
                                  widget.onSelected(port);
                                  Navigator.pop(context);
                                },
                          borderRadius: BorderRadius.circular(10),
                          child: Opacity(
                            opacity: isDisabled ? 0.45 : 1.0,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 11,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFFFFF7ED)
                                    : (isDisabled
                                          ? const Color(0xFFF8FAFC)
                                          : Colors.transparent),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? AppColors.orangeLt
                                          : const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      LucideIcons.anchor,
                                      size: 16,
                                      color: isSelected
                                          ? AppColors.orange
                                          : (isDisabled
                                                ? const Color(0xFF94A3B8)
                                                : const Color(0xFF64748B)),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          port.name,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: isSelected
                                                ? FontWeight.w700
                                                : (isDisabled
                                                      ? FontWeight.w500
                                                      : FontWeight.w600),
                                            color: isSelected
                                                ? AppColors.orange
                                                : (isDisabled
                                                      ? const Color(0xFF94A3B8)
                                                      : AppColors.text),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Row(
                                          children: [
                                            if (port.code.isNotEmpty) ...[
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 5,
                                                      vertical: 1,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: const Color(
                                                    0xFFE2E8F0,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  port.code,
                                                  style: TextStyle(
                                                    fontSize: 10.5,
                                                    fontWeight: FontWeight.w700,
                                                    color: isDisabled
                                                        ? const Color(
                                                            0xFF94A3B8,
                                                          )
                                                        : const Color(
                                                            0xFF475569,
                                                          ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                            ],
                                            if (port.city.isNotEmpty)
                                              Text(
                                                port.city,
                                                style: const TextStyle(
                                                  fontSize: 11.5,
                                                  color: Color(0xFF94A3B8),
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
                                      color: AppColors.orange,
                                    )
                                  else if (isDisabled)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: const Color(0xFFE2E8F0),
                                        ),
                                      ),
                                      child: const Text(
                                        'Sudah Dipilih',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF94A3B8),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PersonnelPickerBottomSheet extends StatefulWidget {
  const _PersonnelPickerBottomSheet({
    required this.title,
    required this.personnelType,
    required this.selectedPersonnel,
    required this.scheduleApi,
    required this.accentColor,
    required this.accentBgColor,
    required this.icon,
    required this.onConfirmed,
  });

  final String title;
  final String personnelType;
  final List<SchedulePersonnelItem> selectedPersonnel;
  final ScheduleApi scheduleApi;
  final Color accentColor;
  final Color accentBgColor;
  final IconData icon;
  final ValueChanged<List<SchedulePersonnelItem>> onConfirmed;

  @override
  State<_PersonnelPickerBottomSheet> createState() =>
      _PersonnelPickerBottomSheetState();
}

class _PersonnelPickerBottomSheetState
    extends State<_PersonnelPickerBottomSheet> {
  late final ScrollController _scrollController;
  late final TextEditingController _searchController;
  Timer? _debounceTimer;

  late List<SchedulePersonnelItem> _selectedItems;
  List<SchedulePersonnelItem> _items = [];
  int _page = 1;
  bool _loading = false;
  bool _loadingMore = false;
  bool _hasMore = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _selectedItems = List.from(widget.selectedPersonnel);
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
      final res = await widget.scheduleApi.getMedicalPersonnel(
        type: widget.personnelType,
        page: page,
        limit: 10,
        search: query.isNotEmpty ? query : null,
      );

      if (!mounted) return;
      setState(() {
        if (reset) {
          _items = res.items;
        } else {
          final existingKeys = _items
              .map(
                (p) => (p.id.isNotEmpty ? p.id : p.name).toLowerCase().trim(),
              )
              .toSet();
          final newItems = res.items
              .where(
                (p) => !existingKeys.contains(
                  (p.id.isNotEmpty ? p.id : p.name).toLowerCase().trim(),
                ),
              )
              .toList();
          _items.addAll(newItems);
        }
        _page = res.page;
        _hasMore = res.hasMore;
        _loading = false;
        _loadingMore = false;
      });
    } catch (e) {
      debugPrint('_PersonnelPickerBottomSheet _fetchPage error: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  bool _isItemSelected(SchedulePersonnelItem item) {
    return _selectedItems.any(
      (s) =>
          (s.id.isNotEmpty && item.id.isNotEmpty && s.id == item.id) ||
          (s.name.toLowerCase().trim() == item.name.toLowerCase().trim()),
    );
  }

  void _toggleItem(SchedulePersonnelItem item) {
    setState(() {
      if (_isItemSelected(item)) {
        _selectedItems.removeWhere(
          (s) =>
              (s.id.isNotEmpty && item.id.isNotEmpty && s.id == item.id) ||
              (s.name.toLowerCase().trim() == item.name.toLowerCase().trim()),
        );
      } else {
        _selectedItems.add(item);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final displayedItems = List<SchedulePersonnelItem>.from(_items);
    if (_searchQuery.isEmpty) {
      for (final sel in _selectedItems) {
        if (!displayedItems.any(
          (p) =>
              (p.id.isNotEmpty && sel.id.isNotEmpty && p.id == sel.id) ||
              (p.name.toLowerCase().trim() == sel.name.toLowerCase().trim()),
        )) {
          displayedItems.insert(0, sel);
        }
      }
    }

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(20, 18, 16, 14),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: widget.accentBgColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(widget.icon, size: 18, color: widget.accentColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.text,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_selectedItems.length} dipilih',
                        style: TextStyle(
                          fontSize: 12,
                          color: widget.accentColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    LucideIcons.x,
                    size: 20,
                    color: AppColors.sub,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.text,
                ),
                decoration: InputDecoration(
                  hintText: 'Cari nama atau spesialisasi...',
                  hintStyle: const TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFF94A3B8),
                  ),
                  prefixIcon: const Icon(
                    LucideIcons.search,
                    size: 16,
                    color: Color(0xFF94A3B8),
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(LucideIcons.x, size: 14),
                          onPressed: () {
                            _searchController.clear();
                            _fetchPage(1, query: '', reset: true);
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 11,
                  ),
                ),
              ),
            ),
          ),

          // Content List
          Expanded(
            child: _loading
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: widget.accentColor,
                      ),
                    ),
                  )
                : displayedItems.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(
                            LucideIcons.searchX,
                            size: 36,
                            color: Color(0xFFCBD5E1),
                          ),
                          SizedBox(height: 10),
                          Text(
                            'Tidak ada data tenaga medis ditemukan.',
                            style: TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    itemCount:
                        displayedItems.length +
                        (_loadingMore || _hasMore ? 1 : 0),
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    itemBuilder: (ctx, idx) {
                      if (idx >= displayedItems.length) {
                        if (_loadingMore) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: widget.accentColor,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Memuat lebih banyak...',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF94A3B8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        } else {
                          return const SizedBox(height: 20);
                        }
                      }

                      final item = displayedItems[idx];
                      final isSelected = _isItemSelected(item);

                      return InkWell(
                        onTap: () => _toggleItem(item),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? widget.accentBgColor.withValues(alpha: 0.4)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: widget.accentColor,
                                child: Text(
                                  item.initials,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.name,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: isSelected
                                            ? FontWeight.w700
                                            : FontWeight.w600,
                                        color: isSelected
                                            ? widget.accentColor
                                            : AppColors.text,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      item.specialization.isNotEmpty
                                          ? item.specialization
                                          : (item.role.isNotEmpty
                                                ? item.role
                                                : widget.personnelType),
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        color: Color(0xFF94A3B8),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? widget.accentColor
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isSelected
                                        ? widget.accentColor
                                        : const Color(0xFFCBD5E1),
                                    width: 1.5,
                                  ),
                                ),
                                child: isSelected
                                    ? const Icon(
                                        LucideIcons.check,
                                        size: 14,
                                        color: Colors.white,
                                      )
                                    : null,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // Footer Actions
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
              color: Colors.white,
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 1,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(42),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Batal',
                      style: TextStyle(
                        color: Color(0xFF475569),
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: widget.accentColor,
                      minimumSize: const Size.fromHeight(42),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () {
                      widget.onConfirmed(_selectedItems);
                      Navigator.pop(context);
                    },
                    child: Text(
                      'Terapkan (${_selectedItems.length})',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
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

class _CrewPickerBottomSheet extends StatefulWidget {
  const _CrewPickerBottomSheet({
    required this.selectedCrews,
    required this.scheduleApi,
    required this.onConfirmed,
  });

  final List<ScheduleCrewItem> selectedCrews;
  final ScheduleApi scheduleApi;
  final ValueChanged<List<ScheduleCrewItem>> onConfirmed;

  @override
  State<_CrewPickerBottomSheet> createState() => _CrewPickerBottomSheetState();
}

class _CrewPickerBottomSheetState extends State<_CrewPickerBottomSheet> {
  late final ScrollController _scrollController;
  late final TextEditingController _searchController;
  Timer? _debounceTimer;

  late List<ScheduleCrewItem> _selectedItems;
  List<ScheduleCrewItem> _items = [];
  int _page = 1;
  bool _loading = false;
  bool _loadingMore = false;
  bool _hasMore = true;
  String _searchQuery = '';

  static const _accentColor = Color(0xFF0284C7);
  static const _accentBgColor = Color(0xFFE0F2FE);

  @override
  void initState() {
    super.initState();
    _selectedItems = List.from(widget.selectedCrews);
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
      final res = await widget.scheduleApi.getCrews(
        page: page,
        limit: 10,
        search: query.isNotEmpty ? query : null,
      );

      if (!mounted) return;
      setState(() {
        if (reset) {
          _items = res.items;
        } else {
          final existingKeys = _items
              .map(
                (c) => (c.id.isNotEmpty ? c.id : c.name).toLowerCase().trim(),
              )
              .toSet();
          final newItems = res.items
              .where(
                (c) => !existingKeys.contains(
                  (c.id.isNotEmpty ? c.id : c.name).toLowerCase().trim(),
                ),
              )
              .toList();
          _items.addAll(newItems);
        }
        _page = res.page;
        _hasMore = res.hasMore;
        _loading = false;
        _loadingMore = false;
      });
    } catch (e) {
      debugPrint('_CrewPickerBottomSheet _fetchPage error: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  bool _isItemSelected(ScheduleCrewItem item) {
    return _selectedItems.any(
      (s) =>
          (s.id.isNotEmpty && item.id.isNotEmpty && s.id == item.id) ||
          (s.name.toLowerCase().trim() == item.name.toLowerCase().trim()),
    );
  }

  void _toggleItem(ScheduleCrewItem item) {
    setState(() {
      if (_isItemSelected(item)) {
        _selectedItems.removeWhere(
          (s) =>
              (s.id.isNotEmpty && item.id.isNotEmpty && s.id == item.id) ||
              (s.name.toLowerCase().trim() == item.name.toLowerCase().trim()),
        );
      } else {
        _selectedItems.add(item);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final displayedItems = List<ScheduleCrewItem>.from(_items);
    if (_searchQuery.isEmpty) {
      for (final sel in _selectedItems) {
        if (!displayedItems.any(
          (c) =>
              (c.id.isNotEmpty && sel.id.isNotEmpty && c.id == sel.id) ||
              (c.name.toLowerCase().trim() == sel.name.toLowerCase().trim()),
        )) {
          displayedItems.insert(0, sel);
        }
      }
    }

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(20, 18, 16, 14),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _accentBgColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    LucideIcons.anchor,
                    size: 18,
                    color: _accentColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Pilih ABK Kapal (Crew)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.text,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_selectedItems.length} dipilih',
                        style: const TextStyle(
                          fontSize: 12,
                          color: _accentColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    LucideIcons.x,
                    size: 20,
                    color: AppColors.sub,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.text,
                ),
                decoration: InputDecoration(
                  hintText: 'Cari nama atau jabatan kru...',
                  hintStyle: const TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFF94A3B8),
                  ),
                  prefixIcon: const Icon(
                    LucideIcons.search,
                    size: 16,
                    color: Color(0xFF94A3B8),
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(LucideIcons.x, size: 14),
                          onPressed: () {
                            _searchController.clear();
                            _fetchPage(1, query: '', reset: true);
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 11,
                  ),
                ),
              ),
            ),
          ),

          // Content List
          Expanded(
            child: _loading
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: _accentColor,
                      ),
                    ),
                  )
                : displayedItems.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(
                            LucideIcons.searchX,
                            size: 36,
                            color: Color(0xFFCBD5E1),
                          ),
                          SizedBox(height: 10),
                          Text(
                            'Tidak ada kru kapal ditemukan.',
                            style: TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    itemCount:
                        displayedItems.length +
                        (_loadingMore || _hasMore ? 1 : 0),
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    itemBuilder: (ctx, idx) {
                      if (idx >= displayedItems.length) {
                        if (_loadingMore) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: _accentColor,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Memuat lebih banyak...',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF94A3B8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        } else {
                          return const SizedBox(height: 20);
                        }
                      }

                      final item = displayedItems[idx];
                      final isSelected = _isItemSelected(item);

                      return InkWell(
                        onTap: () => _toggleItem(item),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? _accentBgColor.withValues(alpha: 0.4)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: _accentColor,
                                child: Text(
                                  item.initials,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.name,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: isSelected
                                            ? FontWeight.w700
                                            : FontWeight.w600,
                                        color: isSelected
                                            ? _accentColor
                                            : AppColors.text,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      item.role.isNotEmpty
                                          ? item.role
                                          : 'ABK Kapal',
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        color: Color(0xFF94A3B8),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? _accentColor
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isSelected
                                        ? _accentColor
                                        : const Color(0xFFCBD5E1),
                                    width: 1.5,
                                  ),
                                ),
                                child: isSelected
                                    ? const Icon(
                                        LucideIcons.check,
                                        size: 14,
                                        color: Colors.white,
                                      )
                                    : null,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // Footer Actions
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
              color: Colors.white,
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 1,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(42),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Batal',
                      style: TextStyle(
                        color: Color(0xFF475569),
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: _accentColor,
                      minimumSize: const Size.fromHeight(42),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () {
                      widget.onConfirmed(_selectedItems);
                      Navigator.pop(context);
                    },
                    child: Text(
                      'Terapkan (${_selectedItems.length})',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
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

class _StopFormItem {
  _StopFormItem({
    this.portId = '',
    required this.portCode,
    required this.portName,
    this.departure,
    this.arrival,
    this.departureTz = 'WIB',
    this.arrivalTz = 'WIB',
  });

  String portId;
  String portCode;
  String portName;
  DateTime? departure;
  DateTime? arrival;
  String departureTz;
  String arrivalTz;
}

class _TopErrorToast extends StatefulWidget {
  final String message;
  final VoidCallback onDismiss;

  const _TopErrorToast({
    required this.message,
    required this.onDismiss,
  });

  @override
  State<_TopErrorToast> createState() => _TopErrorToastState();
}

class _TopErrorToastState extends State<_TopErrorToast>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.35),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    _controller.forward();

    _dismissTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        _controller.reverse().then((_) {
          widget.onDismiss();
        });
      }
    });
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    return Positioned(
      top: topPadding + 16,
      left: 16,
      right: 16,
      child: Align(
        alignment: Alignment.topCenter,
        child: Material(
          color: Colors.transparent,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 560),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFDC2626),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      LucideIcons.alertCircle,
                      color: Colors.white,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        widget.message,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        _controller.reverse().then((_) {
                          widget.onDismiss();
                        });
                      },
                      child: const Icon(
                        LucideIcons.x,
                        color: Colors.white70,
                        size: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
