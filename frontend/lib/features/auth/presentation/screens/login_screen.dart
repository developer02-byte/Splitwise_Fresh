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
  bool _isSignUp = false;
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  void _toggleMode() {
    setState(() => _isSignUp = !_isSignUp);
    _passwordController.clear();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    final auth = ref.read(authNotifierProvider.notifier);
    
    try {
      if (_isSignUp) {
        await auth.register(
            _nameController.text.trim(),
            _emailController.text.trim(),
            _passwordController.text);
      } else {
        await auth.login(_emailController.text.trim(), _passwordController.text);
      }
      
      if (mounted) context.go('/dashboard');
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: AppColors.error, content: Text(e.toString().replaceAll('Exception: ', ''))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 900;
    
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
                          _isSignUp ? 'Create an account' : 'Welcome back',
                          style: Theme.of(context).textTheme.displayMedium?.copyWith(fontSize: 32),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _isSignUp ? 'Sign up to start splitting expenses.' : 'Log in to view your ledger.',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 48),

                        Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (_isSignUp) ...[
                                _buildLabel('Full Name'),
                                TextFormField(
                                  controller: _nameController,
                                  decoration: const InputDecoration(hintText: 'John Appleseed'),
                                  validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                                ),
                                const SizedBox(height: 20),
                              ],
                              _buildLabel('Email Address'),
                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                decoration: const InputDecoration(hintText: 'name@example.com'),
                                validator: (value) {
                                  if (value == null || value.isEmpty) return 'Required';
                                  if (!value.contains('@')) return 'Enter a valid email';
                                  return null;
                                },
                              ),
                              const SizedBox(height: 20),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  _buildLabel('Password'),
                                  if (!_isSignUp)
                                    TextButton(
                                      onPressed: () {},
                                      style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 0)),
                                      child: const Text('Forgot password?'),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _passwordController,
                                obscureText: true,
                                decoration: const InputDecoration(hintText: '••••••••'),
                                validator: (value) => value == null || value.length < 6 ? 'Min 6 characters' : null,
                              ),
                              const SizedBox(height: 40),

                              Consumer(builder: (context, ref, child) {
                                final authState = ref.watch(authNotifierProvider);
                                return SizedBox(
                                  height: 54,
                                  child: ElevatedButton(
                                    onPressed: authState.isLoading ? null : _submit,
                                    child: authState.isLoading
                                        ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                        : Text(_isSignUp ? 'Create Account' : 'Log In', style: const TextStyle(fontSize: 16)),
                                  ),
                                );
                              }),
                              
                              const SizedBox(height: 32),
                              
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(_isSignUp ? "Already have an account?" : "Don't have an account?", 
                                      style: Theme.of(context).textTheme.bodyMedium),
                                  const SizedBox(width: 8),
                                  TextButton(
                                    onPressed: _toggleMode,
                                    child: Text(_isSignUp ? 'Log In' : 'Sign Up'),
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
