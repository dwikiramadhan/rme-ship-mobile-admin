import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bayan_rme/features/doctor/data/medicines_api.dart';
import 'package:bayan_rme/features/doctor/domain/medicine_item.dart';
import 'package:bayan_rme/features/medicine_stock/data/ship_medicine_api.dart';
import 'package:bayan_rme/features/medicine_stock/domain/ship_medicine_history.dart';
import 'package:bayan_rme/features/medicine_stock/domain/ship_medicine_stock.dart';
import 'package:bayan_rme/features/medicine_stock/presentation/medicine_stock_screen.dart';

/// Records added stock; lists are empty, counting how often they load.
class _FakeShipMedicineApi implements ShipMedicineApi {
  final added = <Map<String, Object>>[];
  int stockLoads = 0;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<void> addStock({
    required String shipCode,
    required String medicineId,
    required int quantity,
    String notes = '',
  }) async {
    added.add({
      'shipCode': shipCode,
      'medicineId': medicineId,
      'quantity': quantity,
      'notes': notes,
    });
  }

  @override
  Future<PaginatedShipMedicineStocks> fetchStocks({
    required String shipCode,
    String search = '',
    int page = 1,
    int limit = 15,
  }) async {
    stockLoads++;
    return const PaginatedShipMedicineStocks(
      items: [],
      total: 0,
      page: 1,
      limit: 15,
      totalPages: 1,
    );
  }

  @override
  Future<PaginatedShipMedicineHistories> fetchHistories({
    String? shipCode,
    String search = '',
    int page = 1,
    int limit = 15,
  }) async {
    return const PaginatedShipMedicineHistories(
      items: [],
      total: 0,
      page: 1,
      limit: 15,
      totalPages: 1,
    );
  }
}

/// The master medicine list the picker searches.
class _FakeMedicinesApi extends MedicinesApi {
  String? lastShipCode = 'not called';

  @override
  Future<PaginatedMedicines> fetchMedicines({
    String? shipCode,
    String query = '',
    int page = 1,
    int limit = 10,
  }) async {
    lastShipCode = shipCode;
    return const PaginatedMedicines(
      data: [
        MedicineItem(
          id: 'med-7',
          sku: 'CFX-500',
          name: 'Cefadroxil 500mg',
          category: 'Antibiotik',
          unitOfMeasurement: 'Kapsul',
        ),
      ],
      total: 1,
      page: 1,
      limit: 10,
      totalPages: 1,
    );
  }
}

Future<void> _pumpScreen(
  WidgetTester tester, {
  required bool canManage,
  _FakeShipMedicineApi? stockApi,
  _FakeMedicinesApi? medicinesApi,
}) async {
  tester.view.physicalSize = const Size(900, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        shipMedicineApiProvider.overrideWithValue(
          stockApi ?? _FakeShipMedicineApi(),
        ),
        medicinesApiProvider.overrideWithValue(
          medicinesApi ?? _FakeMedicinesApi(),
        ),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: MedicineStockScreen(canManage: canManage, shipCode: 'KM-01'),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  testWidgets('only the pharmacist can add stock', (tester) async {
    await _pumpScreen(tester, canManage: false);
    expect(find.byTooltip('Tambah Stok'), findsNothing);

    await _pumpScreen(tester, canManage: true);
    expect(find.byTooltip('Tambah Stok'), findsOneWidget);
  });

  testWidgets('needs a medicine and a quantity above 0', (tester) async {
    final stockApi = _FakeShipMedicineApi();
    await _pumpScreen(tester, canManage: true, stockApi: stockApi);

    await tester.tap(find.byTooltip('Tambah Stok'));
    await tester.pumpAndSettle();
    expect(find.text('Tambah Stok Obat'), findsOneWidget);

    await tester.tap(find.widgetWithText(InkWell, 'Tambah Stok').last);
    await tester.pump();
    expect(find.text('Silakan pilih obat terlebih dahulu.'), findsOneWidget);

    await tester.tap(find.text('Pilih obat...'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cefadroxil 500mg'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(InkWell, 'Tambah Stok').last);
    await tester.pump();
    expect(find.text('Jumlah stok harus lebih besar dari 0.'), findsOneWidget);
    expect(stockApi.added, isEmpty);
  });

  testWidgets('adds stock for the chosen medicine and reloads the list', (
    tester,
  ) async {
    final stockApi = _FakeShipMedicineApi();
    final medicinesApi = _FakeMedicinesApi();
    await _pumpScreen(
      tester,
      canManage: true,
      stockApi: stockApi,
      medicinesApi: medicinesApi,
    );
    final loadsBefore = stockApi.stockLoads;

    await tester.tap(find.byTooltip('Tambah Stok'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pilih obat...'));
    await tester.pumpAndSettle();
    // Picks from the master list (no ship code), without stock badges.
    expect(medicinesApi.lastShipCode, isNull);
    expect(find.textContaining('Stok:'), findsNothing);
    await tester.tap(find.text('Cefadroxil 500mg'));
    await tester.pumpAndSettle();

    // The quantity label shows the medicine's unit.
    expect(find.textContaining('Jumlah Ditambahkan (Kapsul)'), findsOneWidget);
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(fields.evaluate().length - 2), '24');
    await tester.enterText(fields.last, 'Restock dari depo pusat');

    await tester.tap(find.widgetWithText(InkWell, 'Tambah Stok').last);
    await tester.pumpAndSettle();

    expect(stockApi.added, [
      {
        'shipCode': 'KM-01',
        'medicineId': 'med-7',
        'quantity': 24,
        'notes': 'Restock dari depo pusat',
      },
    ]);
    expect(find.text('Tambah Stok Obat'), findsNothing);
    expect(find.text('Stok obat berhasil ditambahkan'), findsOneWidget);
    expect(stockApi.stockLoads, greaterThan(loadsBefore));
  });
}
