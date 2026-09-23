/*
 * Guardian - Mobile Safety App
 * Onboarding Screen - Truthful Safety Capabilities & Boundaries
 */

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:guardian/app/routes.dart';
import 'package:guardian/app/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingPage> _pages = [
    OnboardingPage(
      title: 'Welcome to Guardian',
      description:
          'A reliable personal safety companion built for durable SOS alerts, trusted contact escalation, and verified evidence capture.',
      svgAsset: 'assets/icons/guardian_symbol.svg',
      color: AppColors.brand,
    ),
    OnboardingPage(
      title: 'Durable SOS & Telemetry',
      description:
          'When activated, Guardian captures high-accuracy GPS coordinates, sensor evidence, and initiates multi-channel contact notification.',
      icon: Icons.emergency_rounded,
      color: AppColors.emergency,
    ),
    OnboardingPage(
      title: 'Truthful Boundaries',
      description:
          'Guardian does not guarantee municipal police response. Telemetry delivery depends on cellular reception, battery levels, and carrier networks.',
      icon: Icons.fact_check_outlined,
      color: AppColors.warning,
    ),
    OnboardingPage(
      title: 'Location Privacy by Default',
      description:
          'Your location is never broadcast in the background. Coordinates are only shared when you deliberately trigger an emergency SOS.',
      icon: Icons.lock_outline_rounded,
      color: AppColors.brand,
    ),
    OnboardingPage(
      title: 'Your Trusted Circle',
      description:
          'Set up to 5 trusted emergency contacts. Guardian alerts your primary contact first and keeps a durable evidence audit trail.',
      icon: Icons.people_outline_rounded,
      color: AppColors.secondaryAccent,
    ),
    OnboardingPage(
      title: 'Continuous Readiness',
      description:
          'On-device diagnostics actively monitor your permissions, foreground safety service, and battery settings for uninterrupted protection.',
      icon: Icons.verified_user_outlined,
      color: AppColors.success,
    ),
  ];

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete', true);
    if (mounted) {
      context.go(Routes.login);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Skip Button
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: _completeOnboarding,
                child: const Text('Skip'),
              ),
            ),

            // Page View
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  final page = _pages[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: page.color.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: page.color.withValues(alpha: 0.25),
                              width: 2,
                            ),
                          ),
                          child: page.svgAsset != null
                              ? Padding(
                                  padding: const EdgeInsets.all(22.0),
                                  child: SvgPicture.asset(
                                    Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? 'assets/icons/guardian_symbol_dark.svg'
                                        : page.svgAsset!,
                                    fit: BoxFit.contain,
                                  ),
                                )
                              : Icon(
                                  page.icon,
                                  size: 56,
                                  color: page.color,
                                ),
                        ),
                        const SizedBox(height: 36),
                        Text(
                          page.title,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 14),
                        Text(
                          page.description,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppColors.textSecondary,
                                    height: 1.45,
                                  ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Page Indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_pages.length, (index) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentPage == index ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _currentPage == index
                        ? AppColors.brand
                        : AppColors.border,
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),

            const SizedBox(height: 28),

            // Next / Get Started Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _nextPage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    _currentPage == _pages.length - 1
                        ? 'Get Started'
                        : 'Continue',
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class OnboardingPage {
  final String title;
  final String description;
  final IconData? icon;
  final String? svgAsset;
  final Color color;

  OnboardingPage({
    required this.title,
    required this.description,
    this.icon,
    this.svgAsset,
    required this.color,
  });
}
