import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../auth/data/session_storage.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../environment/presentation/environment_controller.dart';
import '../data/ship_medicine_api.dart';
import '../domain/ship_medicine_history.dart';
import '../domain/ship_medicine_stock.dart';

/// Reads the active ship_code from local storage.
final localStorageShipCodeProvider = FutureProvider<String>((ref) async {
  // 1. Direct secure storage keys
  try {
    const storage = FlutterSecureStorage();
    final direct = await storage.read(key: 'ship_code') ??
        await storage.read(key: 'shipCode') ??
        await storage.read(key: 'bayan_rme.active_environment_code') ??
        await storage.read(key: 'bayan_rme.active_environment_ship_id') ??
        await storage.read(key: 'bayan_rme.ship_id');
    if (direct != null && direct.trim().isNotEmpty) {
      return direct.trim();
    }
  } catch (_) {}

  // 2. EnvironmentStorage (cached ship environment in local storage)
  try {
    final envStorage = ref.watch(environmentStorageProvider);
    final envCode = await envStorage.getCode();
    if (envCode != null && envCode.trim().isNotEmpty) {
      return envCode.trim();
    }
    final env = await envStorage.read();
    if (env?.code != null && env!.code.trim().isNotEmpty) {
      return env.code.trim();
    }
    final envShipId = await envStorage.getShipId();
    if (envShipId != null && envShipId.trim().isNotEmpty) {
      return envShipId.trim();
    }
  } catch (_) {}

  // 3. SessionStorage (cached user session in local storage)
  try {
    final session = await SessionStorage().read();
    if (session?.user.shipCode != null && session!.user.shipCode!.trim().isNotEmpty) {
      return session.user.shipCode!.trim();
    }
    if (session?.user.shipId != null && session!.user.shipId!.trim().isNotEmpty) {
      return session.user.shipId!.trim();
    }
  } catch (_) {}

  // 4. Memory fallback via activeEnvironmentCodeProvider or authControllerProvider
  final activeEnv = ref.watch(activeEnvironmentCodeProvider);
  if (activeEnv != null && activeEnv.trim().isNotEmpty) {
    return activeEnv.trim();
  }

  final sessionUser = ref.watch(authControllerProvider).session?.user;
  if (sessionUser?.shipCode != null && sessionUser!.shipCode!.trim().isNotEmpty) {
    return sessionUser.shipCode!.trim();
  }
  if (sessionUser?.shipId != null && sessionUser!.shipId!.trim().isNotEmpty) {
    return sessionUser.shipId!.trim();
  }

  return '';
});

// ==========================================
// 1. INVENTARIS OBAT (STOCKS) STATE & NOTIFIER
// ==========================================

class ShipMedicineStockState {
  const ShipMedicineStockState({
    this.items = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.errorMessage,
    this.searchQuery = '',
    this.page = 1,
    this.limit = 30,
    this.total = 0,
    this.hasMore = false,
  });

  final List<ShipMedicineStock> items;
  final bool isLoading;
  final bool isLoadingMore;
  final String? errorMessage;
  final String searchQuery;
  final int page;
  final int limit;
  final int total;
  final bool hasMore;

