/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'package:flutter/material.dart';
import 'package:guardian/core/constants/app_colors.dart';
import 'package:guardian/core/constants/app_typography.dart';
import 'package:guardian/features/guardian_circle/data/models/guardian_circle_model.dart';

/// A card widget for displaying a guardian circle
class CircleCard extends StatelessWidget {
  /// The circle to display
  final GuardianCircle circle;

  /// Callback when the card is tapped
  final VoidCallback? onTap;

  const CircleCard({
    super.key,
    required this.circle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeMembers = circle.members
        .where(
          (m) => m.status == GuardianMemberStatus.active,
        )
        .length;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: AppColors.primary.withOpacity(0.1),
                    child: const Icon(
                      Icons.people,
                      color: AppColors.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          circle.name,
                          style: AppTypography.heading4.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$activeMembers active members',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (circle.isDefault)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Default',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              if (circle.description != null) ...[
                const SizedBox(height: 12),
                Text(
                  circle.description!,
                  style: AppTypography.bodyMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 12),
              _buildMemberAvatars(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMemberAvatars() {
    final displayMembers = circle.members.take(5).toList();
    final remainingCount = circle.members.length - displayMembers.length;

    return SizedBox(
      height: 32,
      child: Row(
        children: [
          ...List.generate(
            displayMembers.length,
            (index) => Padding(
              padding: EdgeInsets.only(
                  right: index == displayMembers.length - 1 ? 0 : 8),
              child: _buildMemberAvatar(displayMembers[index]),
            ),
          ),
          if (remainingCount > 0) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.textSecondary.withOpacity(0.2),
              child: Text(
                '+$remainingCount',
                style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMemberAvatar(GuardianCircleMember member) {
    return Tooltip(
      message: member.name,
      child: CircleAvatar(
        radius: 16,
        backgroundColor: _getStatusColor(member.status).withOpacity(0.2),
        child: Text(
          member.name.isNotEmpty ? member.name[0].toUpperCase() : '?',
          style: AppTypography.caption.copyWith(
            color: _getStatusColor(member.status),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(GuardianMemberStatus status) {
    switch (status) {
      case GuardianMemberStatus.active:
        return AppColors.success;
      case GuardianMemberStatus.invited:
        return AppColors.warning;
      case GuardianMemberStatus.blocked:
        return AppColors.danger;
    }
  }
}
