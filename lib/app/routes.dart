/*
 * Guardian 2.0 - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * 
 * Route Constants
 */

/// Application route paths
abstract class Routes {
  // Initial
  static const splash = '/';
  static const onboarding = '/onboarding';

  // Auth
  static const login = '/auth/login';
  static const otpVerification = '/auth/login/otp';
  static const profileSetup = '/auth/login/profile-setup';

  // Main
  static const dashboard = '/dashboard';
  static const emergency = '/emergency';
  static const contacts = '/contacts';
  static const map = '/map';
  static const settings = '/settings';
  static const sosSettings = '/settings/sos';
  static const profile = '/profile';

  // Features
  static const safeZones = '/safe-zones';
  static const trustProfile = '/trust';
  static const safeSpots = '/safe-spots';
  static const quickActions = '/quick-actions';
}
