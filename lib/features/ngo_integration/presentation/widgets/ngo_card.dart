/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'package:flutter/material.dart';
import 'package:guardian/core/constants/app_colors.dart';
import 'package:guardian/core/constants/app_typography.dart';
import 'package:guardian/features/ngo_integration/data/models/ngo_model.dart';

/// A card widget for displaying an NGO
class NGOCard extends StatelessWidget {
  /// The NGO to display
  final NGO ngo;

  /// Callback when the card is tapped
  final VoidCallback onTap;

  const NGOCard({
    super.key,
    required this.ngo,
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
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Logo
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(8),
                child: Image.network(
                  ngo.logoUrl,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(
                      Icons.business,
                      size: 32,
                      color: AppColors.primary,
                    );
                  },
                ),
              ),
              const SizedBox(width: 16),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name and verified badge
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            ngo.name,
                            style: AppTypography.heading4.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (ngo.isVerified)
                          const Icon(
                            Icons.verified,
                            size: 16,
                            color: AppColors.success,
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Type
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        _getNGOTypeLabel(ngo.type),
                        style: AppTypography.caption.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Description
                    Text(
                      ngo.description,
                      style: AppTypography.bodyMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),

                    // Services count
                    Row(
                      children: [
                        const Icon(
                          Icons.volunteer_activism,
                          size: 16,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${ngo.services.length} Services',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 16),
                        if (ngo.acceptsDonations) ...[
                          const Icon(
                            Icons.monetization_on,
                            size: 16,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Accepts Donations',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getNGOTypeLabel(NGOType type) {
    switch (type) {
      case NGOType.womenSafety:
        return 'Women\'s Safety';
      case NGOType.crisisSupport:
        return 'Crisis Support';
      case NGOType.legalAid:
        return 'Legal Aid';
      case NGOType.mentalHealth:
        return 'Mental Health';
      case NGOType.communitySafety:
        return 'Community Safety';
      case NGOType.other:
        return 'Other';
    }
  }
}
