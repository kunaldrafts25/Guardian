/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'package:flutter/material.dart';
import 'package:guardian/core/constants/app_colors.dart';
import 'package:guardian/core/constants/app_typography.dart';
import 'package:guardian/features/guardian_mode/data/models/guardian_contact_model.dart';

/// A card widget for displaying a guardian contact
class GuardianContactCard extends StatelessWidget {
  /// The contact to display
  final GuardianContact contact;

  /// Whether this contact is selected
  final bool isSelected;

  /// Callback when the card is tapped
  final VoidCallback onTap;

  const GuardianContactCard({
    super.key,
    required this.contact,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? AppColors.primary : Colors.transparent,
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _buildAvatar(),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contact.name,
                      style: AppTypography.heading4.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      contact.phoneNumber,
                      style: AppTypography.bodyMedium,
                    ),
                    if (contact.relationship != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        contact.relationship!,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Checkbox(
                value: isSelected,
                onChanged: (_) => onTap(),
                activeColor: AppColors.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    if (contact.profilePictureUrl != null) {
      return CircleAvatar(
        radius: 24,
        backgroundImage: NetworkImage(contact.profilePictureUrl!),
      );
    } else {
      return CircleAvatar(
        radius: 24,
        backgroundColor: AppColors.primary.withOpacity(0.2),
        child: Text(
          contact.name.isNotEmpty ? contact.name[0].toUpperCase() : '?',
          style: AppTypography.heading3.copyWith(
            color: AppColors.primary,
          ),
        ),
      );
    }
  }
}
