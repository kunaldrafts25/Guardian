/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'package:flutter/material.dart';
import 'package:guardian/core/constants/app_colors.dart';
import 'package:guardian/core/constants/app_typography.dart';
import 'package:guardian/features/ai_assistant/data/models/ai_model.dart';
import 'package:intl/intl.dart';

/// A card widget for displaying safety advice
class AdviceCard extends StatelessWidget {
  /// The advice to display
  final SafetyAdvice advice;

  /// Callback when the card is tapped
  final VoidCallback onTap;

  const AdviceCard({
    super.key,
    required this.advice,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTypeIcon(),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          advice.title,
                          style: AppTypography.heading4.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat('MMM dd, yyyy').format(advice.createdAt),
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!advice.isRead)
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                advice.content,
                style: AppTypography.bodyMedium,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildRiskLevelBadge(),
                  const Spacer(),
                  if (advice.isPersonalized)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Personalized',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeIcon() {
    IconData icon;
    Color color;

    switch (advice.type) {
      case AdviceType.location:
        icon = Icons.location_on;
        color = Colors.blue;
        break;
      case AdviceType.situation:
        icon = Icons.psychology;
        color = Colors.purple;
        break;
      case AdviceType.emergency:
        icon = Icons.warning;
        color = Colors.red;
        break;
      case AdviceType.travel:
        icon = Icons.directions_car;
        color = Colors.green;
        break;
      case AdviceType.general:
      default:
        icon = Icons.info;
        color = Colors.orange;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        color: color,
        size: 24,
      ),
    );
  }

  Widget _buildRiskLevelBadge() {
    Color color;
    String label;

    switch (advice.riskLevel) {
      case RiskLevel.high:
        color = Colors.red;
        label = 'High Risk';
        break;
      case RiskLevel.medium:
        color = Colors.orange;
        label = 'Medium Risk';
        break;
      case RiskLevel.low:
      default:
        color = Colors.green;
        label = 'Low Risk';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: AppTypography.caption.copyWith(
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
