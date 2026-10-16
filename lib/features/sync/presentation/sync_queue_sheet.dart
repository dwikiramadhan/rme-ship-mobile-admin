import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/offline/outbox_entry.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_helper.dart';
import 'sync_providers.dart';

/// Lists the current user's writes that haven't reached the server yet:
/// waiting ones (sent automatically once online) and ones the server
/// rejected, which can be retried or discarded.
Future<void> showSyncQueueSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    constraints: const BoxConstraints(maxWidth: 720),
    builder: (_) => const SyncQueueSheet(),
  );
}

class SyncQueueSheet extends ConsumerStatefulWidget {
  const SyncQueueSheet({super.key});

  @override
  ConsumerState<SyncQueueSheet> createState() => _SyncQueueSheetState();
}

class _SyncQueueSheetState extends ConsumerState<SyncQueueSheet> {
  List<OutboxEntry> _entries = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final entries = await ref.read(syncServiceProvider)?.entries() ?? const [];
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _loading = false;
    });
  }

  Future<void> _confirmDiscard(OutboxEntry entry) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus data ini?'),
        content: Text(
          '"${entry.label}" belum terkirim ke server dan akan dihapus '
          'dari perangkat. Tindakan ini tidak bisa dibatalkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(syncServiceProvider)?.discard(entry.id);
  }

  @override
  Widget build(BuildContext context) {
    // Reload whenever the outbox changes (sent, failed, retried...).
    ref.listen(syncStatusProvider, (_, _) => _load());
    final syncing =
        ref.watch(syncStatusProvider).valueOrNull?.syncing ?? false;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 8, 10),
            child: Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Data Belum Tersinkron',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.text,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Tersimpan di perangkat; dikirim otomatis saat online.',
                        style: TextStyle(fontSize: 11, color: AppColors.sub),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: syncing
                      ? null
                      : () => ref.read(syncServiceProvider)?.syncNow(),
                  icon: syncing
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(LucideIcons.refreshCw, size: 14),
                  label: Text(syncing ? 'Mengirim...' : 'Kirim sekarang'),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          Flexible(
            child: _loading
                ? const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : _entries.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'Semua data sudah terkirim ke server.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: AppColors.sub),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.all(12),
                    itemCount: _entries.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, i) => _EntryTile(
                      entry: _entries[i],
                      onRetry: () =>
                          ref.read(syncServiceProvider)?.retry(_entries[i].id),
                      onDiscard: () => _confirmDiscard(_entries[i]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({
    required this.entry,
    required this.onRetry,
    required this.onDiscard,
  });

  final OutboxEntry entry;
  final VoidCallback onRetry;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    final failed = entry.status == OutboxStatus.failed;
    final color = failed ? AppColors.red : AppColors.yellow;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: failed ? AppColors.red : AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                failed ? LucideIcons.alertCircle : LucideIcons.clock,
                size: 16,
                color: color,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  entry.label,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text,
                  ),
                ),
              ),
              Text(
                failed ? 'Gagal' : 'Menunggu',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Disimpan ${DateHelper.formatDateTime(entry.createdAt)}',
            style: const TextStyle(fontSize: 10.5, color: AppColors.sub),
          ),
          if (failed && entry.lastError != null) ...[
            const SizedBox(height: 6),
            Text(
              'Ditolak server: ${entry.lastError}',
              style: const TextStyle(fontSize: 11, color: AppColors.red),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: onDiscard,
                  style: TextButton.styleFrom(foregroundColor: AppColors.red),
                  child: const Text('Hapus'),
                ),
                const SizedBox(width: 4),
                TextButton(onPressed: onRetry, child: const Text('Coba lagi')),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
