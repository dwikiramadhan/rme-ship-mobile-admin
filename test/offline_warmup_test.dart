import 'package:bayan_rme/core/network/websocket_service.dart';
import 'package:bayan_rme/features/auth/domain/app_user.dart';
import 'package:bayan_rme/features/auth/domain/auth_repository.dart';
import 'package:bayan_rme/features/auth/domain/user_role.dart';
import 'package:bayan_rme/features/auth/presentation/auth_controller.dart';
import 'package:bayan_rme/features/patients/data/patient_api.dart';
import 'package:bayan_rme/features/patients/data/patient_repository.dart';
import 'package:bayan_rme/features/patients/domain/medical_history.dart';
import 'package:bayan_rme/features/sync/presentation/offline_warmup.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

class _FixedSession implements AuthRepository {
  _FixedSession(this.session);
  final AuthSession session;

  @override
  Future<AuthSession?> restoreSession() async => session;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Records every list request, as the query it would send (= cache key).
class _RecordingApi extends PatientApi {
  final requests = <String>[];

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
    requests.add(
      'history page=$page limit=$limit search=$search '
      'status=$statusPenanganan user=$userId sort=$sortBy order=$order',
    );
    return PaginatedMedicalHistory(
      data: [
        MedicalHistory(
          id: 'rec-${requests.length}',
          code: 'R',
          patientId: 'p',
          patientName: 'Budi',
        ),
      ],
      page: 1,
      limit: limit,
      total: 1,
      totalPages: 1,
    );
  }

  @override
  Future<PaginatedPatients> getPatientsPaginated({
    int page = 1,
    int limit = 10,
    String? search,
    String? status,
  }) async {
    requests.add(
      'patients page=$page limit=$limit search=$search status=$status',
    );
    return PaginatedPatients(
      data: const [],
      page: 1,
      limit: limit,
      total: 0,
      totalPages: 1,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _RecordingApi api;
  late ProviderContainer container;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    api = _RecordingApi();
    container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(
          _FixedSession(
            const AuthSession(
              token: 't',
              user: AppUser(
                id: 'doc-1',
                name: 'dr. Ani',
                email: 'a@b.id',
                role: UserRole.dokter,
              ),
            ),
          ),
        ),
        patientApiProvider.overrideWithValue(api),
        webSocketServiceProvider.overrideWithValue(
          WebSocketService(accessToken: () async => null),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.read(authControllerProvider);
    await pumpEventQueue(); // session restored
  });

  test(
    "doctor: the visit list is cached even if its tab was never opened",
    () async {
      await container.read(offlineWarmupProvider).refresh();
      await pumpEventQueue();

      expect(container.exists(medicalHistoryByUserProvider('doc-1')), isTrue);
      expect(
        api.requests,
        containsAll([
          // The doctor's own visits (Riwayat Kunjungan), as the tab loads them.
          'history page=1 limit=10 search= status=null user=doc-1 sort=created_at order=desc',
          // Waiting patients (Notifikasi).
          contains('status=Menunggu Dokter user=doc-1'),
          'patients page=1 limit=10 search=null status=null',
        ]),
      );
    },
  );

  test('later rounds only refresh the cache, with the same requests', () async {
    final warmup = container.read(offlineWarmupProvider);
    await warmup.refresh();
    await pumpEventQueue();
    final firstRound = [...api.requests];
    final shown = container.read(medicalHistoryByUserProvider('doc-1'));

    api.requests.clear();
    await warmup.refresh();

    // Same cache keys as the screens' first page.
    expect(api.requests.toSet(), firstRound.toSet());
    // The list on screen is left as it is.
    expect(container.read(medicalHistoryByUserProvider('doc-1')), same(shown));
  });
}
