import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/network/api_config.dart';
import '../../../core/network/server_discovery.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/server_settings_dialog.dart';
import '../data/session_storage.dart';
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
  final _storage = SessionStorage();
  bool _obscurePassword = true;
  bool _rememberMe = true;
  String? _errorMessage;
  bool _serverChecking = false;
  bool _serverOnline = false;

  @override
  void initState() {
    super.initState();
    _loadSavedEmail();
    _autoDiscoverServer();
    final authState = ref.read(authControllerProvider);
    if (authState.status == AuthStatus.unauthenticated &&
        authState.errorMessage != null) {
      _errorMessage = _formatErrorMessage(authState.errorMessage!);
    }
  }

  Future<void> _autoDiscoverServer() async {
    if (Platform.environment.containsKey('FLUTTER_TEST')) return;
    setState(() => _serverChecking = true);
    final isAlive = await ApiConfig.testConnection(ApiConfig.baseUrl);
    if (isAlive) {
      if (mounted) {
        setState(() {
          _serverChecking = false;
          _serverOnline = true;
        });
      }
      return;
    }

    final found = await ServerDiscovery.autoDiscover();
    if (!mounted) return;
    setState(() {
      _serverChecking = false;
      _serverOnline = found != null;
    });
  }

  String _formatErrorMessage(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('sesi') || lower.contains('session')) {
      return 'Sesi telah berakhir. Silakan login kembali.';
    } else if (lower.contains('credential') ||
        lower.contains('unauthorized') ||
        lower.contains('password') ||
        lower.contains('401') ||
        lower.contains('tidak valid') ||
        lower.contains('salah')) {
      return 'Email atau password salah';
    }
    return message;
  }

  Future<void> _loadSavedEmail() async {
    try {
      final savedEmail = await _storage.readRememberEmail();
      if (savedEmail != null && savedEmail.isNotEmpty && mounted) {
        setState(() {
          _emailController.text = savedEmail;
          _rememberMe = true;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _errorMessage = null;
    });
    final email = _emailController.text.trim();
    if (_rememberMe) {
      _storage.saveRememberEmail(email);
    } else {
      _storage.clearRememberEmail();
    }
    ref
        .read(authControllerProvider.notifier)
        .login(
          email: email,
          password: _passwordController.text,
          rememberMe: _rememberMe,
        );
  }

  void _showForgotPasswordNotice() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(LucideIcons.helpCircle, color: AppColors.blue, size: 20),
            SizedBox(width: 8),
            Text('Lupa Password?', style: TextStyle(letterSpacing: 0)),
          ],
        ),
        content: const Text(
          'Silakan hubungi Administrator Sistem atau Bagian TI Rumah Sakit / Kapal Anda untuk mereset kata sandi akun.',
          style: TextStyle(
            fontSize: 13,
            height: 1.4,
            color: AppColors.text,
            letterSpacing: 0,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Mengerti',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.blue,
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.status == AuthStatus.authenticating;

    ref.listen<AuthState>(authControllerProvider, (previous, next) {
      if (next.status == AuthStatus.unauthenticated &&
          next.errorMessage != null) {
        final displayMsg = _formatErrorMessage(next.errorMessage!);
        setState(() {
          _errorMessage = displayMsg;
        });

        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              content: Row(
                children: [
                  const Icon(
                    LucideIcons.alertCircle,
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      displayMsg,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                ],
              ),
              backgroundColor: AppColors.red,
            ),
          );
      }
    });

    final screenWidth = MediaQuery.of(context).size.width;
    final isTabletLandscape = screenWidth >= 900;

    return DefaultTextStyle.merge(
      style: const TextStyle(letterSpacing: 0),
      child: Scaffold(
        body: _AnimatedGradientBackground(
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 24,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: isTabletLandscape ? 860 : 460,
                  ),
                  child: Container(
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(40),
                      border: Border.all(
                        color: AppColors.border.withValues(alpha: 0.8),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 36,
                          offset: const Offset(0, 16),
                        ),
                      ],
                    ),
                    child: isTabletLandscape
                        ? IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  flex: 5,
                                  child: _LoginHero(isWide: true),
                                ),
                                Expanded(flex: 6, child: _buildForm(isLoading)),
                              ],
                            ),
                          )
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _LoginHero(isWide: false),
                              _buildForm(isLoading),
                            ],
                          ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForm(bool isLoading) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Welcome Back',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.text,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Please sign in to your account to continue',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.sub,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: () async {
                          await ServerSettingsDialog.show(context);
                          if (mounted) _autoDiscoverServer();
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3.5,
                          ),
                          decoration: BoxDecoration(
                            color: _serverChecking
                                ? AppColors.skyLt
                                : (_serverOnline
                                      ? const Color(0xFFECFDF5)
                                      : AppColors.redLt),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _serverChecking
                                  ? AppColors.skyBlue.withValues(alpha: 0.3)
                                  : (_serverOnline
                                        ? const Color(0xFF10B981).withValues(alpha: 0.3)
                                        : AppColors.red.withValues(alpha: 0.3)),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_serverChecking) ...[
                                const SizedBox(
                                  width: 9,
                                  height: 9,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 1.5,
                                    color: AppColors.skyBlue,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                const Text(
                                  'Mencari server di Wi-Fi...',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: AppColors.skyBlue,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ] else if (_serverOnline) ...[
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Color(0xFF10B981),
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  'Server Terhubung (${ApiConfig.baseUrl.replaceFirst(RegExp(r'https?://'), '')})',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFF059669),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ] else ...[
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.red,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                const Text(
                                  'Server belum terhubung',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: AppColors.red,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Pengaturan Server IP',
                  onPressed: () => ServerSettingsDialog.show(context),
                  icon: const Icon(LucideIcons.server, size: 18),
                  color: AppColors.sub,
                  splashRadius: 20,
                ),
              ],
            ),
            const SizedBox(height: 18),

            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.red.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      LucideIcons.alertCircle,
                      color: AppColors.red,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: AppColors.red,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Email Input
            const Text(
              'Email',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.text,
                letterSpacing: 0,
                height: 1.2,
              ),
              decoration: InputDecoration(
                hintText: 'Masukkan email',
                hintStyle: const TextStyle(
                  fontSize: 12,
                  color: AppColors.sub,
                  letterSpacing: 0,
                  height: 1.2,
                ),
                errorStyle: const TextStyle(fontSize: 11, letterSpacing: 0),
                prefixIcon: const Icon(
                  LucideIcons.mail,
                  size: 14,
                  color: AppColors.sub,
                ),
                filled: true,
                fillColor: AppColors.inputBg,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: AppColors.blue,
                    width: 1.6,
                  ),
                ),
              ),
              validator: (value) {
                final v = value?.trim() ?? '';
                if (v.isEmpty) return 'Email wajib diisi';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Password Input
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Password',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                    letterSpacing: 0,
                  ),
                ),
                GestureDetector(
                  onTap: _showForgotPasswordNotice,
                  child: const Text(
                    'Lupa password?',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.blue,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              onFieldSubmitted: (_) => _submit(),
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.text,
                letterSpacing: 0,
                height: 1.2,
              ),
              decoration: InputDecoration(
                hintText: 'Masukkan kata sandi',
                hintStyle: const TextStyle(
                  fontSize: 12,
                  color: AppColors.sub,
                  letterSpacing: 0,
                  height: 1.2,
                ),
                errorStyle: const TextStyle(fontSize: 11, letterSpacing: 0),
                prefixIcon: const Icon(
                  LucideIcons.lock,
                  size: 12,
                  color: AppColors.sub,
                ),
                filled: true,
                fillColor: AppColors.inputBg,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: AppColors.blue,
                    width: 1.6,
                  ),
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? LucideIcons.eye : LucideIcons.eyeOff,
                    size: 17,
                    color: AppColors.sub,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              validator: (value) {
                if ((value ?? '').isEmpty) return 'Password wajib diisi';
                return null;
              },
            ),
            const SizedBox(height: 14),

            // Remember Me
            InkWell(
              onTap: () => setState(() => _rememberMe = !_rememberMe),
              borderRadius: BorderRadius.circular(6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: Checkbox(
                      value: _rememberMe,
                      onChanged: (v) => setState(() => _rememberMe = v ?? true),
                      activeColor: AppColors.blue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Remember me',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.text,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Submit Button
            AppButton(
              label: 'Masuk',
              icon: LucideIcons.logIn,
              full: true,
              loading: isLoading,
              loadingLabel: 'Memeriksa...',
              onPressed: isLoading ? null : _submit,
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _LoginHero extends StatelessWidget {
  const _LoginHero({required this.isWide});

  final bool isWide;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(28, isWide ? 44 : 32, 28, isWide ? 44 : 28),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F2942), Color(0xFF1E40AF), AppColors.blue],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: -40,
            right: -30,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),
          Positioned(
            bottom: -30,
            left: -20,
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.04),
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        'assets/images/bayan_logo.png',
                        width: 58,
                        height: 58,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(width: 16),
                      Container(
                        width: 1.5,
                        height: 44,
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                      const SizedBox(width: 16),
                      Image.asset(
                        'assets/images/doctorshare_logo.png',
                        width: 95,
                        height: 58,
                        fit: BoxFit.contain,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Bayan Resources',
                  style: TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Sistem Rekam Medis Elektronik Kapal',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      letterSpacing: 0,
                    ),
                  ),
                ),
                if (isWide) ...[
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Row(
                          children: [
                            Icon(
                              LucideIcons.activity,
                              color: Colors.white,
                              size: 16,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Pelayanan Kesehatan Terpadu',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                  letterSpacing: 0,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Mendukung operasional klinik di atas kapal antar perawat, dokter, apotek, dan laboratorium.',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            height: 1.35,
                            letterSpacing: 0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Background dengan animasi 3 gradasi warna yang bergerak secara dinamis
class _AnimatedGradientBackground extends StatefulWidget {
  const _AnimatedGradientBackground({required this.child});

  final Widget child;

  @override
  State<_AnimatedGradientBackground> createState() =>
      _AnimatedGradientBackgroundState();
}

class _AnimatedGradientBackgroundState
    extends State<_AnimatedGradientBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;

        // Alignment pergerakan gradasi 3 warna
        final angle = t * math.pi;
        final begin = Alignment(
          -1.0 + 0.6 * math.sin(angle),
          -1.0 + 0.7 * math.cos(angle),
        );
        final end = Alignment(
          1.0 - 0.6 * math.sin(angle),
          1.0 - 0.7 * math.cos(angle),
        );

        // 3 warna gradasi yang harmonis & elegan (Marine Sky Blue, Soft Violet, Warm Peach/Amber)
        final color1 = Color.lerp(
          const Color(0xFFDCEEFE), // Sky Blue lembut
          const Color(0xFFE0E7FF), // Indigo lembut
          t,
        )!;
        final color2 = Color.lerp(
          const Color(0xFFEDE9FE), // Lavender / Soft Violet
          const Color(0xFFFCE7F3), // Soft Rose
          t,
        )!;
        final color3 = Color.lerp(
          const Color(0xFFFFF7ED), // Soft Peach / Orange Bayan
          const Color(0xFFFEF3C7), // Warm Amber lembut
          t,
        )!;

        return Stack(
          children: [
            // Lapisan 1: Gradasi 3 warna linier yang bergerak
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: begin,
                    end: end,
                    colors: [color1, color2, color3],
                    stops: [
                      0.0,
                      (0.48 + 0.12 * math.sin(t * 2 * math.pi)).clamp(0.2, 0.8),
                      1.0,
                    ],
                  ),
                ),
              ),
            ),
            // Lapisan 2: 3 titik orb gradasi ambient yang bergerak dinamis di latar belakang
            Positioned.fill(
              child: CustomPaint(painter: _MovingOrbsPainter(progress: t)),
            ),
            // Lapisan 3: Konten form login utama
            Positioned.fill(child: child!),
          ],
        );
      },
      child: widget.child,
    );
  }
}

