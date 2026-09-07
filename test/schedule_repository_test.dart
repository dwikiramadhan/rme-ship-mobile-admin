import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bayan_rme/features/schedule/data/schedule_api.dart';
import 'package:bayan_rme/features/schedule/data/schedule_repository.dart';

void main() {
  group('ScheduleApi & ScheduleRepository Tests', () {
    test('ScheduleApi parses schedule list response correctly with ship_code and pagination query params', () async {
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            expect(options.path, contains('/api/v1/schedules/ship/KPL-001'));
            expect(options.queryParameters['page'], 1);
            expect(options.queryParameters['limit'], 10);
            return handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'success': true,
                  'result': [
                    {
                      'id': 'SCH-001',
                      'ship_id': 'SHIP-123',
                      'ship_code': 'KPL-001',
                      'ship_name': 'KM Nusantara 01',
                      'ship_type': 'Cargo Ship',
                      'origin_port_name': 'Pelabuhan Tanjung Priok',
                      'destination_port_name': 'Pelabuhan Tanjung Perak',
                      'origin_port_code': 'TPK',
                      'destination_port_code': 'TPR',
                      'doctor_name': 'dr. Budi Santoso',
                      'departure_time': '2026-09-08T08:00:00Z',
                      'arrival_time': '2026-09-10T12:00:00Z',
                      'status': 'Ongoing',
                    }
                  ],
                },
              ),
            );
          },
        ),
      );

      final api = ScheduleApi(dio: dio);
      final repo = ScheduleRepository(api);

      final schedules = await repo.fetchSchedules(
        shipCode: 'KPL-001',
        page: 1,
        limit: 10,
      );

      expect(schedules.length, 1);
      final item = schedules.first;
      expect(item.id, 'SCH-001');
      expect(item.shipCode, 'KPL-001');
      expect(item.namaKapal, 'KM Nusantara 01');
      expect(item.pelabuhanAsal, 'Pelabuhan Tanjung Priok');
      expect(item.pelabuhanTujuan, 'Pelabuhan Tanjung Perak');
      expect(item.namaDokter, 'dr. Budi Santoso');
      expect(item.isOngoing, isTrue);
    });

    test('ScheduleApi sends search and status filter query parameters to server-side endpoint', () async {
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            expect(options.path, contains('/api/v1/schedules/ship/KPL-001'));
            expect(options.queryParameters['page'], 2);
            expect(options.queryParameters['limit'], 10);
            expect(options.queryParameters['search'], 'Nusantara');
            expect(options.queryParameters['status'], 'Ongoing');
            return handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'success': true,
                  'total': 25,
                  'result': [
                    {
                      'id': 'SCH-002',
                      'ship_code': 'KPL-001',
                      'ship_name': 'KM Nusantara 02',
                      'origin_port_name': 'Pelabuhan Merak',
                      'destination_port_name': 'Pelabuhan Bakauheni',
                      'doctor_name': 'dr. Siti Aminah',
                      'status': 'Ongoing',
                    }
                  ],
                },
              ),
            );
          },
        ),
      );

      final api = ScheduleApi(dio: dio);
      final repo = ScheduleRepository(api);

      final result = await repo.fetchPaginatedSchedules(
        shipCode: 'KPL-001',
        page: 2,
        limit: 10,
        search: 'Nusantara',
        status: 'Ongoing',
      );

      expect(result.items.length, 1);
      expect(result.total, 25);
      expect(result.page, 2);
      expect(result.hasMore, isTrue);
      expect(result.items.first.namaKapal, 'KM Nusantara 02');
      expect(result.items.first.namaDokter, 'dr. Siti Aminah');
    });
  });
}
