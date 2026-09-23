import 'package:flutter/material.dart';

/// Guardian's single canonical semantic color source ("Warm Guardian").
///
/// Blue is completely removed from all product surfaces.
/// Red (#C6424E) is reserved strictly for genuine emergencies and critical actions.
/// Deep Forest Green (#244D3C) represents protection readiness and primary navigation.
/// Warm porcelain (#F7F5EF) provides the grounded neutral canvas.
abstract final class AppColors {
  // Light Palette ("Warm Porcelain")
  static const background = Color(0xFFF7F5EF);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceMuted = Color(0xFFEEF1EC);
  static const textPrimary = Color(0xFF1C2520);
  static const textSecondary = Color(0xFF5E6B64);
  static const textDisabled = Color(0xFF929B96);
  static const border = Color(0xFFD7DDD8);
  static const dividerColor = Color(0xFFE7EAE7);

  // Dark Palette ("Quiet Forest")
  static const backgroundDark = Color(0xFF101613);
  static const surfaceDark = Color(0xFF18201C);
  static const surfaceMutedDark = Color(0xFF202A25);
  static const textPrimaryDark = Color(0xFFF2F5F2);
  static const textSecondaryDark = Color(0xFFB8C2BC);
  static const borderDark = Color(0xFF35423B);

  // Semantic Colors
  static const brand = Color(0xFF244D3C);
  static const brandDark = Color(0xFF82B89D);
  static const brandPressed = Color(0xFF173A2C);
  static const brandContainer = Color(0xFFDDE9E1);
  static const brandContainerDark = Color(0xFF284B3B);

  static const secondaryAccent = Color(0xFF8A684E);
  static const secondaryAccentDark = Color(0xFFC5A184);

  static const emergency = Color(0xFFC6424E);
  static const emergencyDark = Color(0xFFF06B74);
  static const emergencyPressed = Color(0xFF98313A);
  static const emergencyContainer = Color(0xFFF8E1E3);
  static const emergencyContainerDark = Color(0xFF512A2E);

  static const warning = Color(0xFFA96624);
  static const warningDark = Color(0xFFE0A15C);
  static const success = Color(0xFF39705A);
  static const successDark = Color(0xFF79B89A);

  // Information & Neutral Roles (Warm Earth / Neutral Green - Zero Blue)
  static const information = secondaryAccent;
  static const informationDark = secondaryAccentDark;

  // Compatibility aliases
  static const primary = brand;
  static const primaryLight = brandDark;
  static const primaryDark = brandPressed;
  static const secondary = secondaryAccent;
  static const secondaryLight = secondaryAccentDark;
  static const secondaryDark = Color(0xFF5A402D);
  static const error = emergency;
  static const errorLight = emergencyDark;
  static const errorDark = emergencyPressed;
  static const accent = emergency;
  static const accentLight = emergencyDark;
  static const accentDark = emergencyPressed;
  static const danger = emergency;
  static const info = information;
  static const onSurface = textPrimary;
  static const onSurfaceVariant = textSecondary;
  static const onSurfaceDark = textPrimaryDark;
  static const onSurfaceVariantDark = textSecondaryDark;
  static const surfaceVariant = surfaceMuted;
  static const surfaceVariantDark = surfaceMutedDark;
  static const divider = border;
  static const sos = emergency;
  static const safe = success;
  static const guardian = brand;
  static const safeZone = success;
  static const warningZone = warning;
  static const dangerZone = emergency;
}

