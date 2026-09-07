import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:bayan_rme/features/schedule/domain/trip_schedule.dart';
import 'package:bayan_rme/features/schedule/presentation/trip_detail_screen.dart';
import 'package:bayan_rme/features/schedule/presentation/widgets/edit_schedule_modal.dart';

void main() {
  testWidgets('TripDetailScreen renders 4 custom tabs and switches views', (tester) async {
    final schedule = JadwalPerjalanan(
      id: 'sched-1',
      code: 'SCH-2026-001',
      shipCode: 'KPL-001',
      namaKapal: 'KM Nusantara 01',
      shipType: 'Kapal RS',
      pelabuhanAsal: 'Pelabuhan Tanjung Priok',
      kodeAsal: 'TPK',
      pelabuhanTujuan: 'Pelabuhan Sorong',
      kodeTujuan: 'SOQ',
      berangkat: DateTime(2026, 9, 1, 13, 0),
      tiba: DateTime(2026, 9, 16, 14, 0),
      status: 'Ongoing',
      fuelLiters: 1100,
      waterLiters: 2000,
      stops: [
        ScheduleStop(
          id: 'stop-1',
          portCode: 'TPK',
          portName: 'Pelabuhan Tanjung Priok',
          departure: DateTime(2026, 9, 1, 13, 0),
        ),
        ScheduleStop(
          id: 'stop-2',
          portCode: 'TPR',
          portName: 'Pelabuhan Tanjung Perak',
          arrival: DateTime(2026, 9, 9, 12, 0),
          departure: DateTime(2026, 9, 10, 14, 0),
          arrivalTz: 'WITA',
          departureTz: 'WITA',
        ),
        ScheduleStop(
          id: 'stop-3',
          portCode: 'SOQ',
          portName: 'Pelabuhan Sorong',
          arrival: DateTime(2026, 9, 16, 14, 0),
          arrivalTz: 'WIT',
        ),
      ],
      clinics: const [
        ScheduleClinicItem(
          id: 'cl-1',
          poliId: 'p-1',
          poliName: 'Poli Gigi',
          poliCode: 'GIGI',
          openTime: '08:00',
          closeTime: '18:00',
        ),
      ],
      doctorStaff: const [
        SchedulePersonnelItem(
          id: 'doc-1',
          name: 'dr. Andika Pratama',
          specialization: 'DLP, Sp.JP',
          role: 'Dokter Spesialis',
        ),
      ],
      nurseStaff: const [
        SchedulePersonnelItem(
          id: 'nurse-1',
          name: 'Andini Putri Lestari',
          specialization: 'Perawat Umum',
          role: 'Perawat',
        ),
      ],
      crewStaff: const [
        ScheduleCrewItem(
          id: 'crew-1',
          name: 'Herman Yulianto',
          role: 'Mandor',
        ),
        ScheduleCrewItem(
          id: 'crew-2',
          name: 'Dodi Prasetyo',
          role: 'Kelasi',
        ),
      ],
      provisions: [
        ProvisionHistoryItem(
          id: 'prov-1',
          scheduleCode: 'SCH-2026-001',
          fuelOil: 800,
          water: 1800,
          lat: -6.17511,
          lng: 106.827153,
          createdAt: DateTime(2026, 9, 1, 12, 33),
          isLatest: true,
        ),
        ProvisionHistoryItem(
          id: 'prov-2',
          scheduleCode: 'SCH-2026-001',
          fuelOil: 900,
          water: 1900,
          lat: -6.17511,
          lng: 106.827153,
          createdAt: DateTime(2026, 9, 1, 11, 20),
          isLatest: false,
        ),
      ],
      tripIssues: [
        TripIssueItem(
          id: 'issue-1',
          scheduleId: 'sched-1',
          description: 'Badai katrina',
          occurredAt: DateTime(2026, 9, 3, 10, 26),
          lat: -6.20880,
          lng: 106.84560,
        ),
        TripIssueItem(
          id: 'issue-2',
          scheduleId: 'sched-1',
          description: 'Mogok 2 hari di lepas pantai selatan',
          occurredAt: DateTime(2026, 9, 3, 9, 47),
          lat: 6.20880,
          lng: 106.84560,
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: TripDetailScreen(item: schedule),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Tab Bar Items are rendered
    expect(find.text('Info Jadwal'), findsOneWidget);
    expect(find.text('Poli Layanan'), findsOneWidget);
    expect(find.text('Persediaan'), findsOneWidget);
    expect(find.text('Kendala Perjalanan'), findsOneWidget);

    // Tab 1 (Default: Info Jadwal)
    expect(find.text('RUTE PERJALANAN'), findsOneWidget);
    expect(find.text('Pelabuhan Tanjung Priok'), findsOneWidget);
    expect(find.text('Pelabuhan Tanjung Perak'), findsOneWidget);
    expect(find.text('Pelabuhan Sorong'), findsOneWidget);
    expect(find.text('LOGISTIK AWAL JADWAL'), findsOneWidget);
    expect(find.text('BBM AWAL'), findsOneWidget);
    expect(find.text('AIR AWAL'), findsOneWidget);
    expect(find.text('DOKTER BERTUGAS'), findsOneWidget);
    expect(find.text('dr. Andika Pratama'), findsOneWidget);
    expect(find.text('PERAWAT BERTUGAS'), findsOneWidget);
    expect(find.text('Andini Putri Lestari'), findsOneWidget);
    expect(find.text('CREW (ABK KAPAL)'), findsOneWidget);
    expect(find.text('Herman Yulianto'), findsOneWidget);
    expect(find.text('Dodi Prasetyo'), findsOneWidget);

    // Switch to Tab 2: Poli Layanan
    await tester.tap(find.text('Poli Layanan'));
    await tester.pumpAndSettle();

    expect(find.text('Poli Gigi'), findsOneWidget);
    expect(find.text('GIGI'), findsOneWidget);
    expect(find.text('08:00 – 18:00'), findsOneWidget);

    // Switch to Tab 3: Persediaan
    await tester.tap(find.text('Persediaan'));
    await tester.pumpAndSettle();

    expect(find.text('SISA BAHAN BAKAR'), findsOneWidget);
    expect(find.text('SISA AIR BERSIH'), findsNWidgets(2));
    expect(find.text('UPDATE TERAKHIR'), findsOneWidget);
    expect(find.text('Catat Sisa Logistik'), findsOneWidget);
    expect(find.text('RIWAYAT PENCATATAN SISA LOGISTIK'), findsOneWidget);
    expect(find.text('800 Liter'), findsOneWidget);
    expect(find.text('1800 Liter'), findsOneWidget);

    // Switch to Tab 4: Kendala Perjalanan
    await tester.ensureVisible(find.text('Kendala Perjalanan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kendala Perjalanan'));
    await tester.pumpAndSettle();

    expect(find.text('Badai katrina'), findsOneWidget);
    expect(find.text('Mogok 2 hari di lepas pantai selatan'), findsOneWidget);
    expect(find.text('Tambah Kendala'), findsOneWidget);
  });

  testWidgets('Catat Sisa Logistik modal displays correctly with numeric input', (tester) async {
    final schedule = JadwalPerjalanan(
      id: 'sched-1',
      code: 'SCH-2026-001',
      shipCode: 'KPL-001',
      namaKapal: 'KM Nusantara 01',
      shipType: 'Kapal RS',
      pelabuhanAsal: 'Pelabuhan Tanjung Priok',
      kodeAsal: 'TPK',
      pelabuhanTujuan: 'Pelabuhan Sorong',
      kodeTujuan: 'SOQ',
      berangkat: DateTime(2026, 9, 1, 13, 0),
      tiba: DateTime(2026, 9, 16, 14, 0),
      status: 'Ongoing',
      fuelLiters: 1100,
      waterLiters: 2000,
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: TripDetailScreen(item: schedule),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Navigate to Persediaan Tab
    await tester.tap(find.text('Persediaan'));
    await tester.pumpAndSettle();

    // Tap "Catat Sisa Logistik" button
    final catatButton = find.widgetWithText(FilledButton, 'Catat Sisa Logistik');
    expect(catatButton, findsOneWidget);
    await tester.ensureVisible(catatButton);
    await tester.pumpAndSettle();
    await tester.tap(catatButton);
    await tester.pumpAndSettle();

    // Verify modal elements
    expect(find.text('Perbarui sisa stok BBM & air bersih'), findsOneWidget);
    expect(find.text('Sisa Bahan Bakar (BBM)'), findsOneWidget);
    expect(find.text('Sisa Air Bersih'), findsWidgets);
    expect(
      find.descendant(of: find.byType(AlertDialog), matching: find.text('Liter')),
      findsNWidgets(2),
    );
    expect(find.text('Koordinat Posisi (Opsional)'), findsOneWidget);
    expect(find.text('Simpan'), findsOneWidget);

    // Enter numbers into fields
    final textFields = find.byType(TextField);
    expect(textFields, findsNWidgets(4)); // Fuel, Water, Lat, Lng

    await tester.enterText(textFields.at(0), '750.5');
    await tester.enterText(textFields.at(1), '1600');
    await tester.pump();

    expect(find.text('750.5'), findsOneWidget);
    expect(find.text('1600'), findsOneWidget);

    // Close modal
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();
    expect(find.text('Perbarui sisa stok BBM & air bersih'), findsNothing);
  });

  testWidgets('Catat Sisa Logistik validates that input cannot exceed current remaining stock',
      (WidgetTester tester) async {
    final schedule = JadwalPerjalanan(
      id: 'sched-val-1',
      code: 'SCH-VAL-001',
      shipCode: 'KPL-001',
      namaKapal: 'KM Bayan Sehat',
      pelabuhanAsal: 'Tanjung Priok',
      kodeAsal: 'TPR',
      pelabuhanTujuan: 'Sorong',
      kodeTujuan: 'SOQ',
      berangkat: DateTime(2026, 9, 1, 13, 0),
      tiba: DateTime(2026, 9, 16, 14, 0),
      status: 'Ongoing',
      fuelLiters: 1000,
      waterLiters: 2000,
      provisions: [
        ProvisionHistoryItem(
          id: 'prov-1',
          scheduleCode: 'SCH-VAL-001',
          fuelOil: 500, // current remaining fuel: 500 L
          water: 1200, // current remaining water: 1200 L
          createdAt: DateTime(2026, 9, 2, 10, 0),
          isLatest: true,
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: TripDetailScreen(item: schedule),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Navigate to Persediaan
    await tester.tap(find.text('Persediaan'));
    await tester.pumpAndSettle();

    // Open modal
    final catatButton = find.widgetWithText(FilledButton, 'Catat Sisa Logistik');
    await tester.ensureVisible(catatButton);
    await tester.pumpAndSettle();
    await tester.tap(catatButton);
    await tester.pumpAndSettle();

    // Verify info text and current stock badges
    expect(
      find.text('Nilai yang dimasukkan tidak boleh lebih dari sisa logistik saat ini.'),
      findsOneWidget,
    );
    expect(find.text('Saat ini: 500 L'), findsOneWidget);
    expect(find.text('Saat ini: 1200 L'), findsOneWidget);

    final textFields = find.byType(TextField);

    // Enter fuel that EXCEEDS current stock (e.g. 550 > 500)
    await tester.enterText(textFields.at(0), '550');
    await tester.pump();

    // Error should be shown
    expect(
      find.text('Tidak boleh melebihi sisa BBM saat ini (500 L)'),
      findsOneWidget,
    );

    // Save button should be disabled
    final simpanButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Simpan'),
    );
    expect(simpanButton.onPressed, isNull);

    // Fix fuel to valid value (e.g. 450 <= 500)
    await tester.enterText(textFields.at(0), '450');
    await tester.pump();

    // Error should disappear
    expect(
      find.text('Tidak boleh melebihi sisa BBM saat ini (500 L)'),
      findsNothing,
    );

    // Enter water that EXCEEDS current stock (e.g. 1300 > 1200)
    await tester.enterText(textFields.at(1), '1300');
    await tester.pump();

    expect(
      find.text('Tidak boleh melebihi sisa air saat ini (1200 L)'),
      findsOneWidget,
    );

    final simpanButtonAfterWater = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Simpan'),
    );
    expect(simpanButtonAfterWater.onPressed, isNull);

    // Fix water to valid value (e.g. 1100 <= 1200)
    await tester.enterText(textFields.at(1), '1100');
    await tester.pump();

    expect(
      find.text('Tidak boleh melebihi sisa air saat ini (1200 L)'),
      findsNothing,
    );

    final simpanButtonValid = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Simpan'),
    );
    expect(simpanButtonValid.onPressed, isNotNull);

    // Close modal
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();
  });

  testWidgets('Simpan button shows loading state and triggers top-right green toast on success', (tester) async {
    final schedule = JadwalPerjalanan(
      id: 'sched-toast-1',
      code: 'SCH-TOAST-001',
      shipCode: 'KPL-001',
      namaKapal: 'KM Bayan Sehat',
      pelabuhanAsal: 'Tanjung Priok',
      kodeAsal: 'TPR',
      pelabuhanTujuan: 'Sorong',
      kodeTujuan: 'SOQ',
      berangkat: DateTime(2026, 9, 1, 13, 0),
      tiba: DateTime(2026, 9, 16, 14, 0),
      status: 'Ongoing',
      fuelLiters: 1000,
      waterLiters: 2000,
    );

    final fakeRepo = _FakeScheduleRepo(schedule);
    fakeRepo.saveCompleter = Completer<void>();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          scheduleRepositoryProvider.overrideWithValue(fakeRepo),
        ],
        child: MaterialApp(
          home: TripDetailScreen(item: schedule),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Navigate to Persediaan
    await tester.tap(find.text('Persediaan'));
    await tester.pumpAndSettle();

    // Open modal
    final catatButton = find.widgetWithText(FilledButton, 'Catat Sisa Logistik');
    await tester.ensureVisible(catatButton);
    await tester.pumpAndSettle();
    await tester.tap(catatButton);
    await tester.pumpAndSettle();

    // Enter valid fuel and water
    final textFields = find.byType(TextField);
    await tester.enterText(textFields.at(0), '400');
    await tester.enterText(textFields.at(1), '800');
    await tester.pump();

    // Click Simpan
    final simpanButton = find.widgetWithText(FilledButton, 'Simpan');
    expect(simpanButton, findsOneWidget);
    await tester.tap(simpanButton);
    await tester.pump(); // re-render with isSubmitting = true

    // Simpan button should show loading indicator and "Menyimpan..."
    expect(find.text('Menyimpan...'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Complete the save request
    fakeRepo.saveCompleter!.complete();
    await tester.pumpAndSettle();

    // Verify modal is closed
    expect(find.byType(AlertDialog), findsNothing);

    // Verify top-right success toast is shown
    expect(find.text('Sisa logistik berhasil dicatat'), findsOneWidget);
    expect(find.byIcon(LucideIcons.checkCircle2), findsWidgets);

    // Let toast timer elapse and dismiss
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });

  testWidgets('Edit button is inside Info Jadwal and opens EditScheduleModal with form matching mockups', (tester) async {
    final schedule = JadwalPerjalanan(
      id: 'sched-edit-1',
      code: 'SCH-EDIT-001',
      shipCode: 'KPL-001',
      namaKapal: 'KM Bayan Sehat',
      pelabuhanAsal: 'Pelabuhan Tanjung Priok',
      kodeAsal: 'TPK',
      pelabuhanTujuan: 'Pelabuhan Sorong',
      kodeTujuan: 'SOQ',
      berangkat: DateTime(2026, 9, 1, 13, 0),
      tiba: DateTime(2026, 9, 16, 14, 0),
      status: 'Scheduled',
      fuelLiters: 1100,
      waterLiters: 2000,
      stops: [
        ScheduleStop(
          id: 'stop-1',
          portCode: 'TPK',
          portName: 'Pelabuhan Tanjung Priok',
          departure: DateTime(2026, 9, 1, 13, 0),
        ),
        ScheduleStop(
          id: 'stop-2',
          portCode: 'TPR',
          portName: 'Pelabuhan Tanjung Perak',
          arrival: DateTime(2026, 9, 9, 12, 0),
          departure: DateTime(2026, 9, 10, 14, 0),
          arrivalTz: 'WITA',
          departureTz: 'WITA',
        ),
        ScheduleStop(
          id: 'stop-3',
          portCode: 'SOQ',
          portName: 'Pelabuhan Sorong',
          arrival: DateTime(2026, 9, 16, 14, 0),
          arrivalTz: 'WIT',
        ),
      ],
      clinics: const [
        ScheduleClinicItem(
          id: 'cl-1',
          poliId: 'p-1',
          poliName: 'Poli Gigi',
          poliCode: 'GIGI',
          openTime: '08:00',
          closeTime: '18:00',
        ),
        ScheduleClinicItem(
          id: 'cl-2',
          poliId: 'p-2',
          poliName: 'Poli KIA / Anak',
          poliCode: 'KIA',
          openTime: '08:00',
          closeTime: '18:00',
        ),
      ],
      doctorStaff: const [
        SchedulePersonnelItem(
          id: 'doc-1',
          name: 'dr. Andika Pratama',
          role: 'DOKTER',
          specialization: 'Dokter Umum',
        ),
      ],
      nurseStaff: const [
        SchedulePersonnelItem(
          id: 'nurse-1',
          name: 'Andini Putri Lestari',
          role: 'PERAWAT',
          specialization: 'Perawat Umum',
        ),
      ],
      crewStaff: const [
        ScheduleCrewItem(
          id: 'crew-1',
          name: 'Herman Yulianto',
          role: 'Mandor Mesin',
        ),
        ScheduleCrewItem(
          id: 'crew-2',
          name: 'Dodi Prasetyo',
          role: 'Kelasi',
        ),
      ],
    );

    final fakeRepo = _FakeScheduleRepo(schedule);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          scheduleRepositoryProvider.overrideWithValue(fakeRepo),
        ],
        child: MaterialApp(
          home: TripDetailScreen(item: schedule),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Verify AppBar does NOT have the edit button
    expect(
      find.descendant(of: find.byType(AppBar), matching: find.byIcon(LucideIcons.pencilLine)),
      findsNothing,
    );

    // 2. Verify Edit Jadwal button is present inside Info Jadwal (RUTE PERJALANAN card)
    final editJadwalBtn = find.text('Edit Jadwal');
    expect(editJadwalBtn, findsOneWidget);

    // 3. Tap Edit Jadwal button
    await tester.tap(editJadwalBtn);
    await tester.pumpAndSettle();

    // 4. Verify EditScheduleModal content matching all 3 images:
    final modalFinder = find.byType(EditScheduleModal);
    expect(modalFinder, findsOneWidget);

    // Image 3: Status & Route
    expect(find.descendant(of: modalFinder, matching: find.text('STATUS')), findsOneWidget);
    expect(find.descendant(of: modalFinder, matching: find.text('RUTE PELABUHAN')), findsOneWidget);
    expect(find.descendant(of: modalFinder, matching: find.text('Tambah Singgah')), findsOneWidget);

    // Image 2: Doctors, Nurses, Crew, Fuel, Water
    expect(find.descendant(of: modalFinder, matching: find.text('DOKTER BERTUGAS')), findsOneWidget);
    expect(find.descendant(of: modalFinder, matching: find.text('dr. Andika Pratama')), findsWidgets);
    expect(find.descendant(of: modalFinder, matching: find.text('PERAWAT BERTUGAS')), findsOneWidget);
    expect(find.descendant(of: modalFinder, matching: find.text('Andini Putri Lestari')), findsWidgets);
    expect(find.descendant(of: modalFinder, matching: find.text('ABK KAPAL (CREW)')), findsOneWidget);
    expect(find.descendant(of: modalFinder, matching: find.text('Herman Yulianto')), findsWidgets);
    expect(find.descendant(of: modalFinder, matching: find.text('BAHAN BAKAR')), findsOneWidget);
    expect(find.descendant(of: modalFinder, matching: find.text('AIR BERSIH')), findsOneWidget);

    // Clinics section has been removed from EditScheduleModal
    expect(find.descendant(of: modalFinder, matching: find.text('POLI TERSEDIA')), findsNothing);
    expect(find.descendant(of: modalFinder, matching: find.text('Batal')), findsOneWidget);
    expect(find.descendant(of: modalFinder, matching: find.text('Simpan')), findsOneWidget);

    // 5. Tap "Simpan"
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    // Verify modal is dismissed and success toast shown
    expect(find.text('Edit Jadwal Perjalanan'), findsNothing);
    expect(find.text('Jadwal perjalanan berhasil diperbarui'), findsOneWidget);

    // Let toast dismiss
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });

  testWidgets('Edit Poli button in Poli Layanan tab opens EditClinicsModal',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final schedule = createTestSchedule();
    final fakeRepo = _FakeScheduleRepo(schedule);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          scheduleRepositoryProvider.overrideWithValue(fakeRepo),
        ],
        child: MaterialApp(
          home: TripDetailScreen(item: schedule),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Switch to Tab "Poli Layanan"
    await tester.tap(find.text('Poli Layanan'));
    await tester.pumpAndSettle();

    // 2. Verify "Edit Poli" button is rendered
    expect(find.text('DAFTAR POLI LAYANAN'), findsOneWidget);
    final editPoliFinder = find.text('Edit Poli');
    expect(editPoliFinder, findsOneWidget);

    // 3. Tap "Edit Poli" button
    await tester.tap(editPoliFinder);
    await tester.pumpAndSettle();

    // 4. Verify EditClinicsModal is opened
    expect(find.text('Edit Poli Layanan'), findsOneWidget);
    expect(find.text('POLIKLINIK TERSEDIA'), findsOneWidget);
    expect(find.text('Simpan Perubahan'), findsOneWidget);

    // 5. Tap "Simpan Perubahan"
    await tester.tap(find.text('Simpan Perubahan'));
    await tester.pumpAndSettle();

    // Verify modal is dismissed and success toast shown
    expect(find.text('Edit Poli Layanan'), findsNothing);
    expect(find.text('Poli layanan berhasil diperbarui'), findsOneWidget);
  });
}

JadwalPerjalanan createTestSchedule() {
  return JadwalPerjalanan(
    id: 'sched-1',
    code: 'SCH-2026-001',
    shipCode: 'KPL-001',
    namaKapal: 'KM Nusantara 01',
    shipType: 'Kapal RS',
    pelabuhanAsal: 'Pelabuhan Tanjung Priok',
    kodeAsal: 'TPK',
    pelabuhanTujuan: 'Pelabuhan Sorong',
    kodeTujuan: 'SOQ',
    berangkat: DateTime(2026, 9, 1, 13, 0),
    tiba: DateTime(2026, 9, 16, 14, 0),
    status: 'Ongoing',
    fuelLiters: 1100,
    waterLiters: 2000,
    stops: [
      ScheduleStop(
        id: 'stop-1',
        portCode: 'TPK',
        portName: 'Pelabuhan Tanjung Priok',
        departure: DateTime(2026, 9, 1, 13, 0),
      ),
      ScheduleStop(
        id: 'stop-2',
        portCode: 'TPR',
        portName: 'Pelabuhan Tanjung Perak',
        arrival: DateTime(2026, 9, 9, 12, 0),
        departure: DateTime(2026, 9, 10, 14, 0),
        arrivalTz: 'WITA',
        departureTz: 'WITA',
      ),
      ScheduleStop(
        id: 'stop-3',
        portCode: 'SOQ',
        portName: 'Pelabuhan Sorong',
        arrival: DateTime(2026, 9, 16, 14, 0),
        arrivalTz: 'WIT',
      ),
    ],
    clinics: const [
      ScheduleClinicItem(
        id: 'cl-1',
        poliId: 'p-1',
        poliName: 'Poli Gigi',
        poliCode: 'GIGI',
        openTime: '08:00',
        closeTime: '18:00',
      ),
      ScheduleClinicItem(
        id: 'cl-2',
        poliId: 'p-2',
        poliName: 'Poli KIA / Anak',
        poliCode: 'KIA',
        openTime: '08:00',
        closeTime: '18:00',
      ),
    ],
    doctorStaff: const [
      SchedulePersonnelItem(
        id: 'doc-1',
        name: 'dr. Andika Pratama',
        role: 'DOKTER',
        specialization: 'Dokter Umum',
      ),
    ],
    nurseStaff: const [
      SchedulePersonnelItem(
        id: 'nurse-1',
        name: 'Andini Putri Lestari',
        role: 'PERAWAT',
        specialization: 'Perawat Umum',
      ),
    ],
    crewStaff: const [
      ScheduleCrewItem(
        id: 'crew-1',
        name: 'Herman Yulianto',
        role: 'Mandor Mesin',
      ),
    ],
  );
}

class _FakeScheduleRepo extends Fake implements ScheduleRepository {
  Completer<void>? saveCompleter;
  final JadwalPerjalanan schedule;
  Map<String, dynamic>? lastUpdateBody;

  _FakeScheduleRepo(this.schedule);

  @override
  Future<ProvisionHistoryItem> addProvision(Map<String, dynamic> body) async {
    if (saveCompleter != null) {
      await saveCompleter!.future;
    }
    return ProvisionHistoryItem(
      id: 'prov-mock',
      scheduleCode: 'SCH-TOAST-001',
      fuelOil: 400,
      water: 800,
      createdAt: DateTime(2026, 9, 2, 10, 0),
    );
  }

  @override
  Future<JadwalPerjalanan> fetchScheduleById(String id) async {
    return schedule;
  }

  @override
  Future<JadwalPerjalanan> updateSchedule(String id, Map<String, dynamic> body) async {
    lastUpdateBody = body;
    if (saveCompleter != null) {
      await saveCompleter!.future;
    }
    return schedule;
  }
}