class _MovingOrbsPainter extends CustomPainter {
  const _MovingOrbsPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress;
    final w = size.width;
    final h = size.height;

    // Orb 1: Biru Bahari (bergerak di area kiri atas - tengah)
    final center1 = Offset(
      w * (0.22 + 0.22 * math.sin(t * 2 * math.pi)),
      h * (0.24 + 0.18 * math.cos(t * 2 * math.pi)),
    );
    final radius1 = w * 0.48;
    final paint1 = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF38BDF8).withValues(alpha: 0.22),
          const Color(0xFF38BDF8).withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: center1, radius: radius1));
    canvas.drawCircle(center1, radius1, paint1);

    // Orb 2: Violet / Ungu Lembut (bergerak di area kanan atas - tengah bawah)
    final center2 = Offset(
      w * (0.78 - 0.22 * math.cos(t * 2 * math.pi)),
      h * (0.38 + 0.22 * math.sin(t * 2 * math.pi)),
    );
    final radius2 = w * 0.52;
    final paint2 = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF818CF8).withValues(alpha: 0.20),
          const Color(0xFF818CF8).withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: center2, radius: radius2));
    canvas.drawCircle(center2, radius2, paint2);

    // Orb 3: Aksen Oranye / Peach Hangat (bergerak di area bawah)
    final center3 = Offset(
      w * (0.50 + 0.28 * math.cos(t * 2 * math.pi + 1.0)),
      h * (0.76 + 0.14 * math.sin(t * 2 * math.pi + 1.0)),
    );
    final radius3 = w * 0.46;
    final paint3 = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFB923C).withValues(alpha: 0.18),
          const Color(0xFFFB923C).withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: center3, radius: radius3));
    canvas.drawCircle(center3, radius3, paint3);
  }

  @override
  bool shouldRepaint(covariant _MovingOrbsPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
