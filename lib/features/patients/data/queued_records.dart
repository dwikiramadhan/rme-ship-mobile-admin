import '../../../core/network/api_config.dart';
import '../../../core/offline/outbox_entry.dart';
import '../../../core/offline/sync_service.dart';

/// The patients and visits registered offline that still wait in the outbox,
/// read back in the server's JSON shape so screens can show them before they
/// are sent (the outbox is kept on the device, also across restarts).
class QueuedRecords {
  const QueuedRecords._(this._entries);

  static const empty = QueuedRecords._([]);

  static Future<QueuedRecords> of(SyncService? sync) async {
    if (sync == null) return empty;
    return QueuedRecords._([
      for (final e in await sync.entries())
        if (e.status == OutboxStatus.pending && e.method == 'POST') e,
    ]);
  }

  final List<OutboxEntry> _entries;

  static final _visitPath = RegExp(
    '^${RegExp.escape(ApiConfig.patientsPath)}/([^/]+)/medical-records\$',
  );

  /// New patients by their device-made id: the registration body, which
  /// uses the server's field names.
  Map<String, Map<String, dynamic>> get patients => {
    for (final e in _entries)
      if (e.path == ApiConfig.patientsPath && e.body?['id'] is String)
        e.body!['id'] as String: e.body!,
  };

  /// The visits, as the server lists medical records. Each carries its
  /// patient: a new one from the outbox, an earlier one from [patient];
  /// and its doctor from [doctor] when known.
  List<Map<String, dynamic>> visits({
    Map<String, dynamic>? Function(String patientId)? patient,
    Map<String, dynamic>? Function(String doctorId)? doctor,
  }) {
    final newPatients = patients;
    return [
      for (final e in _entries)
        if (_visitPath.firstMatch(e.path) case final match?)
          _visit(
            e,
            match.group(1)!,
            newPatients[match.group(1)] ?? patient?.call(match.group(1)!),
            doctor?.call(e.body?['doctor_id']?.toString() ?? ''),
          ),
    ];
  }

  /// [patientId]'s visits (see [visits]).
  List<Map<String, dynamic>> visitsOf(String patientId) => [
    for (final v in visits())
      if (v['patient_id'] == patientId) v,
  ];

  static Map<String, dynamic> _visit(
    OutboxEntry entry,
    String patientId,
    Map<String, dynamic>? patient,
    Map<String, dynamic>? doctor,
  ) => {
    ...?entry.body,
    // The entry id stands for the record until the server gives it one.
    'id': entry.id,
    'patient_id': patientId,
    'created_at': entry.createdAt.toUtc().toIso8601String(),
    'patient': ?patient,
    'doctor': ?doctor,
  };
}
