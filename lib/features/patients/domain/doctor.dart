import 'package:equatable/equatable.dart';

/// Care-team directory used by Perawat to assign a patient to an on-duty doctor.
class Doctor extends Equatable {
  const Doctor({
    required this.id,
    required this.nama,
    required this.spesialisasi,
    required this.online,
    this.email,
    this.phone,
    this.sip,
    this.shipId,
    this.shipName,
    this.availability,
  });

  final String id;
  final String nama;
  final String spesialisasi;
  final bool online;

  /// Matched against the logged-in user's email (from the real auth API) so
  /// a Dokter session can be tied back to a directory entry. See
  /// AuthSession.doctorDirectoryId.
  final String? email;
  final String? phone;
  final String? sip;
  final String? shipId;
  final String? shipName;
  final String? availability;

  factory Doctor.fromApiJson(Map<String, dynamic> json) {
    final rawAvailability = json['availability']?.toString() ?? '';
    final availabilityLower = rawAvailability.toLowerCase();
    final isOnline = availabilityLower.isEmpty ||
        availabilityLower == 'available' ||
        availabilityLower == 'online' ||
        availabilityLower == 'on duty';

    final user = json['user'] is Map<String, dynamic> ? json['user'] as Map<String, dynamic> : null;
    final ship = json['ship'] is Map<String, dynamic> ? json['ship'] as Map<String, dynamic> : null;

    final email = user?['email']?.toString() ?? json['email']?.toString();
    final phone = json['phone']?.toString() ?? user?['phone']?.toString();
    final sip = json['sip']?.toString();
    final shipId = json['ship_id']?.toString();
    final shipName = ship?['name']?.toString();

    return Doctor(
      id: json['id']?.toString() ?? '',
      nama: json['name']?.toString() ?? '',
      spesialisasi: json['specialty']?.toString() ?? 'Dokter Umum',
      online: isOnline,
      email: email,
      phone: phone,
      sip: sip,
      shipId: shipId,
      shipName: shipName,
      availability: rawAvailability.isNotEmpty ? rawAvailability : null,
    );
  }

  @override
  List<Object?> get props => [id, nama, spesialisasi, online, email, phone, sip, shipId, shipName, availability];
}

const List<String> kObatList = [
  'Amoxicillin 500mg',
  'Paracetamol 500mg',
  'Omeprazole 20mg',
  'Amlodipine 5mg',
  'Salbutamol Inhaler',
  'Ibuprofen 400mg',
  'Cetirizine 10mg',
];

const List<String> kJenisLab = [
  'Darah Lengkap',
  'Urinalisis',
  'Rontgen Thorax',
  'EKG',
  'Gula Darah Sewaktu',
  'Fungsi Hati',
  'Fungsi Ginjal',
];

const List<String> kAlasanGantiObat = [
  'Stok habis',
  'Kadaluarsa',
  'Tidak tersedia di kapal',
  'Alergi pasien',
];
