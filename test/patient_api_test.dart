import 'package:flutter_test/flutter_test.dart';
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
  });
}
