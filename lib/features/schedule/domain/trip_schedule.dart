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
    required this.portCode,
    required this.portName,
    required this.city,
    required this.stopOrder,
    required this.departure,
    required this.arrival,
    this.departureTz = 'WIB',
    this.arrivalTz = 'WIB',
  });

  final String id;
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

    return ScheduleStop(
      id: (json['id'] ?? '').toString(),
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

/// One sailing schedule entry from API / domain
class JadwalPerjalanan extends Equatable {
  const JadwalPerjalanan({
    required this.id,
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
  });

  final String id;
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
      asal = (json['origin_port'] ??
              json['origin'] ??
              json['from'] ??
              json['pelabuhan_asal'] ??
              'Pelabuhan Asal')
          .toString();
      kodeAsal =
          (json['origin_code'] ?? json['kode_asal'] ?? 'IDP').toString();
      tujuan = (json['destination_port'] ??
              json['destination'] ??
              json['to'] ??
              json['pelabuhan_tujuan'] ??
              'Pelabuhan Tujuan')
          .toString();
      kodeTujuan =
          (json['destination_code'] ?? json['kode_tujuan'] ?? 'IDP').toString();

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

    // 6. Parse Crews & Nurses count
    int totalPersonnel = 0;
    if (json['crews'] is List) {
      totalPersonnel += (json['crews'] as List).length;
    }
    if (json['nurses'] is List) {
      totalPersonnel += (json['nurses'] as List).length;
    }
    if (json['crew_count'] != null) {
      totalPersonnel = (json['crew_count'] as num).toInt();
    }

    // 7. Parse Resources
    final fuel = (json['fuel_liters'] as num?)?.toInt() ?? 0;
    final water = (json['water_liters'] as num?)?.toInt() ?? 0;

    return JadwalPerjalanan(
      id: (json['id'] ?? json['schedule_id'] ?? '').toString(),
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
    );
  }

  @override
  List<Object?> get props => [
        id,
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
      ];
}
