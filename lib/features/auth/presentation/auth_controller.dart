import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/offline/http_cache.dart';
import '../../../core/routing/app_navigator.dart';
import '../data/auth_repository_impl.dart';
import '../domain/auth_repository.dart';
import 'auth_state.dart';

class AuthController extends StateNotifier<AuthState> {
  // `cache:` is a private named parameter.
  AuthController(this._repository, {this._cache = const SqliteHttpCache()})
      : super(const AuthState.unknown()) {
    DioClient.onUnauthorized = _handleUnauthorized;
    _restore();
  }

  final AuthRepository _repository;
  final HttpCacheStore _cache;

  void _handleUnauthorized() {
    if (state.status == AuthStatus.unauthenticated) return;
    _repository.logout();
    _clearOfflineCache();
    rootNavigatorKey.currentState?.popUntil((route) => route.isFirst);
    state = const AuthState.unauthenticated(
      errorMessage: 'Sesi telah berakhir. Silakan login kembali.',
    );
  }

  Future<void> _restore() async {
    try {
      final session = await _repository.restoreSession();
      state = session != null ? AuthState.authenticated(session) : const AuthState.unauthenticated();
    } catch (_) {
      state = const AuthState.unauthenticated();
    }
  }

  Future<void> login({required String email, required String password, bool rememberMe = true}) async {
    state = const AuthState.authenticating();
    try {
      final session = await _repository.login(email: email, password: password, rememberMe: rememberMe);
      state = AuthState.authenticated(session);
    } catch (e) {
      state = AuthState.unauthenticated(errorMessage: e.toString());
    }
  }

  Future<void> changePassword({required String oldPassword, required String newPassword}) {
    return _repository.changePassword(oldPassword: oldPassword, newPassword: newPassword);
  }

  Future<void> logout() async {
    try {
      await _repository.logout();
    } catch (_) {
      // Best-effort clear.
    }
    _clearOfflineCache();
    rootNavigatorKey.currentState?.popUntil((route) => route.isFirst);
    state = const AuthState.unauthenticated();
  }

  /// The cached GET responses belong to the user who fetched them; the next
  /// one to log in on this device must not see them. Kept: master data
  /// (doctors, harbors) the next user needs offline, and the outbox, whose
  /// entries are sent once their own user logs in again.
  void _clearOfflineCache() {
    unawaited(
      _cache.clearUserData().catchError(
        (Object e) => debugPrint('⚠️ [Auth] offline cache clear failed: $e'),
      ),
    );
  }

  @override
  void dispose() {
    if (DioClient.onUnauthorized == _handleUnauthorized) {
      DioClient.onUnauthorized = null;
    }
    super.dispose();
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepositoryImpl());

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(ref.watch(authRepositoryProvider));
});
