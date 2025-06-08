/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'package:flutter/material.dart';
import 'package:guardian/core/constants/app_colors.dart';
import 'package:guardian/core/constants/app_typography.dart';
import 'package:guardian/features/guardian_mode/data/models/guardian_session_model.dart';

/// A widget for displaying the current movement pattern
class MovementIndicator extends StatelessWidget {
  /// The current movement pattern
  final MovementPattern movementPattern;

  const MovementIndicator({
    super.key,
    required this.movementPattern,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          _getIconForPattern(movementPattern),
          size: 16,
          color: _getColorForPattern(movementPattern),
        ),
        const SizedBox(width: 4),
        Text(
          _getLabelForPattern(movementPattern),
          style: AppTypography.bodyMedium.copyWith(
            fontWeight: FontWeight.bold,
            color: _getColorForPattern(movementPattern),
          ),
        ),
      ],
    );
  }

  IconData _getIconForPattern(MovementPattern pattern) {
    switch (pattern) {
      case MovementPattern.stationary:
        return Icons.accessibility_new;
      case MovementPattern.walking:
        return Icons.directions_walk;
      case MovementPattern.running:
        return Icons.directions_run;
      case MovementPattern.inVehicle:
        return Icons.directions_car;
      case MovementPattern.unknown:
        return Icons.help_outline;
    }
  }

  String _getLabelForPattern(MovementPattern pattern) {
    switch (pattern) {
      case MovementPattern.stationary:
        return 'Stationary';
      case MovementPattern.walking:
        return 'Walking';
      case MovementPattern.running:
        return 'Running';
      case MovementPattern.inVehicle:
        return 'In Vehicle';
      case MovementPattern.unknown:
        return 'Unknown';
    }
  }

  Color _getColorForPattern(MovementPattern pattern) {
    switch (pattern) {
      case MovementPattern.stationary:
        return AppColors.textPrimary;
      case MovementPattern.walking:
        return AppColors.success;
      case MovementPattern.running:
        return AppColors.warning;
      case MovementPattern.inVehicle:
        return AppColors.info;
      case MovementPattern.unknown:
        return AppColors.textSecondary;
    }
  }
}
