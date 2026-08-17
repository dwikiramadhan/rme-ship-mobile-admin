import 'app_user.dart';

abstract class AuthRepository {
  /// Attempts login against the real backend. When [rememberMe] is true
  /// (default), the session is persisted so it survives app restarts
  /// (offline-enabled session per spec); otherwise it only lives in memory
  /// for the current app run.
  Future<AuthSession> login({required String email, required String password, bool rememberMe = true});

  /// Reads back a previously persisted session, if any.
  Future<AuthSession?> restoreSession();

  /// Clears the persisted session.
  Future<void> logout();

  /// Changes the current user's password.
  Future<void> changePassword({required String oldPassword, required String newPassword});
}
