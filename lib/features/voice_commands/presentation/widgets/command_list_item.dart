/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'package:flutter/material.dart';
import 'package:guardian/core/constants/app_colors.dart';
import 'package:guardian/core/constants/app_typography.dart';

/// A list item widget for displaying a voice command
class CommandListItem extends StatelessWidget {
  /// The command text
  final String command;

  /// Callback when the item is tapped
  final VoidCallback onTap;

  const CommandListItem({
    super.key,
    required this.command,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.mic,
                  color: AppColors.primary,
                  size: 16,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  command,
                  style: AppTypography.bodyLarge,
                ),
              ),
              const Icon(
                Icons.play_arrow,
                color: AppColors.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
