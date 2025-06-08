/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'package:flutter/material.dart';
import 'package:guardian/core/constants/app_colors.dart';
import 'package:guardian/core/constants/app_text_styles.dart';

/// A widget to display a loading indicator with optional text
class LoadingIndicator extends StatelessWidget {
  /// Optional text to display below the loading indicator
  final String? text;

  /// Color of the loading indicator
  final Color color;

  /// Size of the loading indicator
  final double size;

  /// Style for the text
  final TextStyle? textStyle;

  /// Stroke width of the loading indicator
  final double strokeWidth;

  /// Whether to center the loading indicator
  final bool centered;

  /// Creates a loading indicator widget
  const LoadingIndicator({
    super.key,
    this.text,
    this.color = AppColors.primary,
    this.size = 48.0,
    this.textStyle,
    this.strokeWidth = 4.0,
    this.centered = true,
  });

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(color),
            strokeWidth: strokeWidth,
          ),
        ),
        if (text != null) ...[
          const SizedBox(height: 16.0),
          Text(
            text!,
            style: textStyle ?? AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );

    return centered ? Center(child: content) : content;
  }
}
