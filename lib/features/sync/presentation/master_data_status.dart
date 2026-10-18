import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_config.dart';
import '../../../core/offline/http_cache.dart';
import '../../../core/utils/ship_code_helper.dart';
import '../../doctor/data/icd_catalog.dart';
import '../../patients/data/region_api.dart';

/// A master data list kept on the device for offline forms.
class MasterDataEntry {
  const MasterDataEntry({
    required this.label,
    required this.updatedAt,
    this.bundled = false,
  });

  final String label;

  /// When the device last downloaded it — or, for [bundled] data, when it
  /// was exported into the app. Null = not on the device yet.
  final DateTime? updatedAt;

  /// Shipped inside the app (updated by an app release, not downloaded).
  final bool bundled;

  /// Downloaded data older than this gets a warning in the forms.
  static const staleAfter = Duration(days: 7);

  bool get isStale =>
      !bundled &&
      updatedAt != null &&
      DateTime.now().difference(updatedAt!) > staleAfter;
}

/// What master data the device holds, and how recent it is.
class MasterDataStatus {
  const MasterDataStatus({required this.doctors, required this.entries});

  final MasterDataEntry doctors;

  /// Every list, in the order shown in the profile.
  final List<MasterDataEntry> entries;
}

final httpCacheStoreProvider = Provider<HttpCacheStore>(
  (ref) => const SqliteHttpCache(),
);

/// The bundled ICD-10 list (its export date stands for both ICD lists).
final icdCatalogProvider = Provider<IcdCatalog>(
  (ref) => IcdCatalog(IcdCatalog.icd10Asset),
);

/// The active ship's code, from device storage; '' when none.
final shipCodeResolverProvider = Provider<Future<String> Function()>(
  (ref) => resolveLocalStorageShipCode,
);

class MasterDataStatusNotifier extends AsyncNotifier<MasterDataStatus> {
  @override
  Future<MasterDataStatus> build() async {
    final cache = ref.watch(httpCacheStoreProvider);
    final wilayah = ref.watch(wilayahApiProvider);

    Future<DateTime?> stored(String path) async {
      try {
        return await cache.lastStoredAt(path);
      } catch (_) {
        return null; // no local database (e.g. under tests)
      }
    }

    final doctors = MasterDataEntry(
      label: 'Dokter',
      updatedAt: await stored(ApiConfig.medicalPersonnelPath),
    );
    final shipCode = await ref.watch(shipCodeResolverProvider)();
    return MasterDataStatus(
      doctors: doctors,
      entries: [
        doctors,
        MasterDataEntry(
          label: 'Pelabuhan',
          updatedAt: await stored(ApiConfig.portsPath),
        ),
        MasterDataEntry(
          label: 'Obat & stok kapal',
          // The full list from MedicinesApi.downloadShipStocks, not searches.
          updatedAt: shipCode.isEmpty
              ? null
              : await stored(
                  '${ApiConfig.shipMedicineStocksPath(shipCode)}?all=true',
                ),
        ),
        MasterDataEntry(
          label: 'Wilayah (provinsi s.d. kelurahan)',
          updatedAt: await wilayah.exportedAt(),
          bundled: true,
        ),
        MasterDataEntry(
          label: 'ICD-10 & ICD-9-CM',
          updatedAt: await ref.watch(icdCatalogProvider).exportedAt(),
          bundled: true,
        ),
      ],
    );
  }
}

final masterDataStatusProvider =
    AsyncNotifierProvider<MasterDataStatusNotifier, MasterDataStatus>(
      MasterDataStatusNotifier.new,
    );
