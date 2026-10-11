import 'package:bayan_rme/features/lab/presentation/lab_order_detail.dart';
import 'package:bayan_rme/features/patients/data/patient_repository.dart';
import 'package:bayan_rme/features/patients/domain/medical_history.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

MedicalHistoryNotifier _historyWith(List<MedicalHistory> items) =>
    MedicalHistoryNotifier(autoFetch: false)..state = items;

Future<void> _pumpDetail(
  WidgetTester tester,
  String notes, {
  MedicalHistory? history,
}) async {
  tester.view.physicalSize = const Size(1180, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        doctorsProvider.overrideWith((ref) async => []),
        patientsProvider.overrideWith(
          (ref) => PatientsNotifier(autoFetch: false),
        ),
        medicalHistoryProvider.overrideWith((ref) => _historyWith([])),
        labOrderHistoryProvider.overrideWith(
          (ref) => _historyWith([
            history ??
            MedicalHistory(
              id: 'hist-1',
              code: 'REG-1',
              patientId: 'patient-1',
              patientName: 'Budi Darmawan',
              patientNik: '3171010101900010',
              statusPenanganan: 'Menunggu Lab',
              notes: notes,
              treatment: 'Hematologi Lengkap',
              date: '2026-09-07',
              createdAt: '2026-09-07T08:30:00Z',
            ),
          ]),
        ),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: LabOrderDetail(patientId: 'patient-1', medRecId: 'hist-1'),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('doctor note with triage vitals renders the VitalTile grid', (
    tester,
  ) async {
    await _pumpDetail(
      tester,
      '[Triage] Durasi: 2 hari | Lokasi: Kepala | TD: 120/80 | Nadi: 88 | '
      'Suhu: 36.5 | RR: 20 | SpO2: 98',
    );

    expect(find.text('Catatan Khusus Dokter'), findsOneWidget);
    for (final label in ['TEKANAN DARAH', 'NADI', 'SUHU TUBUH', 'FREK. NAPAS', 'SPO₂']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    for (final value in ['120/80', '88', '36.5', '20', '98']) {
      expect(find.text(value), findsOneWidget, reason: value);
    }
    // Non-vital parts stay as text; the raw "TD:" string is gone.
    expect(find.text('Durasi: 2 hari · Lokasi: Kepala'), findsOneWidget);
    expect(find.textContaining('TD:'), findsNothing);
  });

  testWidgets('doctor note without vitals still renders as plain text', (
    tester,
  ) async {
    await _pumpDetail(tester, 'Pasien puasa 8 jam sebelum pengambilan darah');

    expect(find.text('Pasien puasa 8 jam sebelum pengambilan darah'), findsOneWidget);
    expect(find.text('TEKANAN DARAH'), findsNothing);
  });

  testWidgets('card shows the doctor exam summary from the selected record', (
    tester,
  ) async {
    // Shaped like GET /api/v1/medical-history from rme-ship-hospitality-be.
    final history = MedicalHistory.fromApiJson({
      'id': 'hist-1',
      'code': 'RJ07092026-00001',
      'patient_id': 'patient-1',
      'status_penanganan': 'Menunggu Lab',
      'date': '2026-09-07',
      'created_at': '2026-09-07T08:30:00Z',
      'complaint': 'Demam',
      'diagnosis': 'J06.9',
      'diagnosis_detail': 'Acute upper respiratory infection (J06.9)',
      'diagnoses': [
        {'code': 'J06.9', 'display': 'Acute upper respiratory infection'},
      ],
      'treatment': '89.7',
      'tindakan_detail': 'General physical examination (89.7)',
      'prescriptions': [
        {
          'id': 'rx-1',
          'sku': 'MED-001',
          'medicine': {'sku': 'MED-001', 'name': 'Paracetamol 500mg'},
          'dosage': '3x1',
          'quantity': 10,
          'instructions': 'Sesudah makan',
        },
      ],
      'notes': '[Triage] TD: 120/80 | Nadi: 88',
      'doctor': {'name': 'dr. Budi Santoso'},
    });

    await _pumpDetail(tester, '', history: history);

    expect(find.text('Hasil Pemeriksaan Dokter'), findsOneWidget);
    expect(find.text('DIAGNOSA KLINIS'), findsOneWidget);
    expect(find.text('Acute upper respiratory infection'), findsOneWidget);
    expect(find.text('J06.9'), findsOneWidget);
    expect(find.text('General physical examination'), findsOneWidget);
    // Doctor's special note (with vitals) sits above "Diagnosa Klinis".
    expect(find.text('Catatan Khusus Dokter'), findsOneWidget);
    expect(find.text('120/80'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Catatan Khusus Dokter')).dy,
      lessThan(tester.getTopLeft(find.text('DIAGNOSA KLINIS')).dy),
    );
  });

  testWidgets('waiting lab order shows the visit vitals and is not "selesai"', (tester) async {
    // Shape of a visit the doctor just referred (as returned by the API):
    // vitals are structured fields, the lab note is the doctor's own note,
    // there are no results yet, and a leftover file from another visit.
    final history = MedicalHistory.fromApiJson({
      'id': 'hist-1',
      'code': 'RJ11102026-00005',
      'patient_id': 'patient-1',
      'status_penanganan': 'Menunggu Lab',
      'notes': 'banyak minum',
      'blood_pressure': '123/80',
      'heart_rate': 78,
      'temperature': 36.6,
      'respiratory_rate': 18,
      'oxygen_saturation': 99,
      'attachment_url': 'hasil-kunjungan-lama.pdf',
      'lab_examination': {
        'id': 'lab-1',
        'requested_test': 'Rontgen Thorax',
        'doctor_notes': 'Hemoglobin',
        'attachment_url': '',
      },
    });

    await _pumpDetail(tester, '', history: history);

    // The referral: requested test and the note for the analyst.
    expect(find.text('Permintaan Pemeriksaan Lab'), findsOneWidget);
    expect(find.text('JENIS PEMERIKSAAN'), findsOneWidget);
    expect(find.text('Rontgen Thorax'), findsOneWidget);
    expect(find.text('CATATAN UNTUK ANALIS'), findsOneWidget);
    expect(find.text('Hemoglobin'), findsOneWidget);
    // Vitals stay in their own box (the note isn't repeated there).
    expect(find.text('Tanda Vital Pasien'), findsOneWidget);
    expect(find.text('123/80'), findsOneWidget);
    expect(find.text('78'), findsOneWidget);
    expect(
      find.text('Pemeriksaan Lab telah selesai & hasil telah dikirim ke dokter'),
      findsNothing,
    );
  });
}
