import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  String? _serverError;
  int _failedAttempts = 0;
  DateTime? _lockoutUntil;
  Timer? _lockoutTimer;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _lockoutTimer?.cancel();
    super.dispose();
  }

  void _checkLockoutState() {
    if (_lockoutUntil != null) {
      if (DateTime.now().isAfter(_lockoutUntil!)) {
        setState(() {
          _failedAttempts = 0;
          _lockoutUntil = null;
          _serverError = null;
        });
      }
    }
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  Future<void> _submit() async {
    _checkLockoutState();
    if (_lockoutUntil != null) return;

    setState(() { _serverError = null; });
    if (!_formKey.currentState!.validate()) return;
    
    final auth = ref.read(authNotifierProvider.notifier);
    
    try {
      await auth.login(_emailController.text.trim(), _passwordController.text);
      if (mounted) context.go('/dashboard');
    } catch (e) {
      if (mounted) {
        setState(() {
          final errorMsg = e.toString().replaceAll('Exception: ', '');
          if (errorMsg.contains('Too many attempts')) {
            _serverError = 'Too many attempts. Please try again later.';
          } else {
            _serverError = errorMsg;
          }
          _passwordController.clear();
          
          _failedAttempts++;
          if (_failedAttempts >= 5) {
            _lockoutUntil = DateTime.now().add(const Duration(minutes: 5));
            _serverError = 'Too many attempts. Locked out for 5 minutes.';
            _lockoutTimer = Timer(const Duration(minutes: 5), () {
              if (mounted) setState(() {});
            });
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 900;
    _checkLockoutState();
    final isLockedOut = _lockoutUntil != null;
    
    return Scaffold(
      body: Row(
        children: [
          if (isDesktop)
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primary500, Color(0xFF8B5CF6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.splitscreen_rounded, size: 64, color: Colors.white),
                        const SizedBox(height: 24),
                        Text('SplitEase Premium', style: Theme.of(context).textTheme.displayMedium?.copyWith(color: Colors.white)),
                        const SizedBox(height: 16),
                        Text('The fastest way to track expenses and settle up with friends.', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white70, fontWeight: FontWeight.normal)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          Expanded(
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!isDesktop) ...[
                          Container(
                            height: 56, width: 56,
                            decoration: BoxDecoration(
                              color: AppColors.primary500.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16)
                            ),
                            child: const Icon(Icons.splitscreen_rounded, size: 32, color: AppColors.primary500),
                          ),
                          const SizedBox(height: 32),
                        ],
                        Text(
                          'Welcome back',
                          style: Theme.of(context).textTheme.displayMedium?.copyWith(fontSize: 32),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Log in to view your ledger.',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 32),
                        
                        // --- Social Login Section ---
                        OutlinedButton.icon(
                          onPressed: () async {
                            try {
                              await ref.read(authNotifierProvider.notifier).loginWithGoogle();
                              if (context.mounted) context.go('/dashboard');
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                              }
                            }
                          },
                          icon: Image.network('https://upload.wikimedia.org/wikipedia/commons/c/c1/Google_%22G%22_logo.svg', width: 20),
                          label: const Text('Continue with Google', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 48),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                        
                        if (!kIsWeb && Platform.isIOS) ...[
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () async {
                              try {
                                await ref.read(authNotifierProvider.notifier).loginWithApple();
                                if (context.mounted) context.go('/dashboard');
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                                }
                              }
                            },
                            icon: const Icon(Icons.apple, color: Colors.white, size: 24),
                            label: const Text('Continue with Apple', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              minimumSize: const Size(double.infinity, 48),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ],
                        
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            const Expanded(child: Divider(color: Colors.grey)),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Text('OR', style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold, fontSize: 12)),
                            ),
                            const Expanded(child: Divider(color: Colors.grey)),
                          ],
                        ),
                        const SizedBox(height: 24),

                        Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildLabel('Email Address'),
                              TextFormField(
                                controller: _emailController,
                                autofocus: true,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                decoration: const InputDecoration(hintText: 'name@example.com'),
                                validator: (value) {
                                  if (value == null || value.isEmpty) return 'Required';
                                  if (!_isValidEmail(value)) return 'Enter a valid email';
                                  return null;
                                },
                                onChanged: (_) => setState(() => _serverError = null),
                              ),
                              const SizedBox(height: 20),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  _buildLabel('Password'),
                                  TextButton(
                                    onPressed: () {
                                      context.push('/forgot-password');
                                    },
                                    style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 0)),
                                    child: const Text('Forgot password?'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _passwordController,
                                obscureText: true,
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (_) => isLockedOut ? null : _submit(),
                                decoration: InputDecoration(
                                  hintText: '••••••••',
                                  errorText: _serverError,
                                ),
                                validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                                onChanged: (_) => setState(() => _serverError = null),
                              ),
                              const SizedBox(height: 40),

                              Consumer(builder: (context, ref, child) {
                                final authState = ref.watch(authNotifierProvider);
                                return SizedBox(
                                  height: 54,
                                  child: ElevatedButton(
                                    onPressed: (authState.isLoading || isLockedOut) ? null : _submit,
                                    child: authState.isLoading
                                        ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                        : const Text('Log In', style: TextStyle(fontSize: 16)),
                                  ),
                                );
                              }),
                              
                              const SizedBox(height: 32),
                              
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text("Don't have an account?", 
                                      style: Theme.of(context).textTheme.bodyMedium),
                                  const SizedBox(width: 8),
                                  TextButton(
                                    onPressed: () => context.push('/signup'),
                                    child: const Text('Sign Up'),
                                  ),
                                ],
                              )
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
    );
  }
}
