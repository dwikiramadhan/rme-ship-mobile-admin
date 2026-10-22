import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../features/auth/data/session_storage.dart';
import '../../features/auth/presentation/auth_controller.dart';
import '../../features/environment/data/environment_storage.dart';
import '../../features/environment/presentation/environment_controller.dart';

/// Resolves the active `ship_code` from on-device local storage (FlutterSecureStorage,
/// EnvironmentStorage, SessionStorage) with fallback to memory state.
/// Empty when no ship is set on this device.
Future<String> resolveLocalStorageShipCode([dynamic ref]) async {
  // 1. Direct FlutterSecureStorage keys
  try {
    const storage = FlutterSecureStorage();
    final direct =
        await storage.read(key: 'ship_code') ??
        await storage.read(key: 'shipCode') ??
        await storage.read(key: 'bayan_rme.active_environment_code') ??
        await storage.read(key: 'bayan_rme.active_environment_ship_id') ??
        await storage.read(key: 'bayan_rme.ship_id');
    if (direct != null && direct.trim().isNotEmpty) {
      return direct.trim();
    }
  } catch (_) {}

  // 2. EnvironmentStorage (cached ship environment in local storage)
  try {
    final envStorage = EnvironmentStorage();
    final envCode = await envStorage.getCode();
    if (envCode != null && envCode.trim().isNotEmpty) {
      return envCode.trim();
    }
    final env = await envStorage.read();
    if (env?.code != null && env!.code.trim().isNotEmpty) {
      return env.code.trim();
    }
    final envShipId = await envStorage.getShipId();
    if (envShipId != null && envShipId.trim().isNotEmpty) {
      return envShipId.trim();
    }
  } catch (_) {}

  // 3. SessionStorage (cached user session in local storage)
  try {
    final session = await SessionStorage().read();
    if (session?.user.shipCode != null &&
        session!.user.shipCode!.trim().isNotEmpty) {
      return session.user.shipCode!.trim();
    }
    if (session?.user.shipId != null &&
        session!.user.shipId!.trim().isNotEmpty) {
      return session.user.shipId!.trim();
    }
  } catch (_) {}

  // 4. Memory fallback via activeEnvironmentCodeProvider or authControllerProvider
  if (ref != null) {
    try {
      final activeEnv = ref.read(activeEnvironmentCodeProvider);
      if (activeEnv != null && activeEnv.trim().isNotEmpty) {
        return activeEnv.trim();
      }

      final user = ref.read(authControllerProvider).session?.user;
      if (user?.shipCode != null && user!.shipCode!.trim().isNotEmpty) {
        return user.shipCode!.trim();
      }
      if (user?.shipId != null && user!.shipId!.trim().isNotEmpty) {
        return user.shipId!.trim();
      }
    } catch (_) {}
  }

  return '';
}

/// The active ship's id (a UUID), which the backend requires on every new
/// visit: the logged-in user's ship first, then the ship set on this device.
/// Null when there is none.
Future<String?> resolveActiveShipId(WidgetRef ref) async {
  final sessionShipId = ref.read(authControllerProvider).session?.user.shipId;
  if (sessionShipId != null && sessionShipId.trim().isNotEmpty) {
    return sessionShipId.trim();
  }
  try {
    final stored = await ref.read(environmentStorageProvider).getShipId();
    if (stored != null && stored.trim().isNotEmpty) return stored.trim();
  } catch (_) {}
  final active = ref.read(activeEnvironmentShipIdProvider);
  if (active != null && active.trim().isNotEmpty) return active.trim();
  return null;
}

/// Shown when [resolveActiveShipId] finds no ship.
const String noActiveShipMessage =
    'Kapal aktif belum diatur. Pilih kapal terlebih dahulu.';

/// Riverpod provider for active ship_code from local storage
final localStorageShipCodeProvider = FutureProvider<String>((ref) async {
  return resolveLocalStorageShipCode(ref);
});
