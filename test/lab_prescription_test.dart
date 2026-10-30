import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bayan_rme/features/doctor/presentation/widgets/examination_input_modal.dart';
import 'package:bayan_rme/features/notifications/domain/notification_rules.dart';
import 'package:bayan_rme/features/patients/data/patient_api.dart';
import 'package:bayan_rme/features/patients/data/patient_repository.dart';
import 'package:bayan_rme/features/patients/domain/medical_history.dart';
import 'package:bayan_rme/features/patients/domain/pending_prescription.dart';
import 'package:bayan_rme/features/patients/domain/prescription_item.dart';

// A prescription given together with a lab referral: the pharmacy dispenses
// it without waiting for the lab results.

const _dispensed = {
  'id': 'rx-1',
  'sku': 'PCT',
  'quantity': 10,
  'dosage': '3x1',
  'instructions': 'Sesudah makan',
  'medicine': {'sku': 'PCT', 'name': 'Paracetamol 500mg', 'unit': 'Tablet'},
  'dispenses': [
    {'dispensed_sku': 'PCT', 'dispensed_quantity': 10},
  ],
};

const _pending = {
  'id': 'rx-2',
  'sku': 'AMX',
  'quantity': 6,
  'dosage': '2x1',
  'instructions': 'Sesudah makan',
  'medicine': {'sku': 'AMX', 'name': 'Amoxicillin 500mg', 'unit': 'Kapsul'},
  'dispenses': <Map<String, dynamic>>[],
};

MedicalHistory _visit(String status, List<Map<String, dynamic>> prescriptions) =>
    MedicalHistory.fromApiJson({
      'id': 'mr-1',
      'code': 'RJ22102026-00001',
      'patient_id': 'p-1',
      'patient': {'id': 'p-1', 'name': 'Siti Aminah'},
      'status_penanganan': status,
      'prescriptions': prescriptions,
    });

class _RecordingApi extends PatientApi {
  final pendingFlags = <bool>[];

  @override
  Future<PaginatedMedicalHistory> getMedicalHistoryPaginated({
    int page = 1,
    int limit = 10,
    String? search,
    String? statusPenanganan,
    String? userId,
    bool includePendingPrescriptions = false,
    bool includeReferred = false,
    String sortBy = 'created_at',
    String order = 'desc',
  }) async {
    pendingFlags.add(includePendingPrescriptions);
    return PaginatedMedicalHistory(
      data: const [],
      page: 1,
      limit: limit,
      total: 0,
      totalPages: 1,
    );
  }
}

