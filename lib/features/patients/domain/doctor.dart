import 'package:equatable/equatable.dart';

/// Care-team directory used by Perawat to assign a patient to an on-duty doctor.
class Doctor extends Equatable {
  const Doctor({
    required this.id,
    required this.nama,
    required this.spesialisasi,
    required this.online,
    this.email,
  });

  final String id;
  final String nama;
  final String spesialisasi;
  final bool online;

  /// Matched against the logged-in user's email (from the real auth API) so
  /// a Dokter session can be tied back to a directory entry. See
  /// AuthSession.doctorDirectoryId.
  final String? email;

  factory Doctor.fromApiJson(Map<String, dynamic> json) {
    final availability = json['availability']?.toString().toLowerCase() ?? '';
    final isOnline = availability.isEmpty || availability == 'available' || availability == 'online';
    return Doctor(
      id: json['id']?.toString() ?? '',
      nama: json['name']?.toString() ?? '',
      spesialisasi: json['specialty']?.toString() ?? 'Dokter Umum',
      online: isOnline,
      email: json['email']?.toString(),
    );
  }

  @override
  List<Object?> get props => [id, nama, spesialisasi, online, email];
}


const List<Doctor> kDoctors = [
  Doctor(id: '8afc72cb-b1c5-4ea1-a438-b06c6ae4a99b', nama: 'Dr. Budi Santoso Soedibyo', spesialisasi: 'General Practitioner', online: true, email: 'budi.santoso@rme.id'),
  Doctor(id: '7dde5814-0813-47c4-9802-367d2d38f511', nama: 'dr. Lie Dharmawan', spesialisasi: 'Emergency Medicine, Internal Medicine', online: true, email: 'dr_lie@yopmail.com'),
  Doctor(id: '5bef5428-83d8-4743-996c-5b015e5da5ce', nama: 'Dr. Agus Wijaya', spesialisasi: 'Pediatrics', online: true, email: 'agus.wijaya@rme.id'),
  Doctor(id: '3e33ee55-214a-4b72-9c27-bfaa324359a9', nama: 'Dr. Siti Rahayu Putri', spesialisasi: 'Cardiology', online: true, email: 'siti.rahayu@rme.id'),
  Doctor(id: '9a44e863-01eb-4be2-b017-05bd72d43a13', nama: 'Dr. Dewi Kusuma Wardani', spesialisasi: 'Pulmonology', online: false, email: 'dewi.kusuma@rme.id'),
];

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

/// Maps a logged-in Dokter's account (from the real auth API) to the mock
/// care-team directory used by Perawat's "assign dokter" dropdown, so a
/// signed-in doctor sees the patients assigned to them. Matches by email;
/// falls back to the first directory entry if this account isn't seeded
/// there yet (demo data limitation — see mock_patient_repository.dart).
String resolveDoctorId(String email) {
  for (final d in kDoctors) {
    if (d.email != null && d.email!.toLowerCase() == email.toLowerCase()) return d.id;
  }
  return kDoctors.first.id;
}

const List<String> kAlasanGantiObat = [
  'Stok habis',
  'Kadaluarsa',
  'Tidak tersedia di kapal',
  'Alergi pasien',
];
