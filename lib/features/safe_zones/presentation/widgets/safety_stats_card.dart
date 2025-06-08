/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'package:flutter/material.dart';
import 'package:guardian/core/constants/app_colors.dart';
import 'package:guardian/core/constants/app_typography.dart';
import 'package:guardian/features/safe_zones/data/models/safe_zone_model.dart';

/// A card widget for displaying safety statistics
class SafetyStatsCard extends StatelessWidget {
  /// The average safety rating
  final double averageRating;

  /// The number of ratings
  final int ratingCount;

  /// The predominant time context
  final TimeContext timeContext;

  const SafetyStatsCard({
    super.key,
    required this.averageRating,
    required this.ratingCount,
    required this.timeContext,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Safety Statistics',
              style: AppTypography.heading4.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    label: 'Safety Rating',
                    value: _getRatingLabel(),
                    icon: _getRatingIcon(),
                    color: _getRatingColor(),
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    label: 'Time Context',
                    value: _getTimeContextLabel(),
                    icon: _getTimeContextIcon(),
                    color: AppColors.info,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    label: 'Average Score',
                    value: averageRating.toStringAsFixed(1),
                    icon: Icons.star,
                    color: AppColors.primary,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    label: 'Total Ratings',
                    value: ratingCount.toString(),
                    icon: Icons.people,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildSafetyMeter(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.caption.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: color,
            ),
            const SizedBox(width: 4),
            Text(
              value,
              style: AppTypography.bodyLarge.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSafetyMeter() {
    // Convert rating to percentage (1-5 scale to 0-100%)
    final percentage = (averageRating / 5) * 100;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Safety Meter',
          style: AppTypography.caption.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percentage / 100,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(_getRatingColor()),
            minHeight: 8,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Very Unsafe',
              style: AppTypography.caption.copyWith(
                color: Colors.red,
              ),
            ),
            Text(
              'Very Safe',
              style: AppTypography.caption.copyWith(
                color: Colors.green,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Color _getRatingColor() {
    if (averageRating >= 4.0) {
      return Colors.green;
    } else if (averageRating >= 3.0) {
      return Colors.lightGreen;
    } else if (averageRating >= 2.0) {
      return Colors.yellow.shade700;
    } else if (averageRating >= 1.0) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }

  IconData _getRatingIcon() {
    if (averageRating >= 4.0) {
      return Icons.sentiment_very_satisfied;
    } else if (averageRating >= 3.0) {
      return Icons.sentiment_satisfied;
    } else if (averageRating >= 2.0) {
      return Icons.sentiment_neutral;
    } else if (averageRating >= 1.0) {
      return Icons.sentiment_dissatisfied;
    } else {
      return Icons.sentiment_very_dissatisfied;
    }
  }

  String _getRatingLabel() {
    if (averageRating >= 4.0) {
      return 'Very Safe';
    } else if (averageRating >= 3.0) {
      return 'Safe';
    } else if (averageRating >= 2.0) {
      return 'Moderate';
    } else if (averageRating >= 1.0) {
      return 'Unsafe';
    } else {
      return 'Very Unsafe';
    }
  }

  IconData _getTimeContextIcon() {
    switch (timeContext) {
      case TimeContext.allTimes:
        return Icons.access_time;
      case TimeContext.daytimeOnly:
        return Icons.wb_sunny;
      case TimeContext.nighttimeOnly:
        return Icons.nightlight_round;
      case TimeContext.neverSafe:
        return Icons.dangerous;
    }
  }

  String _getTimeContextLabel() {
    switch (timeContext) {
      case TimeContext.allTimes:
        return 'All Times';
      case TimeContext.daytimeOnly:
        return 'Daytime Only';
      case TimeContext.nighttimeOnly:
        return 'Nighttime Only';
      case TimeContext.neverSafe:
        return 'Never Safe';
    }
  }
}
