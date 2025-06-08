/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:guardian/core/constants/app_strings.dart';
import 'package:guardian/core/di/service_locator.dart';
import 'package:guardian/core/localization/app_localizations.dart';
import 'package:guardian/core/services/analytics_service.dart';
import 'package:guardian/core/services/connectivity_service.dart';
import 'package:guardian/core/services/language_service.dart';
import 'package:guardian/core/services/safety_notification_manager.dart';
import 'package:guardian/core/services/theme_service.dart';
import 'package:guardian/core/utils/logger.dart';
import 'package:guardian/features/onboarding/data/onboarding_service.dart';
import 'package:guardian/features/splash/presentation/screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Initialize service locator
    await setupServiceLocator();

    // Initialize analytics
    await AnalyticsService.init();

    // Initialize services
    final themeService = sl<ThemeService>();
    await themeService.init();

    final languageService = sl<LanguageService>();
    await languageService.init();

    final connectivityService = sl<ConnectivityService>();
    connectivityService.init();

    final onboardingService = sl<OnboardingService>();
    await onboardingService.init();

    // Initialize safety notification manager
    final safetyManager = sl<SafetyNotificationManager>();
    await safetyManager.initialize();

    // Run the app
    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ThemeService>.value(value: themeService),
          ChangeNotifierProvider<LanguageService>.value(value: languageService),
          ChangeNotifierProvider<ConnectivityService>.value(
              value: connectivityService),
          ChangeNotifierProvider<OnboardingService>.value(
              value: onboardingService),
        ],
        child: const MyApp(),
      ),
    );
  } catch (e) {
    Logger.error('Error initializing app', e);
    // Run app with minimal services if initialization fails
    runApp(const MaterialApp(home: SplashScreen()));
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);
    final languageService = Provider.of<LanguageService>(context);

    return MaterialApp(
      title: AppStrings.appName,
      theme: themeService.themeData,
      locale: languageService.locale,
      supportedLocales: languageService.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      navigatorObservers: [
        if (AnalyticsService.observer != null) AnalyticsService.observer!,
      ],
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
