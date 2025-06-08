/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'package:flutter/material.dart';
import 'package:guardian/core/constants/app_colors.dart';
import 'package:guardian/core/constants/app_typography.dart';

/// A widget for displaying the safety level of a location
class SafetyLevelIndicator extends StatelessWidget {
  /// The safety level
  final String safetyLevel;

  /// The message to display
  final String message;

  /// Callback when the widget is dismissed
  final VoidCallback? onDismiss;

  const SafetyLevelIndicator({
    super.key,
    required this.safetyLevel,
    required this.message,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _getSafetyColor().withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _getSafetyIcon(),
                color: _getSafetyColor(),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _getSafetyLabel(),
                    style: AppTypography.bodyLarge.copyWith(
                      fontWeight: FontWeight.bold,
                      color: _getSafetyColor(),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    message,
                    style: AppTypography.caption,
                  ),
                ],
              ),
            ),
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
      ),
    );
  }

  Color _getSafetyColor() {
    switch (safetyLevel) {
      case 'very_safe':
        return Colors.green;
      case 'safe':
        return Colors.lightGreen;
      case 'moderate':
        return Colors.yellow.shade700;
      case 'caution':
        return Colors.orange;
      case 'unsafe':
      case 'very_unsafe':
        return Colors.red;
      case 'unknown':
      case 'error':
      default:
        return AppColors.textSecondary;
    }
  }

  IconData _getSafetyIcon() {
    switch (safetyLevel) {
      case 'very_safe':
        return Icons.verified;
      case 'safe':
        return Icons.check_circle;
      case 'moderate':
        return Icons.info;
      case 'caution':
        return Icons.warning;
      case 'unsafe':
      case 'very_unsafe':
        return Icons.dangerous;
      case 'unknown':
      case 'error':
      default:
        return Icons.help;
    }
  }

  String _getSafetyLabel() {
    switch (safetyLevel) {
      case 'very_safe':
        return 'Very Safe Area';
      case 'safe':
        return 'Safe Area';
      case 'moderate':
        return 'Moderately Safe';
      case 'caution':
        return 'Use Caution';
      case 'unsafe':
        return 'Unsafe Area';
      case 'very_unsafe':
        return 'Very Unsafe Area';
      case 'unknown':
        return 'Safety Unknown';
      case 'error':
        return 'Error';
      default:
        return 'Safety Information';
    }
  }
}
