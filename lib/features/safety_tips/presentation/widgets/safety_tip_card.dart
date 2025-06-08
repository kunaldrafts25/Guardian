/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'package:flutter/material.dart';
import 'package:guardian/core/constants/app_typography.dart';
import 'package:guardian/features/safety_tips/data/safety_tip_model.dart';

/// A card widget to display a safety tip
class SafetyTipCard extends StatelessWidget {
  /// The safety tip to display
  final SafetyTip tip;

  /// Callback when the card is tapped
  final VoidCallback? onTap;

  /// Whether to show the full description
  final bool showFullDescription;

  /// Whether to show the category badge
  final bool showCategory;

  const SafetyTipCard({
    super.key,
    required this.tip,
    this.onTap,
    this.showFullDescription = false,
    this.showCategory = true,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                tip.color.withOpacity(0.1),
                tip.color.withOpacity(0.05),
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Category badge
              if (showCategory)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: tip.color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    tip.category.displayName,
                    style: AppTypography.caption.copyWith(
                      color: tip.color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

              const SizedBox(height: 12),

              // Icon and title
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: tip.color.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      tip.icon,
                      color: tip.color,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      tip.title,
                      style: AppTypography.heading4,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Description
              Text(
                tip.description,
                style: AppTypography.bodyMedium,
                maxLines: showFullDescription ? null : 3,
                overflow: showFullDescription ? null : TextOverflow.ellipsis,
              ),

              if (!showFullDescription) ...[
                const SizedBox(height: 8),
                Text(
                  'Tap to read more',
                  style: AppTypography.caption.copyWith(
                    color: tip.color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
