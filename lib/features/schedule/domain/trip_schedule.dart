import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

export '../data/schedule_repository.dart';

enum TripStatus {
  ongoing('Ongoing', 'Ongoing', Color(0xFF0284C7), Color(0xFFE0F2FE)),
  scheduled('Scheduled', 'Scheduled', Color(0xFFD97706), Color(0xFFFEF3C7)),
  completed('Completed', 'Completed', Color(0xFF059669), Color(0xFFD1FAE5)),
  cancelled('Cancelled', 'Cancelled', Color(0xFFDC2626), Color(0xFFFEE2E2));

  const TripStatus(this.code, this.label, this.color, this.containerColor);

  final String code;
  final String label;
  final Color color;
  final Color containerColor;

  static TripStatus fromString(String val) {
    switch (val.trim().toLowerCase()) {
      case 'ongoing':
      case 'berlayar':
      case 'sedang berlayar':
      case 'in progress':
      case 'sailing':
      case 'active':
        return TripStatus.ongoing;
      case 'scheduled':
      case 'terjadwal':
      case 'upcoming':
      case 'pending':
      case 'planned':
        return TripStatus.scheduled;
      case 'completed':
      case 'selesai':
      case 'done':
      case 'finished':
      case 'arrived':
        return TripStatus.completed;
      case 'cancelled':
      case 'canceled':
      case 'tertunda':
      case 'delayed':
      case 'batal':
      case 'dibatalkan':
        return TripStatus.cancelled;
      default:
        return TripStatus.scheduled;
    }
  }
}

/// A stop / port in a sailing schedule
class ScheduleStop extends Equatable {
  const ScheduleStop({
    required this.id,
    this.portId = '',
    required this.portCode,
    required this.portName,
    this.city = '',
    this.stopOrder = 0,
    this.departure,
    this.arrival,
    this.departureTz = 'WIB',
    this.arrivalTz = 'WIB',
  });

  final String id;
  final String portId;
  final String portCode;
  final String portName;
  final String city;
  final int stopOrder;
  final DateTime? departure;
  final DateTime? arrival;
  final String departureTz;
  final String arrivalTz;

  factory ScheduleStop.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) {
      if (value is String && value.isNotEmpty) {
        final parsed = DateTime.tryParse(value);
        if (parsed != null) return parsed.toLocal();
      }
      return null;
    }

    final portObj = json['port'] is Map<String, dynamic>
        ? json['port'] as Map<String, dynamic>
        : null;

    final portId = (portObj?['id'] ??
            json['port_id'] ??
            json['portId'] ??
            '')
        .toString();

    return ScheduleStop(
      id: (json['id'] ?? '').toString(),
      portId: portId,
      portCode: (portObj?['code'] ?? json['port_code'] ?? 'IDP').toString(),
      portName:
          (portObj?['name'] ?? json['port_name'] ?? 'Pelabuhan').toString(),
      city: (portObj?['city'] ?? json['city'] ?? '').toString(),
      stopOrder: (json['stop_order'] as num?)?.toInt() ?? 0,
      departure: parseDate(json['departure']),
      arrival: parseDate(json['arrival']),
      departureTz: (json['departure_tz'] ?? 'WIB').toString(),
      arrivalTz: (json['arrival_tz'] ?? 'WIB').toString(),
    );
  }

  @override
  List<Object?> get props => [
        id,
        portId,
        portCode,
        portName,
        city,
        stopOrder,
        departure,
        arrival,
        departureTz,
        arrivalTz,
      ];
}

/// Represents a clinic assigned to a schedule (Poli Layanan)
class ScheduleClinicItem extends Equatable {
  const ScheduleClinicItem({
    required this.id,
    required this.poliId,
    required this.poliName,
    required this.poliCode,
    required this.openTime,
    required this.closeTime,
  });

  final String id;
  final String poliId;
  final String poliName;
  final String poliCode;
  final String openTime;
  final String closeTime;

  String get operationalHours => '$openTime – $closeTime';
  String get name => poliName;
  String get code => poliCode;

