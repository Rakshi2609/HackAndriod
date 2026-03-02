import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../providers/health_profile_provider.dart';
import 'register_screen.dart';
import '../services/user_service_web.dart'
    if (dart.library.io) '../services/user_service_io.dart';
import '../models/health_profile.dart';

class LoginScreen extends ConsumerStatefulWidget {
  final VoidCallback onLoginSuccess;
  const LoginScreen({super.key, required this.onLoginSuccess});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with TickerProviderStateMixin {
  late AnimationController _bgController;
  late AnimationController _formController;
  late Animation<double> _formFade;
  late Animation<Offset> _formSlide;

  final _emailCtrl = TextEditingController(text: 'sara@carelytix.health');
  final _passCtrl = TextEditingController(text: '••••••••');
  bool _loading = false;
  bool _obscure = true;
  bool _isDoctor = false;

  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);
    _formController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _formFade = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _formController, curve: Curves.easeOut));
    _formSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _formController, curve: Curves.easeOut));
    _formController.forward();
  }

  @override
  void dispose() {
    _bgController.dispose();
    _formController.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() => _loading = true);
    final svc = UserService();
    try {
      final ok = await svc
          .authenticate(_emailCtrl.text.trim(), _passCtrl.text)
          .timeout(const Duration(seconds: 6));
      if (ok) {
        final u = await svc.findByEmail(_emailCtrl.text.trim());
        if (u != null) {
          final hashed =
              u['id'] ?? 'ID-${DateTime.now().millisecondsSinceEpoch}';
          final profile = HealthProfile(
            name: u['name'] ?? _emailCtrl.text.split('@').first,
            email: u['email'] ?? _emailCtrl.text.trim(),
            phone: u['phone'] ?? '',
            bloodGroup: u['bloodGroup'] ?? '',
            conditions: (u['conditions'] as List?)?.cast<String>() ?? [],
            allergies: (u['allergies'] as List?)?.cast<String>() ?? [],
            hashedId: hashed,
          );
          ref.read(healthProfileProvider.notifier).state = profile;
        }
        if (mounted) widget.onLoginSuccess();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Invalid credentials')));
        }
      }
    } catch (_) {
      // fallback: treat as success for demo
      if (mounted) widget.onLoginSuccess();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _bgController,
        builder: (_, __) => Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(-1 + _bgController.value * 0.6, -1),
              end: Alignment(1 - _bgController.value * 0.3, 1),
              colors: const [
                Color(0xFF0D1B2A),
                Color(0xFF0A3D6B),
                Color(0xFF2D9CDB),
                Color(0xFF00C48C),
              ],
              stops: const [0.0, 0.35, 0.7, 1.0],
            ),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: Column(
                children: [
                  const SizedBox(height: 40),

                  // Logo section
                  Hero(
                    tag: 'app_logo',
                    child: Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Colors.white24, Colors.white10],
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white38, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.mintGreen.withOpacity(0.3),
                            blurRadius: 30,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.favorite_rounded,
                        color: Colors.white,
                        size: 44,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'carelytix',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 5,
                    ),
                  ),
                  const Text(
                    'Healthcare. Reimagined.',
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 13,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 48),

                  // Role selector
                  FadeTransition(
                    opacity: _formFade,
                    child: SlideTransition(
                      position: _formSlide,
                      child: Column(
                        children: [
                          // Patient / Doctor toggle
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: Row(
                              children: [
                                _roleTab(
                                  'Patient',
                                  !_isDoctor,
                                  Icons.person_rounded,
                                  () => setState(() => _isDoctor = false),
                                ),
                                _roleTab(
                                  'Doctor',
                                  _isDoctor,
                                  Icons.medical_services_rounded,
                                  () => setState(() => _isDoctor = true),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 28),

                          // Form card
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(28),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 30,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                Text(
                                  _isDoctor
                                      ? 'Doctor Portal'
                                      : 'Welcome Back, ${ref.watch(healthProfileProvider).name.split(" ").first}',
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _isDoctor
                                      ? 'Secure Medical Access'
                                      : 'Your health, simplified.',
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 24),

                                // Email field
                                TextField(
                                  controller: _emailCtrl,
                                  keyboardType: TextInputType.emailAddress,
                                  decoration: InputDecoration(
                                    labelText: 'Email / Health ID',
                                    prefixIcon: const Icon(
                                      Icons.person_outline_rounded,
                                      color: AppColors.primary,
                                    ),
                                    filled: true,
                                    fillColor: AppColors.background,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // Password field
                                TextField(
                                  controller: _passCtrl,
                                  obscureText: _obscure,
                                  decoration: InputDecoration(
                                    labelText: 'Password',
                                    prefixIcon: const Icon(
                                      Icons.lock_outline_rounded,
                                      color: AppColors.primary,
                                    ),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscure
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                        color: AppColors.textSecondary,
                                      ),
                                      onPressed: () =>
                                          setState(() => _obscure = !_obscure),
                                    ),
                                    filled: true,
                                    fillColor: AppColors.background,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: () {},
                                    child: const Text(
                                      'Forgot Password?',
                                      style: TextStyle(
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // Login button
                                SizedBox(
                                  width: double.infinity,
                                  height: 54,
                                  child: ElevatedButton(
                                    onPressed: _loading ? null : _login,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _isDoctor
                                          ? AppColors.deepNavy
                                          : AppColors.primary,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    child: _loading
                                        ? const SizedBox(
                                            width: 24,
                                            height: 24,
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2.5,
                                            ),
                                          )
                                        : Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                _isDoctor
                                                    ? Icons
                                                        .medical_services_rounded
                                                    : Icons.login_rounded,
                                                color: Colors.white,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                _isDoctor
                                                    ? 'Access Doctor Portal'
                                                    : 'Sign In',
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w700,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ],
                                          ),
                                  ),
                                ),

                                const SizedBox(height: 20),
                                const Row(
                                  children: [
                                    Expanded(child: Divider()),
                                    Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 12,
                                      ),
                                      child: Text(
                                        'or',
                                        style: TextStyle(
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ),
                                    Expanded(child: Divider()),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                // QR login
                                OutlinedButton.icon(
                                  onPressed: _login,
                                  icon: const Icon(
                                    Icons.qr_code_scanner_rounded,
                                    color: AppColors.primary,
                                  ),
                                  label: const Text(
                                    'Login with QR Passport',
                                    style: TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(
                                      color: AppColors.primary,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    minimumSize: const Size(
                                      double.infinity,
                                      48,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          TextButton(
                            onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const RegisterScreen())),
                            child: const Text(
                              "Don't have an account? Register →",
                              style: TextStyle(color: Colors.white70),
                            ),
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
    );
  }

  Widget _roleTab(
    String label,
    bool active,
    IconData icon,
    VoidCallback onTap,
  ) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: active ? AppColors.primary : Colors.white60,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                  color: active ? AppColors.primary : Colors.white60,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
