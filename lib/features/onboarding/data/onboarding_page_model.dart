/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'package:flutter/material.dart';

/// Model class for onboarding page data
class OnboardingPageModel {
  /// Title of the onboarding page
  final String title;
  
  /// Description text for the onboarding page
  final String description;
  
  /// Image asset path for the onboarding page
  final String imagePath;
  
  /// Optional icon to display
  final IconData? icon;
  
  /// Optional background color
  final Color? backgroundColor;
  
  OnboardingPageModel({
    required this.title,
    required this.description,
    required this.imagePath,
    this.icon,
    this.backgroundColor,
  });
}

/// Sample onboarding pages data
List<OnboardingPageModel> onboardingPages = [
  OnboardingPageModel(
    title: 'Welcome to Guardian',
    description: 'Your personal safety companion that helps you stay protected wherever you go.',
    imagePath: 'assets/images/onboarding/welcome.png',
    icon: Icons.shield,
  ),
  OnboardingPageModel(
    title: 'Emergency SOS',
    description: 'Long press the SOS button in case of emergency to alert your trusted contacts with your location.',
    imagePath: 'assets/images/onboarding/sos.png',
    icon: Icons.warning_rounded,
  ),
  OnboardingPageModel(
    title: 'Safety Map',
    description: 'View safe routes, danger zones, and nearby helpers on the interactive map.',
    imagePath: 'assets/images/onboarding/map.png',
    icon: Icons.map,
  ),
  OnboardingPageModel(
    title: 'Safety Devices',
    description: 'Connect with wearable safety devices for quick access to emergency features.',
    imagePath: 'assets/images/onboarding/devices.png',
    icon: Icons.watch,
  ),
];
