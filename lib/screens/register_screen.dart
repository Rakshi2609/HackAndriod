import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:math';
import '../theme/app_theme.dart';
import '../services/user_service_web.dart'
    if (dart.library.io) '../services/user_service_io.dart';
import '../models/health_profile.dart';
import '../providers/health_profile_provider.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _loading = false;
  bool _isDoctor = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final svc = UserService();
    try {
      final created = await svc
          .createUser(
              name: _nameCtrl.text.trim(),
              email: _emailCtrl.text.trim(),
              password: _passCtrl.text,
              role: _isDoctor ? 'doctor' : 'patient')
          .timeout(const Duration(seconds: 10));
      setState(() => _loading = false);
      if (created) {
        // update active profile to newly registered user
        final rand = Random();
        final hashed =
            'ID-${DateTime.now().millisecondsSinceEpoch.toRadixString(36).toUpperCase()}';
        final newProfile = HealthProfile(
          name: _nameCtrl.text.trim(),
          email: _emailCtrl.text.trim(),
          phone: '',
          bloodGroup: '',
          conditions: [],
          allergies: [],
          hashedId: hashed,
        );
        ref.read(healthProfileProvider.notifier).state = newProfile;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Account created successfully')));
          Navigator.pop(context);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Email already registered')));
        }
      }
    } on TimeoutException {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Registration timed out — check MongoDB server or network')));
      }
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                // Role selector
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _isDoctor = false),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                              color: !_isDoctor
                                  ? AppColors.primary
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8)),
                          child: Center(
                              child: Text('Patient',
                                  style: TextStyle(
                                      color: !_isDoctor
                                          ? Colors.white
                                          : AppColors.textPrimary,
                                      fontWeight: FontWeight.w700))),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _isDoctor = true),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                              color: _isDoctor
                                  ? AppColors.deepNavy
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8)),
                          child: Center(
                              child: Text('Doctor',
                                  style: TextStyle(
                                      color: _isDoctor
                                          ? Colors.white
                                          : AppColors.textPrimary,
                                      fontWeight: FontWeight.w700))),
                        ),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(labelText: 'Full name'),
                  validator: (v) => (v == null || v.trim().length < 2)
                      ? 'Enter your name'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emailCtrl,
                  decoration: const InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) => (v == null || !v.contains('@'))
                      ? 'Enter a valid email'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passCtrl,
                  decoration: const InputDecoration(labelText: 'Password'),
                  obscureText: true,
                  validator: (v) => (v == null || v.length < 6)
                      ? 'Password must be at least 6 chars'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _confirmCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Confirm password'),
                  obscureText: true,
                  validator: (v) =>
                      (v != _passCtrl.text) ? 'Passwords do not match' : null,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _register,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12))),
                    child: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('Create account'),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
