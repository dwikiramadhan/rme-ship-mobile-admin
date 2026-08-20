import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/domain/user_role.dart';
import '../../features/auth/presentation/auth_controller.dart';
import '../../features/auth/presentation/auth_state.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/doctor/presentation/doctor_home_screen.dart';
import '../../features/lab/presentation/lab_home_screen.dart';
import '../../features/nurse/presentation/nurse_home_screen.dart';
import '../../features/patients/domain/doctor.dart';
import '../../features/pharmacy/presentation/pharmacy_home_screen.dart';
import '../../features/ship_admin/presentation/ship_admin_home_screen.dart';
import '../theme/app_colors.dart';

/// Top-level router: shows a splash while restoring a persisted session,
/// the login form when signed out, or the matching role's home screen once
/// authenticated — role comes entirely from the session, never chosen by
/// hand (per the "role read from login session" requirement).
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);

    switch (authState.status) {
      case AuthStatus.unknown:
        return const _SplashScreen();
      case AuthStatus.unauthenticated:
      case AuthStatus.authenticating:
        return const LoginScreen();
      case AuthStatus.authenticated:
        return _roleHome(authState);
    }
  }

  Widget _roleHome(AuthState authState) {
    final user = authState.session!.user;
    return switch (user.role) {
      UserRole.perawat => PerawatHomeScreen(perawatName: user.name),
      UserRole.adminKapal => AdminKapalHomeScreen(adminName: user.name),
      UserRole.dokter => DokterHomeScreen(doctorId: resolveDoctorId(user.email, userId: user.id), doctorName: user.name),
      UserRole.pharmacy => PharmacyHomeScreen(apotekerName: user.name),
      UserRole.lab => LabHomeScreen(analystName: user.name),
    };
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.loginBg,
      body: Center(child: CircularProgressIndicator(color: AppColors.blue)),
    );
  }
}