void main() {
  test('a lab visit with medicine not yet dispensed waits for the pharmacy', () {
    final visit = _visit('Menunggu Lab', [_pending]);
    expect(visit.prescriptionPending, isTrue);
    expect(visit.waitingForPharmacy, isTrue);
    expect(isWaitingForPharmacy(visit.toPatient()), isTrue);
  });

  test('nothing waits once dispensed, or outside the doctor–lab–pharmacy flow', () {
    expect(_visit('Menunggu Lab', [_dispensed]).waitingForPharmacy, isFalse);
    expect(isWaitingForPharmacy(_visit('Menunggu Lab', [_dispensed]).toPatient()), isFalse);
    // Diperiksa: the medicine was taken from stock without the pharmacy.
    expect(_visit('Diperiksa', [_pending]).waitingForPharmacy, isFalse);
    expect(_visit('Selesai', [_pending]).waitingForPharmacy, isFalse);
  });

  test("the backend's prescription_pending wins", () {
    expect(
      hasPendingPrescription({
        'status_penanganan': 'Menunggu Lab',
        'prescription_pending': false,
        'prescriptions': [_pending],
      }),
      isFalse,
    );
  });

  test('the examining doctor can edit until medicine is dispensed', () {
    Map<String, dynamic> visit(String status, List<Map<String, dynamic>> rx) => {
      'status_penanganan': status,
      'doctor': {'id': 'doc-a', 'user_id': 'user-a'},
      'prescriptions': rx,
    };
    expect(canEditExam(visit('Menunggu Obat', [_pending]), 'user-a'), isTrue);
    // Another doctor, or no account.
    expect(canEditExam(visit('Menunggu Obat', [_pending]), 'user-b'), isFalse);
    expect(canEditExam(visit('Menunggu Obat', [_pending]), ''), isFalse);
    // The pharmacy already dispensed something.
    expect(
      canEditExam(visit('Menunggu Obat', [_dispensed, _pending]), 'user-a'),
      isFalse,
    );
    for (final status in ['Selesai', 'Menunggu Lab', 'Menunggu Dokter']) {
      expect(canEditExam(visit(status, [_pending]), 'user-a'), isFalse);
    }
  });

  testWidgets('editing starts from the saved exam and cannot refer', (tester) async {
    tester.view.physicalSize = const Size(900, 2800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final history = MedicalHistory.fromApiJson({
      'id': 'mr-1',
      'code': 'RJ22102026-00001',
      'patient_id': 'p-1',
      'patient': {'id': 'p-1', 'name': 'Siti Aminah'},
      'status_penanganan': 'Menunggu Obat',
      'status': 'Stable',
      'diagnosis': 'J06.9',
      'diagnoses': [
        {'code': 'J06.9', 'display': 'ISPA'},
      ],
      'notes': '[Dokter] Faring hiperemis',
      'prescriptions': [_pending],
    });
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: ExaminationInputModal(
              patient: history.toPatient(),
              history: history,
              editing: true,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Edit Rekam Medis'), findsOneWidget);
    expect(find.textContaining('J06.9'), findsWidgets);
    expect(find.text('Amoxicillin 500mg'), findsOneWidget);
    expect(find.text('Simpan Perubahan'), findsOneWidget);

    await tester.tap(find.text('Baik'));
    await tester.pumpAndSettle();
    expect(find.text('Perlu Rujukan'), findsNothing);

    // Let the ICD cache warm-up the modal starts finish.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 30));
  });

  test('a prescription line knows it was dispensed', () {
    final item = ResepItem.fromJson(Map<String, dynamic>.from(_dispensed));
    expect(item.dispensed, isTrue);
    expect(ResepItem.fromJson(item.toJson()).dispensed, isTrue);
    expect(ResepItem.fromJson(Map<String, dynamic>.from(_pending)).dispensed, isFalse);
  });

  test('only the pharmacy "Menunggu Obat" queue asks for pending prescriptions', () async {
    final api = _RecordingApi();
    final pharmacy = MedicalHistoryNotifier(
      api: api,
      autoFetch: false,
      statusPenanganan: 'Menunggu Obat',
      includePendingPrescriptions: true,
    );
    addTearDown(pharmacy.dispose);

    await pharmacy.fetchHistory(refresh: true);
    expect(api.pendingFlags.last, isTrue);

    pharmacy.setStatusPenanganan('Selesai');
    await pharmacy.fetchHistory(refresh: true);
    expect(api.pendingFlags.last, isFalse);

    final other = MedicalHistoryNotifier(
      api: api,
      autoFetch: false,
      statusPenanganan: 'Menunggu Obat',
    );
    addTearDown(other.dispose);
    await other.fetchHistory(refresh: true);
    expect(api.pendingFlags.last, isFalse);
  });

  testWidgets('the doctor sees dispensed medicine locked, and may prescribe with a lab referral', (tester) async {
    tester.view.physicalSize = const Size(900, 2800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final history = _visit('Menunggu Dokter', [_dispensed, _pending]);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: ExaminationInputModal(patient: history.toPatient(), history: history),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Paracetamol 500mg'), findsOneWidget);
    expect(find.text('Sudah diserahkan farmasi'), findsOneWidget);
    expect(find.text('2 Item Obat'), findsOneWidget);

    await tester.tap(find.text('Ya, Perlu Rujukan Lab'));
    await tester.pump();
    expect(find.text('Perlu Resep Obat?'), findsOneWidget);
    expect(find.text('2 Item Obat'), findsOneWidget);

    // "Tidak Perlu Obat" hides the picker; the dispensed medicine stays shown.
    await tester.tap(find.text('Tidak Perlu Obat'));
    await tester.pump();
    expect(find.text('1 Item Obat'), findsOneWidget);
    expect(find.text('Sudah diserahkan farmasi'), findsOneWidget);
    expect(find.text('Tambah obat lainnya'), findsNothing);
    await tester.tap(find.text('Ya, Perlu Obat'));
    await tester.pump();
    expect(find.text('2 Item Obat'), findsOneWidget);
    expect(find.text('Tambah obat lainnya'), findsOneWidget);

    // Let the ICD cache warm-up the modal starts finish.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 30));
  });
}
