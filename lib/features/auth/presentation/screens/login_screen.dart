/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:guardian/core/constants/app_colors.dart';
import 'package:guardian/core/constants/app_strings.dart';
import 'package:guardian/core/widgets/custom_button.dart';
import 'package:guardian/core/widgets/custom_text_field.dart';
import 'package:guardian/features/auth/data/auth_repository.dart';
import 'package:guardian/features/auth/presentation/screens/signup_screen.dart';
import 'package:guardian/features/dashboard/presentation/screens/dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authRepository = AuthRepository();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final user = await _authRepository.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (mounted) {
        if (user != null) {
          // Normal login with Firebase Auth
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const DashboardScreen()),
          );
        } else if (kIsWeb) {
          // Development mode - direct login
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Development mode: Proceeding with direct login'),
              backgroundColor: AppColors.info,
            ),
          );

          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const DashboardScreen()),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Direct login for development
  Future<void> _directLogin() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _authRepository.directLogin();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Development mode: Direct login successful'),
            backgroundColor: AppColors.success,
          ),
        );

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Direct login failed: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _navigateToSignup() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SignupScreen()),
    );
  }

  void _forgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your email address'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    try {
      await _authRepository.resetPassword(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password reset email sent. Check your inbox.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Logo and app name
                  const Icon(
                    Icons.shield,
                    size: 80,
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    AppStrings.appName,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    AppStrings.appTagline,
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 48),

                  // Login form
                  CustomTextField(
                    label: AppStrings.email,
                    hint: 'Enter your email',
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    prefixIcon: const Icon(Icons.email),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your email';
                      }
                      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                          .hasMatch(value)) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  CustomTextField(
                    label: AppStrings.password,
                    hint: 'Enter your password',
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your password';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _forgotPassword,
                      child: const Text(AppStrings.forgotPassword),
                    ),
                  ),
                  const SizedBox(height: 24),
                  CustomButton(
                    text: AppStrings.login,
                    onPressed: _login,
                    isLoading: _isLoading,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        AppStrings.dontHaveAccount,
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                      TextButton(
                        onPressed: _navigateToSignup,
                        child: const Text(AppStrings.signup),
                      ),
                    ],
                  ),

                  // Only show direct login button in development mode
                  if (kIsWeb) ...[
                    const SizedBox(height: 32),
                    const Divider(),
                    const SizedBox(height: 16),
                    const Text(
                      'Development Options',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    CustomButton(
                      text: 'Direct Login (Development Only)',
                      onPressed: _directLogin,
                      isLoading: false,
                      type: ButtonType.secondary,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
