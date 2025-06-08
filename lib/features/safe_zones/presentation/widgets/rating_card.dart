/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'package:flutter/material.dart';
import 'package:guardian/core/constants/app_colors.dart';
import 'package:guardian/core/constants/app_typography.dart';
import 'package:guardian/features/safe_zones/data/models/safe_zone_model.dart';
import 'package:intl/intl.dart';

/// A card widget for displaying a safety rating
class RatingCard extends StatelessWidget {
  /// The rating to display
  final SafetyRating rating;

  const RatingCard({
    super.key,
    required this.rating,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: _getRatingColor().withOpacity(0.2),
                  child: Icon(
                    _getRatingIcon(),
                    color: _getRatingColor(),
                    size: 16,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  rating.isAnonymous ? 'Anonymous' : 'User',
                  style: AppTypography.bodyLarge.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  DateFormat('MMM dd, yyyy').format(rating.createdAt),
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildRatingBadge(),
                const SizedBox(width: 8),
                _buildTimeContextBadge(),
                if (rating.incidentType != null) ...[
                  const SizedBox(width: 8),
                  _buildIncidentBadge(),
                ],
              ],
            ),
            if (rating.comment != null) ...[
              const SizedBox(height: 12),
              Text(
                rating.comment!,
                style: AppTypography.bodyMedium,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRatingBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: _getRatingColor().withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: _getRatingColor()),
      ),
      child: Text(
        _getRatingLabel(),
        style: AppTypography.caption.copyWith(
          color: _getRatingColor(),
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildTimeContextBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: AppColors.info.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        _getTimeContextLabel(),
        style: AppTypography.caption.copyWith(
          color: AppColors.info,
        ),
      ),
    );
  }

  Widget _buildIncidentBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: AppColors.warning.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        rating.incidentType!,
        style: AppTypography.caption.copyWith(
          color: AppColors.warning,
        ),
      ),
    );
  }

  Color _getRatingColor() {
    switch (rating.rating) {
      case SafetyRatingLevel.verySafe:
        return Colors.green;
      case SafetyRatingLevel.safe:
        return Colors.lightGreen;
      case SafetyRatingLevel.moderate:
        return Colors.yellow.shade700;
      case SafetyRatingLevel.unsafe:
        return Colors.orange;
      case SafetyRatingLevel.veryUnsafe:
        return Colors.red;
    }
  }

  IconData _getRatingIcon() {
    switch (rating.rating) {
      case SafetyRatingLevel.verySafe:
        return Icons.sentiment_very_satisfied;
      case SafetyRatingLevel.safe:
        return Icons.sentiment_satisfied;
      case SafetyRatingLevel.moderate:
        return Icons.sentiment_neutral;
      case SafetyRatingLevel.unsafe:
        return Icons.sentiment_dissatisfied;
      case SafetyRatingLevel.veryUnsafe:
        return Icons.sentiment_very_dissatisfied;
    }
  }

  String _getRatingLabel() {
    switch (rating.rating) {
      case SafetyRatingLevel.verySafe:
        return 'Very Safe';
      case SafetyRatingLevel.safe:
        return 'Safe';
      case SafetyRatingLevel.moderate:
        return 'Moderate';
      case SafetyRatingLevel.unsafe:
        return 'Unsafe';
      case SafetyRatingLevel.veryUnsafe:
        return 'Very Unsafe';
    }
  }

  String _getTimeContextLabel() {
    switch (rating.timeContext) {
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
