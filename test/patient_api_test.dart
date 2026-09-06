import 'package:flutter_test/flutter_test.dart';
import 'package:bayan_rme/features/auth/domain/user_role.dart';
import 'package:bayan_rme/features/patients/domain/patient.dart';

void main() {
  group('Patient.fromApiJson', () {
    test('parses complete patient JSON from backend', () {
      final json = {
        'id': 'p-123',
        'nik': '3171065506940002',
        'name': 'Siti Rahayu',
        'gender': 'Perempuan',
        'dob': '1995-06-15',
        'address': 'Jakarta Pusat',
        'status': 'Monitoring',
        'created_at': '2026-08-17T09:12:00Z',
        'updated_at': '2026-08-17T09:45:00Z',
        'medical_records': [
          {
            'id': 'rec-1',
            'doctor_id': 'doc-1',
            'complaint': 'Demam dan pusing',
            'diagnosis': 'Febris',
            'treatment': 'Paracetamol 500mg',
            'notes': '3x1 sesudah makan',
          }
        ]
      };

      final patient = Patient.fromApiJson(json);
      expect(patient.id, equals('p-123'));
      expect(patient.nama, equals('Siti Rahayu'));
      expect(patient.nik, equals('3171065506940002'));
      expect(patient.jk, equals(Gender.p));
      expect(patient.alamat, equals('Jakarta Pusat'));
      expect(patient.keluhanUtama, equals('Demam dan pusing'));
      expect(patient.diagnosa, equals('Febris'));
      expect(patient.status, equals(PatientStatus.diperiksa));
      expect(patient.resep.length, equals(1));
      expect(patient.resep.first.obat, equals('Paracetamol 500mg'));
    });

    test('handles empty medical_records gracefully', () {
      final json = {
        'id': 'p-456',
        'nik': '3374031203680001',
        'name': 'Budi Santoso',
        'gender': 'Laki-laki',
        'dob': '1980-01-01',
        'address': 'Semarang',
        'status': 'Stable',
        'medical_records': []
      };

      final patient = Patient.fromApiJson(json);
      expect(patient.id, equals('p-456'));
      expect(patient.nama, equals('Budi Santoso'));
      expect(patient.jk, equals(Gender.l));
      expect(patient.status, equals(PatientStatus.menungguDokter));
      expect(patient.diagnosa, isNull);
    });

    test('parses status_penanganan from backend and maps to statusMeta', () {
      final json = {
        'id': 'p-789',
        'nik': '3374031203680002',
        'name': 'Ahmad Fauzi',
        'gender': 'Laki-laki',
        'status': 'Monitoring',
        'status_penanganan': 'Menunggu Obat',
      };

      final patient = Patient.fromApiJson(json);
      expect(patient.statusPenanganan, equals('Menunggu Obat'));
    });

    test('parses master patient fields: register_no, phone, poliklinik, service_ship, last_visit', () {
      final json = {
        'id': '03872b15-c38d-4aa5-a007-e6a59b9b2241',
        'register_no': 'RJ30082026-00001',
        'nik': '3173051208950007',
        'name': 'Pierre Gasly',
        'dob': '1995-08-17T00:00:00Z',
        'gender': 'Laki-laki',
        'blood_type': 'O+',
        'phone': '081234567890',
        'address': 'Jl. Pelabuhan No. 12, RT 01 / RW 02',
        'status': 'Active',
        'service_ship_code': 'RSK-BYNP-LD1',
        'service_ship': {
          'id': '3a7ff982-e187-49f8-a34e-95f775afda61',
          'code': 'RSK-BYNP-LD1',
          'name': 'RSK dr. Lie Dharmawan Bayan Peduli I',
        },
        'poli_code': 'UMUM',
        'poliklinik': {
          'id': '50ef5a36-85b1-4be4-8ed7-d6fe0bbc7251',
          'code': 'UMUM',
          'name': 'Poli Umum',
        },
        'last_visit': '2026-09-05T00:00:00Z',
      };

      final patient = Patient.fromApiJson(json);
      expect(patient.id, equals('03872b15-c38d-4aa5-a007-e6a59b9b2241'));
      expect(patient.registerNo, equals('RJ30082026-00001'));
      expect(patient.phone, equals('081234567890'));
      expect(patient.poliName, equals('Poli Umum'));
      expect(patient.serviceShipName, equals('RSK dr. Lie Dharmawan Bayan Peduli I'));
      expect(patient.dbStatus, equals('Active'));
      expect(patient.lastVisit, equals('2026-09-05T00:00:00Z'));
    });
  });

  group('userRoleFromApiValue', () {
    test('parses Pharmacist and pharmacy synonyms correctly', () {
      expect(userRoleFromApiValue('Pharmacist'), equals(UserRole.pharmacy));
      expect(userRoleFromApiValue('pharmacist'), equals(UserRole.pharmacy));
      expect(userRoleFromApiValue('pharmacy'), equals(UserRole.pharmacy));
      expect(userRoleFromApiValue('apoteker'), equals(UserRole.pharmacy));
    });

    test('parses Nurse, Doctor, Lab, and Admin roles correctly', () {
      expect(userRoleFromApiValue('Doctor'), equals(UserRole.dokter));
      expect(userRoleFromApiValue('dokter'), equals(UserRole.dokter));
      expect(userRoleFromApiValue('Nurse'), equals(UserRole.perawat));
      expect(userRoleFromApiValue('perawat'), equals(UserRole.perawat));
      expect(userRoleFromApiValue('Lab Analyst'), equals(UserRole.lab));
      expect(userRoleFromApiValue('admin_kapal'), equals(UserRole.adminKapal));
    });
  });
}
