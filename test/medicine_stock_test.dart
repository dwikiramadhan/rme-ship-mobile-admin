import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bayan_rme/features/auth/domain/app_user.dart';
import 'package:bayan_rme/features/auth/domain/auth_repository.dart';
import 'package:bayan_rme/features/auth/domain/user_role.dart';
import 'package:bayan_rme/features/auth/presentation/auth_controller.dart';
import 'package:bayan_rme/features/medicine_stock/data/ship_medicine_api.dart';
import 'package:bayan_rme/features/medicine_stock/domain/ship_medicine_history.dart';
import 'package:bayan_rme/features/medicine_stock/domain/ship_medicine_stock.dart';
import 'package:bayan_rme/features/medicine_stock/presentation/medicine_stock_screen.dart';

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository(this.session);
  final AuthSession? session;

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
    bool rememberMe = true,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<AuthSession?> restoreSession() async => session;

  @override
  Future<void> logout() async {}

  @override
  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {}
}

class _FakeShipMedicineApi implements ShipMedicineApi {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<PaginatedShipMedicineStocks> fetchStocks({
    required String shipCode,
    String search = '',
    int page = 1,
    int limit = 15,
  }) async {
    return PaginatedShipMedicineStocks(
      items: [
        ShipMedicineStock(
          shipId: 'ship-1',
          shipCode: shipCode,
          shipName: 'KM Harapan',
          medicineId: 'med-1',
          medicineSku: 'MED-001',
          medicineName: 'Paracetamol 500mg',
          category: 'Analgesik',
          unitOfMeasurement: 'tablet',
          stock: 120,
          minStock: 20,
          lastUpdate: DateTime(2026, 9, 6, 14, 30),
        ),
        ShipMedicineStock(
          shipId: 'ship-1',
          shipCode: shipCode,
          shipName: 'KM Harapan',
          medicineId: 'med-2',
          medicineSku: 'MED-002',
          medicineName: 'Amoxicillin 500mg',
          category: 'Antibiotik',
          unitOfMeasurement: 'kapsul',
          stock: 0,
          minStock: 10,
          lastUpdate: DateTime(2026, 9, 6, 10, 15),
        ),
      ],
      total: 2,
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
    return PaginatedShipMedicineHistories(
      items: [
        ShipMedicineHistory(
          id: 'hist-1',
          shipCode: shipCode ?? 'KM-01',
          shipName: 'KM Harapan',
          medicineSku: 'MED-001',
          medicineName: 'Paracetamol 500mg',
          medicineCategory: 'Analgesik',
          unitOfMeasurement: 'tablet',
          quantity: 100,
          notes: 'Restock mingguan dari depo pusat',
          userName: 'Budi Apoteker',
          createdAt: DateTime(2026, 9, 6, 11, 0),
        ),
      ],
      total: 1,
      page: 1,
      limit: 15,
      totalPages: 1,
    );
  }
}

void main() {
  group('ShipMedicineStock & History domain parsing', () {
    test('ShipMedicineStock.fromJson correctly maps fields and stock status', () {
      final json = {
        'ship_id': 's1',
        'ship_code': 'KM-01',
        'ship_name': 'Kapal Nusantara',
        'medicine_id': 'm1',
        'medicine_sku': 'SKU-101',
        'medicine_name': 'Ibuprofen 400mg',
        'category': 'Antiinflamasi',
        'unit_of_measurement': 'tablet',
        'stock': 50,
        'min_stock': 10,
        'last_update': '2026-09-06T12:00:00Z',
      };

      final stock = ShipMedicineStock.fromJson(json);
      expect(stock.medicineName, 'Ibuprofen 400mg');
      expect(stock.medicineSku, 'SKU-101');
      expect(stock.category, 'Antiinflamasi');
      expect(stock.stock, 50);
      expect(stock.isOutOfStock, false);
      expect(stock.isLowStock, false);
      expect(stock.isAvailable, true);

      final outOfStock = stock.copyWith(stock: 0);
      expect(outOfStock.isOutOfStock, true);
      expect(outOfStock.isAvailable, false);

      final lowStock = stock.copyWith(stock: 5, minStock: 10);
      expect(lowStock.isLowStock, true);
      expect(lowStock.isOutOfStock, false);
    });

    test('ShipMedicineHistory.fromJson correctly maps fields', () {
      final json = {
        'id': 'h1',
        'ship_code': 'KM-01',
        'medicine_sku': 'SKU-101',
        'quantity': 25,
        'notes': 'Penambahan stok darurat',
        'created_at': '2026-09-06T13:30:00Z',
        'medicine': {
          'sku': 'SKU-101',
          'name': 'Ibuprofen 400mg',
          'category': 'Antiinflamasi',
          'unit_of_measurement': 'strip',
        },
        'user': {
          'full_name': 'Dr. Ahmad',
        },
      };

      final history = ShipMedicineHistory.fromJson(json);
      expect(history.medicineName, 'Ibuprofen 400mg');
      expect(history.medicineSku, 'SKU-101');
      expect(history.medicineCategory, 'Antiinflamasi');
      expect(history.unitOfMeasurement, 'strip');
      expect(history.quantity, 25);
      expect(history.notes, 'Penambahan stok darurat');
      expect(history.userName, 'Dr. Ahmad');
    });
  });

  group('MedicineStockScreen widget tests', () {
    testWidgets('renders 2 tabs and displays inventaris & riwayat data', (tester) async {
      final session = AuthSession(
        token: 'fake-token',
        user: const AppUser(
          id: 'u1',
          name: 'Apoteker Joko',
          email: 'joko@bayan.id',
          role: UserRole.pharmacy,
          shipId: 'KM-01',
        ),
      );

      final fakeApi = _FakeShipMedicineApi();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(_FakeAuthRepository(session)),
            shipMedicineApiProvider.overrideWithValue(fakeApi),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: MedicineStockScreen(canManage: true, shipCode: 'KM-01'),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Tab 1 & Tab 2 headers exist
      expect(find.text('Inventaris Obat'), findsAtLeastNWidgets(1));
      expect(find.text('Riwayat Tambah Obat'), findsOneWidget);

      // Verify Tab 1 data
      expect(find.text('Paracetamol 500mg'), findsOneWidget);
      expect(find.text('MED-001'), findsOneWidget);
      expect(find.text('Amoxicillin 500mg'), findsOneWidget);
      expect(find.text('Habis'), findsOneWidget);
      expect(find.text('Tersedia'), findsOneWidget);
      // Verify date is hidden for out-of-stock item ('Habis') and '-' is not rendered
      expect(find.text('-'), findsNothing);

      // Tap Tab 2: Riwayat Tambah Obat
      await tester.tap(find.text('Riwayat Tambah Obat'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify Tab 2 data
      expect(find.text('Restock mingguan dari depo pusat'), findsOneWidget);
      expect(find.text('+100 tablet'), findsOneWidget);
      expect(find.text('Budi Apoteker'), findsOneWidget);
    });
  });
}