  factory ScheduleClinicItem.fromJson(Map<String, dynamic> json) {
    final poli = json['poliklinik'] is Map<String, dynamic>
        ? json['poliklinik'] as Map<String, dynamic>
        : null;
    return ScheduleClinicItem(
      id: (json['id'] ?? '').toString(),
      poliId: (json['poliklinik_id'] ??
              poli?['id'] ??
              json['poli_id'] ??
              json['id'] ??
              '')
          .toString(),
      poliName: (poli?['name'] ?? poli?['nama'] ?? json['name'] ?? 'Poli').toString(),
      poliCode: (poli?['code'] ?? poli?['kode'] ?? json['code'] ?? 'POLI').toString().toUpperCase(),
      openTime: (json['open_time'] ?? '08:00').toString(),
      closeTime: (json['close_time'] ?? '18:00').toString(),
    );
  }

  @override
  List<Object?> get props => [id, poliId, poliName, poliCode, openTime, closeTime];
}

/// Represents a medical personnel (Doctor or Nurse) assigned to a schedule
class SchedulePersonnelItem extends Equatable {
  const SchedulePersonnelItem({
    this.id = '',
    required this.name,
    this.role = '',
    this.specialization = '',
    this.type = 'Doctor',
  });

  final String id;
  final String name;
  final String role;
  final String specialization;
  final String type;

  String get initials {
    final clean = name.replaceAll('dr.', '').replaceAll('Dr.', '').trim();
    final parts = clean.split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'D';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  factory SchedulePersonnelItem.fromJson(
    Map<String, dynamic> json, {
    String defaultType = 'Doctor',
  }) {
    final nested = (json['doctor'] is Map<String, dynamic>)
        ? json['doctor'] as Map<String, dynamic>
        : (json['nurse'] is Map<String, dynamic>)
            ? json['nurse'] as Map<String, dynamic>
            : (json['medical_personnel'] is Map<String, dynamic>)
                ? json['medical_personnel'] as Map<String, dynamic>
                : null;

    final name = (nested?['name'] ??
            nested?['full_name'] ??
            json['name'] ??
            json['full_name'] ??
            '')
        .toString()
        .trim();
    final spec = (nested?['specialty'] ??
            nested?['specialization'] ??
            nested?['spesialis'] ??
            json['specialty'] ??
            json['specialization'] ??
            '')
        .toString()
        .trim();
    final role = (nested?['role'] ?? json['role'] ?? '').toString().trim();
    final type = (nested?['type'] ?? json['type'] ?? defaultType).toString();

    // Prioritize actual medical personnel ID over the schedule_personnels pivot table row ID
    final effectiveId = (nested?['id'] ??
            json['medical_personnel_id'] ??
            json['doctor_id'] ??
            json['nurse_id'] ??
            json['id'] ??
            '')
        .toString();

    return SchedulePersonnelItem(
      id: effectiveId,
      name: name.isNotEmpty ? name : 'Tenaga Medis',
      specialization: spec,
      role: role,
      type: type,
    );
  }

  @override
  List<Object?> get props => [id, name, role, specialization, type];
}

/// Represents a ship crew member assigned to a schedule
class ScheduleCrewItem extends Equatable {
  const ScheduleCrewItem({
    required this.id,
    required this.name,
    required this.role,
  });

  final String id;
  final String name;
  final String role;

  String get initials {
    final parts = name.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'C';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  factory ScheduleCrewItem.fromJson(Map<String, dynamic> json) {
    final crew = json['crew'] is Map<String, dynamic>
        ? json['crew'] as Map<String, dynamic>
        : null;

    // Prioritize actual crew member ID over schedule_crews pivot ID
    final effectiveId = (crew?['id'] ?? json['crew_id'] ?? json['id'] ?? '').toString();

    return ScheduleCrewItem(
      id: effectiveId,
      name: (crew?['name'] ?? json['name'] ?? 'Crew').toString().trim(),
      role: (crew?['role'] ?? json['role'] ?? 'ABK').toString().trim(),
    );
  }

  @override
  List<Object?> get props => [id, name, role];
}

/// Represents provision (BBM and Water) history entry
class ProvisionHistoryItem extends Equatable {
  const ProvisionHistoryItem({
    required this.id,
    required this.scheduleCode,
    required this.fuelOil,
    required this.water,
    this.lat,
    this.lng,
    required this.createdAt,
    this.isLatest = false,
  });

