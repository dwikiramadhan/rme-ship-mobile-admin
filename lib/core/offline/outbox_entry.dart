import 'dart:convert';

enum OutboxStatus {
  /// Waiting to be sent.
  pending,

  /// Rejected by the server (4xx); kept for the user to retry or discard.
  failed,
}

/// One write (POST/PUT/PATCH/DELETE) made while offline, waiting in the
/// outbox to be sent to the server in the order it was made.
///
/// [path] and [body] may contain placeholder tokens (a local patient id, a
/// not-yet-uploaded photo); an earlier entry's [produces] says which value of
/// its response replaces each token once it has been sent.
class OutboxEntry {
  const OutboxEntry({
    required this.id,
    required this.userId,
    required this.method,
    required this.path,
    required this.label,
    required this.createdAt,
    this.body,
    this.files = const {},
    this.produces = const {},
    this.status = OutboxStatus.pending,
    this.attempts = 0,
    this.lastError,
  });

  /// Also sent as the `Idempotency-Key`, so a replay is applied only once.
  final String id;

  /// Only the user who made the change sends it, with their own token.
  final String userId;
  final String method;
  final String path;

  /// JSON body, or the plain form fields of a multipart request.
  final Map<String, dynamic>? body;

  /// Multipart file fields: field name -> local file path. A request with
  /// files is sent as multipart/form-data.
  final Map<String, String> files;

  /// Placeholder token -> dotted path in the response (e.g. `result.id`).
  final Map<String, String> produces;

  /// What the user sees in the sync list, e.g. "Pasien baru: Budi".
  final String label;
  final DateTime createdAt;
  final OutboxStatus status;
  final int attempts;
  final String? lastError;

  OutboxEntry copyWith({
    OutboxStatus? status,
    int? attempts,
    String? lastError,
  }) {
    return OutboxEntry(
      id: id,
      userId: userId,
      method: method,
      path: path,
      label: label,
      createdAt: createdAt,
      body: body,
      files: files,
      produces: produces,
      status: status ?? this.status,
      attempts: attempts ?? this.attempts,
      lastError: lastError ?? this.lastError,
    );
  }

  Map<String, Object?> toRow() => {
        'id': id,
        'user_id': userId,
        'method': method,
        'path': path,
        'body': body == null ? null : jsonEncode(body),
        'files': jsonEncode(files),
        'produces': jsonEncode(produces),
        'label': label,
        'status': status.name,
        'attempts': attempts,
        'last_error': lastError,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  factory OutboxEntry.fromRow(Map<String, Object?> row) {
    final body = row['body'] as String?;
    return OutboxEntry(
      id: row['id'] as String,
      userId: row['user_id'] as String,
      method: row['method'] as String,
      path: row['path'] as String,
      body: body == null ? null : jsonDecode(body) as Map<String, dynamic>,
      files: Map<String, String>.from(
        jsonDecode(row['files'] as String? ?? '{}') as Map,
      ),
      produces: Map<String, String>.from(
        jsonDecode(row['produces'] as String? ?? '{}') as Map,
      ),
      label: row['label'] as String,
      status: OutboxStatus.values.byName(row['status'] as String),
      attempts: row['attempts'] as int? ?? 0,
      lastError: row['last_error'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
    );
  }
}
