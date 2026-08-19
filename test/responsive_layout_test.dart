// Guards against layout overflow across the two breakpoints the app
// actually ships with: a phone-sized viewport and a tablet-sized one, for
// each of the 4 role home screens plus the login screen. Any RenderFlex
// overflow (or other uncaught FlutterError) fails the test automatically.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bayan_rme/app.dart';
import 'package:bayan_rme/features/auth/domain/app_user.dart';
import 'package:bayan_rme/features/auth/domain/auth_repository.dart';
import 'package:bayan_rme/features/auth/domain/user_role.dart';
import 'package:bayan_rme/features/auth/presentation/auth_controller.dart';

import 'package:bayan_rme/features/patients/data/patient_repository.dart';

class _FixedSessionAuthRepository implements AuthRepository {

  _FixedSessionAuthRepository(this.session);
  final AuthSession? session;

  @override
  Future<AuthSession> login({required String email, required String password, bool rememberMe = true}) {
    throw UnimplementedError();
  }

  @override
  Future<AuthSession?> restoreSession() async => session;

  @override
  Future<void> logout() async {}

  @override
  Future<void> changePassword({required String oldPassword, required String newPassword}) async {}
}

AuthSession _sessionFor(UserRole role, String email) {
  return AuthSession(
    token: 'test-token',
    user: AppUser(id: 'U1', name: 'Test User', email: email, role: role),
  );
}

const _phoneSize = Size(390, 844);
const _tabletSize = Size(1180, 820);

Future<void> _pumpRole(WidgetTester tester, UserRole? role, {String email = 'test@bayan.id'}) async {
  final session = role == null ? null : _sessionFor(role, email);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(_FixedSessionAuthRepository(session)),
        patientsProvider.overrideWith((ref) => PatientsNotifier(autoFetch: false)),
      ],
      child: const BayanRmeApp(),
    ),
  );
  await tester.pump();
  await tester.pump();
}


void main() {
  for (final size in [_phoneSize, _tabletSize]) {
    final sizeLabel = size == _phoneSize ? 'phone' : 'tablet';

    testWidgets('login screen has no overflow ($sizeLabel)', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await _pumpRole(tester, null);
    });

    for (final role in UserRole.values) {
      testWidgets('${role.apiValue} home screen has no overflow ($sizeLabel)', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final email = switch (role) {
          UserRole.dokter => 'dr.ahmad@bayan.id',
          _ => 'someone@bayan.id',
        };
        await _pumpRole(tester, role, email: email);
      });
    }
  }
}