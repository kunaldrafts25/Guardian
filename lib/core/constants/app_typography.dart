/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:guardian/core/constants/app_colors.dart';

/// Typography styles for the app
class AppTypography {
  // Base text styles with Poppins font
  static final TextStyle _baseTextStyle = GoogleFonts.poppins(
    color: AppColors.textPrimary,
    fontWeight: FontWeight.normal,
  );

  // Headings
  static final TextStyle heading1 = _baseTextStyle.copyWith(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    letterSpacing: -0.5,
  );

  static final TextStyle heading2 = _baseTextStyle.copyWith(
    fontSize: 22,
    fontWeight: FontWeight.bold,
  );

  static final TextStyle heading3 = _baseTextStyle.copyWith(
    fontSize: 20,
    fontWeight: FontWeight.bold,
  );

  static final TextStyle heading4 = _baseTextStyle.copyWith(
    fontSize: 18,
    fontWeight: FontWeight.bold,
  );

  // Body text
  static final TextStyle bodyLarge = _baseTextStyle.copyWith(
    fontSize: 16,
    height: 1.5,
  );

  static final TextStyle bodyMedium = _baseTextStyle.copyWith(
    fontSize: 14,
    height: 1.5,
  );

  static final TextStyle bodySmall = _baseTextStyle.copyWith(
    fontSize: 12,
    height: 1.5,
  );

  // Button text
  static final TextStyle buttonLarge = _baseTextStyle.copyWith(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
  );

  static final TextStyle buttonMedium = _baseTextStyle.copyWith(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
  );

  static final TextStyle buttonSmall = _baseTextStyle.copyWith(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
  );

  // Caption and overline
  static final TextStyle caption = _baseTextStyle.copyWith(
    fontSize: 12,
    color: AppColors.textSecondary,
  );

  static final TextStyle overline = _baseTextStyle.copyWith(
    fontSize: 10,
    fontWeight: FontWeight.w500,
    letterSpacing: 1.5,
    color: AppColors.textSecondary,
  );

  // Special styles
  static final TextStyle label = _baseTextStyle.copyWith(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
  );

  static final TextStyle tabLabel = _baseTextStyle.copyWith(
    fontSize: 14,
    fontWeight: FontWeight.w600,
  );

  static final TextStyle appBarTitle = _baseTextStyle.copyWith(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  );

  // Helper method to get all caps text style
  static TextStyle allCaps(TextStyle base) {
    return base.copyWith(
      fontWeight: FontWeight.bold,
      letterSpacing: 1.0,
    );
  }
}
