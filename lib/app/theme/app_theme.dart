/*
 * Guardian 2.0 - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * 
 * Application Theme
 */

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Application color palette
abstract class AppColors {
  // Primary - Safety Orange/Red
  static const primary = Color(0xFFE53935);
  static const primaryLight = Color(0xFFFF6F60);
  static const primaryDark = Color(0xFFAB000D);

  // Secondary - Calm Blue
  static const secondary = Color(0xFF1E88E5);
  static const secondaryLight = Color(0xFF6AB7FF);
  static const secondaryDark = Color(0xFF005CB2);

  // Success - Safe Green
  static const success = Color(0xFF43A047);
  static const successLight = Color(0xFF76D275);
  static const successDark = Color(0xFF00701A);

  // Warning
  static const warning = Color(0xFFFF9100);
  static const warningLight = Color(0xFFFFC246);
  static const warningDark = Color(0xFFC56200);

  // Error
  static const error = Color(0xFFD32F2F);
  static const errorLight = Color(0xFFFF6659);
  static const errorDark = Color(0xFF9A0007);

  // Neutral
  static const background = Color(0xFFFAFAFA);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceVariant = Color(0xFFF5F5F5);
  static const onSurface = Color(0xFF212121);
  static const onSurfaceVariant = Color(0xFF757575);

  // Dark Theme
  static const backgroundDark = Color(0xFF121212);
  static const surfaceDark = Color(0xFF1E1E1E);
  static const surfaceVariantDark = Color(0xFF2C2C2C);
  static const onSurfaceDark = Color(0xFFE0E0E0);
  static const onSurfaceVariantDark = Color(0xFFB0B0B0);

  // Special
  static const sos = Color(0xFFFF1744);
  static const sosGlow = Color(0x40FF1744);
  static const safe = Color(0xFF00C853);
  static const guardian = Color(0xFF7C4DFF);
}

/// Application theme configuration
abstract class AppTheme {
  /// Light theme
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,

      // Color scheme
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.light,
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        error: AppColors.error,
        surface: AppColors.surface,
      ),

      // Scaffold
      scaffoldBackgroundColor: AppColors.background,

      // App Bar
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.onSurface,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.onSurface,
        ),
      ),

      // Text
      textTheme: GoogleFonts.poppinsTextTheme().apply(
        bodyColor: AppColors.onSurface,
        displayColor: AppColors.onSurface,
      ),

      // Card
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),

      // Button
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // Input
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error, width: 1),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),

      // Navigation Bar
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.primary.withOpacity(0.15),
        labelTextStyle: WidgetStateProperty.all(
          GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ),

      // Floating Action Button
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.sos,
        foregroundColor: Colors.white,
        elevation: 8,
      ),
    );
  }

  /// Dark theme
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,

      // Color scheme
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.dark,
        primary: AppColors.primaryLight,
        secondary: AppColors.secondaryLight,
        error: AppColors.errorLight,
        surface: AppColors.surfaceDark,
      ),

      // Scaffold
      scaffoldBackgroundColor: AppColors.backgroundDark,

      // App Bar
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surfaceDark,
        foregroundColor: AppColors.onSurfaceDark,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.onSurfaceDark,
        ),
      ),

      // Text
      textTheme: GoogleFonts.poppinsTextTheme().apply(
        bodyColor: AppColors.onSurfaceDark,
        displayColor: AppColors.onSurfaceDark,
      ),

      // Card
      cardTheme: CardThemeData(
        color: AppColors.surfaceDark,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),

      // Button
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryLight,
          foregroundColor: Colors.black,
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // Input
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceVariantDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primaryLight, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),

      // Navigation Bar
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surfaceDark,
        indicatorColor: AppColors.primaryLight.withOpacity(0.2),
        labelTextStyle: WidgetStateProperty.all(
          GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ),

      // Floating Action Button
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.sos,
        foregroundColor: Colors.white,
        elevation: 8,
      ),
    );
  }
}
