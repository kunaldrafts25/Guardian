/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:guardian/core/constants/app_typography.dart';

/// A quick access floating action button for the dashboard
class QuickAccessFab extends StatelessWidget {
  /// The icon to display in the FAB
  final IconData icon;

  /// The label to display below the FAB
  final String label;

  /// The color of the FAB
  final Color color;

  /// The callback when the FAB is tapped
  final VoidCallback onTap;

  /// The size of the FAB
  final double size;

  const QuickAccessFab({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.size = 56,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // FAB
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              onTap();
            },
            customBorder: const CircleBorder(),
            child: Ink(
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.3),
                    blurRadius: 8,
                    spreadRadius: 1,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              width: size,
              height: size,
              child: Center(
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: size * 0.5,
                ),
              ),
            ),
          ),
        ),

        // Label
        const SizedBox(height: 8),
        Text(
          label,
          style: AppTypography.caption.copyWith(
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