  final String id;
  final String scheduleCode;
  final int fuelOil;
  final int water;
  final double? lat;
  final double? lng;
  final DateTime createdAt;
  final bool isLatest;

  String get coordinateDisplay {
    if (lat != null && lng != null) {
      return '${lat!.toStringAsFixed(5)}, ${lng!.toStringAsFixed(6)}';
    }
    return '—';
  }

  factory ProvisionHistoryItem.fromJson(
    Map<String, dynamic> json, {
    bool isLatest = false,
  }) {
    DateTime parseDate(dynamic val) {
      if (val is String && val.isNotEmpty) {
        final parsed = DateTime.tryParse(val);
        if (parsed != null) return parsed.toLocal();
      }
      return DateTime.now();
    }

    double? parseNum(dynamic val) {
      if (val is num) return val.toDouble();
      if (val is String && val.isNotEmpty) return double.tryParse(val);
      return null;
    }

    return ProvisionHistoryItem(
      id: (json['id'] ?? '').toString(),
      scheduleCode: (json['schedule_code'] ?? '').toString(),
      fuelOil: (json['fuel_oil'] as num?)?.toInt() ?? 0,
      water: (json['water'] as num?)?.toInt() ?? 0,
      lat: parseNum(json['lat']),
      lng: parseNum(json['lng']),
      createdAt: parseDate(json['created_at']),
      isLatest: isLatest,
    );
  }

  @override
  List<Object?> get props => [
        id,
        scheduleCode,
        fuelOil,
        water,
        lat,
        lng,
        createdAt,
        isLatest,
      ];
}

/// Represents an obstacle / incident on a trip
class TripIssueItem extends Equatable {
  const TripIssueItem({
    required this.id,
    required this.scheduleId,
    required this.description,
    required this.occurredAt,
    this.occurredAtTz = 'WIB',
    this.lat,
    this.lng,
  });

  final String id;
  final String scheduleId;
  final String description;
  final DateTime occurredAt;
  final String occurredAtTz;
  final double? lat;
  final double? lng;

  String get coordinateDisplay {
    if (lat != null && lng != null) {
      return '${lat!.toStringAsFixed(5)}, ${lng!.toStringAsFixed(5)}';
    }
    return '—';
  }

  factory TripIssueItem.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic val) {
      if (val is String && val.isNotEmpty) {
        final parsed = DateTime.tryParse(val);
        if (parsed != null) return parsed.toLocal();
      }
      return DateTime.now();
    }

    double? parseNum(dynamic val) {
      if (val is num) return val.toDouble();
      if (val is String && val.isNotEmpty) return double.tryParse(val);
      return null;
    }

    return TripIssueItem(
      id: (json['id'] ?? '').toString(),
      scheduleId: (json['schedule_id'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      occurredAt: parseDate(json['occurred_at'] ?? json['created_at']),
      occurredAtTz: (json['occurred_at_tz'] ?? 'WIB').toString(),
      lat: parseNum(json['lat']),
      lng: parseNum(json['lng']),
    );
  }

  @override
  List<Object?> get props => [
        id,
        scheduleId,
        description,
        occurredAt,
        occurredAtTz,
        lat,
        lng,
      ];
}

/// One sailing schedule entry from API / domain
class JadwalPerjalanan extends Equatable {
  const JadwalPerjalanan({
    required this.id,
    this.code = '',
    this.shipId = '',
    required this.shipCode,
    required this.namaKapal,
    this.shipType = 'Passenger',
    this.doctors = const ['dr. Lie Dharmawan'],
    required this.pelabuhanAsal,
    required this.kodeAsal,
    required this.pelabuhanTujuan,
    required this.kodeTujuan,
    required this.berangkat,
    required this.tiba,
    required this.status,
    this.estimasiDurasi = '2 Hari 6 Jam',
    this.kecepatan = '12.5 Knots',
    this.kruCount = 0,
    this.catatan = '',
    this.progressPersen = 0.0,
    this.stops = const [],
    this.fuelLiters = 0,
    this.waterLiters = 0,
    this.clinics = const [],
    this.doctorStaff = const [],
    this.nurseStaff = const [],
    this.crewStaff = const [],
    this.provisions = const [],
    this.tripIssues = const [],
  });

