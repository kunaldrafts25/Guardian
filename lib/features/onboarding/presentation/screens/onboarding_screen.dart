/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:guardian/core/constants/app_colors.dart';
import 'package:guardian/core/constants/app_typography.dart';
import 'package:guardian/core/utils/page_transitions.dart';
import 'package:guardian/core/widgets/custom_button.dart';
import 'package:guardian/features/onboarding/data/onboarding_page_model.dart';
import 'package:guardian/features/onboarding/presentation/screens/language_selection_screen.dart';
import 'package:guardian/features/onboarding/presentation/widgets/onboarding_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isLastPage = false;

  @override
  void initState() {
    super.initState();
    _isLastPage = _currentPage == onboardingPages.length - 1;
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int page) {
    HapticFeedback.lightImpact();
    setState(() {
      _currentPage = page;
      _isLastPage = _currentPage == onboardingPages.length - 1;
    });
  }

  void _nextPage() {
    if (_isLastPage) {
      _completeOnboarding();
    } else {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _skipOnboarding() {
    _completeOnboarding();
  }

  Future<void> _completeOnboarding() async {
    // Mark onboarding as completed
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);

    if (!mounted) return;

    // Navigate to language selection screen
    Navigator.of(context).pushReplacement(
      PageTransitions.fadeSlide(
        page: const LanguageSelectionScreen(),
        direction: SlideDirection.fromBottom,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            if (!_isLastPage)
              Align(
                alignment: Alignment.topRight,
                child: TextButton(
                  onPressed: _skipOnboarding,
                  child: Text(
                    'Skip',
                    style: AppTypography.buttonMedium.copyWith(
                      color: AppColors.secondary,
                    ),
                  ),
                ),
              ),

            // Page content
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                itemCount: onboardingPages.length,
                itemBuilder: (context, index) {
                  return OnboardingPage(
                    pageModel: onboardingPages[index],
                  );
                },
              ),
            ),

            // Page indicator and buttons
            Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Page indicator
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      onboardingPages.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        height: 8,
                        width: _currentPage == index ? 24 : 8,
                        decoration: BoxDecoration(
                          color: _currentPage == index
                              ? AppColors.primary
                              : AppColors.secondary.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Next/Get Started button
                  CustomButton(
                    text: _isLastPage ? 'Get Started' : 'Next',
                    onPressed: _nextPage,
                    type: ButtonType.primary,
                    isFullWidth: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
