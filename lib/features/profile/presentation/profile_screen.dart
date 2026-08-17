import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../auth/presentation/auth_state.dart';

/// Profile screen with change-password support for all ship-based roles.
/// RBAC: Ubah Kata Sandi — all roles (Perawat, Dokter, Pharmacist, Admin Kapal, Lab).
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key, required this.name, required this.role});

  final String name;
  final String role;

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  String get _initials {
    final stripped = widget.name.replaceFirst(RegExp(r'^(dr\.|Suster|Apt\.|Analis)\s*'), '');
    return stripped.isNotEmpty ? stripped[0].toUpperCase() : 'U';
  }

  void _showChangePassword() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => _ChangePasswordSheet(
        onSuccess: () {
          Navigator.of(sheetContext).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Kata sandi berhasil diubah')),
          );
        },
        onError: (msg) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
              Text(widget.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
              const SizedBox(height: 3),
              Text('${widget.role} · Bayan RME', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.75))),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Change password tile
              Material(
                color: AppColors.blueLt,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: _showChangePassword,
                  child: const Padding(
                    padding: EdgeInsets.all(13),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 34,
                          height: 34,
                          child: Icon(LucideIcons.keyRound, size: 17, color: AppColors.blue),
                        ),
                        SizedBox(width: 11),
                        Text('Ubah Kata Sandi', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.blue)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Logout tile
              Material(
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
            ],
          ),
        ),
      ],
    );
  }
}

class _ChangePasswordSheet extends ConsumerStatefulWidget {
  const _ChangePasswordSheet({required this.onSuccess, required this.onError});

  final VoidCallback onSuccess;
  final void Function(String message) onError;

  @override
  ConsumerState<_ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends ConsumerState<_ChangePasswordSheet> {
  final _formKey = GlobalKey<FormState>();
  final _oldPw = TextEditingController();
  final _newPw = TextEditingController();
  final _confirmPw = TextEditingController();
  bool _loading = false;
  bool _obscureOld = true;
  bool _obscureNew = true;

  @override
  void dispose() {
    _oldPw.dispose();
    _newPw.dispose();
    _confirmPw.dispose();
    super.dispose();
  }

  String? _required(String? v) => (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ref.read(authControllerProvider.notifier).changePassword(
            oldPassword: _oldPw.text,
            newPassword: _newPw.text,
          );
      widget.onSuccess();
    } catch (e) {
      widget.onError(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Ubah Kata Sandi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.text)),
                const SizedBox(height: 14),
                _PasswordField(
                  label: 'Kata Sandi Lama',
                  controller: _oldPw,
                  obscure: _obscureOld,
                  onToggle: () => setState(() => _obscureOld = !_obscureOld),
                ),
                const SizedBox(height: 10),
                _PasswordField(
                  label: 'Kata Sandi Baru',
                  controller: _newPw,
                  obscure: _obscureNew,
                  onToggle: () => setState(() => _obscureNew = !_obscureNew),
                ),
                const SizedBox(height: 10),
                _PasswordField(
                  label: 'Konfirmasi Kata Sandi Baru',
                  controller: _confirmPw,
                  obscure: _obscureNew,
                  validator: (v) {
                    if ((v == null || v.trim().isEmpty)) return 'Wajib diisi';
                    if (v.trim() != _newPw.text.trim()) return 'Tidak cocok dengan kata sandi baru';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _loading
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                        onPressed: _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Simpan', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PasswordField extends StatelessWidget {
  const _PasswordField({
    required this.label,
    required this.controller,
    this.obscure = true,
    this.onToggle,
    this.validator,
  });

  final String label;
  final TextEditingController controller;
  final bool obscure;
  final VoidCallback? onToggle;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text)),
        const SizedBox(height: 5),
        TextFormField(
          controller: controller,
          obscureText: obscure,
          validator: validator ?? _defaultRequired,
          decoration: InputDecoration(
            suffixIcon: onToggle != null
                ? IconButton(
                    onPressed: onToggle,
                    icon: Icon(obscure ? LucideIcons.eye : LucideIcons.eyeOff, size: 18, color: AppColors.sub),
                  )
                : null,
          ),
        ),
      ],
    );
  }

  static String? _defaultRequired(String? v) => (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null;
}