  final String id;
  final String code;
  final String shipId;
  final String shipCode;
  final String namaKapal;
  final String shipType;
  final List<String> doctors;
  final String pelabuhanAsal;
  final String kodeAsal;
  final String pelabuhanTujuan;
  final String kodeTujuan;
  final DateTime berangkat;
  final DateTime tiba;
  final String status;
  final String estimasiDurasi;
  final String kecepatan;
  final int kruCount;
  final String catatan;
  final double progressPersen;
  final List<ScheduleStop> stops;
  final int fuelLiters;
  final int waterLiters;
  final List<ScheduleClinicItem> clinics;
  final List<SchedulePersonnelItem> doctorStaff;
  final List<SchedulePersonnelItem> nurseStaff;
  final List<ScheduleCrewItem> crewStaff;
  final List<ProvisionHistoryItem> provisions;
  final List<TripIssueItem> tripIssues;

  String get scheduleCode => code.isNotEmpty ? code : shipCode;

  String get namaDokter =>
      doctors.isNotEmpty ? doctors.join(', ') : 'dr. Lie Dharmawan';

  // Backward compatible aliases
  String get voyageNumber => shipCode;
  String get tipeKapal => shipType;
  String get nakhoda => namaDokter;

  TripStatus get tripStatus => TripStatus.fromString(status);

  bool get isOngoing => tripStatus == TripStatus.ongoing;
  bool get isScheduled => tripStatus == TripStatus.scheduled;
  bool get isCompleted => tripStatus == TripStatus.completed;
  bool get isCancelled => tripStatus == TripStatus.cancelled;

  JadwalPerjalanan copyWith({
    String? id,
    String? code,
    String? shipId,
    String? shipCode,
    String? namaKapal,
    String? shipType,
    List<String>? doctors,
    String? pelabuhanAsal,
    String? kodeAsal,
    String? pelabuhanTujuan,
    String? kodeTujuan,
    DateTime? berangkat,
    DateTime? tiba,
    String? status,
    String? estimasiDurasi,
    String? kecepatan,
    int? kruCount,
    String? catatan,
    double? progressPersen,
    List<ScheduleStop>? stops,
    int? fuelLiters,
    int? waterLiters,
    List<ScheduleClinicItem>? clinics,
    List<SchedulePersonnelItem>? doctorStaff,
    List<SchedulePersonnelItem>? nurseStaff,
    List<ScheduleCrewItem>? crewStaff,
    List<ProvisionHistoryItem>? provisions,
    List<TripIssueItem>? tripIssues,
  }) {
    return JadwalPerjalanan(
      id: id ?? this.id,
      code: code ?? this.code,
      shipId: shipId ?? this.shipId,
      shipCode: shipCode ?? this.shipCode,
      namaKapal: namaKapal ?? this.namaKapal,
      shipType: shipType ?? this.shipType,
      doctors: doctors ?? this.doctors,
      pelabuhanAsal: pelabuhanAsal ?? this.pelabuhanAsal,
      kodeAsal: kodeAsal ?? this.kodeAsal,
      pelabuhanTujuan: pelabuhanTujuan ?? this.pelabuhanTujuan,
      kodeTujuan: kodeTujuan ?? this.kodeTujuan,
      berangkat: berangkat ?? this.berangkat,
      tiba: tiba ?? this.tiba,
      status: status ?? this.status,
      estimasiDurasi: estimasiDurasi ?? this.estimasiDurasi,
      kecepatan: kecepatan ?? this.kecepatan,
      kruCount: kruCount ?? this.kruCount,
      catatan: catatan ?? this.catatan,
      progressPersen: progressPersen ?? this.progressPersen,
      stops: stops ?? this.stops,
      fuelLiters: fuelLiters ?? this.fuelLiters,
      waterLiters: waterLiters ?? this.waterLiters,
      clinics: clinics ?? this.clinics,
      doctorStaff: doctorStaff ?? this.doctorStaff,
      nurseStaff: nurseStaff ?? this.nurseStaff,
      crewStaff: crewStaff ?? this.crewStaff,
      provisions: provisions ?? this.provisions,
      tripIssues: tripIssues ?? this.tripIssues,
    );
  }

