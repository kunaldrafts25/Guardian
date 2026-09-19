import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:guardian/app/routes.dart';
import 'package:guardian/app/theme/app_theme.dart';
import 'package:guardian/core/providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  String _normalizedPhone() {
    final input = _phoneController.text.replaceAll(RegExp(r'[\s()-]'), '');
    return input.startsWith('+') ? input : '+91$input';
  }

  Future<void> _sendOtp() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final phone = _normalizedPhone();
    final sent =
        await ref.read(phoneVerificationProvider.notifier).sendOtp(phone);
    if (!mounted) return;
    if (sent) {
      context.push(Routes.otpVerification, extra: phone);
      return;
    }
    final message = ref.read(phoneVerificationProvider.notifier).errorMessage ??
        'Unable to send the verification code.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(phoneVerificationProvider);
    final loading = state == PhoneVerificationState.verifying;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.shield, size: 80, color: AppColors.primary),
                  const SizedBox(height: 24),
                  Text(
                    'Welcome to Guardian',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sign in securely with a one-time code sent by AWS Cognito.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .bodyLarge
                        ?.copyWith(color: Colors.grey),
                  ),
                  const SizedBox(height: 40),
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    autofillHints: const [AutofillHints.telephoneNumber],
                    decoration: const InputDecoration(
                      labelText: 'Mobile number',
                      hintText: '+91 98765 43210',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                    validator: (value) {
                      final normalized =
                          (value ?? '').replaceAll(RegExp(r'[\s()-]'), '');
                      if (!RegExp(r'^\+?[0-9]{10,15}$').hasMatch(normalized)) {
                        return 'Enter a valid mobile number with country code.';
                      }
                      return null;
                    },
                    onFieldSubmitted: loading ? null : (_) => _sendOtp(),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: loading ? null : _sendOtp,
                    child: loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Send verification code'),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'New users are securely registered during phone verification.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
