import '../domain/app_user.dart';
import '../domain/auth_repository.dart';
import 'auth_api.dart';
import 'session_storage.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({AuthApi? api, SessionStorage? storage})
      : _api = api ?? AuthApi(),
        _storage = storage ?? SessionStorage();

  final AuthApi _api;
  final SessionStorage _storage;

  @override
  Future<AuthSession> login({required String email, required String password, bool rememberMe = true}) async {
    final session = await _api.login(email: email, password: password);
    // A login that succeeded against the API should not be reported as a
    // failure just because on-device storage couldn't persist it.
    try {
      if (rememberMe) {
        await _storage.save(session);
      } else {
        await _storage.clear();
      }
    } catch (_) {
      // Session will simply not survive an app restart this time.
    }
    return session;
  }

  @override
  Future<AuthSession?> restoreSession() => _storage.read();

  @override
  Future<void> logout() => _storage.clear();
}
