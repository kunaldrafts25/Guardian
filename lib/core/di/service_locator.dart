/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'package:get_it/get_it.dart';
import 'package:guardian/core/services/mock_data_service.dart';
import 'package:guardian/core/services/mock_auth_service.dart';
import 'package:guardian/core/services/maps_service.dart';
import 'package:guardian/core/services/theme_service.dart';
import 'package:guardian/core/services/language_service.dart';
import 'package:guardian/core/services/connectivity_service.dart';
import 'package:guardian/core/services/ai_service.dart';
import 'package:guardian/core/services/safety_notification_manager.dart';
import 'package:guardian/features/auth/data/auth_repository.dart';
import 'package:guardian/features/onboarding/data/onboarding_service.dart';
import 'package:guardian/features/emergency/data/mock_emergency_repository.dart';
import 'package:guardian/features/profile/data/mock_profile_repository.dart';
import 'package:guardian/features/store/data/mock_store_repository.dart';
import 'package:guardian/features/community/data/mock_community_repository.dart';
import 'package:guardian/features/guardian_mode/data/guardian_repository.dart';
import 'package:guardian/features/guardian_circle/data/guardian_circle_repository.dart';
// SafeZoneRepository removed - using SafeZoneProvider instead
import 'package:guardian/features/ai_assistant/data/ai_repository.dart';
import 'package:guardian/features/voice_commands/data/voice_command_service.dart';
import 'package:guardian/features/ngo_integration/data/ngo_repository.dart';
import 'package:guardian/features/incident_reporting/data/incident_repository.dart';

/// Global ServiceLocator instance
final sl = GetIt.instance;

/// Initialize the Service Locator with all dependencies
Future<void> setupServiceLocator() async {
  // Core services
  sl.registerLazySingleton<ThemeService>(() => ThemeService());
  sl.registerLazySingleton<LanguageService>(() => LanguageService());
  sl.registerLazySingleton<ConnectivityService>(() => ConnectivityService());
  sl.registerLazySingleton<AIService>(() => AIService());
  sl.registerLazySingleton<SafetyNotificationManager>(
      () => SafetyNotificationManager());

  // Mock data services (replacing Firebase)
  await MockDataService.initialize();
  await MockAuthService.initialize();

  // Location and maps services
  // LocationService has only static methods, no need to register it
  sl.registerLazySingleton<MapsService>(() => MapsService());

  // Feature repositories
  sl.registerLazySingleton<AuthRepository>(() => AuthRepository());
  sl.registerLazySingleton<OnboardingService>(() => OnboardingService());
  sl.registerLazySingleton<EmergencyRepository>(() => EmergencyRepository());
  sl.registerLazySingleton<ProfileRepository>(() => ProfileRepository());
  sl.registerLazySingleton<StoreRepository>(() => StoreRepository());
  sl.registerLazySingleton<CommunityRepository>(() => CommunityRepository());
  sl.registerLazySingleton<GuardianRepository>(() => GuardianRepository());
  sl.registerLazySingleton<GuardianCircleRepository>(
      () => GuardianCircleRepository());
  // SafeZone uses Riverpod provider instead of service locator
  sl.registerLazySingleton<AIRepository>(() => AIRepository());
  sl.registerLazySingleton<VoiceCommandService>(() => VoiceCommandService());
  sl.registerLazySingleton<NGORepository>(() => NGORepository());
  sl.registerLazySingleton<IncidentRepository>(() => IncidentRepository());
}

/// Reset the Service Locator (useful for testing)
void resetServiceLocator() {
  sl.reset();
}

/// Register test dependencies
void setupTestServiceLocator({
  ThemeService? themeService,
  LanguageService? languageService,
  ConnectivityService? connectivityService,
  MapsService? mapsService,
  AuthRepository? authRepository,
  OnboardingService? onboardingService,
  EmergencyRepository? emergencyRepository,
  ProfileRepository? profileRepository,
  StoreRepository? storeRepository,
  CommunityRepository? communityRepository,
}) {
  // Core services
  sl.registerLazySingleton<ThemeService>(() => themeService ?? ThemeService());
  sl.registerLazySingleton<LanguageService>(
      () => languageService ?? LanguageService());
  sl.registerLazySingleton<ConnectivityService>(
      () => connectivityService ?? ConnectivityService());
  sl.registerLazySingleton<AIService>(() => AIService());
  sl.registerLazySingleton<SafetyNotificationManager>(
      () => SafetyNotificationManager());

  // Mock services (no need to register them as they use static methods)

  // Location and maps services
  // LocationService has only static methods, no need to register it
  sl.registerLazySingleton<MapsService>(() => mapsService ?? MapsService());

  // Feature repositories
  sl.registerLazySingleton<AuthRepository>(
      () => authRepository ?? AuthRepository());
  sl.registerLazySingleton<OnboardingService>(
      () => onboardingService ?? OnboardingService());
  sl.registerLazySingleton<EmergencyRepository>(
      () => emergencyRepository ?? EmergencyRepository());
  sl.registerLazySingleton<ProfileRepository>(
      () => profileRepository ?? ProfileRepository());
  sl.registerLazySingleton<StoreRepository>(
      () => storeRepository ?? StoreRepository());
  sl.registerLazySingleton<CommunityRepository>(
      () => communityRepository ?? CommunityRepository());
  sl.registerLazySingleton<GuardianRepository>(() => GuardianRepository());
  sl.registerLazySingleton<GuardianCircleRepository>(
      () => GuardianCircleRepository());
  // SafeZone uses Riverpod provider instead of service locator
  sl.registerLazySingleton<AIRepository>(() => AIRepository());
  sl.registerLazySingleton<VoiceCommandService>(() => VoiceCommandService());
  sl.registerLazySingleton<NGORepository>(() => NGORepository());
  sl.registerLazySingleton<IncidentRepository>(() => IncidentRepository());
}