  ShipMedicineStockState copyWith({
    List<ShipMedicineStock>? items,
    bool? isLoading,
    bool? isLoadingMore,
    String? errorMessage,
    bool clearError = false,
    String? searchQuery,
    int? page,
    int? limit,
    int? total,
    bool? hasMore,
  }) {
    return ShipMedicineStockState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      searchQuery: searchQuery ?? this.searchQuery,
      page: page ?? this.page,
      limit: limit ?? this.limit,
      total: total ?? this.total,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

class ShipMedicineStockNotifier extends StateNotifier<ShipMedicineStockState> {
  ShipMedicineStockNotifier({
    required this.api,
    required this.shipCode,
  }) : super(const ShipMedicineStockState()) {
    if (shipCode.trim().isNotEmpty) {
      loadInitial();
    }
  }

  final ShipMedicineApi api;
  final String shipCode;
  Timer? _debounceTimer;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> loadInitial({bool refresh = false}) async {
    if (shipCode.trim().isEmpty) return;

    if (!refresh) {
      state = state.copyWith(isLoading: true, clearError: true);
    }

    try {
      final res = await api.fetchStocks(
        shipCode: shipCode,
        search: state.searchQuery,
        page: 1,
        limit: state.limit,
      );

      state = state.copyWith(
        items: res.items,
        isLoading: false,
        clearError: true,
        page: 1,
        total: res.total,
        hasMore: res.items.length < res.total && res.items.isNotEmpty,
      );
    } catch (e) {
      debugPrint('Error loadInitial stocks: $e');
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  void onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 400), () {
      if (state.searchQuery == query) return;
      state = state.copyWith(searchQuery: query);
      loadInitial();
    });
  }

  Future<void> loadMore() async {
    if (state.isLoading || state.isLoadingMore || !state.hasMore) return;
    if (shipCode.trim().isEmpty) return;

    state = state.copyWith(isLoadingMore: true);
    final nextPage = state.page + 1;

    try {
      final res = await api.fetchStocks(
        shipCode: shipCode,
        search: state.searchQuery,
        page: nextPage,
        limit: state.limit,
      );

      final newItems = [...state.items, ...res.items];
      state = state.copyWith(
        items: newItems,
        isLoadingMore: false,
        page: nextPage,
        total: res.total,
        hasMore: newItems.length < res.total && res.items.isNotEmpty,
      );
    } catch (e) {
      debugPrint('Error loadMore stocks: $e');
      state = state.copyWith(
        isLoadingMore: false,
      );
    }
  }
}

final shipMedicineStockProvider = StateNotifierProvider.autoDispose
    .family<ShipMedicineStockNotifier, ShipMedicineStockState, String>((ref, shipCode) {
  final api = ref.watch(shipMedicineApiProvider);
  return ShipMedicineStockNotifier(api: api, shipCode: shipCode);
});

// ==========================================
// 2. RIWAYAT TRANSAKSI STATE & NOTIFIER
// ==========================================

class ShipMedicineHistoryState {
  const ShipMedicineHistoryState({
    this.items = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.errorMessage,
    this.searchQuery = '',
    this.page = 1,
    this.limit = 15,
    this.total = 0,
    this.hasMore = false,
  });

  final List<ShipMedicineHistory> items;
  final bool isLoading;
  final bool isLoadingMore;
  final String? errorMessage;
  final String searchQuery;
  final int page;
  final int limit;
  final int total;
  final bool hasMore;

  ShipMedicineHistoryState copyWith({
    List<ShipMedicineHistory>? items,
    bool? isLoading,
    bool? isLoadingMore,
    String? errorMessage,
    bool clearError = false,
    String? searchQuery,
    int? page,
    int? limit,
    int? total,
    bool? hasMore,
  }) {
    return ShipMedicineHistoryState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      searchQuery: searchQuery ?? this.searchQuery,
      page: page ?? this.page,
      limit: limit ?? this.limit,
      total: total ?? this.total,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

class ShipMedicineHistoryNotifier extends StateNotifier<ShipMedicineHistoryState> {
  ShipMedicineHistoryNotifier({
    required this.api,
    required this.shipCode,
  }) : super(const ShipMedicineHistoryState()) {
    loadInitial();
  }

  final ShipMedicineApi api;
  final String shipCode;
  Timer? _debounceTimer;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> loadInitial({bool refresh = false}) async {
    if (!refresh) {
      state = state.copyWith(isLoading: true, clearError: true);
    }

    try {
      final res = await api.fetchHistories(
        shipCode: shipCode.trim().isNotEmpty ? shipCode.trim() : null,
        search: state.searchQuery,
        page: 1,
        limit: state.limit,
      );

      state = state.copyWith(
        items: res.items,
        isLoading: false,
        clearError: true,
        page: 1,
        total: res.total,
        hasMore: res.items.length < res.total,
      );
    } catch (e) {
      debugPrint('Error loadInitial histories: $e');
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  void onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 400), () {
      if (state.searchQuery == query) return;
      state = state.copyWith(searchQuery: query);
      loadInitial();
    });
  }

  Future<void> loadMore() async {
    if (state.isLoading || state.isLoadingMore || !state.hasMore) return;

    state = state.copyWith(isLoadingMore: true);
    final nextPage = state.page + 1;

    try {
      final res = await api.fetchHistories(
        shipCode: shipCode.trim().isNotEmpty ? shipCode.trim() : null,
        search: state.searchQuery,
        page: nextPage,
        limit: state.limit,
      );

      final newItems = [...state.items, ...res.items];
      state = state.copyWith(
        items: newItems,
        isLoadingMore: false,
        page: nextPage,
        total: res.total,
        hasMore: newItems.length < res.total,
      );
    } catch (e) {
      debugPrint('Error loadMore histories: $e');
      state = state.copyWith(
        isLoadingMore: false,
      );
    }
  }
}

final shipMedicineHistoryProvider = StateNotifierProvider.autoDispose
    .family<ShipMedicineHistoryNotifier, ShipMedicineHistoryState, String>((ref, shipCode) {
  final api = ref.watch(shipMedicineApiProvider);
  return ShipMedicineHistoryNotifier(api: api, shipCode: shipCode);
});
