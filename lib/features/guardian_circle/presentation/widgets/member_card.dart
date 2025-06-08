/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'package:flutter/material.dart';
import 'package:guardian/core/constants/app_colors.dart';
import 'package:guardian/core/constants/app_typography.dart';
import 'package:guardian/features/guardian_circle/data/models/guardian_circle_model.dart';

/// A card widget for displaying a guardian circle member
class MemberCard extends StatelessWidget {
  /// The member to display
  final GuardianCircleMember member;

  /// Callback when the remove button is pressed
  final VoidCallback? onRemove;

  const MemberCard({
    super.key,
    required this.member,
    this.onRemove,
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
        child: Row(
          children: [
            _buildAvatar(),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          member.name,
                          style: AppTypography.bodyLarge.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      _buildStatusBadge(),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    member.phoneNumber,
                    style: AppTypography.bodyMedium,
                  ),
                  if (member.relationship != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      member.relationship!,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (onRemove != null)
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                color: AppColors.danger,
                onPressed: onRemove,
                tooltip: 'Remove member',
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    if (member.profilePictureUrl != null) {
      return CircleAvatar(
        radius: 20,
        backgroundImage: NetworkImage(member.profilePictureUrl!),
      );
    } else {
      return CircleAvatar(
        radius: 20,
        backgroundColor: _getStatusColor().withOpacity(0.2),
        child: Text(
          member.name.isNotEmpty ? member.name[0].toUpperCase() : '?',
          style: AppTypography.heading4.copyWith(
            color: _getStatusColor(),
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }
  }

  Widget _buildStatusBadge() {
    String label;
    Color color;

    if (member.role == GuardianMemberRole.admin) {
      label = 'Admin';
      color = AppColors.info;
    } else {
      switch (member.status) {
        case GuardianMemberStatus.active:
          label = 'Active';
          color = AppColors.success;
          break;
        case GuardianMemberStatus.invited:
          label = 'Invited';
          color = AppColors.warning;
          break;
        case GuardianMemberStatus.blocked:
          label = 'Blocked';
          color = AppColors.danger;
          break;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
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

  Color _getStatusColor() {
    switch (member.status) {
      case GuardianMemberStatus.active:
        return AppColors.success;
      case GuardianMemberStatus.invited:
        return AppColors.warning;
      case GuardianMemberStatus.blocked:
        return AppColors.danger;
    }
  }
}
