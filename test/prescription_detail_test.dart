import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:bayan_rme/features/doctor/data/icd10_api.dart';
import 'package:bayan_rme/features/doctor/domain/icd10_item.dart';
import 'package:bayan_rme/features/patients/data/patient_repository.dart';
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

  @override
  Future<void> fetchPatientDetail(String id) async {}

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

class _FakeMedicalHistoryNotifier extends MedicalHistoryNotifier {
  _FakeMedicalHistoryNotifier() : super(autoFetch: false);

  @override
  Future<void> fetchHistory({bool refresh = false}) async {}
}

void main() {
  testWidgets('PrescriptionMedicineRow renders layout matching screenshot', (
    tester,
  ) async {
    final item = ResepItem(
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
            index: 0,
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

  testWidgets(
      'PrescriptionMedicineRow renders unit_of_measurement properly',
      (tester) async {
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
            index: 0,
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
            index: 0,
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
  });

  testWidgets(
      'PrescriptionMedicineRow renders - when dosis, instruksi, and qty are empty',
      (tester) async {
    const item = ResepItem(
      obat: 'Paracetamol',
      dosis: '',
      instruksi: '',
      sku: '',
      jumlah: null,
      satuan: null,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PrescriptionMedicineRow(
            index: 0,
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
  });

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

    // Verify Diagnosa Klinis display
    expect(find.text('DIAGNOSA KLINIS'), findsOneWidget);
    expect(find.text('Gastroenteritis (A09)'), findsOneWidget);
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

      expect(find.text('DIAGNOSA KLINIS'), findsOneWidget);
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
                child: PrescriptionDetail(
                  patientId: 'p-4',
                ),
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
}
