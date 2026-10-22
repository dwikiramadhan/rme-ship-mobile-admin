import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/ship_code_helper.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../doctor/data/medicines_api.dart';
import '../../environment/presentation/server_connection_controller.dart';
import '../../patients/data/patient_repository.dart';
import '../../schedule/data/schedule_repository.dart';
import 'master_data_status.dart';
import 'sync_providers.dart';

/// Keeps a recent copy of the master data the forms need offline (the
/// ship's doctors, the harbors, the lab tests, the ship's medicine stock list) on the
/// device: downloaded right after login and again each time the server is
/// reachable again, so the offline cache (`masterDataPaths`) has it even if
/// no form was opened while online.
class MasterDataRefresher {
  MasterDataRefresher(this._ref);

  final Ref _ref;

  /// Downloads every list again. Offline, the copies on the device stay.
  Future<void> refresh() async {
    _ref.invalidate(doctorsProvider);
    _ref.invalidate(portsProvider);
    _ref.invalidate(labTestsProvider);
    // Errors are handled where the lists are shown.
    await Future.wait([
      _ref.read(doctorsProvider.future).then((_) {}, onError: (_) {}),
      _ref.read(portsProvider.future).then((_) {}, onError: (_) {}),
      _ref.read(labTestsProvider.future).then((_) {}, onError: (_) {}),
      _downloadShipStocks(),
    ]);
    _ref.invalidate(masterDataStatusProvider);
  }

  /// After the outbox sent something: the server's stock now includes what
  /// was dispensed or added offline, and those entries left the outbox.
  Future<void> refreshShipStocks() async {
    await _downloadShipStocks();
    _ref.invalidate(masterDataStatusProvider);
  }

  Future<void> _downloadShipStocks() async {
    try {
      final shipCode = await resolveLocalStorageShipCode();
      if (shipCode.isEmpty) return;
      await _ref.read(medicinesApiProvider).downloadShipStocks(shipCode);
    } catch (_) {
      // Offline or no ship yet: the copy on the device (if any) stays.
    }
  }
}

/// Watched by the app root. Its automatic refreshes are off under
/// `flutter test`, where the lists come from each test's overrides.
final masterDataRefresherProvider = Provider<MasterDataRefresher>((ref) {
  final refresher = MasterDataRefresher(ref);
  final isTest = !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');
  if (isTest) return refresher;

  ref.listen<String?>(
    authControllerProvider.select((s) => s.session?.user.id),
    (_, userId) {
      if (userId != null) refresher.refresh();
    },
    fireImmediately: true,
  );
  ref.listen<bool>(serverConnectionProvider, (previous, connected) {
    final loggedIn = ref.read(authControllerProvider).session != null;
    if (connected && previous == false && loggedIn) refresher.refresh();
  });
  final synced = ref
      .watch(syncServiceProvider)
      ?.onSynced
      .listen((_) => refresher.refreshShipStocks());
  ref.onDispose(() => synced?.cancel());
  return refresher;
});
