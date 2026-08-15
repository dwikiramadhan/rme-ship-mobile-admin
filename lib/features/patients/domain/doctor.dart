import 'package:equatable/equatable.dart';

/// Care-team directory used by Perawat to assign a patient to an on-duty
/// doctor. This is demo/seed data — the same scope decision that keeps
/// patient records mock while only auth talks to a real API (see
/// mock_patient_repository.dart doc comment for the full rationale).
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

  @override
  List<Object?> get props => [id, nama, spesialisasi, online, email];
}

const List<Doctor> kDoctors = [
  Doctor(id: 'D1', nama: 'dr. Ahmad Fauzi, Sp.PD', spesialisasi: 'Penyakit Dalam', online: true, email: 'dr.ahmad@bayan.id'),
  Doctor(id: 'D2', nama: 'dr. Siti Rahma', spesialisasi: 'Dokter Umum', online: true, email: 'dr.siti@bayan.id'),
  Doctor(id: 'D3', nama: 'dr. Bimo Prakoso', spesialisasi: 'Bedah', online: false, email: 'dr.bimo@bayan.id'),
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