  factory JadwalPerjalanan.fromApiJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic value) {
      if (value is String && value.isNotEmpty) {
        final parsed = DateTime.tryParse(value);
        if (parsed != null) return parsed.toLocal();
      } else if (value is int) {
        return DateTime.fromMillisecondsSinceEpoch(value).toLocal();
      }
      return DateTime.now();
    }

    // 1. Parse Ship
    final shipObj = json['ship'] is Map<String, dynamic>
        ? json['ship'] as Map<String, dynamic>
        : null;
    final shipId = (shipObj?['id'] ??
            json['ship_id'] ??
            '')
        .toString();
    final shipName = (shipObj?['name'] ??
            json['ship_name'] ??
            json['nama_kapal'] ??
            'Kapal')
        .toString();
    final shipCode = (shipObj?['code'] ??
            json['ship_code'] ??
            json['kode_kapal'] ??
            json['code'] ??
            '—')
        .toString();
    final shipType = (shipObj?['type'] ??
            json['ship_type'] ??
            json['tipe_kapal'] ??
            'Passenger')
        .toString();

    // 2. Parse Stops / Route
    final List<ScheduleStop> parsedStops = [];
    if (json['stops'] is List) {
      for (final s in json['stops'] as List) {
        if (s is Map<String, dynamic>) {
          parsedStops.add(ScheduleStop.fromJson(s));
        }
      }
      parsedStops.sort((a, b) => a.stopOrder.compareTo(b.stopOrder));
    }

    String asal = '';
    String kodeAsal = '';
    DateTime departureDate = DateTime.now();

    String tujuan = '';
    String kodeTujuan = '';
    DateTime arrivalDate = DateTime.now();

    if (parsedStops.isNotEmpty) {
      final firstStop = parsedStops.first;
      final lastStop = parsedStops.last;

      asal = firstStop.portName;
      kodeAsal = firstStop.portCode;
      departureDate = firstStop.departure ?? firstStop.arrival ?? DateTime.now();

      tujuan = lastStop.portName;
      kodeTujuan = lastStop.portCode;
      arrivalDate = lastStop.arrival ??
          lastStop.departure ??
          DateTime.now().add(const Duration(days: 2));
    } else {
      // Fallback to legacy/flat fields
      asal = (json['origin_port_name'] ??
              json['origin_port'] ??
              json['origin'] ??
              json['from'] ??
              json['pelabuhan_asal'] ??
              'Pelabuhan Asal')
          .toString();
      kodeAsal = (json['origin_port_code'] ??
              json['origin_code'] ??
              json['kode_asal'] ??
              'IDP')
          .toString();
      tujuan = (json['destination_port_name'] ??
              json['destination_port'] ??
              json['destination'] ??
              json['to'] ??
              json['pelabuhan_tujuan'] ??
              'Pelabuhan Tujuan')
          .toString();
      kodeTujuan = (json['destination_port_code'] ??
              json['destination_code'] ??
              json['kode_tujuan'] ??
              'IDP')
          .toString();

      departureDate = parseDate(json['departure_time'] ??
          json['departure_date'] ??
          json['etd'] ??
          json['berangkat']);
      arrivalDate = parseDate(json['arrival_time'] ??
          json['arrival_date'] ??
          json['eta'] ??
          json['tiba']);
    }

    // 3. Parse Status
    final statusRaw = (json['status'] ??
            json['trip_status'] ??
            json['schedule_status'] ??
            'Scheduled')
        .toString();
    final statusObj = TripStatus.fromString(statusRaw);

    // 4. Calculate Progress & Duration
    double progress = 0.0;
    if (json['progress'] != null) {
      progress = (json['progress'] as num).toDouble();
      if (progress > 1.0) progress = progress / 100.0;
    } else if (statusObj == TripStatus.completed) {
      progress = 1.0;
    } else if (statusObj == TripStatus.ongoing) {
      final now = DateTime.now();
      if (now.isAfter(arrivalDate) || now.isAtSameMomentAs(arrivalDate)) {
        progress = 1.0;
      } else if (now.isBefore(departureDate)) {
        progress = 0.0;
      } else {
        final total = arrivalDate.difference(departureDate).inMinutes;
        final current = now.difference(departureDate).inMinutes;
        if (total > 0) {
          progress = (current / total).clamp(0.0, 1.0);
        } else {
          progress = 1.0;
        }
      }
    }

