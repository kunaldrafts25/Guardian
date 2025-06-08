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

/// A card widget for displaying safety alerts
class AlertCard extends StatelessWidget {
  /// The alert to display
  final SafetyAlert alert;

  /// Callback when the card is tapped
  final VoidCallback onTap;

  /// Callback when the dismiss button is pressed
  final VoidCallback onDismiss;

  const AlertCard({
    super.key,
    required this.alert,
    required this.onTap,
    required this.onDismiss,
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
                  _buildRiskLevelIcon(),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          alert.title,
                          style: AppTypography.heading4.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat('MMM dd, yyyy').format(alert.createdAt),
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!alert.isRead)
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
                alert.content,
                style: AppTypography.bodyMedium,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildRiskLevelBadge(),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: onDismiss,
                    icon: const Icon(
                      Icons.close,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                    label: const Text(
                      'Dismiss',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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

  Widget _buildRiskLevelIcon() {
    Color color;
    IconData icon;

    switch (alert.riskLevel) {
      case RiskLevel.high:
        color = Colors.red;
        icon = Icons.warning_amber_rounded;
        break;
      case RiskLevel.medium:
        color = Colors.orange;
        icon = Icons.warning_outlined;
        break;
      case RiskLevel.low:
      default:
        color = Colors.blue;
        icon = Icons.info_outline;
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

    switch (alert.riskLevel) {
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
        color = Colors.blue;
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
