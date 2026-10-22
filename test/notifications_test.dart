import 'package:flutter_test/flutter_test.dart';

import 'package:bayan_rme/features/auth/domain/user_role.dart';
import 'package:bayan_rme/features/notifications/domain/notification_rules.dart';
import 'package:bayan_rme/features/patients/data/patient_api.dart';
import 'package:bayan_rme/features/patients/data/patient_repository.dart';
import 'package:bayan_rme/features/patients/data/seen_notification_storage.dart';
import 'package:bayan_rme/features/patients/domain/medical_history.dart';

final _now = DateTime.utc(2026, 10, 13, 12);

Map<String, dynamic> _visit(
  String id, {
  String patientId = 'p-1',
  String status = 'Menunggu Dokter',
  Duration ago = const Duration(hours: 1),
  bool withLabResult = false,
}) {
  final at = _now.subtract(ago).toIso8601String();
  return {
    'id': id,
    'code': 'RJ-$id',
    'patient_id': patientId,
    'patient': {'id': patientId, 'name': 'Pasien $patientId'},
    'doctor_id': 'personnel-a',
    'status_penanganan': status,
    'created_at': at,
    'updated_at': at,
    if (withLabResult)
      'lab_examinations': [
        {
          'items': [
            {'test_name': 'Darah Rutin', 'result_value': '12'},
          ],
        },
      ],
  };
}

/// Serves [visits] from /medical-history, recording each request.
class _FakePatientApi extends PatientApi {
  _FakePatientApi(this.visits);

  List<Map<String, dynamic>> visits;
  final requests = <({String? status, String? userId})>[];

  @override
  Future<PaginatedMedicalHistory> getMedicalHistoryPaginated({
    int page = 1,
    int limit = 10,
    String? search,
    String? statusPenanganan,
    String? userId,
    bool includePendingPrescriptions = false,
    bool includeReferred = false,
    String sortBy = 'created_at',
    String order = 'desc',
  }) async {
    requests.add((status: statusPenanganan, userId: userId));
    return PaginatedMedicalHistory(
      data: visits.map(MedicalHistory.fromApiJson).toList(),
      page: 1,
      limit: limit,
      total: visits.length,
      totalPages: 1,
    );
  }
}

/// Read marks in memory instead of the device's secure storage.
class _MemorySeenStorage extends SeenNotificationStorage {
  final doctor = <String>{};
  final doctorLab = <String>{};

  @override
  Future<void> load() async {}

  @override
  bool isDoctorSeen(String id) => doctor.contains(id);

  @override
  bool isDoctorLabSeen(String id) => doctorLab.contains(id);

  @override
  Future<void> markDoctorSeen(String id) async => doctor.add(id);

  @override
  Future<void> markDoctorLabSeen(String id) async => doctorLab.add(id);
}

/// A doctor's notifications, once the first load (started on creation)
/// has finished.
Future<NotificationsNotifier> _doctorNotifications(
  _FakePatientApi api, {
  String? userId = 'user-dokter-a',
  _MemorySeenStorage? seen,
}) async {
  final notifier = NotificationsNotifier(
    api: api,
    seenStorage: seen ?? _MemorySeenStorage(),
    currentRole: UserRole.dokter,
    currentUserId: userId,
    clock: () => _now,
  );
  addTearDown(notifier.dispose);
  await pumpEventQueue();
  return notifier;
}

void main() {
  test('a doctor only gets their own waiting visits', () async {
    final api = _FakePatientApi([_visit('mr-1')]);
    final notifier = await _doctorNotifications(api);

    // The backend filters by the signed-in doctor (user id -> personnel).
    expect(api.requests.last, (
      status: 'Menunggu Dokter',
      userId: 'user-dokter-a',
    ));
    expect(notifier.state.map(notificationKey), ['mr-1']);
  });

  test('a doctor without a known id gets nothing, not everyone\'s', () async {
    final api = _FakePatientApi([_visit('mr-1')]);
    final notifier = await _doctorNotifications(api, userId: null);

    expect(notifier.state, isEmpty);
    expect(api.requests, isEmpty);
  });

  test('only visits with activity in the last 24 hours notify', () async {
    final api = _FakePatientApi([
      _visit('mr-new', ago: const Duration(hours: 2)),
      _visit('mr-old', patientId: 'p-2', ago: const Duration(days: 3)),
    ]);
    final notifier = await _doctorNotifications(api);

    expect(notifier.state.map(notificationKey), ['mr-new']);
  });

  test('read marks are per visit: a new visit notifies again', () async {
    final api = _FakePatientApi([_visit('mr-1')]);
    final seen = _MemorySeenStorage();
    final notifier = await _doctorNotifications(api, seen: seen);

    notifier.markDoctorSeen('mr-1');
    expect(notifier.state, isEmpty);

    // Same patient, next visit.
    api.visits = [_visit('mr-1'), _visit('mr-2')];
    await notifier.fetchRecentNotifications();
    expect(notifier.state.map(notificationKey), ['mr-2']);
  });

  test('a visit back from the lab is the lab-result notification', () async {
    final api = _FakePatientApi([_visit('mr-1', withLabResult: true)]);
    final seen = _MemorySeenStorage()..doctor.add('mr-1');
    final notifier = await _doctorNotifications(api, seen: seen);

    // Read as a new patient earlier, but the lab result is news.
    final p = notifier.state.single;
    expect(isLabResultForDoctor(p), isTrue);
    expect(isWaitingForDoctor(p), isFalse);
  });

  test('opening a notification keeps the list in order', () async {
    final api = _FakePatientApi([_visit('mr-2', ago: Duration.zero)]);
    final notifier = await _doctorNotifications(api);

    final list = MedicalHistoryNotifier(api: api, autoFetch: false);
    addTearDown(list.dispose);
    // The same patient's earlier visit is already in the list.
    list.upsertHistory(
      MedicalHistory.fromApiJson(
        _visit('mr-1', status: 'Selesai', ago: const Duration(days: 2)),
      ),
    );

    list.upsertHistory(notifier.recordFor(notifier.state.single)!);

    // Both visits stay, newest first.
    expect(list.state.map((h) => h.id), ['mr-2', 'mr-1']);
  });
}