    final diff = arrivalDate.difference(departureDate);
    final calculatedDuration = diff.inDays > 0
        ? '${diff.inDays} Hari ${diff.inHours % 24} Jam'
        : '${diff.inHours} Jam';

    // 5. Parse Doctors (supports doctors[i].doctor.name)
    final List<String> parsedDoctors = [];
    final rawDoctors =
        json['doctors'] ?? json['doctor_names'] ?? json['dokters'];

    if (rawDoctors is List) {
      for (final d in rawDoctors) {
        if (d is Map<String, dynamic>) {
          final nestedDoc = d['doctor'] is Map<String, dynamic>
              ? d['doctor'] as Map<String, dynamic>
              : null;
          final name = (nestedDoc?['name'] ??
                  d['name'] ??
                  d['full_name'] ??
                  d['doctor_name'] ??
                  '')
              .toString()
              .trim();
          if (name.isNotEmpty) parsedDoctors.add(name);
        } else if (d is String && d.trim().isNotEmpty) {
          parsedDoctors.add(d.trim());
        }
      }
    }

    if (parsedDoctors.isEmpty) {
      final singleDoc = (json['doctor_name'] ?? json['nama_dokter'] ?? '')
          .toString()
          .trim();
      if (singleDoc.isNotEmpty && singleDoc != 'null') {
        parsedDoctors.add(singleDoc);
      }
    }

    // 6. Parse Crews & Nurses count and staff lists
    final List<SchedulePersonnelItem> parsedDoctorStaff = [];
    if (json['doctors'] is List) {
      for (final d in json['doctors'] as List) {
        if (d is Map<String, dynamic>) {
          parsedDoctorStaff.add(
            SchedulePersonnelItem.fromJson(d, defaultType: 'Doctor'),
          );
        }
      }
    }

    final List<SchedulePersonnelItem> parsedNurseStaff = [];
    if (json['nurses'] is List) {
      for (final n in json['nurses'] as List) {
        if (n is Map<String, dynamic>) {
          parsedNurseStaff.add(
            SchedulePersonnelItem.fromJson(n, defaultType: 'Nurse'),
          );
        }
      }
    }

    final List<ScheduleCrewItem> parsedCrewStaff = [];
    if (json['crews'] is List) {
      for (final cr in json['crews'] as List) {
        if (cr is Map<String, dynamic>) {
          parsedCrewStaff.add(ScheduleCrewItem.fromJson(cr));
        }
      }
    }

    final List<ScheduleClinicItem> parsedClinics = [];
    if (json['clinics'] is List) {
      for (final c in json['clinics'] as List) {
        if (c is Map<String, dynamic>) {
          parsedClinics.add(ScheduleClinicItem.fromJson(c));
        }
      }
    }

    final List<ProvisionHistoryItem> parsedProvisions = [];
    if (json['provisions'] is List) {
      final list = json['provisions'] as List;
      for (var i = 0; i < list.length; i++) {
        final p = list[i];
        if (p is Map<String, dynamic>) {
          parsedProvisions.add(
            ProvisionHistoryItem.fromJson(p, isLatest: i == 0),
          );
        }
      }
    }

    final List<TripIssueItem> parsedTripIssues = [];
    if (json['trip_issues'] is List) {
      for (final ti in json['trip_issues'] as List) {
        if (ti is Map<String, dynamic>) {
          parsedTripIssues.add(TripIssueItem.fromJson(ti));
        }
      }
    }

    int totalPersonnel = parsedCrewStaff.length + parsedNurseStaff.length;
    if (json['crew_count'] != null) {
      totalPersonnel = (json['crew_count'] as num).toInt();
    }

    // 7. Parse Resources
    final fuel = (json['fuel_liters'] as num?)?.toInt() ?? 0;
    final water = (json['water_liters'] as num?)?.toInt() ?? 0;
    final scheduleCode = (json['code'] ?? json['schedule_code'] ?? '').toString();

