/*
 * Guardian 2.0 - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * 
 * OTP Verification Screen
 */

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../app/routes.dart';

class OtpVerificationScreen extends ConsumerStatefulWidget {
  final String phoneNumber;

  const OtpVerificationScreen({super.key, required this.phoneNumber});

  @override
  ConsumerState<OtpVerificationScreen> createState() =>
      _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends ConsumerState<OtpVerificationScreen> {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  String get _otp => _controllers.map((c) => c.text).join();

  void _onOtpChanged(int index, String value) {
    if (value.isNotEmpty && index < 5) {
      _focusNodes[index + 1].requestFocus();
    }
    if (_otp.length == 6) {
      _verifyOtp();
    }
  }

  void _onKeyPressed(int index, RawKeyEvent event) {
    if (event is RawKeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _controllers[index].text.isEmpty &&
        index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
  }

  Future<void> _verifyOtp() async {
    final success =
        await ref.read(phoneVerificationProvider.notifier).verifyOtp(_otp);
    if (success && mounted) {
      await _continueAfterVerification();
    }
  }

  Future<void> _continueAfterVerification() async {
    final profile = await ref.read(authServiceProvider).getUserProfile();
    if (!mounted) return;
    final displayName = profile?['display_name'] as String?;
    context.go(
      displayName == null || displayName.trim().isEmpty
          ? Routes.profileSetup
          : Routes.dashboard,
    );
  }

  void _resendOtp() {
    ref.read(phoneVerificationProvider.notifier).resendOtp(widget.phoneNumber);
  }

  @override
  Widget build(BuildContext context) {
    final verificationState = ref.watch(phoneVerificationProvider);
    final errorMessage =
        ref.read(phoneVerificationProvider.notifier).errorMessage;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify OTP'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 32),

              // Instructions
              Text(
                'Enter verification code',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'We sent a 6-digit code to\n${widget.phoneNumber}',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 36),

              // OTP Input Fields
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(6, (index) {
                  return SizedBox(
                    width: 48,
                    child: RawKeyboardListener(
                      focusNode: FocusNode(),
                      onKey: (event) => _onKeyPressed(index, event),
                      child: TextFormField(
                        controller: _controllers[index],
                        focusNode: _focusNodes[index],
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        maxLength: 1,
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                        decoration: InputDecoration(
                          counterText: '',
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 16),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide:
                                const BorderSide(color: AppColors.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                                color: AppColors.brand, width: 2),
                          ),
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        onChanged: (value) => _onOtpChanged(index, value),
                      ),
                    ),
                  );
                }),
              ),

              // Error Message
              if (verificationState == PhoneVerificationState.error &&
                  errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    errorMessage,
                    style: const TextStyle(
                      color: AppColors.emergency,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

              const SizedBox(height: 32),

              // Verify Button
              ElevatedButton(
                onPressed:
                    verificationState == PhoneVerificationState.verifying ||
                            _otp.length < 6
                        ? null
                        : _verifyOtp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brand,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: verificationState == PhoneVerificationState.verifying
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Verify & Continue'),
              ),

              const SizedBox(height: 24),

              // Resend
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Didn't receive the code? ",
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                  TextButton(
                    onPressed: _resendOtp,
                    child: const Text('Resend Code'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
