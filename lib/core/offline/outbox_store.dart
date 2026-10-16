import 'offline_database.dart';
import 'outbox_entry.dart';

/// Persistence for the outbox and its resolved placeholder tokens.
abstract class OutboxStore {
  Future<void> add(OutboxEntry entry);

  /// [userId]'s entries, oldest first (the order they must be sent in).
  Future<List<OutboxEntry>> entries(String userId);
  Future<void> update(OutboxEntry entry);
  Future<void> remove(String id);

  Future<Map<String, String>> tokens();
  Future<void> saveToken(String token, String value);
  Future<void> clearTokens();
}

class SqliteOutboxStore implements OutboxStore {
  const SqliteOutboxStore();

  @override
  Future<void> add(OutboxEntry entry) async {
    final db = await OfflineDatabase.instance;
    await db.insert('outbox', entry.toRow());
  }

  @override
  Future<List<OutboxEntry>> entries(String userId) async {
    final db = await OfflineDatabase.instance;
    // rowid breaks ties between entries queued in the same millisecond
    // (e.g. a patient and their first visit).
    final rows = await db.query(
      'outbox',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at, rowid',
    );
    return rows.map(OutboxEntry.fromRow).toList();
  }

  @override
  Future<void> update(OutboxEntry entry) async {
    final db = await OfflineDatabase.instance;
    await db.update(
      'outbox',
      entry.toRow(),
      where: 'id = ?',
      whereArgs: [entry.id],
    );
  }

  @override
  Future<void> remove(String id) async {
    final db = await OfflineDatabase.instance;
    await db.delete('outbox', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<Map<String, String>> tokens() async {
    final db = await OfflineDatabase.instance;
    final rows = await db.query('outbox_tokens');
    return {
      for (final row in rows) row['token'] as String: row['value'] as String,
    };
  }

  @override
  Future<void> saveToken(String token, String value) async {
    final db = await OfflineDatabase.instance;
    await db.rawInsert(
      'INSERT OR REPLACE INTO outbox_tokens (token, value) VALUES (?, ?)',
      [token, value],
    );
  }

  @override
  Future<void> clearTokens() async {
    final db = await OfflineDatabase.instance;
    await db.delete('outbox_tokens');
  }
}
