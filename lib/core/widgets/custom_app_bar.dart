/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'package:flutter/material.dart';
import 'package:guardian/core/constants/app_colors.dart';
import 'package:guardian/core/constants/app_text_styles.dart';

/// A custom app bar widget for the Guardian app
class CustomAppBar extends AppBar {
  /// Creates a custom app bar
  CustomAppBar({
    super.key,
    required String title,
    bool showBackButton = false,
    VoidCallback? onBackPressed,
    super.actions,
    Widget? leading,
    Color? backgroundColor,
    double? elevation,
    bool centerTitle = false,
    TextStyle? titleStyle,
    VoidCallback? onTap,
  }) : super(
          title: GestureDetector(
            onTap: onTap,
            child: Text(
              title,
              style: titleStyle ?? AppTextStyles.heading3,
            ),
          ),
          backgroundColor: backgroundColor ?? AppColors.primary,
          elevation: elevation ?? 2.0,
          centerTitle: centerTitle,
          leading: showBackButton
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: onBackPressed ?? () {},
                )
              : leading,
        );
}
