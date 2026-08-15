import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_button.dart';
import 'auth_controller.dart';
import 'auth_state.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _rememberMe = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    ref.read(authControllerProvider.notifier).login(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          rememberMe: _rememberMe,
        );
  }

  void _showForgotPasswordNotice() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Lupa Password?'),
        content: const Text('Hubungi admin rumah sakit / kapal Anda untuk mengatur ulang password.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Mengerti')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.status == AuthStatus.authenticating;

    ref.listen<AuthState>(authControllerProvider, (previous, next) {
      if (next.status == AuthStatus.unauthenticated && next.errorMessage != null) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(next.errorMessage!), backgroundColor: AppColors.red));
      }
    });

    return Scaffold(
      backgroundColor: AppColors.loginBg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: [
                    BoxShadow(color: AppColors.text.withValues(alpha: 0.25), blurRadius: 70, offset: const Offset(0, 30)),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _LoginHero(),
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Selamat Datang', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.text)),
                            const SizedBox(height: 2),
                            const Text('Masuk untuk melanjutkan ke Bayan RME', style: TextStyle(fontSize: 12.5, color: AppColors.sub)),
                            const SizedBox(height: 20),
                            const Text('Email', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text)),
                            const SizedBox(height: 5),
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.email],
                              decoration: const InputDecoration(
                                hintText: 'nama@bayan.id',
                                prefixIcon: Icon(LucideIcons.mail, size: 18, color: AppColors.sub),
                              ),
                              validator: (value) {
                                final v = value?.trim() ?? '';
                                if (v.isEmpty) return 'Email wajib diisi';
                                final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
                                if (!emailRegex.hasMatch(v)) return 'Format email tidak valid';
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),
                            const Text('Password', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text)),
                            const SizedBox(height: 5),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              textInputAction: TextInputAction.done,
                              autofillHints: const [AutofillHints.password],
                              onFieldSubmitted: (_) => _submit(),
                              decoration: InputDecoration(
                                hintText: 'Masukkan password',
                                prefixIcon: const Icon(LucideIcons.lock, size: 18, color: AppColors.sub),
                                suffixIcon: IconButton(
                                  icon: Icon(_obscurePassword ? LucideIcons.eye : LucideIcons.eyeOff, size: 18, color: AppColors.sub),
                                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                ),
                              ),
                              validator: (value) {
                                if ((value ?? '').isEmpty) return 'Password wajib diisi';
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: InkWell(
                                    onTap: () => setState(() => _rememberMe = !_rememberMe),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: Checkbox(
                                            value: _rememberMe,
                                            onChanged: (v) => setState(() => _rememberMe = v ?? true),
                                            activeColor: AppColors.blue,
                                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          ),
                                        ),
                                        const SizedBox(width: 7),
                                        const Flexible(
                                          child: Text(
                                            'Ingat saya',
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(fontSize: 12.5, color: AppColors.sub, fontWeight: FontWeight.w600),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: _showForgotPasswordNotice,
                                  child: const Text(
                                    'Lupa password?',
                                    style: TextStyle(fontSize: 12.5, color: AppColors.blue, fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            AppButton(
                              label: 'Masuk',
                              full: true,
                              loading: isLoading,
                              loadingLabel: 'Memeriksa...',
                              onPressed: isLoading ? null : _submit,
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.only(top: 1),
                                  child: Icon(LucideIcons.shield, size: 13, color: AppColors.sub),
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    'Koneksi terenkripsi · Role ditentukan otomatis dari akun',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 11, color: AppColors.sub.withValues(alpha: 0.9)),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginHero extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 36, 24, 30),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E40AF), AppColors.blue, Color(0xFF2563EB)],
          stops: [0, 0.55, 1],
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: -60,
            right: -50,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.08)),
            ),
          ),
          Column(
            children: [
              Container(
                width: 76,
                height: 76,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.22), blurRadius: 32, offset: const Offset(0, 12))],
                ),
                child: Image.asset('assets/images/bayan_logo.png', width: 50, height: 50, fit: BoxFit.contain),
              ),
              const SizedBox(height: 14),
              const Text('Bayan RME', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white)),
              const SizedBox(height: 4),
              Text('Rekam Medis Elektronik', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.white.withValues(alpha: 0.78))),
            ],
          ),
        ],
      ),
    );
  }
}
