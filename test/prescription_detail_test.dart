import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:bayan_rme/features/doctor/data/icd10_api.dart';
import 'package:bayan_rme/features/doctor/domain/icd10_item.dart';
import 'package:bayan_rme/features/patients/data/patient_repository.dart';
import 'package:bayan_rme/features/patients/domain/medical_history.dart';
import 'package:bayan_rme/features/patients/domain/patient.dart';
import 'package:bayan_rme/features/patients/domain/prescription_item.dart';
import 'package:bayan_rme/features/patients/domain/vitals.dart';
import 'package:bayan_rme/features/pharmacy/presentation/prescription_detail.dart';
import 'package:bayan_rme/features/pharmacy/presentation/prescription_medicine_row.dart';

class _FakePatientsNotifier extends PatientsNotifier {
  _FakePatientsNotifier(List<Patient> initial) : super(autoFetch: false) {
    state = initial;
  }

  String? lastDispensedMedRecId;
  String? lastDispensedPatientId;
  String? lastDispensedById;
  List<ResepItem>? lastDispensedItems;

  final fetchedDetails = <String>[];

  @override
  Future<void> fetchPatientDetail(String id) async => fetchedDetails.add(id);

  @override
  Future<void> dispensePrescription({
    required String medRecId,
    required String patientId,
    required String dispensedById,
    required List<ResepItem> items,
  }) async {
    lastDispensedMedRecId = medRecId;
    lastDispensedPatientId = patientId;
    lastDispensedById = dispensedById;
    lastDispensedItems = items;
    final index = state.indexWhere((p) => p.id == patientId);
    if (index != -1) {
      final updated = state[index].copyWith(
        resepStatus: ResepStatus.selesai,
        statusPenanganan: 'Selesai',
      );
      state = [
        for (int i = 0; i < state.length; i++)
          if (i == index) updated else state[i],
      ];
    }
  }
}

/// Rudi's visit as the pharmacy queue (GET /medical-history) has it.
MedicalHistory _rudiVisit() => MedicalHistory.fromApiJson({
  'id': 'mr-5',
  'code': 'RJ12102026-00005',
  'patient_id': 'p-5',
  'patient': {'id': 'p-5', 'name': 'Rudi Hartono'},
  'status_penanganan': 'Menunggu Obat',
  'diagnosis': 'G43',
  'doctor_id': 'd-1',
  'doctor': {'id': 'd-1', 'name': 'dr. Putri', 'sip': 'SIP-123'},
  'created_by_user': {
    'id': 'u-1',
    'full_name': 'Andini Putri',
    'role': 'Perawat',
  },
  'prescriptions': [
    {
      'name': 'Paracetamol 500mg',
      'dosis': '3x1',
      'instruksi': 'Sesudah makan',
      'qty': '10',
      'unit_of_measurement': 'Tablet',
    },
  ],
});