abstract final class AppTheme {
  static ThemeData get lightTheme => _build(Brightness.light);
  static ThemeData get darkTheme => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final background = dark ? AppColors.backgroundDark : AppColors.background;
    final surface = dark ? AppColors.surfaceDark : AppColors.surface;
    final muted = dark ? AppColors.surfaceMutedDark : AppColors.surfaceMuted;
    final border = dark ? AppColors.borderDark : AppColors.border;
    final primary = dark ? AppColors.brandDark : AppColors.brand;
    final emergency = dark ? AppColors.emergencyDark : AppColors.emergency;
    final onSurface = dark ? AppColors.textPrimaryDark : AppColors.textPrimary;
    final secondaryText =
        dark ? AppColors.textSecondaryDark : AppColors.textSecondary;
    final primaryContainer =
        dark ? AppColors.brandContainerDark : AppColors.brandContainer;
    final emergencyContainer =
        dark ? AppColors.emergencyContainerDark : AppColors.emergencyContainer;

    final scheme = ColorScheme(
      brightness: brightness,
      primary: primary,
      onPrimary: dark ? AppColors.textPrimary : Colors.white,
      primaryContainer: primaryContainer,
      onPrimaryContainer: dark ? AppColors.brandDark : AppColors.brandPressed,
      secondary:
          dark ? AppColors.secondaryAccentDark : AppColors.secondaryAccent,
      onSecondary: dark ? AppColors.textPrimary : Colors.white,
      secondaryContainer:
          dark ? const Color(0xFF382A20) : const Color(0xFFF3ECE6),
      onSecondaryContainer:
          dark ? AppColors.secondaryAccentDark : AppColors.secondaryAccent,
      tertiary: dark ? AppColors.successDark : AppColors.success,
      onTertiary: dark ? AppColors.textPrimary : Colors.white,
      error: emergency,
      onError: Colors.white,
      errorContainer: emergencyContainer,
      onErrorContainer:
          dark ? AppColors.emergencyDark : AppColors.emergencyPressed,
      surface: surface,
      onSurface: onSurface,
      surfaceContainerHighest: muted,
      onSurfaceVariant: secondaryText,
      outline: border,
      outlineVariant: border,
    );

    final baseText = Typography.material2021(
      platform: TargetPlatform.android,
      colorScheme: scheme,
    ).black.apply(bodyColor: onSurface, displayColor: onSurface);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      dividerColor: border,
      textTheme: baseText.copyWith(
        displayLarge: baseText.displayLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
          color: onSurface,
        ),
        headlineLarge: baseText.headlineLarge?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: -0.5,
          color: onSurface,
        ),
        headlineMedium: baseText.headlineMedium?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: -0.25,
          color: onSurface,
        ),
        headlineSmall: baseText.headlineSmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: onSurface,
        ),
        titleLarge: baseText.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
          color: onSurface,
        ),
        titleMedium: baseText.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: onSurface,
        ),
        titleSmall: baseText.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: onSurface,
        ),
        bodyLarge: baseText.bodyLarge?.copyWith(
          fontSize: 16,
          height: 1.45,
          color: onSurface,
        ),
        bodyMedium: baseText.bodyMedium?.copyWith(
          fontSize: 14,
          height: 1.4,
          color: secondaryText,
        ),
        bodySmall: baseText.bodySmall?.copyWith(
          fontSize: 13,
          height: 1.35,
          color: secondaryText,
        ),
        labelLarge: baseText.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
        labelMedium: baseText.labelMedium?.copyWith(
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        labelSmall: baseText.labelSmall?.copyWith(
          fontWeight: FontWeight.w600,
          fontSize: 11,
          letterSpacing: 0.5,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: border),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(48, 52),
          elevation: 0,
          backgroundColor: primary,
          foregroundColor: dark ? AppColors.textPrimary : Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 52),
          foregroundColor: primary,
          side: BorderSide(color: border),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: primary,
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: muted,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: emergency),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: primary.withValues(alpha: 0.12),
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return TextStyle(
            color:
                states.contains(WidgetState.selected) ? primary : secondaryText,
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.w500,
          );
        }),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: onSurface,
        contentTextStyle: TextStyle(color: background),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: primary),
      iconTheme: IconThemeData(color: onSurface),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: dark ? AppColors.textPrimary : Colors.white,
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
