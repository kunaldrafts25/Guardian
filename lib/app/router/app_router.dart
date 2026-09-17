/*
 * Guardian 2.0 - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * 
 * Application Router Configuration
 */

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:guardian/app/routes.dart';
import 'package:guardian/core/providers/auth_provider.dart';

// Splash Screen
import 'package:guardian/features/splash/presentation/screens/splash_screen.dart';

// Auth Screens
import 'package:guardian/features/auth/presentation/screens/login_screen.dart';
import 'package:guardian/features/auth/presentation/screens/signup_screen.dart';
import 'package:guardian/features/auth/presentation/screens/otp_verification_screen.dart';
import 'package:guardian/features/auth/presentation/screens/profile_setup_screen.dart';

// Onboarding
import 'package:guardian/features/onboarding/presentation/screens/onboarding_screen.dart';

// Main Screens
import 'package:guardian/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:guardian/features/emergency/presentation/screens/emergency_screen.dart';
import 'package:guardian/features/contacts/presentation/screens/contacts_screen.dart';
import 'package:guardian/features/map/presentation/screens/map_screen.dart';
import 'package:guardian/features/settings/presentation/screens/settings_screen.dart';
import 'package:guardian/features/profile/presentation/screens/profile_screen.dart';
import 'package:guardian/features/safezone/presentation/screens/safe_zones_screen.dart';
import 'package:guardian/features/quickactions/presentation/screens/quick_actions_screen.dart';
import 'package:guardian/features/settings/presentation/screens/sos_settings_screen.dart';

/// Provider for the app router
final appRouterProvider = Provider<GoRouter>((ref) {
  // Watch auth state for redirect decisions
  final authState = ref.watch(authStateProvider);
  
  return GoRouter(
    initialLocation: Routes.dashboard,
    debugLogDiagnostics: false, // Never log routes in production (contains sensitive navigation)
    
    // Redirect logic based on auth state
    redirect: (context, state) {
      final isLoggedIn = authState.valueOrNull != null;
      final isGoingToAuth = state.matchedLocation.startsWith('/auth');
      final isGoingToSplash = state.matchedLocation == Routes.splash;
      final isGoingToOnboarding = state.matchedLocation == Routes.onboarding;
      final isGoingToDashboard = state.matchedLocation == Routes.dashboard ||
          state.matchedLocation.startsWith('/emergency');
      
      // Allow dashboard, emergency, splash and onboarding directly for demo & evaluation
      if (isGoingToDashboard || isGoingToSplash || isGoingToOnboarding) {
        return null;
      }
      
      // Redirect to login if not authenticated and trying to access private sub-routes
      if (!isLoggedIn && !isGoingToAuth) {
        return Routes.login;
      }
      
      // Redirect to dashboard if already logged in and going to auth
      if (isLoggedIn && isGoingToAuth) {
        return Routes.dashboard;
      }
      
      return null;
    },
    
    routes: [
      // Splash
      GoRoute(
        path: Routes.splash,
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),
      
      // Onboarding
      GoRoute(
        path: Routes.onboarding,
        name: 'onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      
      // Auth Routes
      GoRoute(
        path: Routes.login,
        name: 'login',
        builder: (context, state) => const LoginScreen(),
        routes: [
          GoRoute(
            path: 'otp',
            name: 'otp-verification',
            builder: (context, state) {
              final phoneNumber = state.extra as String? ?? '';
              return OtpVerificationScreen(phoneNumber: phoneNumber);
            },
          ),
          GoRoute(
            path: 'profile-setup',
            name: 'profile-setup',
            builder: (context, state) => const ProfileSetupScreen(),
          ),
        ],
      ),
      
      // Signup Route
      GoRoute(
        path: Routes.signup,
        name: 'signup',
        builder: (context, state) => const SignupScreen(),
      ),
      
      // Main App Shell
      ShellRoute(
        builder: (context, state, child) {
          return MainShell(child: child);
        },
        routes: [
          // Dashboard (Home)
          GoRoute(
            path: Routes.dashboard,
            name: 'dashboard',
            builder: (context, state) => const DashboardScreen(),
          ),
          
          // Emergency
          GoRoute(
            path: Routes.emergency,
            name: 'emergency',
            builder: (context, state) => const EmergencyScreen(),
          ),
          
          // Contacts
          GoRoute(
            path: Routes.contacts,
            name: 'contacts',
            builder: (context, state) => const ContactsScreen(),
          ),
          
          // Map
          GoRoute(
            path: Routes.map,
            name: 'map',
            builder: (context, state) => const MapScreen(),
          ),
          
          // Settings
          GoRoute(
            path: Routes.settings,
            name: 'settings',
            builder: (context, state) => const SettingsScreen(),
          ),
          
          // SOS Settings
          GoRoute(
            path: Routes.sosSettings,
            name: 'sos-settings',
            builder: (context, state) => const SosSettingsScreen(),
          ),
          
          // Profile
          GoRoute(
            path: Routes.profile,
            name: 'profile',
            builder: (context, state) => const ProfileScreen(),
          ),
          
          // Safe Zones
          GoRoute(
            path: Routes.safeZones,
            name: 'safe-zones',
            builder: (context, state) => const SafeZonesScreen(),
          ),
          
          // Quick Actions
          GoRoute(
            path: Routes.quickActions,
            name: 'quick-actions',
            builder: (context, state) => const QuickActionsScreen(),
          ),
        ],
      ),
    ],
    
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Page not found: ${state.error}'),
      ),
    ),
  );
});

/// Main shell with bottom navigation
class MainShell extends StatelessWidget {
  final Widget child;
  
  const MainShell({super.key, required this.child});
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: const MainBottomNavigation(),
    );
  }
}

/// Bottom navigation bar
class MainBottomNavigation extends ConsumerWidget {
  const MainBottomNavigation({super.key});
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLocation = GoRouterState.of(context).matchedLocation;
    
    int currentIndex = 0;
    if (currentLocation.startsWith(Routes.dashboard)) currentIndex = 0;
    if (currentLocation.startsWith(Routes.map)) currentIndex = 1;
    if (currentLocation.startsWith(Routes.contacts)) currentIndex = 2;
    if (currentLocation.startsWith(Routes.settings)) currentIndex = 3;
    
    return NavigationBar(
      selectedIndex: currentIndex,
      onDestinationSelected: (index) {
        switch (index) {
          case 0:
            context.go(Routes.dashboard);
            break;
          case 1:
            context.go(Routes.map);
            break;
          case 2:
            context.go(Routes.contacts);
            break;
          case 3:
            context.go(Routes.settings);
            break;
        }
      },
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home),
          label: 'Home',
        ),
        NavigationDestination(
          icon: Icon(Icons.map_outlined),
          selectedIcon: Icon(Icons.map),
          label: 'Map',
        ),
        NavigationDestination(
          icon: Icon(Icons.people_outline),
          selectedIcon: Icon(Icons.people),
          label: 'Contacts',
        ),
        NavigationDestination(
          icon: Icon(Icons.settings_outlined),
          selectedIcon: Icon(Icons.settings),
          label: 'Settings',
        ),
      ],
    );
  }
}
