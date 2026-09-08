// Smoke test: the app boots to the login screen (no persisted session) and
// shows the core login form fields. Auth is faked so the test never touches
// the real secure-storage platform channel (unavailable under flutter test).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bayan_rme/app.dart';
import 'package:bayan_rme/core/network/dio_client.dart';
import 'package:bayan_rme/features/auth/domain/app_user.dart';
import 'package:bayan_rme/features/auth/domain/auth_repository.dart';
import 'package:bayan_rme/features/auth/domain/user_role.dart';
import 'package:bayan_rme/features/auth/presentation/auth_controller.dart';
import 'package:bayan_rme/features/auth/presentation/auth_state.dart';

class _FakeAuthRepository implements AuthRepository {
  @override
  Future<AuthSession> login({required String email, required String password, bool rememberMe = true}) {
    throw UnimplementedError();
  }

  @override
  Future<AuthSession?> restoreSession() async => null;

  @override
  Future<void> logout() async {}

  @override
  Future<void> changePassword({required String oldPassword, required String newPassword}) async {}
}

void main() {
  testWidgets('boots to login screen with email/password fields', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(_FakeAuthRepository())],
        child: const BayanRmeApp(),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Bayan Resources'), findsWidgets);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Masuk'), findsOneWidget);

    // Verify both Bayan and doctorSHARE logos are present
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Image &&
            w.image is AssetImage &&
            (w.image as AssetImage).assetName == 'assets/images/bayan_logo.png',
      ),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Image &&
            w.image is AssetImage &&
            (w.image as AssetImage).assetName ==
                'assets/images/doctorshare_logo.png',
      ),
      findsOneWidget,
    );
  });

  testWidgets('redirects to login page when DioClient.onUnauthorized is invoked',
      (WidgetTester tester) async {
    final fakeRepo = _FakeAuthRepository();
    const testSession = AuthSession(
      token: 'jwt-123',
      user: AppUser(
        id: 'user-1',
        email: 'nurse@bayan.id',
        name: 'Suster Siti',
        role: UserRole.perawat,
      ),
    );

    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(fakeRepo),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const BayanRmeApp(),
      ),
    );
    await tester.pump();

    // Authenticate user
    container.read(authControllerProvider.notifier).state =
        const AuthState.authenticated(testSession);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Password'), findsNothing);

    // Trigger unauthorized callback
    DioClient.onUnauthorized?.call();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    // Must be redirected back to Login page
    expect(find.text('Password'), findsOneWidget);
    expect(
      find.text('Sesi telah berakhir. Silakan login kembali.'),
      findsOneWidget,
    );
  });
}