import 'package:bayan_rme/core/offline/http_cache.dart';
import 'package:bayan_rme/features/auth/domain/app_user.dart';
import 'package:bayan_rme/features/auth/domain/auth_repository.dart';
import 'package:bayan_rme/features/auth/domain/user_role.dart';
import 'package:bayan_rme/features/auth/presentation/auth_controller.dart';
import 'package:bayan_rme/features/auth/presentation/auth_state.dart';
import 'package:flutter_test/flutter_test.dart';

// Koordinator works in the web admin only: the app doesn't let them in.

AppUser _user(UserRole role) =>
    AppUser(id: 'u1', name: 'User', email: 'user@example.com', role: role);

/// The server's answers, and whether the saved session was cleared.
class _Repository implements AuthRepository {
  _Repository({this.saved, this.loginUser, this.serverUser});

  final AuthSession? saved;
  final AppUser? loginUser;
  AppUser? serverUser;
  bool cleared = false;

  @override
  Future<AuthSession?> restoreSession() async => saved;

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
    bool rememberMe = true,
  }) async => AuthSession(token: 't', user: loginUser!);

  @override
  Future<AuthSession?> refreshUser(AuthSession current) async =>
      serverUser == null
      ? null
      : AuthSession(token: current.token, user: serverUser!);

  @override
  Future<void> logout() async => cleared = true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NoCache implements HttpCacheStore {
  @override
  Future<void> clearUserData() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<AuthController> _opened(_Repository repository) async {
  final controller = AuthController(repository, cache: _NoCache());
  addTearDown(controller.dispose);
  await pumpEventQueue();
  return controller;
}

void main() {
  // Signing out returns to the first screen.
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a Koordinator can not log in', () async {
    final repository = _Repository(loginUser: _user(UserRole.koordinator));
    final controller = await _opened(repository);

    await controller.login(email: 'koordinator1', password: '123456');

    expect(controller.state.status, AuthStatus.unauthenticated);
    expect(controller.state.errorMessage, AuthController.webOnlyMessage);
    expect(repository.cleared, isTrue);
  });

  test('the other roles still log in', () async {
    for (final role in UserRole.values.where(
      (r) => r != UserRole.koordinator,
    )) {
      final controller = await _opened(_Repository(loginUser: _user(role)));

      await controller.login(email: 'user', password: '123456');

      expect(controller.state.isAuthenticated, isTrue, reason: '$role');
    }
  });

  test('a Koordinator signed in on an older version is signed out', () async {
    final repository = _Repository(
      saved: AuthSession(token: 't', user: _user(UserRole.koordinator)),
    );
    final controller = await _opened(repository);

    expect(controller.state.status, AuthStatus.unauthenticated);
    expect(controller.state.errorMessage, AuthController.webOnlyMessage);
    expect(repository.cleared, isTrue);
  });

  test('a user made Koordinator since the login is signed out', () async {
    final repository = _Repository(
      saved: AuthSession(token: 't', user: _user(UserRole.perawat)),
      serverUser: _user(UserRole.koordinator),
    );
    final controller = await _opened(repository);

    expect(controller.state.status, AuthStatus.unauthenticated);
    expect(controller.state.errorMessage, AuthController.webOnlyMessage);
  });
}
