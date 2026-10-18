import 'package:bayan_rme/core/offline/http_cache.dart';
import 'package:bayan_rme/features/doctor/data/medicines_api.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/offline_fakes.dart';

Map<String, dynamic> _stock(String sku, String name, int stock) => {
  'medicine_id': 'id-$sku',
  'medicine_sku': sku,
  'medicine_name': name,
  'category': 'Tablet',
  'unit_of_measurement': 'tab',
  'stock': stock,
};

void main() {
  // The backend's order: most stock first, then by name.
  final shipStocks = [
    _stock('PCT500', 'Paracetamol 500mg', 40),
    _stock('AMX500', 'Amoxicillin 500mg', 12),
    _stock('PCT120', 'Paracetamol Sirup 120mg', 3),
    _stock('OMZ20', 'Omeprazole 20mg', 0),
  ];

  late FakeServerAdapter server;
  late MedicinesApi api;

  setUp(() async {
    server = FakeServerAdapter(
      (r) => r.options.queryParameters['all'] == 'true'
          ? (status: 200, body: {'result': shipStocks})
          : (status: 200, body: {'result': {'data': [], 'total': 0}}),
    );
    final dio = fakeDio(server)
      ..interceptors.add(OfflineCacheInterceptor(InMemoryHttpCache()));
    api = MedicinesApi(dio: dio);
  });

  test('offline: searches the downloaded ship stock list like the backend', () async {
    await api.downloadShipStocks('RSK-1');
    server.handler = (_) => null; // offline

    final byName = await api.fetchMedicines(shipCode: 'RSK-1', query: 'paracetamol');
    expect(byName.data.map((m) => m.sku), ['PCT500', 'PCT120']);
    expect(byName.data.first.stock, 40);
    expect(byName.total, 2);

    final bySku = await api.fetchMedicines(shipCode: 'RSK-1', query: 'amx');
    expect(bySku.data.single.name, 'Amoxicillin 500mg');
  });

  test('offline: pages through the matches', () async {
    await api.downloadShipStocks('RSK-1');
    server.handler = (_) => null;

    final page2 = await api.fetchMedicines(shipCode: 'RSK-1', page: 2, limit: 3);
    expect(page2.data.map((m) => m.sku), ['OMZ20']);
    expect(page2.totalPages, 2);
  });

  test('offline without a downloaded list: empty, no crash', () async {
    server.handler = (_) => null;
    final res = await api.fetchMedicines(shipCode: 'RSK-1', query: 'para');
    expect(res.data, isEmpty);
  });

  test('the stock list is master data, kept across logouts', () {
    expect(isMasterDataKey('/api/v1/ship-medicines/stocks/RSK-1?all=true'), isTrue);
    expect(isMasterDataKey('/api/v1/patients?page=1'), isFalse);
  });
}
