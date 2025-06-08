/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'package:flutter/material.dart';
import 'package:guardian/core/constants/app_colors.dart';
import 'package:guardian/core/constants/app_typography.dart';

import 'package:guardian/core/services/ai_service.dart';

/// A widget for displaying safety alerts and suggestions
class SafetyAlert extends StatelessWidget {
  /// The risk level of the alert
  final RiskLevel riskLevel;

  /// The message to display
  final String message;

  /// Callback when the alert is dismissed
  final VoidCallback? onDismiss;

  /// Callback when the action button is pressed
  final VoidCallback? onAction;

  /// Text for the action button
  final String? actionText;

  const SafetyAlert({
    super.key,
    required this.riskLevel,
    required this.message,
    this.onDismiss,
    this.onAction,
    this.actionText,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: _getColorForRiskLevel(),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  _getIconForRiskLevel(),
                  color: _getColorForRiskLevel(),
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  _getTitleForRiskLevel(),
                  style: AppTypography.heading4.copyWith(
                    fontWeight: FontWeight.bold,
                    color: _getColorForRiskLevel(),
                  ),
                ),
                const Spacer(),
                if (onDismiss != null)
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: onDismiss,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    iconSize: 20,
                    color: AppColors.textSecondary,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: AppTypography.bodyMedium,
            ),
            if (onAction != null && actionText != null) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: onAction,
                  style: TextButton.styleFrom(
                    foregroundColor: _getColorForRiskLevel(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                  child: Text(actionText!),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Get the color for the current risk level
  Color _getColorForRiskLevel() {
    switch (riskLevel) {
      case RiskLevel.low:
        return AppColors.success;
      case RiskLevel.medium:
        return AppColors.warning;
      case RiskLevel.high:
        return AppColors.danger;
    }
  }

  /// Get the icon for the current risk level
  IconData _getIconForRiskLevel() {
    switch (riskLevel) {
      case RiskLevel.low:
        return Icons.check_circle;
      case RiskLevel.medium:
        return Icons.info;
      case RiskLevel.high:
        return Icons.warning;
    }
  }

  /// Get the title for the current risk level
  String _getTitleForRiskLevel() {
    switch (riskLevel) {
      case RiskLevel.low:
        return 'Safety Tip';
      case RiskLevel.medium:
        return 'Safety Alert';
      case RiskLevel.high:
        return 'Warning';
    }
  }
}