    return JadwalPerjalanan(
      id: (json['id'] ?? json['schedule_id'] ?? '').toString(),
      code: scheduleCode,
      shipId: shipId,
      shipCode: shipCode,
      namaKapal: shipName,
      shipType: shipType,
      doctors: parsedDoctors,
      pelabuhanAsal: asal,
      kodeAsal: kodeAsal,
      pelabuhanTujuan: tujuan,
      kodeTujuan: kodeTujuan,
      berangkat: departureDate,
      tiba: arrivalDate,
      status: statusObj.code, // Standardized code ("Ongoing", "Scheduled", "Completed", "Cancelled")
      estimasiDurasi: (json['duration'] ?? calculatedDuration).toString(),
      kecepatan: (json['speed'] ?? '12.5 Knots').toString(),
      kruCount: totalPersonnel,
      catatan: (json['notes'] ?? json['description'] ?? '').toString(),
      progressPersen: progress,
      stops: parsedStops,
      fuelLiters: fuel,
      waterLiters: water,
      clinics: parsedClinics,
      doctorStaff: parsedDoctorStaff,
      nurseStaff: parsedNurseStaff,
      crewStaff: parsedCrewStaff,
      provisions: parsedProvisions,
      tripIssues: parsedTripIssues,
    );
  }

  @override
  List<Object?> get props => [
        id,
        code,
        shipId,
        shipCode,
        namaKapal,
        shipType,
        doctors,
        pelabuhanAsal,
        kodeAsal,
        pelabuhanTujuan,
        kodeTujuan,
        berangkat,
        tiba,
        status,
        estimasiDurasi,
        kecepatan,
        kruCount,
        catatan,
        progressPersen,
        stops,
        fuelLiters,
        waterLiters,
        clinics,
        doctorStaff,
        nurseStaff,
        crewStaff,
        provisions,
        tripIssues,
      ];
}

/// Represents a Port in the ports master
class PortItem extends Equatable {
  const PortItem({
    required this.id,
    required this.code,
    required this.name,
    this.city = '',
  });

  final String id;
  final String code;
  final String name;
  final String city;

  factory PortItem.fromJson(Map<String, dynamic> json) {
    return PortItem(
      id: (json['id'] ?? json['port_id'] ?? json['code'] ?? '').toString(),
      code: (json['code'] ?? json['port_code'] ?? '').toString(),
      name: (json['name'] ?? json['port_name'] ?? '').toString(),
      city: (json['city'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'code': code,
        'name': name,
        'city': city,
      };

  @override
  List<Object?> get props => [id, code, name, city];
}

class PaginatedPortResult {
  const PaginatedPortResult({
    required this.items,
    this.total = 0,
    this.page = 1,
    this.limit = 10,
    this.hasMore = false,
  });

  final List<PortItem> items;
  final int total;
  final int page;
  final int limit;
  final bool hasMore;
}

class PaginatedPersonnelResult {
  const PaginatedPersonnelResult({
    required this.items,
    this.total = 0,
    this.page = 1,
    this.limit = 10,
    this.hasMore = false,
  });

  final List<SchedulePersonnelItem> items;
  final int total;
  final int page;
  final int limit;
  final bool hasMore;
}

class PaginatedCrewResult {
  const PaginatedCrewResult({
    required this.items,
    this.total = 0,
    this.page = 1,
    this.limit = 10,
    this.hasMore = false,
  });

  final List<ScheduleCrewItem> items;
  final int total;
  final int page;
  final int limit;
  final bool hasMore;
}

class PoliklinikItem extends Equatable {
  const PoliklinikItem({
    required this.id,
    required this.code,
    required this.name,
    this.description = '',
  });

  final String id;
  final String code;
  final String name;
  final String description;

  factory PoliklinikItem.fromJson(Map<String, dynamic> json) {
    return PoliklinikItem(
      id: (json['id'] ?? json['poliklinik_id'] ?? '').toString(),
      code: (json['code'] ?? json['kode'] ?? json['poli_code'] ?? '').toString().toUpperCase(),
      name: (json['name'] ?? json['nama'] ?? json['poli_name'] ?? 'Poliklinik').toString(),
      description: (json['description'] ?? json['deskripsi'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'code': code,
        'name': name,
        'description': description,
      };

  @override
  List<Object?> get props => [id, code, name, description];
}

class PaginatedPoliklinikResult {
  const PaginatedPoliklinikResult({
    required this.items,
    this.total = 0,
    this.page = 1,
    this.limit = 10,
    this.hasMore = false,
  });

  final List<PoliklinikItem> items;
  final int total;
  final int page;
  final int limit;
  final bool hasMore;
}


