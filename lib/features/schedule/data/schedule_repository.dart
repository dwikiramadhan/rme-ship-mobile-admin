import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_controller.dart';
import '../domain/trip_schedule.dart';
import 'schedule_api.dart';

class ScheduleRepository {
  ScheduleRepository(this._api);

  final ScheduleApi _api;

  /// Fetches schedules directly from API
  Future<List<JadwalPerjalanan>> fetchSchedules({
    String? shipId,
  }) async {
    try {
      if (shipId != null && shipId.isNotEmpty) {
        return await _api.getSchedulesByShipId(shipId);
      }
      return await _api.getSchedules();
    } catch (e) {
      debugPrint('ScheduleRepository fetchSchedules error: $e');
      rethrow;
    }
  }

  /// Fetches schedule by ID directly from API
  Future<JadwalPerjalanan> fetchScheduleById(String id) async {
    try {
      return await _api.getScheduleById(id);
    } catch (e) {
      debugPrint('ScheduleRepository fetchScheduleById error: $e');
      rethrow;
    }
  }
}

final scheduleApiProvider = Provider<ScheduleApi>((ref) => ScheduleApi());

final scheduleRepositoryProvider = Provider<ScheduleRepository>((ref) {
  final api = ref.watch(scheduleApiProvider);
  return ScheduleRepository(api);
});

class SchedulesNotifier
    extends StateNotifier<AsyncValue<List<JadwalPerjalanan>>> {
  SchedulesNotifier(this._repository, this._ref)
      : super(const AsyncValue.loading()) {
    load();
  }

  final ScheduleRepository _repository;
  final Ref _ref;

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final user = _ref.read(authControllerProvider).session?.user;
      final schedules = await _repository.fetchSchedules(
        shipId: user?.shipId,
      );
      state = AsyncValue.data(schedules);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh() async {
    try {
      final user = _ref.read(authControllerProvider).session?.user;
      final schedules = await _repository.fetchSchedules(
        shipId: user?.shipId,
      );
      state = AsyncValue.data(schedules);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final schedulesNotifierProvider = StateNotifierProvider<SchedulesNotifier,
    AsyncValue<List<JadwalPerjalanan>>>((ref) {
  final repository = ref.watch(scheduleRepositoryProvider);
  return SchedulesNotifier(repository, ref);
});

/// Backwards compatible provider providing the list directly
final jadwalPerjalananProvider = Provider<List<JadwalPerjalanan>>((ref) {
  final asyncValue = ref.watch(schedulesNotifierProvider);
  return asyncValue.maybeWhen(
    data: (data) => data,
    orElse: () => const [],
  );
});
