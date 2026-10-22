import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bayan_rme/features/auth/domain/user_role.dart';
import 'package:bayan_rme/features/doctor/domain/medicine_item.dart';
import 'package:bayan_rme/features/schedule/domain/trip_schedule.dart';
import 'package:bayan_rme/features/schedule/presentation/widgets/poli_layanan_section.dart';
import 'package:bayan_rme/features/stock_adjustment/data/stock_adjustment_api.dart';
import 'package:bayan_rme/features/stock_adjustment/domain/stock_adjustment.dart';
import 'package:bayan_rme/features/stock_adjustment/presentation/stock_adjustment_form.dart';
import 'package:bayan_rme/features/stock_adjustment/presentation/stock_adjustment_report_view.dart';

// Koordinator: adjusts the ship's medicine stock to what was counted on
// board, with a reason per medicine and the harbor the ship is at.

const _ambroxol = MedicineItem(
  id: 'med-1',
  sku: 'GT-A013',
  name: 'Ambroxol 30 mg',
  category: 'Mukolitik',
  unitOfMeasurement: 'strip',
  stock: 124,
);

JadwalPerjalanan _trip(String status, {String id = 'trip-1', int day = 20}) =>
    JadwalPerjalanan(
      id: id,
      shipCode: 'SHP-01',
      namaKapal: 'KM Bayan Peduli',
      pelabuhanAsal: 'Sorong',
      kodeAsal: 'SOQ',
      pelabuhanTujuan: 'Makassar',
      kodeTujuan: 'MKQ',
      berangkat: DateTime(2026, 10, day),
      tiba: DateTime(2026, 10, day + 5),
      status: status,
    );

const _sorong = ScheduleStop(
  id: 'stop-1',
  portId: 'port-soq',
  portCode: 'IDSOQ',
  portName: 'Pelabuhan Sorong',
);

class _FakeAdjustmentApi extends StockAdjustmentApi {
  final created = <Map<String, dynamic>>[];
  final queries = <Map<String, String>>[];
  List<AdjustmentReportRow> rows = const [];

  @override
  Future<bool> create(Map<String, dynamic> body, {String label = ''}) async {
    created.add(body);
    return false;
  }

  @override
  Future<List<AdjustmentReportRow>> fetchReport(
    Map<String, String> query,
  ) async {
    queries.add(query);
    return rows;
  }
}

