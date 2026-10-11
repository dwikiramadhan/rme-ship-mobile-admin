import 'dart:async';

import 'package:bayan_rme/features/medicine_stock/data/ship_medicine_api.dart';
import 'package:bayan_rme/features/medicine_stock/domain/ship_medicine_stock.dart';
import 'package:bayan_rme/features/medicine_stock/presentation/medicine_stock_controller.dart';
import 'package:flutter_test/flutter_test.dart';

/// Each fetchStocks call waits on its own completer so the test controls the
/// order responses arrive in.
class _ControlledApi implements ShipMedicineApi {
  final pending = <String, Completer<PaginatedShipMedicineStocks>>{};

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<PaginatedShipMedicineStocks> fetchStocks({
    required String shipCode,
    String search = '',
    int page = 1,
    int limit = 15,
  }) {
    return (pending['$search#$page'] = Completer()).future;
  }

  void respond(String search, String medicineName, {int page = 1}) {
    pending['$search#$page']!.complete(
      PaginatedShipMedicineStocks(
        items: [
          ShipMedicineStock(
            shipId: 's',
            shipCode: 'KPL',
            shipName: 'KM',
            medicineId: medicineName,
            medicineSku: medicineName,
            medicineName: medicineName,
            category: '',
            unitOfMeasurement: 'tablet',
            lastUpdate: DateTime(2026),
          ),
        ],
        total: 5,
        page: page,
        limit: 15,
        totalPages: 5,
      ),
    );
  }
}

void main() {
  test('a new search is not dropped while a load is running, and the latest query wins', () async {
    final api = _ControlledApi();
    final notifier = ShipMedicineStockNotifier(api: api, shipCode: 'KPL');
    // Constructor started the initial load (search '') which is still pending.

    notifier.state = notifier.state.copyWith(searchQuery: 'para');
    unawaited(notifier.loadInitial());
    expect(api.pending.containsKey('para#1'), isTrue, reason: 'search must not be dropped');

    // Newer response first, then the stale initial one.
    api.respond('para', 'Paracetamol');
    await Future<void>.delayed(Duration.zero);
    api.respond('', 'Amoxicillin');
    await Future<void>.delayed(Duration.zero);

    expect(notifier.state.items.single.medicineName, 'Paracetamol');
    expect(notifier.state.isLoading, isFalse);
    notifier.dispose();
  });

  test('a loadMore page from an old query is not appended after a new search', () async {
    final api = _ControlledApi();
    final notifier = ShipMedicineStockNotifier(api: api, shipCode: 'KPL');
    api.respond('', 'Amoxicillin');
    await Future<void>.delayed(Duration.zero);

    unawaited(notifier.loadMore()); // page 2 of '' pending
    notifier.state = notifier.state.copyWith(searchQuery: 'para');
    unawaited(notifier.loadInitial());

    api.respond('para', 'Paracetamol');
    await Future<void>.delayed(Duration.zero);
    api.respond('', 'Stale page 2', page: 2);
    await Future<void>.delayed(Duration.zero);

    expect(notifier.state.items.map((e) => e.medicineName), ['Paracetamol']);
    expect(notifier.state.isLoadingMore, isFalse);
    notifier.dispose();
  });
}
