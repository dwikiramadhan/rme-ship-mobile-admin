import 'package:bayan_rme/core/offline/outbox_entry.dart';
import 'package:bayan_rme/core/widgets/list_item_button.dart';
import 'package:bayan_rme/features/sync/presentation/unsynced_ids.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

OutboxEntry _entry(
  String id,
  String method,
  String path, {
  Map<String, dynamic>? body,
  OutboxStatus status = OutboxStatus.pending,
}) => OutboxEntry(
  id: id,
  userId: 'u1',
  method: method,
  path: path,
  label: '',
  createdAt: DateTime(2026, 10, 20),
  body: body,
  status: status,
);

void main() {
  test('marks the patients and visits with a change in the outbox', () {
    final ids = UnsyncedIds.of([
      _entry('e1', 'POST', '/api/v1/patients/upload-photo'),
      _entry('e2', 'POST', '/api/v1/patients', body: {'id': 'local-p'}),
      _entry('e3', 'POST', '/api/v1/patients/local-p/medical-records'),
      _entry('e4', 'PUT', '/api/v1/patients/srv-7'),
      _entry('e5', 'PATCH', '/api/v1/patients/srv-7/medical-records/rec-1'),
      _entry('e6', 'POST', '/api/v1/medical-records/rec-2/dispense'),
      // Rejected by the server: still not on it.
      _entry(
        'e7',
        'POST',
        '/api/v1/medical-records/rec-3/lab-examinations',
        status: OutboxStatus.failed,
      ),
      _entry('e8', 'POST', '/api/v1/ship-medicines'),
    ]);

    expect(ids.patients, {'local-p', 'srv-7'});
    // e3 = the new visit (its entry id), then the exam, dispense, lab.
    expect(ids.visits, {'e3', 'rec-1', 'rec-2', 'rec-3'});
  });

  test("marks a trip's provision records and trip issues", () {
    final ids = UnsyncedIds.of([
      _entry('e1', 'POST', '/api/v1/ship-provisions-history'),
      _entry('e2', 'PUT', '/api/v1/ship-provisions-history/prov-1'),
      _entry('e3', 'POST', '/api/v1/trip-issues'),
      _entry('e4', 'DELETE', '/api/v1/trip-issues/iss-1'),
    ]);

    // Added offline: the entry id (the id the item is shown under).
    expect(ids.logistics, {'e1', 'prov-1', 'e3', 'iss-1'});
    expect(ids.patients, isEmpty);
    expect(ids.visits, isEmpty);
  });

  testWidgets('list items show "Belum sync" only when unsynced', (
    tester,
  ) async {
    Widget item({required bool unsynced}) => MaterialApp(
      home: Scaffold(
        body: ListItemButton(
          active: false,
          onTap: () {},
          avatarColor: Colors.blue,
          avatarBg: Colors.white,
          initial: 'B',
          title: 'Budi',
          subtitle: 'Menunggu Dokter',
          unsynced: unsynced,
        ),
      ),
    );

    await tester.pumpWidget(item(unsynced: true));
    expect(find.text('Belum sync'), findsOneWidget);

    await tester.pumpWidget(item(unsynced: false));
    expect(find.text('Belum sync'), findsNothing);
  });
}
