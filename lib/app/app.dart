/*
 * Guardian — Main Application Widget
 */

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:guardian/app/router/app_router.dart';
import 'package:guardian/app/theme/app_theme.dart';
import 'package:guardian/core/providers/settings_provider.dart';
import 'package:guardian/core/providers/sos_trigger_provider.dart';
import 'package:guardian/core/services/offline_sync_service.dart';

class GuardianApp extends ConsumerStatefulWidget {
  /// Global navigator key — required for FCM notification-tap navigation
  final GlobalKey<NavigatorState>? navigatorKey;

  const GuardianApp({super.key, this.navigatorKey});

  @override
  ConsumerState<GuardianApp> createState() => _GuardianAppState();
}

class _GuardianAppState extends ConsumerState<GuardianApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Initialize shake-detection SOS trigger
      ref.read(sosTriggerProvider);
      // Start offline sync watcher — sends queued alerts when connectivity returns
      ref.read(offlineSyncProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);

    return MaterialApp.router(
      title: 'Guardian',
      debugShowCheckedModeBanner: false,

      // Theme
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,

      // Routing
      routerConfig: router,

      // Localization
      locale: locale,
      supportedLocales: const [
        Locale('en', 'US'),
        Locale('hi', 'IN'),
        Locale('ta', 'IN'),
        Locale('te', 'IN'),
        Locale('bn', 'IN'),
        Locale('mr', 'IN'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
