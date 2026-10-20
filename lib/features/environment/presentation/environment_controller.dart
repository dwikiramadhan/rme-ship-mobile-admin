import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_controller.dart';
import '../data/environment_api.dart';
import '../data/environment_storage.dart';
import '../domain/environment_item.dart';

final environmentStorageProvider = Provider<EnvironmentStorage>((ref) {
  return EnvironmentStorage();
});

final environmentApiProvider = Provider<EnvironmentApi>((ref) {
  return EnvironmentApi(storage: ref.watch(environmentStorageProvider));
});

class EnvironmentController
    extends StateNotifier<AsyncValue<EnvironmentItem?>> {
  EnvironmentController(
    this._api,
    this._storage, {
    this._shipId,
    this._withoutShip = false,
  }) : super(const AsyncValue.loading()) {
    init();
  }

  final EnvironmentApi _api;
  final EnvironmentStorage _storage;

  /// The logged-in user's ship: only its environment is shown.
  final String? _shipId;

  /// The logged-in user is not set to any ship: no environment is shown.
  final bool _withoutShip;

  Future<void> init() async {
    if (_withoutShip) {
      state = const AsyncValue.data(null);
      // Another user's ship, saved on this device, is not used either.
      await _storage.clear();
      return;
    }

    // 1. Immediately emit cached data if available for instant display
    final cached = await _api.cached(_shipId);
    if (cached != null) {
      state = AsyncValue.data(cached);
    }

    // 2. Refresh from backend API
    await refresh();
  }

  Future<void> refresh() async {
    if (_withoutShip) return;
    try {
      final env = await _api.fetchFirstEnvironment(shipId: _shipId);
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

/// Global provider for the active environment (ship): the logged-in user's
/// ship, loaded again when another user logs in. None for a user who is not
/// set to any ship.
final activeEnvironmentProvider =
    StateNotifierProvider<EnvironmentController, AsyncValue<EnvironmentItem?>>((
      ref,
    ) {
      final (:loggedIn, :shipId) = ref.watch(
        authControllerProvider.select(
          (s) => (loggedIn: s.isAuthenticated, shipId: s.session?.user.shipId),
        ),
      );
      return EnvironmentController(
        ref.watch(environmentApiProvider),
        ref.watch(environmentStorageProvider),
        shipId: shipId,
        withoutShip: loggedIn && (shipId == null || shipId.isEmpty),
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
