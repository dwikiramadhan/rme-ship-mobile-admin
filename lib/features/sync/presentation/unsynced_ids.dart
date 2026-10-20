import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_config.dart';
import '../../../core/offline/outbox_entry.dart';
import 'sync_providers.dart';

/// The patients and visits with a change still in the outbox (waiting, or
/// rejected and waiting for the user), marked "Belum sync" in the lists.
class UnsyncedIds {
  const UnsyncedIds({
    this.patients = const {},
    this.visits = const {},
    this.logistics = const {},
  });

  final Set<String> patients;

  /// Medical records, by id (a visit registered offline has its outbox
  /// entry's id until it is sent).
  final Set<String> visits;

  /// A trip's provision records and trip issues, by id (one added offline
  /// has its outbox entry's id until it is sent).
  final Set<String> logistics;

  static const _logisticsPaths = [
    ApiConfig.shipProvisionsHistoryPath,
    ApiConfig.tripIssuesPath,
  ];

  static final _patientPath = RegExp(
    '^${RegExp.escape(ApiConfig.patientsPath)}/([^/]+)',
  );
  static final _visitPath = RegExp(
    '^${RegExp.escape(ApiConfig.patientsPath)}/[^/]+/medical-records(?:/([^/]+))?\$',
  );
  static final _recordActionPath = RegExp(r'/medical-records/([^/]+)/[^/]+$');

  factory UnsyncedIds.of(Iterable<OutboxEntry> entries) {
    final patients = <String>{};
    final visits = <String>{};
    final logistics = <String>{};
    // Every entry still in the outbox, waiting or rejected.
    for (final e in entries) {
      if (_logisticsPaths.contains(e.path)) {
        logistics.add(e.id); // added offline
        continue;
      }
      final base = _logisticsPaths
          .where((path) => e.path.startsWith('$path/'))
          .firstOrNull;
      if (base != null) {
        logistics.add(e.path.substring(base.length + 1)); // edited, deleted
        continue;
      }
      if (e.path == ApiConfig.patientsPath) {
        // A new patient: the id it was registered under.
        if (e.body?['id'] case final String id) patients.add(id);
        continue;
      }
      final patient = _patientPath.firstMatch(e.path)?.group(1);
      if (patient != null && patient != 'upload-photo') patients.add(patient);

      if (_visitPath.firstMatch(e.path) case final match?) {
        // POST: a new visit (the entry id); PATCH: the doctor's exam.
        visits.add(match.group(1) ?? e.id);
      } else if (_recordActionPath.firstMatch(e.path) case final match?) {
        // Dispense, lab results.
        visits.add(match.group(1)!);
      }
    }
    return UnsyncedIds(
      patients: patients,
      visits: visits,
      logistics: logistics,
    );
  }
}

class UnsyncedIdsNotifier extends AsyncNotifier<UnsyncedIds> {
  @override
  Future<UnsyncedIds> build() async {
    // Counted again whenever the outbox changes.
    ref.watch(syncStatusProvider);
    final sync = ref.watch(syncServiceProvider);
    if (sync == null) return const UnsyncedIds();
    return UnsyncedIds.of(await sync.entries());
  }
}

final unsyncedIdsProvider =
    AsyncNotifierProvider<UnsyncedIdsNotifier, UnsyncedIds>(
      UnsyncedIdsNotifier.new,
    );
