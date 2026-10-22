import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/domain/user_role.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../environment/presentation/server_connection_controller.dart';
import '../../patients/data/patient_repository.dart';
import '../../patients/domain/medical_history.dart';
import '../../schedule/data/schedule_repository.dart';

/// Keeps the signed-in role's lists in the offline cache, so they open
/// offline even if their screen was never opened while online (each screen
/// only caches what it loaded). Runs right after login, when the server is
/// reachable again, shortly after a real-time event, and every [interval]
/// while online.
///
/// Only the cache is refreshed: lists on screen don't jump back to the top.
class OfflineWarmup {
  OfflineWarmup(this._ref);

  final Ref _ref;
  bool _running = false;

  static const interval = Duration(seconds: 60);

  Future<void> refresh() async {
    final user = _ref.read(authControllerProvider).session?.user;
    if (user == null || _running) return;
    _running = true;
    try {
      await Future.wait([
        for (final task in _tasksFor(user.role, user.id))
          task().catchError((Object e) {
            // Offline or a server error: the copy on the device stays.
            debugPrint('⚠️ [OfflineWarmup] $e');
          }),
      ]);
    } finally {
      _running = false;
    }
  }

  List<Future<void> Function()> _tasksFor(UserRole role, String userId) =>
      switch (role) {
        UserRole.dokter => [
          _notifications,
          () => _history(medicalHistoryByUserProvider(userId)),
          _patients,
        ],
        UserRole.perawat => [
          _patients,
          () => _history(medicalHistoryProvider),
          _schedules,
        ],
        UserRole.pharmacy => [
          _notifications,
          () => _history(pharmacyPrescriptionHistoryProvider),
          _patients,
        ],
        UserRole.lab => [
          _notifications,
          () => _history(labOrderHistoryProvider),
          _patients,
        ],
        UserRole.adminKapal || UserRole.koordinator => [_tripsInProgress],
      };

  Future<void> _notifications() =>
      _ref.read(notificationsProvider.notifier).fetchRecentNotifications();

  /// A list not created yet loads its first page as it is created.
  Future<void> _history(
    StateNotifierProvider<MedicalHistoryNotifier, List<MedicalHistory>> list,
  ) async {
    if (!_ref.exists(list)) {
      _ref.read(list);
      return;
    }
    await _ref.read(list.notifier).warmCache();
  }

  Future<void> _patients() async {
    if (!_ref.exists(patientsProvider)) {
      _ref.read(patientsProvider);
      return;
    }
    await _ref.read(patientsProvider.notifier).warmCache();
  }

  Future<void> _schedules() async {
    await _ref.read(schedulesNotifierProvider.notifier).warmCache();
  }

  /// The schedules, and for each trip under way what its detail screen
  /// loads (the trip, its provisions and trip issues).
  Future<void> _tripsInProgress() async {
    final trips = await _ref
        .read(schedulesNotifierProvider.notifier)
        .warmCache();
    final repository = _ref.read(scheduleRepositoryProvider);
    await Future.wait([
      for (final trip in trips.where((t) => t.isOngoing)) ...[
        repository.fetchScheduleById(trip.id),
        if (trip.code.isNotEmpty) repository.fetchProvisionsHistory(trip.code),
        repository.fetchTripIssues(trip.id),
      ],
    ]);
  }
}

/// Watched by the app root. Off under `flutter test`, where each test sets
/// up its own data.
final offlineWarmupProvider = Provider<OfflineWarmup>((ref) {
  final warmup = OfflineWarmup(ref);
  final isTest = !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');
  if (isTest) return warmup;

  Timer? timer;
  Timer? soon;
  bool online() => ref.read(serverConnectionProvider);

  ref.listen<String?>(
    authControllerProvider.select((s) => s.session?.user.id),
    (_, userId) {
      timer?.cancel();
      if (userId == null) return;
      warmup.refresh();
      timer = Timer.periodic(OfflineWarmup.interval, (_) {
        if (online()) warmup.refresh();
      });
    },
    fireImmediately: true,
  );
  ref.listen<bool>(serverConnectionProvider, (previous, connected) {
    if (connected && previous == false) warmup.refresh();
  });
  // Something changed on the ship: cache the new state once the burst of
  // events is over.
  final events = ref.read(webSocketServiceProvider).onEvent.listen((_) {
    soon?.cancel();
    soon = Timer(const Duration(seconds: 3), warmup.refresh);
  });

  ref.onDispose(() {
    timer?.cancel();
    soon?.cancel();
    events.cancel();
  });
  return warmup;
});
