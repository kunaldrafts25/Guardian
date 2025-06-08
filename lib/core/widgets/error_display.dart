/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'package:flutter/material.dart';
import 'package:guardian/core/constants/app_colors.dart';
import 'package:guardian/core/constants/app_text_styles.dart';
import 'package:guardian/core/widgets/custom_button.dart';

/// A widget to display error messages with optional retry functionality
class ErrorDisplay extends StatelessWidget {
  /// The error message to display
  final String message;
  
  /// Callback when retry button is pressed
  final VoidCallback? onRetry;
  
  /// Text to display on the retry button
  final String retryText;
  
  /// Icon to display
  final IconData icon;
  
  /// Color of the icon
  final Color iconColor;
  
  /// Size of the icon
  final double iconSize;
  
  /// Style for the error message
  final TextStyle? messageStyle;
  
  /// Creates an error display widget
  const ErrorDisplay({
    super.key,
    required this.message,
    this.onRetry,
    this.retryText = 'Retry',
    this.icon = Icons.error_outline,
    this.iconColor = AppColors.danger,
    this.iconSize = 64.0,
    this.messageStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: iconColor,
              size: iconSize,
            ),
            const SizedBox(height: 16.0),
            Text(
              message,
              style: messageStyle ?? AppTextStyles.bodyLarge.copyWith(
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24.0),
              CustomButton(
                text: retryText,
                onPressed: onRetry,
                type: ButtonType.primary,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