void main() {
  test('the Koordinator role is read from the session', () {
    expect(userRoleFromApiValue('Koordinator'), UserRole.koordinator);
    expect(userRoleFromApiValue('coordinator'), UserRole.koordinator);
    expect(UserRole.koordinator.label, 'Koordinator');
  });

  test('every medicine needs its counted stock and a reason', () {
    const line = AdjustmentLine(
      sku: 'GT-A013',
      name: 'Ambroxol 30 mg',
      currentStock: 124,
    );
    expect(adjustmentError([]), 'Pilih minimal 1 obat.');
    expect(adjustmentError([line]), 'Isi stok akhir Ambroxol 30 mg.');
    final counted = line.copyWith(stockAfter: () => 44);
    expect(counted.difference, -80);
    expect(adjustmentError([counted]), contains('Alasan adjustment'));
    expect(
      adjustmentError([counted.copyWith(stockAfter: () => -1, reason: 'x')]),
      contains('tidak boleh negatif'),
    );
    expect(adjustmentError([counted.copyWith(reason: 'Kedaluwarsa')]), isNull);
  });

  test('the request carries the harbor and each medicine', () {
    final body = adjustmentRequestJson(
      shipCode: ' SHP-01 ',
      portId: 'port-soq',
      lines: const [
        AdjustmentLine(
          sku: 'GT-A013',
          name: 'Ambroxol',
          currentStock: 124,
          stockAfter: 44,
          reason: ' Kedaluwarsa ',
        ),
      ],
      createdAt: DateTime.utc(2026, 10, 22, 3),
    );
    expect(body, {
      'ship_code': 'SHP-01',
      'port_id': 'port-soq',
      'client_created_at': '2026-10-22T03:00:00.000Z',
      'items': [
        {'medicine_sku': 'GT-A013', 'stock_after': 44, 'reason': 'Kedaluwarsa'},
      ],
    });
    // Not on a trip: no harbor.
    expect(
      adjustmentRequestJson(shipCode: 'SHP-01', portId: '', lines: const []),
      isNot(contains('port_id')),
    );
  });

  test('report rows and filter', () {
    final row = AdjustmentReportRow.fromJson({
      'no': 1,
      'code': 'ADJ22102026-00001',
      'date': '2026-10-22T10:00:00+07:00',
      'product': '[GT-A013] Ambroxol 30 mg',
      'uom': 'strip',
      'stock_before': 124,
      'stock_after': 44,
      'difference': -80,
      'reason': 'Kedaluwarsa',
      'port': 'Pelabuhan Sorong',
      'user': 'Koordinator 1',
    });
    expect(row.difference, -80);
    expect(row.date, isNotNull);
    expect(signedDifference(row.difference), '-80');
    expect(signedDifference(4), '+4');
    expect(
      adjustmentReportQuery(
        shipCode: 'SHP-01',
        from: DateTime(2026, 10),
        to: DateTime(2026, 10, 22),
      ),
      {
        'ship_code': 'SHP-01',
        'date_from': '2026-10-01',
        'date_to': '2026-10-22',
      },
    );
    expect(
      StockAdjustmentApi.reportDownloadPath(AdjustmentReportFormat.xlsx, {
        'ship_code': 'SHP-01',
      }),
      '/api/v1/stock-adjustments/report/download?format=xlsx&ship_code=SHP-01',
    );
  });

  testWidgets('the form checks each medicine and sends the adjustment', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final api = _FakeAdjustmentApi();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          stockAdjustmentApiProvider.overrideWithValue(api),
          ongoingTripProvider.overrideWith((ref) async => _trip('Ongoing')),
          currentPortProvider.overrideWith((ref) async => _sorong),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: StockAdjustmentForm(pickMedicine: (_, _) async => _ambroxol),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Pelabuhan Sorong'), findsOneWidget);

    await tester.tap(find.text('Tambah Obat'));
    await tester.pumpAndSettle();
    expect(find.text('[GT-A013] Ambroxol 30 mg'), findsOneWidget);
    expect(find.text('Sisa stok: 124 strip'), findsOneWidget);

    // Picking it again doesn't add a second row.
    await tester.tap(find.text('Tambah Obat'));
    await tester.pumpAndSettle();
    expect(find.text('[GT-A013] Ambroxol 30 mg'), findsOneWidget);

    await tester.tap(find.text('Simpan Adjustment'));
    await tester.pump();
    expect(find.text('Isi stok akhir Ambroxol 30 mg.'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Stok Akhir'), '44');
    await tester.pump();
    expect(find.text('Selisih: -80'), findsOneWidget);
    await tester.tap(find.text('Simpan Adjustment'));
    await tester.pump();
    expect(
      find.text('Alasan adjustment Ambroxol 30 mg wajib diisi.'),
      findsOneWidget,
    );
    expect(api.created, isEmpty);

    await tester.enterText(
      find.widgetWithText(TextField, 'Alasan'),
      'Kedaluwarsa',
    );
    await tester.tap(find.text('Simpan Adjustment'));
    await tester.pumpAndSettle();

    expect(api.created, hasLength(1));
    final body = api.created.single;
    expect(body['ship_code'], 'SHP-01');
    expect(body['port_id'], 'port-soq');
    expect(body['items'], [
      {'medicine_sku': 'GT-A013', 'stock_after': 44, 'reason': 'Kedaluwarsa'},
    ]);
    expect(find.text('Adjustment stok berhasil disimpan.'), findsOneWidget);
    expect(find.text('[GT-A013] Ambroxol 30 mg'), findsNothing);
  });

  testWidgets('the report lists each medicine of the month so far', (
    tester,
  ) async {
    final api = _FakeAdjustmentApi()
      ..rows = [
        AdjustmentReportRow.fromJson({
          'no': 1,
          'code': 'ADJ22102026-00001',
          'product': '[GT-A013] Ambroxol 30 mg',
          'uom': 'strip',
          'stock_before': 124,
          'stock_after': 44,
          'reason': 'Kedaluwarsa',
          'port': 'Pelabuhan Sorong',
          'user': 'Koordinator 1',
        }),
      ];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [stockAdjustmentApiProvider.overrideWithValue(api)],
        child: MaterialApp(
          home: Scaffold(
            body: StockAdjustmentReportView(
              shipCode: 'SHP-01',
              today: DateTime(2026, 10, 22),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(api.queries.single, {
      'ship_code': 'SHP-01',
      'date_from': '2026-10-01',
      'date_to': '2026-10-22',
    });
    expect(find.text('[GT-A013] Ambroxol 30 mg'), findsOneWidget);
    expect(find.text('-80'), findsOneWidget);
    expect(find.text('Alasan: Kedaluwarsa'), findsOneWidget);
    expect(find.text('Unduh PDF'), findsOneWidget);
    expect(find.text('Unduh Excel'), findsOneWidget);
  });

  testWidgets('no adjustment without an ongoing trip assigned', (tester) async {
    final api = _FakeAdjustmentApi();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          stockAdjustmentApiProvider.overrideWithValue(api),
          ongoingTripProvider.overrideWith((ref) async => null),
          currentPortProvider.overrideWith((ref) async => null),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: StockAdjustmentForm(pickMedicine: (_, _) async => _ambroxol),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(notOnOngoingTripMessage), findsOneWidget);
    await tester.tap(find.text('Tambah Obat'));
    await tester.tap(find.text('Simpan Adjustment'));
    await tester.pumpAndSettle();
    expect(find.text('[GT-A013] Ambroxol 30 mg'), findsNothing);
    expect(api.created, isEmpty);
  });

  testWidgets('the report is of the ship of the assigned trip', (tester) async {
    Future<void> pump(JadwalPerjalanan? trip, _FakeAdjustmentApi api) async {
      await tester.pumpWidget(
        ProviderScope(
          key: UniqueKey(),
          overrides: [
            stockAdjustmentApiProvider.overrideWithValue(api),
            assignedTripProvider.overrideWith((ref) async => trip),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: StockAdjustmentReportView(today: DateTime(2026, 10, 22)),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    final api = _FakeAdjustmentApi();
    await pump(_trip('Completed'), api);
    expect(api.queries.single['ship_code'], 'SHP-01');

    final none = _FakeAdjustmentApi();
    await pump(null, none);
    expect(none.queries, isEmpty);
    expect(
      find.text('Anda belum ditugaskan di jadwal perjalanan mana pun.'),
      findsOneWidget,
    );
  });

  test('the Koordinator works on the ongoing trip, else the next one', () {
    final done = _trip('Completed', id: 'done', day: 1);
    final later = _trip('Scheduled', id: 'later', day: 28);
    final next = _trip('Scheduled', id: 'next', day: 24);
    final ongoing = _trip('Ongoing', id: 'ongoing');

    expect(currentAssignedTrip([later, next, done, ongoing])?.id, 'ongoing');
    expect(currentAssignedTrip([later, next, done])?.id, 'next');
    expect(currentAssignedTrip([done])?.id, 'done');
    expect(currentAssignedTrip(const []), isNull);

    expect(ongoing.clinicsEditable, isTrue);
    expect(next.clinicsEditable, isTrue);
    expect(done.clinicsEditable, isFalse);
    expect(_trip('Cancelled').clinicsEditable, isFalse);
  });

  test('the trip lists its coordinators', () {
    final trip = JadwalPerjalanan.fromApiJson(const {
      'id': 'trip-1',
      'code': 'SCH-01',
      'ship_code': 'SHP-01',
      'status': 'Scheduled',
      'coordinators': [
        {
          'id': 'smp-1',
          'medical_personnel_id': 'mp-koor',
          'coordinator_id': 'mp-koor',
          'coordinator': {'id': 'mp-koor', 'name': 'UAT Koordinator'},
        },
      ],
    });
    expect(trip.coordinatorStaff, hasLength(1));
    expect(trip.coordinatorStaff.single.id, 'mp-koor');
    expect(trip.coordinatorStaff.single.name, 'UAT Koordinator');
    expect(trip.coordinatorStaff.single.type, 'Coordinator');
    expect(trip.doctorStaff, isEmpty);
  });

  test('assigned trips come from the logged-in user', () async {
    final container = ProviderContainer(
      overrides: [
        assignedTripsProvider.overrideWith(
          (ref) async => [_trip('Completed', id: 'old'), _trip('Ongoing')],
        ),
      ],
    );
    addTearDown(container.dispose);
    final sub = container.listen(assignedTripProvider, (_, _) {});
    addTearDown(sub.close);
    expect((await container.read(assignedTripProvider.future))?.id, 'trip-1');
  });

  testWidgets('only the Koordinator can change the clinic schedule', (
    tester,
  ) async {
    final trip = _trip('Ongoing');
    var edits = 0;
    Widget section(VoidCallback? onEdit) => MaterialApp(
      home: Scaffold(
        body: PoliLayananSection(
          schedule: trip,
          clinics: const [],
          onEdit: onEdit,
        ),
      ),
    );

    // Perawat: read-only.
    await tester.pumpWidget(section(null));
    expect(find.text('Atur Poli'), findsNothing);
    expect(find.text('Atur Poli Layanan'), findsNothing);

    // Koordinator.
    await tester.pumpWidget(section(() => edits++));
    await tester.tap(find.text('Atur Poli'));
    expect(edits, 1);
  });
}
