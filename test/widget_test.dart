// Smoke test: the app boots to the login screen (no persisted session) and
// shows the core login form fields. Auth is faked so the test never touches
// the real secure-storage platform channel (unavailable under flutter test).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bayan_rme/app.dart';
import 'package:bayan_rme/features/auth/domain/app_user.dart';
import 'package:bayan_rme/features/auth/domain/auth_repository.dart';
import 'package:bayan_rme/features/auth/presentation/auth_controller.dart';

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

    expect(find.text('Bayan RME'), findsWidgets);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Masuk'), findsOneWidget);
  });
}