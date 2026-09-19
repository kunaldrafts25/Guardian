/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'package:flutter/material.dart';
import 'package:guardian/core/utils/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service to manage onboarding state
class OnboardingService extends ChangeNotifier {
  static const String _onboardingCompletedKey = 'onboarding_completed';

  bool _isOnboardingCompleted = false;

  /// Check if onboarding is completed
  bool get isOnboardingCompleted => _isOnboardingCompleted;

  /// Initialize onboarding service
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isOnboardingCompleted = prefs.getBool(_onboardingCompletedKey) ?? false;
      Logger.info(
          'Onboarding status: ${_isOnboardingCompleted ? 'completed' : 'not completed'}');
    } catch (e) {
      Logger.error('Error initializing onboarding service', e);
      _isOnboardingCompleted = false;
    }
  }

  /// Mark onboarding as completed
  Future<void> completeOnboarding() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_onboardingCompletedKey, true);
      _isOnboardingCompleted = true;
      notifyListeners();
      Logger.info('Onboarding marked as completed');
    } catch (e) {
      Logger.error('Error completing onboarding', e);
    }
  }

  /// Reset onboarding status (for testing)
  Future<void> resetOnboarding() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_onboardingCompletedKey, false);
      _isOnboardingCompleted = false;
      notifyListeners();
      Logger.info('Onboarding reset');
    } catch (e) {
      Logger.error('Error resetting onboarding', e);
    }
  }
}
