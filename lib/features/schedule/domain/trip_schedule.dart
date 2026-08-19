import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One sailing schedule entry, shown read-only to Admin Kapal per the RBAC
/// matrix (Ship Web Admin: Jadwal Perjalanan — Admin Kapal R only).
class JadwalPerjalanan extends Equatable {
  const JadwalPerjalanan({
    required this.id,
    required this.namaKapal,
    required this.pelabuhanAsal,
    required this.pelabuhanTujuan,
    required this.berangkat,
    required this.tiba,
    required this.status,
  });

  final String id;
  final String namaKapal;
  final String pelabuhanAsal;
  final String pelabuhanTujuan;
  final DateTime berangkat;
  final DateTime tiba;
  final String status;

  @override
  List<Object?> get props => [id, namaKapal, pelabuhanAsal, pelabuhanTujuan, berangkat, tiba, status];
}

/// Mock schedule data — same pattern as the patient repository: local seed
/// now, swap for the backend later keeping the provider signature.
final jadwalPerjalananProvider = Provider<List<JadwalPerjalanan>>((ref) {
  final now = DateTime.now();
  return [
    JadwalPerjalanan(
      id: 'J001',
      namaKapal: 'KM Bayan Utama',
      pelabuhanAsal: 'Tanjung Priok',
      pelabuhanTujuan: 'Makassar',
      berangkat: now.add(const Duration(days: 1, hours: 8)),
      tiba: now.add(const Duration(days: 3, hours: 14)),
      status: 'Terjadwal',
    ),
    JadwalPerjalanan(
      id: 'J002',
      namaKapal: 'KM Bayan Utama',
      pelabuhanAsal: 'Makassar',
      pelabuhanTujuan: 'Balikpapan',
      berangkat: now.add(const Duration(days: 4, hours: 9)),
      tiba: now.add(const Duration(days: 5, hours: 18)),
      status: 'Terjadwal',
    ),
    JadwalPerjalanan(
      id: 'J003',
      namaKapal: 'KM Bayan Utama',
      pelabuhanAsal: 'Surabaya',
      pelabuhanTujuan: 'Tanjung Priok',
      berangkat: now.subtract(const Duration(days: 2, hours: 6)),
      tiba: now.subtract(const Duration(hours: 12)),
      status: 'Selesai',
    ),
  ];
});
