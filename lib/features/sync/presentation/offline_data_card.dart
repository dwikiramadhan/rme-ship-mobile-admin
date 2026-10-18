import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_helper.dart';
import '../../environment/presentation/server_connection_controller.dart';
import 'master_data_refresher.dart';
import 'master_data_status.dart';

/// Profile card: which master data lists are on the device for offline
/// forms, how recent they are, and a button to download them again.
class OfflineDataCard extends ConsumerStatefulWidget {
  const OfflineDataCard({super.key});

  @override
  ConsumerState<OfflineDataCard> createState() => _OfflineDataCardState();
}

class _OfflineDataCardState extends ConsumerState<OfflineDataCard> {
  bool _refreshing = false;

  Future<void> _refresh() async {
    setState(() => _refreshing = true);
    try {
      await ref.read(masterDataRefresherProvider).refresh();
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(masterDataStatusProvider);
    final online = ref.watch(serverConnectionProvider);
    final entries = status.valueOrNull?.entries ?? const <MasterDataEntry>[];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (status.isLoading && entries.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          for (final (i, entry) in entries.indexed) ...[
            if (i > 0)
              const Divider(height: 1, indent: 54, color: AppColors.border),
            _EntryRow(entry: entry),
          ],
          const Divider(height: 1, color: AppColors.border),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    online
                        ? 'Diunduh otomatis saat login dan saat koneksi kembali.'
                        : 'Butuh koneksi internet untuk memperbarui.',
                    style: const TextStyle(fontSize: 10, color: AppColors.sub),
                  ),
                ),
                TextButton.icon(
                  onPressed: online && !_refreshing ? _refresh : null,
                  icon: _refreshing
                      ? const SizedBox(
                          width: 13,
                          height: 13,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(LucideIcons.refreshCw, size: 13),
                  label: Text(
                    _refreshing ? 'Memperbarui...' : 'Perbarui sekarang',
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.entry});

  final MasterDataEntry entry;

  @override
  Widget build(BuildContext context) {
    final updatedAt = entry.updatedAt;
    final (String text, Color color) = switch (entry) {
      _ when updatedAt == null => (
        'Belum tersimpan di perangkat',
        AppColors.red,
      ),
      MasterDataEntry(bundled: true) => (
        'Bawaan aplikasi · data ${DateHelper.formatDate(updatedAt)}',
        AppColors.sub,
      ),
      MasterDataEntry(isStale: true) => (
        'Diperbarui ${DateHelper.formatDateTime(updatedAt)} · perlu diperbarui',
        AppColors.yellow,
      ),
      _ => ('Diperbarui ${DateHelper.formatDateTime(updatedAt)}', AppColors.sub),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.skyLt,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              entry.bundled ? LucideIcons.package : LucideIcons.database,
              size: 17,
              color: AppColors.sky,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(text, style: TextStyle(fontSize: 10.5, color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Under a doctor picker: warns when the doctor list on the device hasn't
/// been downloaded for a while (it may miss a doctor who just joined).
class DoctorsStaleNote extends ConsumerWidget {
  const DoctorsStaleNote({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final doctors = ref.watch(masterDataStatusProvider).valueOrNull?.doctors;
    if (doctors == null || !doctors.isStale) return const SizedBox.shrink();
    final days = DateTime.now().difference(doctors.updatedAt!).inDays;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        'Daftar dokter terakhir diperbarui $days hari lalu. '
        'Sambungkan ke internet untuk memperbaruinya.',
        style: const TextStyle(fontSize: 10, color: AppColors.yellow),
      ),
    );
  }
}
