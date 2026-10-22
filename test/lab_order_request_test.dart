import 'package:flutter_test/flutter_test.dart';

import 'package:bayan_rme/features/patients/domain/lab_order.dart';
import 'package:bayan_rme/features/patients/domain/medical_history.dart';

void main() {
  test('lab referral is sent as lab_order with the test and the note', () {
    const order = LabOrder(id: 'L1', jenis: 'Darah Lengkap', catatan: 'Puasa 8 jam');
    expect(labOrderRequestJson(order), {
      'requested_test': 'Darah Lengkap',
      'notes': 'Puasa 8 jam',
      'requires_fasting': false,
    });
  });

  group('MedicalHistory.requestedLabOrder', () {
    MedicalHistory history(Map<String, dynamic> labExam, {String status = 'Menunggu Lab'}) =>
        MedicalHistory.fromApiJson({
          'id': 'mr-1',
          'status_penanganan': status,
          'notes': 'Catatan umum dokter',
          'lab_examination': labExam,
        });

    test('reads the referral saved on the server', () {
      final h = history({
        'id': 'lab-1',
        'requested_test': 'Urinalisis',
        'doctor_notes': 'Urin pagi',
        'items': <Map<String, dynamic>>[],
      });

      final order = h.requestedLabOrder!;
      expect(order.jenis, 'Urinalisis');
      expect(order.catatan, 'Urin pagi');
      expect(order.status, LabOrderStatus.baru);
      // The patient built from the visit carries the same referral.
      expect(h.toPatient().labOrder?.jenis, 'Urinalisis');
      expect(h.toPatient().labOrder?.catatan, 'Urin pagi');
    });

    test('is done once results are in', () {
      final h = history({
        'requested_test': 'Darah Lengkap',
        'items': [
          {'test_name': 'Hemoglobin', 'result_value': '14.2'},
        ],
      }, status: 'Menunggu Dokter');
      expect(h.requestedLabOrder!.status, LabOrderStatus.selesai);
    });

    test('is null for records referred before referrals were stored', () {
      expect(history({'items': <Map<String, dynamic>>[]}).requestedLabOrder, isNull);
    });
  });
}
