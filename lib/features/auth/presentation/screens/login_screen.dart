import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:guardian/app/routes.dart';
import 'package:guardian/app/theme/app_theme.dart';
import 'package:guardian/core/providers/auth_provider.dart';

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  Future<void> _handleGoogleSignIn(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final success = await ref.read(googleSignInStateProvider.notifier).signIn();
    if (!context.mounted) return;
    if (success) {
      context.go(Routes.dashboard);
      return;
    }
    final error = ref.read(googleSignInStateProvider.notifier).errorMessage;
    if (error != null && error.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final googleState = ref.watch(googleSignInStateProvider);
    final isGoogleLoading = googleState == GoogleSignInState.authenticating;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
                  'Sign in securely with your Google account.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 36),
                SizedBox(
                  height: 52,
                  child: OutlinedButton(
                    onPressed: isGoogleLoading
                        ? null
                        : () => _handleGoogleSignIn(context, ref),
                    style: OutlinedButton.styleFrom(
                      backgroundColor:
                          isDark ? const Color(0xFF18201C) : Colors.white,
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
                              _GoogleIcon(isDark: isDark),
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
                const SizedBox(height: 32),
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
                          'Phone OTP sign-in is not used. Emergency contact phone numbers are separate from account authentication.',
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
    );
  }
}

class _GoogleIcon extends StatelessWidget {
  final bool isDark;
  const _GoogleIcon({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      height: 20,
      child: CustomPaint(painter: _GoogleIconPainter()),
    );
  }
}

class _GoogleIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final center = Offset(w / 2, h / 2);
    final radius = w / 2;

    final redPaint = Paint()..color = const Color(0xFFEA4335);
    final bluePaint = Paint()..color = const Color(0xFF4285F4);
    final yellowPaint = Paint()..color = const Color(0xFFFBBC05);
    final greenPaint = Paint()..color = const Color(0xFF34A853);

    canvas.drawPath(
      Path()
        ..moveTo(center.dx, center.dy)
        ..lineTo(w, center.dy)
        ..arcTo(
          Rect.fromCircle(center: center, radius: radius),
          0,
          -0.85,
          false,
        )
        ..close(),
      bluePaint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(center.dx, center.dy)
        ..arcTo(
          Rect.fromCircle(center: center, radius: radius),
          -0.85,
          -1.8,
          false,
        )
        ..close(),
      redPaint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(center.dx, center.dy)
        ..arcTo(
          Rect.fromCircle(center: center, radius: radius),
          -2.65,
          -1.3,
          false,
        )
        ..close(),
      yellowPaint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(center.dx, center.dy)
        ..arcTo(
          Rect.fromCircle(center: center, radius: radius),
          -3.95,
          -1.5,
          false,
        )
        ..close(),
      greenPaint,
    );

    canvas.drawCircle(center, radius * 0.58, Paint()..color = Colors.white);
    canvas.drawRect(
      Rect.fromLTRB(w * 0.45, h * 0.38, w * 0.95, h * 0.62),
      bluePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
