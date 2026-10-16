import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/offline/sync_service.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../environment/presentation/server_connection_controller.dart';

/// The app-wide outbox. Null under `flutter test` (no SQLite plugin there),
/// where writes go straight to the (fake) API as before; tests that cover
/// offline mode override this provider.
final syncServiceProvider = Provider<SyncService?>((ref) {
  final isTest = !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');
  if (isTest) return null;

  final sync = SyncService();
  ref.onDispose(sync.dispose);

  // Back online: send what was queued.
  ref.listen<bool>(serverConnectionProvider, (previous, connected) {
    if (connected && previous != true) sync.syncNow();
  });
  // Each user only sees and sends their own queue.
  ref.listen<String?>(
    authControllerProvider.select((s) => s.session?.user.id),
    (_, _) async {
      await sync.refreshStatus();
      await sync.syncNow();
    },
    fireImmediately: true,
  );
  return sync;
});

final syncStatusProvider = StreamProvider<SyncStatus>((ref) async* {
  final sync = ref.watch(syncServiceProvider);
  if (sync == null) {
    yield const SyncStatus();
    return;
  }
  yield sync.status;
  yield* sync.statusStream;
});