Future<void> _pumpRudiDetail(
  WidgetTester tester, {
  required _FakePatientsNotifier patients,
  required _FakeMedicalHistoryNotifier queue,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        patientsProvider.overrideWith((ref) => patients),
        pharmacyPrescriptionHistoryProvider.overrideWith((ref) => queue),
        icd10LookupProvider('G43').overrideWith(
          (ref) async => const Icd10Item(code: 'G43', display: 'Migrain'),
        ),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: PrescriptionDetail(patientId: 'p-5', medRecId: 'mr-5'),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  // The diagnosis name (ICD lookup) arrives a frame later.
  await tester.pump();
}

void _expectVisitDetails() {
  expect(find.text('dr. Putri'), findsOneWidget);
  expect(find.text('SIP: SIP-123'), findsOneWidget);
  expect(find.text('Andini Putri'), findsOneWidget);
  expect(find.textContaining('Migrain'), findsOneWidget);
  expect(find.textContaining('Paracetamol 500mg'), findsOneWidget);
}

class _FakeMedicalHistoryNotifier extends MedicalHistoryNotifier {
  _FakeMedicalHistoryNotifier() : super(autoFetch: false);

  @override
  Future<void> fetchHistory({bool refresh = false}) async {}
}

void main() {
  testWidgets('PrescriptionMedicineRow renders layout matching screenshot', (
    tester,
  ) async {
    const item = ResepItem(
      obat: 'Cairan D 40% 25 Ml',
      dosis: '3x1',
      instruksi: 'Sesudah makan',
      sku: 'GT-C009',
      jumlah: '1',
      satuan: 'Tablet',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PrescriptionMedicineRow(
            item: item,
            disabled: false,
            onGanti: (_, _) {},
          ),
        ),
      ),
    );

    // Verify index badge #1
    expect(find.text('#1'), findsOneWidget);

    // Verify medicine name and SKU
    expect(find.textContaining('Cairan D 40% 25 Ml'), findsOneWidget);
    expect(find.textContaining('(GT-C009)'), findsOneWidget);

    // Verify Dosis and Aturan formatted
    expect(find.textContaining('Dosis:'), findsOneWidget);
    expect(find.textContaining('3×1'), findsOneWidget);
    expect(find.textContaining('Aturan:'), findsOneWidget);
    expect(find.textContaining('Sesudah makan'), findsOneWidget);

    // Verify quantity badge
    expect(find.text('1 Tablet'), findsOneWidget);

    // Verify Edit button with pencil icon
    expect(find.text('Ubah'), findsOneWidget);
    expect(find.byIcon(LucideIcons.pencil), findsOneWidget);
  });

  testWidgets('PrescriptionMedicineRow renders unit_of_measurement properly', (
    tester,
  ) async {
    final item = ResepItem.fromJson(const {
      'name': 'Amoxicillin 500mg',
      'dosis': '3x1',
      'instruksi': 'Sesudah makan',
      'qty': '2',
      'unit_of_measurement': 'Kapsul',
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PrescriptionMedicineRow(
            item: item,
            disabled: false,
            onGanti: (_, _) {},
          ),
        ),
      ),
    );

    expect(find.text('2 Kapsul'), findsOneWidget);
  });

  testWidgets(
    'PrescriptionMedicineRow shows replacement form matching Form Input Rekam Medis without Obat Utama',
    (tester) async {
      const item = ResepItem(
        obat: 'Amoxicillin 500mg',
        dosis: '3x1',
        instruksi: 'Sesudah makan',
        jumlah: '10',
        satuan: 'Tablet',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PrescriptionMedicineRow(
              item: item,
              disabled: false,
              onGanti: (_, _) {},
            ),
          ),
        ),
      );

      // Tap 'Ubah' to open replacement form
      await tester.tap(find.text('Ubah'));
      await tester.pumpAndSettle();

      // Verify 'Obat Utama' text is NOT present
      expect(find.text('Obat Utama'), findsNothing);

      // Verify circle index badge #1
      expect(find.text('1'), findsWidgets);

      // Verify fields
      expect(find.text('Nama Obat'), findsOneWidget);
      expect(find.text('Dosis'), findsOneWidget);
      expect(find.text('Aturan Pakai'), findsOneWidget);
      expect(find.text('Alasan Penggantian'), findsOneWidget);
      expect(find.text('Simpan'), findsOneWidget);
      expect(find.byIcon(LucideIcons.minus), findsOneWidget);
      expect(find.byIcon(LucideIcons.plus), findsOneWidget);
    },
  );

  testWidgets(
    'PrescriptionMedicineRow renders - when dosis, instruksi, and qty are empty',
    (tester) async {
      const item = ResepItem(
        obat: 'Paracetamol',
        dosis: '',
        instruksi: '',
        sku: '',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PrescriptionMedicineRow(
              item: item,
              disabled: false,
              onGanti: (_, _) {},
            ),
          ),
        ),
      );

      expect(find.textContaining('Dosis: -'), findsOneWidget);
      expect(find.textContaining('Aturan: -'), findsOneWidget);
      expect(find.text('-'), findsWidgets);
    },
  );

  testWidgets('PrescriptionDetail displays updated header and diagnosa', (
    tester,
  ) async {
    final patient = Patient(
      id: 'p-1',
      nama: 'Budi Santoso',
      nik: '1234567890123456',
      jk: Gender.l,
      umur: 35,
      alamat: 'Balikpapan',
      keluhanUtama: 'Demam tinggi',
      durasiKeluhan: '2 hari',
      lokasiKeluhan: 'Seluruh tubuh',
      vitals: const Vitals(),
      assignedDokterId: 'd-1',
      waktuMasuk: '2026-09-06T10:00:00Z',
      updatedAt: DateTime(2026, 9, 6),
      diagnosa: 'Gastroenteritis (A09)',
      tindakan: 'Injeksi antibiotik (99.21)',
      resep: const [
        ResepItem(
          obat: 'Cairan D 40% 25 Ml (GT-C009)',
          dosis: '3x1',
          instruksi: 'Sesudah makan',
          jumlah: '1',
          satuan: 'Tablet',
        ),
      ],
      resepStatus: ResepStatus.baru,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          patientsProvider.overrideWith(
            (ref) => _FakePatientsNotifier([patient]),
          ),
          icd10LookupProvider('A09').overrideWith(
            (ref) => Future.value(
              const Icd10Item(code: 'A09', display: 'Gastroenteritis'),
            ),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PrescriptionDetail(patientId: 'p-1'),
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify header title
    expect(
      find.text('Rincian Obat (Dapat Disesuaikan / Diganti)'),
      findsOneWidget,
    );

    // Diagnosis and procedure each as one plain sentence.
    expect(find.text('Diagnosa Klinis'), findsOneWidget);
    expect(find.text('Gastroenteritis (A09)'), findsOneWidget);
    expect(find.text('Tindakan / Prosedur (ICD-9-CM)'), findsOneWidget);
    expect(find.text('Injeksi antibiotik (99.21)'), findsOneWidget);
  });

  testWidgets(
    'PrescriptionDetail resolves raw ICD-10 code to display name and code',
    (tester) async {
      final patient = Patient(
        id: 'p-2',
        nama: 'Siti Rahma',
        nik: '1234567890123457',
        jk: Gender.p,
        umur: 28,
        alamat: 'Samarinda',
        keluhanUtama: 'Sakit perut',
        durasiKeluhan: '1 hari',
        lokasiKeluhan: 'Perut',
        vitals: const Vitals(),
        assignedDokterId: 'd-1',
        waktuMasuk: '2026-09-06T11:00:00Z',
        updatedAt: DateTime(2026, 9, 6),
        diagnosa: 'A09',
        resep: const [
          ResepItem(
            obat: 'Cairan D 40% 25 Ml',
            dosis: '1x1',
            instruksi: 'Sesudah makan',
            sku: 'GT-C009',
          ),
        ],
        resepStatus: ResepStatus.baru,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            patientsProvider.overrideWith(
              (ref) => _FakePatientsNotifier([patient]),
            ),
            icd10LookupProvider('A09').overrideWith(
              (ref) => Future.value(
                const Icd10Item(code: 'A09', display: 'Gastroenteritis'),
              ),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: PrescriptionDetail(patientId: 'p-2'),
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      expect(find.text('Diagnosa Klinis'), findsOneWidget);
      expect(find.text('Gastroenteritis (A09)'), findsOneWidget);
    },
  );

  testWidgets(
    'PrescriptionDetail invokes dispensePrescription when marking selesai',
    (tester) async {
      final patient = Patient(
        id: 'p-3',
        nama: 'Ahmad Fauzi',
        nik: '1234567890123458',
        jk: Gender.l,
        umur: 40,
        alamat: 'Balikpapan',
        keluhanUtama: 'Batuk pilek',
        durasiKeluhan: '3 hari',
        lokasiKeluhan: 'Tenggorokan',
        vitals: const Vitals(),
        assignedDokterId: 'd-1',
        waktuMasuk: '2026-09-06T12:00:00Z',
        updatedAt: DateTime(2026, 9, 6),
        medicalRecordId: 'med-rec-uuid-123',
        resep: const [
          ResepItem(
            id: 'rx-uuid-1',
            obat: 'Paracetamol 500mg',
            sku: 'SKU-PCM',
            dosis: '3x1',
            instruksi: 'Sesudah makan',
            jumlah: '10',
            satuan: 'Tablet',
          ),
        ],
        resepStatus: ResepStatus.diproses,
      );

      final fakeNotifier = _FakePatientsNotifier([patient]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            patientsProvider.overrideWith((ref) => fakeNotifier),
            pharmacyPrescriptionHistoryProvider.overrideWith(
              (ref) => _FakeMedicalHistoryNotifier(),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: PrescriptionDetail(
                  patientId: 'p-3',
                  medRecId: 'med-rec-uuid-123',
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final button = find.text('Tandai Selesai & Serahkan Obat');
      expect(button, findsOneWidget);
      await tester.tap(button);
      await tester.pumpAndSettle();

      expect(find.text('Konfirmasi Penyerahan Obat'), findsOneWidget);
      // Compact dialog, not stretched by the long question (720 before;
      // the wide test font makes the title look wider than on a device).
      final dialogBox = find
          .descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(Material),
          )
          .first;
      expect(tester.getSize(dialogBox).width, lessThan(500));
      final confirmBtn = find.text('Ya, Serahkan');
      expect(confirmBtn, findsOneWidget);
      await tester.tap(confirmBtn);
      await tester.pump();

      expect(fakeNotifier.lastDispensedMedRecId, 'med-rec-uuid-123');
      expect(fakeNotifier.lastDispensedPatientId, 'p-3');
      expect(fakeNotifier.lastDispensedItems?.length, 1);
      expect(fakeNotifier.lastDispensedItems?.first.id, 'rx-uuid-1');
      expect(fakeNotifier.lastDispensedItems?.first.sku, 'SKU-PCM');
    },
  );

  testWidgets(
    'PrescriptionDetail displays Selesai banner when status_penanganan is Selesai',
    (tester) async {
      final patient = Patient(
        id: 'p-4',
        nama: 'Siti Aminah',
        nik: '1234567890123459',
        jk: Gender.p,
        umur: 28,
        alamat: 'Balikpapan',
        keluhanUtama: 'Demam',
        durasiKeluhan: '1 hari',
        lokasiKeluhan: 'Kepala',
        vitals: const Vitals(),
        assignedDokterId: 'd-1',
        waktuMasuk: '2026-09-06T12:00:00Z',
        updatedAt: DateTime(2026, 9, 6),
        statusPenanganan: 'Selesai',
        resep: const [
          ResepItem(
            id: 'rx-uuid-2',
            obat: 'Amoxicillin 500mg',
            sku: 'SKU-AMX',
            dosis: '3x1',
            instruksi: 'Sesudah makan',
            jumlah: '10',
            satuan: 'Kapsul',
          ),
        ],
      );

      final fakeNotifier = _FakePatientsNotifier([patient]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            patientsProvider.overrideWith((ref) => fakeNotifier),
            pharmacyPrescriptionHistoryProvider.overrideWith(
              (ref) => _FakeMedicalHistoryNotifier(),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: PrescriptionDetail(patientId: 'p-4'),
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Tandai Selesai & Serahkan Obat'), findsNothing);
      expect(
        find.text('Obat telah selesai diserahkan ke pasien'),
        findsOneWidget,
      );
    },
  );
  testWidgets(
    'PrescriptionDetail shows the drugs from the queue item without a tap',
    (tester) async {
      // As on a tablet: the first queue entry is opened automatically, the
      // patient store only has the patient (no drugs) and the detail fetch
      // doesn't bring them either.
      final patient = Patient(
        id: 'p-5',
        nama: 'Rudi Hartono',
        nik: '1234567890123460',
        jk: Gender.l,
        umur: 45,
        alamat: 'Balikpapan',
        keluhanUtama: 'Pusing',
        durasiKeluhan: '1 hari',
        lokasiKeluhan: 'Kepala',
        vitals: const Vitals(),
        assignedDokterId: 'd-1',
        waktuMasuk: '2026-10-12T08:00:00Z',
        updatedAt: DateTime(2026, 10, 12),
      );
      final queue = _FakeMedicalHistoryNotifier()..upsertHistory(_rudiVisit());

      final patients = _FakePatientsNotifier([patient]);
      await _pumpRudiDetail(tester, patients: patients, queue: queue);

      expect(find.text('1 Item Obat'), findsOneWidget);
      expect(find.textContaining('Paracetamol 500mg'), findsOneWidget);
      // Doctor and nurse of the visit.
      expect(find.text('Dokter Pemeriksa'), findsOneWidget);
      expect(find.text('dr. Putri'), findsOneWidget);
      expect(find.text('SIP: SIP-123'), findsOneWidget);
      expect(find.text('Perawat'), findsOneWidget);
      expect(find.text('Andini Putri'), findsOneWidget);
      // No letter spacing on this page, also for text using theme defaults.
      for (final text in ['Dokter Pemeriksa', 'Andini Putri', '1 Item Obat']) {
        final rendered = tester.widget<RichText>(
          find.descendant(of: find.text(text), matching: find.byType(RichText)),
        );
        expect(rendered.text.style?.letterSpacing, 0, reason: text);
      }
      // Everything came with the queue item: no patient/records requests.
      expect(patients.fetchedDetails, isEmpty);
    },
  );

  testWidgets(
    'PrescriptionDetail fetches the patient when the visit is not in the queue',
    (tester) async {
      final patients = _FakePatientsNotifier([]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            patientsProvider.overrideWith((ref) => patients),
            pharmacyPrescriptionHistoryProvider.overrideWith(
              (ref) => _FakeMedicalHistoryNotifier(),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: PrescriptionDetail(patientId: 'p-6', medRecId: 'mr-6'),
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(patients.fetchedDetails, ['p-6']);
    },
  );

  testWidgets(
    'PrescriptionDetail keeps its details when the patient list refreshes',
    (tester) async {
      final patients = _FakePatientsNotifier([]);
      final queue = _FakeMedicalHistoryNotifier()..upsertHistory(_rudiVisit());
      await _pumpRudiDetail(tester, patients: patients, queue: queue);
      _expectVisitDetails();

      // A refresh replaces the list with page 1 of /patients: other patients,
      // or this one without doctor, diagnosis or visit.
      patients.state = [
        Patient(
          id: 'p-5',
          nama: 'Rudi Hartono',
          nik: '',
          jk: Gender.l,
          umur: 45,
          alamat: '',
          keluhanUtama: '',
          durasiKeluhan: '',
          lokasiKeluhan: '',
          vitals: const Vitals(),
          assignedDokterId: '',
          waktuMasuk: '',
          updatedAt: DateTime(2026, 10, 12),
        ),
      ];
      await tester.pump();
      _expectVisitDetails();

      patients.state = [];
      await tester.pump();
      _expectVisitDetails();
    },
  );

  testWidgets(
    'PrescriptionDetail fills in the visit when the queue loads after opening',
    (tester) async {
      final patients = _FakePatientsNotifier([]);
      final queue = _FakeMedicalHistoryNotifier();
      await _pumpRudiDetail(tester, patients: patients, queue: queue);
      expect(find.text('dr. Putri'), findsNothing);

      queue.upsertHistory(_rudiVisit());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      _expectVisitDetails();
    },
  );
}
