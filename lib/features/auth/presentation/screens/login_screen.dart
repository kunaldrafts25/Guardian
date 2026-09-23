import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
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

  Future<void> _handleGoogleSignIn() async {
    final success =
        await ref.read(googleSignInStateProvider.notifier).signIn();
    if (!mounted) return;
    if (success) {
      context.go(Routes.dashboard);
      return;
    }
    final error = ref.read(googleSignInStateProvider.notifier).errorMessage;
    if (error != null && error.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final phoneState = ref.watch(phoneVerificationProvider);
    final googleState = ref.watch(googleSignInStateProvider);
    final isPhoneLoading = phoneState == PhoneVerificationState.verifying;
    final isGoogleLoading = googleState == GoogleSignInState.authenticating;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Brand Logo Mark
                  Center(
                    child: Container(
                      width: 76,
                      height: 76,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.brandContainerDark.withValues(alpha: 0.5)
                            : AppColors.brandContainer.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: isDark ? AppColors.borderDark : AppColors.border,
                          width: 1.2,
                        ),
                      ),
                      child: SvgPicture.asset(
                        isDark
                            ? 'assets/icons/guardian_symbol_dark.svg'
                            : 'assets/icons/guardian_symbol.svg',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Header Titles
                  Text(
                    'Welcome to Guardian',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Durable protection and peace of mind.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 36),

                  // ─── Primary Google Sign-In Button ───
                  SizedBox(
                    height: 52,
                    child: OutlinedButton(
                      onPressed: (isGoogleLoading || isPhoneLoading)
                          ? null
                          : _handleGoogleSignIn,
                      style: OutlinedButton.styleFrom(
                        backgroundColor: isDark
                            ? const Color(0xFF18201C)
                            : Colors.white,
                        side: const BorderSide(
                          color: AppColors.border,
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      child: isGoogleLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: AppColors.brand,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _buildGoogleIcon(),
                                const SizedBox(width: 12),
                                Text(
                                  'Continue with Google',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.onSurface,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // ─── Visual Divider ───
                  const Row(
                    children: [
                      Expanded(
                        child: Divider(color: AppColors.divider, thickness: 1),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 14),
                        child: Text(
                          'OR CONTINUE WITH PHONE',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Divider(color: AppColors.divider, thickness: 1),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // ─── Phone Number Input Field ───
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    autofillHints: const [AutofillHints.telephoneNumber],
                    decoration: InputDecoration(
                      labelText: 'Mobile number',
                      hintText: '+91 98765 43210',
                      prefixIcon: const Icon(Icons.phone_outlined,
                          color: AppColors.brand),
                      filled: true,
                      fillColor: isDark
                          ? const Color(0xFF18201C)
                          : const Color(0xFFF7F5EF),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(
                            color: AppColors.brand, width: 1.8),
                      ),
                    ),
                    validator: (value) {
                      final normalized =
                          (value ?? '').replaceAll(RegExp(r'[\s()-]'), '');
                      if (!RegExp(r'^\+?[0-9]{10,15}$').hasMatch(normalized)) {
                        return 'Enter a valid mobile number with country code.';
                      }
                      return null;
                    },
                    onFieldSubmitted:
                        (isPhoneLoading || isGoogleLoading) ? null : (_) => _sendOtp(),
                  ),
                  const SizedBox(height: 16),

                  // ─── Send Verification Code Button ───
                  SizedBox(
                    height: 52,
                    child: FilledButton(
                      onPressed:
                          (isPhoneLoading || isGoogleLoading) ? null : _sendOtp,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.brand,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                      ),
                      child: isPhoneLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Send verification code'),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // ─── Truthful Boundaries Disclaimer ───
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF18201C)
                          : const Color(0xFFEEF1EC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.border.withValues(alpha: 0.6),
                        width: 1,
                      ),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 18,
                          color: AppColors.textSecondary,
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Guardian provides durable telemetry and trusted contact escalation. It does not guarantee municipal police dispatch.',
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.4,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
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

  Widget _buildGoogleIcon() {
    return SizedBox(
      width: 20,
      height: 20,
      child: CustomPaint(
        painter: _GoogleIconPainter(),
      ),
    );
  }
}

class _GoogleIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    final redPaint = Paint()..color = const Color(0xFFEA4335);
    final bluePaint = Paint()..color = const Color(0xFF4285F4);
    final yellowPaint = Paint()..color = const Color(0xFFFBBC05);
    final greenPaint = Paint()..color = const Color(0xFF34A853);

    final center = Offset(w / 2, h / 2);
    final radius = w / 2;

    final bluePath = Path()
      ..moveTo(center.dx, center.dy)
      ..lineTo(w, center.dy)
      ..arcTo(Rect.fromCircle(center: center, radius: radius), 0, -0.85, false)
      ..close();
    canvas.drawPath(bluePath, bluePaint);

    final redPath = Path()
      ..moveTo(center.dx, center.dy)
      ..arcTo(Rect.fromCircle(center: center, radius: radius), -0.85, -1.8, false)
      ..close();
    canvas.drawPath(redPath, redPaint);

    final yellowPath = Path()
      ..moveTo(center.dx, center.dy)
      ..arcTo(Rect.fromCircle(center: center, radius: radius), -2.65, -1.3, false)
      ..close();
    canvas.drawPath(yellowPath, yellowPaint);

    final greenPath = Path()
      ..moveTo(center.dx, center.dy)
      ..arcTo(Rect.fromCircle(center: center, radius: radius), -3.95, -1.5, false)
      ..close();
    canvas.drawPath(greenPath, greenPaint);

    final innerPaint = Paint()..color = Colors.white;
    canvas.drawCircle(center, radius * 0.58, innerPaint);

    final barRect = Rect.fromLTRB(w * 0.45, h * 0.38, w * 0.95, h * 0.62);
    canvas.drawRect(barRect, bluePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
