import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/presentation/auth_controller.dart';

/// Port of the prototype's generic `ProfilScreen` — gradient header with
/// initials, then a single "Keluar / Ganti Role" action that ends the
/// session (clears the persisted token) and drops back to the login screen.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key, required this.name, required this.role});

  final String name;
  final String role;

  String get _initials {
    final stripped = name.replaceFirst(RegExp(r'^(dr\.|Suster|Apt\.|Analis)\s*'), '');
    return stripped.isNotEmpty ? stripped[0].toUpperCase() : 'U';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.blue, Color(0xFF1E40AF)],
            ),
          ),
          child: Column(
            children: [
              Container(
                width: 72,
                height: 72,
                alignment: Alignment.center,
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)),
                child: Text(_initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 28)),
              ),
              Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
              const SizedBox(height: 3),
              Text('$role · Bayan RME', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.75))),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Material(
            color: AppColors.redLt,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => ref.read(authControllerProvider.notifier).logout(),
              child: Padding(
                padding: const EdgeInsets.all(13),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(9)),
                      child: const Icon(LucideIcons.logOut, size: 17, color: AppColors.red),
                    ),
                    const SizedBox(width: 11),
                    const Text('Keluar / Ganti Role', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.red)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
