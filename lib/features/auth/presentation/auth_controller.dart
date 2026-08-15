import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/auth_repository_impl.dart';
import '../domain/auth_repository.dart';
import 'auth_state.dart';

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._repository) : super(const AuthState.unknown()) {
    _restore();
  }

  final AuthRepository _repository;

  Future<void> _restore() async {
    try {
      final session = await _repository.restoreSession();
      state = session != null ? AuthState.authenticated(session) : const AuthState.unauthenticated();
    } catch (_) {
      // Secure storage unavailable/corrupt (e.g. first launch, platform not
      // ready) — fall back to a clean sign-in rather than getting stuck.
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

  Future<void> logout() async {
    try {
      await _repository.logout();
    } catch (_) {
      // Best-effort clear — still drop the in-memory session below.
    }
    state = const AuthState.unauthenticated();
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepositoryImpl());

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(ref.watch(authRepositoryProvider));
});
