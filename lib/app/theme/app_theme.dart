import 'package:flutter/material.dart';

/// Guardian's single semantic color source.
///
/// Red is intentionally reserved for emergency and destructive actions. The
/// compatibility aliases keep older widgets on the same palette while they
/// are migrated to semantic names.
abstract final class AppColors {
  static const background = Color(0xFFF7F7F5);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceMuted = Color(0xFFEFF1F2);
  static const textPrimary = Color(0xFF1C232B);
  static const textSecondary = Color(0xFF66717D);
  static const border = Color(0xFFDDE1E5);

  static const backgroundDark = Color(0xFF111315);
  static const surfaceDark = Color(0xFF1A1D20);
  static const surfaceMutedDark = Color(0xFF24282C);
  static const textPrimaryDark = Color(0xFFF3F5F7);
  static const textSecondaryDark = Color(0xFFAEB6BF);
  static const borderDark = Color(0xFF343A40);

  static const brand = Color(0xFF34556F);
  static const brandDark = Color(0xFF78A6C8);
  static const emergency = Color(0xFFC43D4D);
  static const emergencyDark = Color(0xFFE66A76);
  static const success = Color(0xFF2F765E);
  static const successDark = Color(0xFF65B394);
  static const warning = Color(0xFFA66B18);
  static const warningDark = Color(0xFFD5A04B);
  static const information = Color(0xFF3F668C);
  static const informationDark = Color(0xFF79A5CE);

  // Compatibility aliases for widgets still being migrated.
  static const primary = brand;
  static const primaryLight = brandDark;
  static const primaryDark = Color(0xFF233E53);
  static const secondary = information;
  static const secondaryLight = informationDark;
  static const secondaryDark = Color(0xFF294A68);
  static const error = emergency;
  static const errorLight = emergencyDark;
  static const errorDark = Color(0xFF8E2836);
  static const accent = emergency;
  static const accentLight = emergencyDark;
  static const accentDark = errorDark;
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

    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.brand,
      brightness: brightness,
    ).copyWith(
      primary: primary,
      onPrimary: dark ? AppColors.textPrimary : Colors.white,
      secondary: dark ? AppColors.informationDark : AppColors.information,
      error: emergency,
      surface: surface,
      onSurface: onSurface,
      outline: border,
      outlineVariant: border,
      surfaceContainerHighest: muted,
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
        headlineLarge: baseText.headlineLarge?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: -0.5,
        ),
        headlineMedium: baseText.headlineMedium?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: -0.25,
        ),
        headlineSmall: baseText.headlineSmall?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        titleLarge: baseText.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        titleMedium:
            baseText.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        bodyLarge: baseText.bodyLarge?.copyWith(height: 1.45),
        bodyMedium: baseText.bodyMedium?.copyWith(
          height: 1.4,
          color: secondaryText,
        ),
        bodySmall: baseText.bodySmall?.copyWith(
          height: 1.35,
          color: secondaryText,
        ),
        labelLarge: baseText.labelLarge?.copyWith(fontWeight: FontWeight.w600),
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
          borderRadius: BorderRadius.circular(16),
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
            borderRadius: BorderRadius.circular(14),
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
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: primary,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: muted,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
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
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: onSurface,
        contentTextStyle: TextStyle(color: background),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: primary),
      iconTheme: IconThemeData(color: onSurface),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: dark ? AppColors.textPrimary : Colors.white,
        elevation: 1,
      ),
    );
  }
}
