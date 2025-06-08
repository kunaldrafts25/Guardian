/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:guardian/core/constants/app_colors.dart';
import 'package:guardian/core/constants/app_strings.dart';
import 'package:guardian/core/utils/page_transitions.dart';
import 'package:guardian/features/auth/data/auth_repository.dart';
import 'package:guardian/features/auth/presentation/screens/login_screen.dart';
import 'package:guardian/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:guardian/features/onboarding/data/onboarding_service.dart';
import 'package:guardian/features/onboarding/presentation/screens/onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  final _authRepository = AuthRepository();

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _checkAuthAndNavigate();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    _animationController.forward();
  }

  Future<void> _checkAuthAndNavigate() async {
    // Delay for at least 2 seconds to show splash screen
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    // Check if onboarding is completed
    final onboardingService = Provider.of<OnboardingService>(context, listen: false);
    final isOnboardingCompleted = onboardingService.isOnboardingCompleted;

    if (!isOnboardingCompleted) {
      // Navigate to onboarding screen
      Navigator.of(context).pushReplacement(
        PageTransitions.fadeSlide(
          page: const OnboardingScreen(),
          direction: SlideDirection.fromRight,
        ),
      );
      return;
    }

    // Check if user is logged in
    final user = _authRepository.currentUser;

    if (user != null) {
      // User is logged in, navigate to dashboard
      Navigator.of(context).pushReplacement(
        PageTransitions.fadeSlide(
          page: const DashboardScreen(),
          direction: SlideDirection.fromRight,
        ),
      );
    } else {
      // User is not logged in, navigate to login screen
      Navigator.of(context).pushReplacement(
        PageTransitions.fadeSlide(
          page: const LoginScreen(),
          direction: SlideDirection.fromRight,
        ),
      );
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // App Icon
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.shield,
                        size: 80,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // App Name
                    const Text(
                      AppStrings.appName,
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // App Tagline
                    const Text(
                      AppStrings.appTagline,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 48),

                    // Loading Indicator
                    const SizedBox(
                      width: 40,
                      height: 40,
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        strokeWidth: 3,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
