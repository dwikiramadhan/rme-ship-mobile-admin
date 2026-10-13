import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bayan_rme/core/utils/ship_code_helper.dart';
import 'package:bayan_rme/features/auth/presentation/auth_controller.dart';
import 'package:bayan_rme/features/auth/presentation/auth_state.dart';
import 'package:bayan_rme/features/environment/presentation/environment_controller.dart';
import 'package:bayan_rme/features/schedule/data/schedule_api.dart';
import 'package:bayan_rme/features/schedule/data/schedule_repository.dart';

/// Counts schedule requests; there should be none without a ship.
class _CountingScheduleRepository extends ScheduleRepository {
  _CountingScheduleRepository() : super(ScheduleApi());

  int calls = 0;

  @override
  Future<SchedulePageResult> fetchPaginatedSchedules({
    String? shipCode,
    String? shipId,
    int page = 1,
    int limit = 10,
    String? search,
    String? status,
  }) async {
    calls++;
    throw StateError('unexpected request for "$shipCode"');
  }

  @override
  Future<ScheduleCounter> fetchScheduleCounter(String shipCode) async {
    calls++;
    throw StateError('unexpected request for "$shipCode"');
  }
}

/// Signed out, without restoring a session from device storage.
class _SignedOutAuthController extends StateNotifier<AuthState>
    implements AuthController {
  _SignedOutAuthController() : super(const AuthState.unauthenticated());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // No ship anywhere: device storage is unavailable in tests, and the
  // active environment is empty.
  ProviderContainer containerWithoutShip(ScheduleRepository repository) {
    final container = ProviderContainer(
      overrides: [
        scheduleRepositoryProvider.overrideWithValue(repository),
        activeEnvironmentCodeProvider.overrideWithValue(null),
        authControllerProvider.overrideWith(
          (ref) => _SignedOutAuthController(),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('no ship: no dummy ship code is made up', () async {
    expect(
      await resolveLocalStorageShipCode(
        containerWithoutShip(_CountingScheduleRepository()),
      ),
      isEmpty,
    );
  });

  test('no ship: the schedule counter is empty, without a request', () async {
    final repository = _CountingScheduleRepository();
    final container = containerWithoutShip(repository);

    final counter = await container.read(scheduleCounterProvider.future);

    expect(counter.total, 0);
    expect(repository.calls, 0);
  });

  test('no ship: the schedule list says so, without a request', () async {
    final repository = _CountingScheduleRepository();
    final container = containerWithoutShip(repository);

    final notifier = container.read(schedulesNotifierProvider.notifier);
    await notifier.load();

    final state = container.read(schedulesNotifierProvider);
    expect(state.hasError, isTrue);
    expect(state.error.toString(), contains(noActiveShipMessage));
    expect(repository.calls, 0);
  });
}
