import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/environment_api.dart';
import '../data/environment_storage.dart';
import '../domain/environment_item.dart';

final environmentStorageProvider = Provider<EnvironmentStorage>((ref) {
  return EnvironmentStorage();
});

final environmentApiProvider = Provider<EnvironmentApi>((ref) {
  return EnvironmentApi(
    storage: ref.watch(environmentStorageProvider),
  );
});

class EnvironmentController
    extends StateNotifier<AsyncValue<EnvironmentItem?>> {
  EnvironmentController(this._api, this._storage)
      : super(const AsyncValue.loading()) {
    init();
  }

  final EnvironmentApi _api;
  final EnvironmentStorage _storage;

  Future<void> init() async {
    // 1. Immediately emit cached data if available for instant display
    final cached = await _storage.read();
    if (cached != null) {
      state = AsyncValue.data(cached);
    }

    // 2. Refresh from backend API
    await refresh();
  }

  Future<void> refresh() async {
    try {
      final env = await _api.fetchFirstEnvironment();
      if (env != null) {
        state = AsyncValue.data(env);
      } else if (state.value == null) {
        state = const AsyncValue.data(null);
      }
    } catch (e, st) {
      if (state.value == null) {
        state = AsyncValue.error(e, st);
      }
    }
  }
}

/// Global provider for the active environment (ship)
final activeEnvironmentProvider = StateNotifierProvider<
    EnvironmentController, AsyncValue<EnvironmentItem?>>((ref) {
  return EnvironmentController(
    ref.watch(environmentApiProvider),
    ref.watch(environmentStorageProvider),
  );
});

/// Convenience provider returning only the active environment code
/// e.g. "KAPAL-01" or null.
final activeEnvironmentCodeProvider = Provider<String?>((ref) {
  return ref.watch(activeEnvironmentProvider).valueOrNull?.code;
});

/// Convenience provider returning only the active environment name
/// e.g. "KM Bayan 01" or null.
final activeEnvironmentNameProvider = Provider<String?>((ref) {
  return ref.watch(activeEnvironmentProvider).valueOrNull?.name;
});

/// Convenience provider returning only the active environment ship_id
/// e.g. "3a7ff982-e187-49f8-a34e-95f775afda61" or null.
final activeEnvironmentShipIdProvider = Provider<String?>((ref) {
  return ref.watch(activeEnvironmentProvider).valueOrNull?.shipId;
});

