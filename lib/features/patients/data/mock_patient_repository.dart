import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/lab_order.dart';
import '../domain/patient.dart';
import '../domain/resep_item.dart';
import '../domain/vitals.dart';

/// In-memory patient records, seeded with the same 3 demo patients as the
/// HTML prototype. Only auth talks to a real API in this build (per scope
/// decision) — clinical records stay mock/local for now. Point this class at
/// a real backend later by keeping the same public method signatures.
class PatientsNotifier extends StateNotifier<List<Patient>> {
  PatientsNotifier() : super(_seed());

  static List<Patient> _seed() {
    final now = DateTime.now();
    return [
      Patient(
        id: 'Q001',
        nama: 'Siti Rahayu',
        nik: '3171065506940002',
        jk: Gender.p,
        umur: 32,
        alamat: 'Jakarta',
        keluhanUtama: 'Demam tinggi dan sakit kepala',
        durasiKeluhan: '2 hari',
        lokasiKeluhan: 'Kepala bagian depan',
        vitals: const Vitals(tekananDarah: '120/80', nadi: '88', suhu: '38.6', frekuensiNapas: '20', spo2: '97'),
        assignedDokterId: 'D1',
        waktuMasuk: '09:12',
        updatedAt: now.subtract(const Duration(minutes: 30)),
        status: PatientStatus.menungguDokter,
      ),
      Patient(
        id: 'Q002',
        nama: 'Budi Santoso',
        nik: '3374031203680001',
        jk: Gender.l,
        umur: 58,
        alamat: 'Semarang',
        keluhanUtama: 'Nyeri dada sebelah kiri, menjalar ke lengan',
        durasiKeluhan: '3 jam',
        lokasiKeluhan: 'Dada kiri',
        vitals: const Vitals(tekananDarah: '145/92', nadi: '96', suhu: '37.1', frekuensiNapas: '22', spo2: '95'),
        assignedDokterId: 'D1',
        waktuMasuk: '08:20',
        updatedAt: now.subtract(const Duration(minutes: 20)),
        status: PatientStatus.diperiksa,
        diagnosa: 'Angina Pektoris Stabil (I20.9)',
        resep: const [
          ResepItem(obat: 'Amlodipine 5mg', dosis: '1x1', instruksi: 'Diminum pagi hari setelah makan'),
        ],
        resepStatus: ResepStatus.baru,
        dilihatDokter: true,
      ),
      Patient(
        id: 'Q003',
        nama: 'Dewi Kurnia',
        nik: '3273076907990004',
        jk: Gender.p,
        umur: 27,
        alamat: 'Bandung',
        keluhanUtama: 'Nyeri ulu hati, mual, tidak nafsu makan',
        durasiKeluhan: '5 hari',
        lokasiKeluhan: 'Ulu hati',
        vitals: const Vitals(tekananDarah: '110/70', nadi: '80', suhu: '36.8', frekuensiNapas: '18', spo2: '98'),
        assignedDokterId: 'D2',
        waktuMasuk: '10:05',
        updatedAt: now.subtract(const Duration(minutes: 10)),
        status: PatientStatus.diperiksa,
        diagnosa: 'Gastritis akut, susp. tukak lambung (K29.1)',
        resep: const [
          ResepItem(obat: 'Omeprazole 20mg', dosis: '2x1', instruksi: 'Sebelum makan pagi & malam'),
        ],
        resepStatus: ResepStatus.diproses,
        labOrder: const LabOrder(
          id: 'L001',
          jenis: 'Darah Lengkap',
          catatan: 'Cek Hb & leukosit, kecurigaan anemia ringan',
          status: LabOrderStatus.baru,
        ),
        dilihatDokter: true,
        dilihatPharmacy: true,
      ),
    ];
  }

  void _update(String id, Patient Function(Patient) updater) {
    state = [
      for (final p in state)
        if (p.id == id) updater(p).copyWith(updatedAt: DateTime.now()) else p,
    ];
  }

  void addPatient(Patient patient) {
    state = [...state, patient.copyWith(updatedAt: DateTime.now())];
  }

  void markDilihatDokter(String id) => _update(id, (p) => p.copyWith(dilihatDokter: true));
  void markDilihatDokterLab(String id) => _update(id, (p) => p.copyWith(dilihatDokterLab: true));
  void markDilihatPharmacy(String id) => _update(id, (p) => p.copyWith(dilihatPharmacy: true));
  void markDilihatLab(String id) => _update(id, (p) => p.copyWith(dilihatLab: true));

  void submitDiagnosaResep({
    required String id,
    required String diagnosa,
    required List<ResepItem> resep,
    LabOrder? labOrder,
  }) {
    _update(
      id,
      (p) => p.copyWith(
        status: PatientStatus.diperiksa,
        diagnosa: diagnosa,
        resep: resep,
        resepStatus: ResepStatus.baru,
        labOrder: labOrder ?? p.labOrder,
        dilihatDokter: true,
      ),
    );
  }

  void gantiObat(String id, int index, String obatBaru, String alasan) {
    _update(id, (p) {
      final resep = [...p.resep];
      final row = resep[index];
      resep[index] = row.copyWith(
        obat: obatBaru,
        penggantian: ObatPenggantian(dari: row.penggantian?.dari ?? row.obat, alasan: alasan),
      );
      return p.copyWith(resep: resep);
    });
  }

  void setResepStatus(String id, ResepStatus status) => _update(id, (p) => p.copyWith(resepStatus: status));

  void submitLabHasil({required String id, required String catatanHasil, String? fileName}) {
    _update(id, (p) {
      final order = p.labOrder;
      if (order == null) return p;
      return p.copyWith(
        labOrder: order.copyWith(status: LabOrderStatus.selesai, hasil: LabHasil(catatanHasil: catatanHasil, fileName: fileName)),
        dilihatDokterLab: false,
      );
    });
  }
}

final patientsProvider = StateNotifierProvider<PatientsNotifier, List<Patient>>((ref) {
  return PatientsNotifier();
});
