import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../providers/auth_provider.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  String? _serverError;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  double _calculatePasswordStrength(String password) {
    if (password.isEmpty) return 0;
    double strength = 0;
    if (password.length >= 8) strength += 0.25;
    if (RegExp(r'[A-Z]').hasMatch(password)) strength += 0.25;
    if (RegExp(r'[0-9]').hasMatch(password)) strength += 0.25;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(password)) strength += 0.25;
    return strength;
  }

  Color _getPasswordStrengthColor(double strength) {
    if (strength <= 0.25) return Colors.red;
    if (strength <= 0.5) return Colors.orange;
    if (strength <= 0.75) return Colors.blue;
    return Colors.green;
  }

  Future<void> _submit() async {
    setState(() { _serverError = null; });
    if (!_formKey.currentState!.validate()) return;
    
    final auth = ref.read(authNotifierProvider.notifier);
    
    try {
      await auth.register(
        _nameController.text.trim(),
        _emailController.text.trim(),
        _passwordController.text
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.success, 
            content: Text('Account created successfully!')
          ),
        );
        context.go('/dashboard');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _serverError = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 900;
    
    return Scaffold(
      appBar: isDesktop ? null : AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
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
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Create an account',
                          style: Theme.of(context).textTheme.displayMedium?.copyWith(fontSize: 32),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Sign up to start splitting expenses.',
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
                        
                        if (!kIsWeb && Theme.of(context).platform == TargetPlatform.iOS) ...[
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
                              _buildLabel('Full Name'),
                              TextFormField(
                                controller: _nameController,
                                autofocus: true,
                                textInputAction: TextInputAction.next,
                                decoration: const InputDecoration(hintText: 'John Appleseed'),
                                validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                              ),
                              const SizedBox(height: 20),
                              
                              _buildLabel('Email Address'),
                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                decoration: InputDecoration(
                                  hintText: 'name@example.com',
                                  errorText: _serverError != null && _serverError!.contains('Email') ? _serverError : null,
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) return 'Required';
                                  if (!_isValidEmail(value)) return 'Enter a valid email';
                                  return null;
                                },
                                onChanged: (_) => setState(() => _serverError = null),
                              ),
                              const SizedBox(height: 20),
                              
                              _buildLabel('Password'),
                              TextFormField(
                                controller: _passwordController,
                                obscureText: true,
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (_) => _submit(),
                                decoration: InputDecoration(
                                  hintText: '••••••••',
                                  errorText: _serverError != null && !_serverError!.contains('Email') ? _serverError : null,
                                ),
                                onChanged: (value) {
                                  setState(() => _serverError = null);
                                },
                                validator: (value) {
                                  if (value == null || value.length < 8) return 'Min 8 characters';
                                  if (!RegExp(r'(?=.*[A-Za-z])(?=.*\d)').hasMatch(value)) {
                                    return 'Must contain at least one letter and one number';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 8),
                              
                              // Password Strength Meter
                              if (_passwordController.text.isNotEmpty) ...[
                                LinearProgressIndicator(
                                  value: _calculatePasswordStrength(_passwordController.text),
                                  backgroundColor: Colors.grey.shade300,
                                  color: _getPasswordStrengthColor(_calculatePasswordStrength(_passwordController.text)),
                                  minHeight: 4,
                                ),
                                const SizedBox(height: 4),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: Text(
                                    _calculatePasswordStrength(_passwordController.text) <= 0.25 ? 'Weak' :
                                    _calculatePasswordStrength(_passwordController.text) <= 0.5 ? 'Fair' :
                                    _calculatePasswordStrength(_passwordController.text) <= 0.75 ? 'Good' : 'Strong',
                                    style: TextStyle(
                                      fontSize: 12, 
                                      color: _getPasswordStrengthColor(_calculatePasswordStrength(_passwordController.text))
                                    ),
                                  ),
                                ),
                              ],

                              const SizedBox(height: 40),

                              Consumer(builder: (context, ref, child) {
                                final authState = ref.watch(authNotifierProvider);
                                return SizedBox(
                                  height: 54,
                                  child: ElevatedButton(
                                    onPressed: authState.isLoading ? null : _submit,
                                    child: authState.isLoading
                                        ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                        : const Text('Create Account', style: TextStyle(fontSize: 16)),
                                  ),
                                );
                              }),
                              
                              const SizedBox(height: 32),
                              
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text("Already have an account?", 
                                      style: Theme.of(context).textTheme.bodyMedium),
                                  const SizedBox(width: 8),
                                  TextButton(
                                    onPressed: () {
                                      if (isDesktop) {
                                        context.go('/login');
                                      } else {
                                        context.pop();
                                      }
                                    },
                                    child: const Text('Log In'),
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
