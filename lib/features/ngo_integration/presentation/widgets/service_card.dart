/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'package:flutter/material.dart';
import 'package:guardian/core/constants/app_colors.dart';
import 'package:guardian/core/constants/app_typography.dart';
import 'package:guardian/features/ngo_integration/data/models/ngo_model.dart';

/// A card widget for displaying an NGO service
class ServiceCard extends StatelessWidget {
  /// The service to display
  final NGOService service;

  /// Callback when the book button is pressed
  final VoidCallback onBook;

  const ServiceCard({
    super.key,
    required this.service,
    required this.onBook,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Name and cost
            Row(
              children: [
                Expanded(
                  child: Text(
                    service.name,
                    style: AppTypography.bodyLarge.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: service.isFree
                        ? AppColors.success.withOpacity(0.1)
                        : AppColors.info.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    service.isFree
                        ? 'Free'
                        : '${service.cost} ${service.currency}',
                    style: AppTypography.caption.copyWith(
                      color:
                          service.isFree ? AppColors.success : AppColors.info,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Description
            Text(
              service.description,
              style: AppTypography.bodyMedium,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),

            // Service details
            Row(
              children: [
                // Availability
                Expanded(
                  child: Row(
                    children: [
                      const Icon(
                        Icons.access_time,
                        size: 16,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          service.isAvailable24x7
                              ? 'Available 24/7'
                              : service.availabilityHours ??
                                  'Contact for hours',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),

                // Mode
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        _getModeIcon(),
                        size: 16,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          _getServiceMode(),
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Book button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onBook,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
                child: const Text('Book Service'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getModeIcon() {
    if (service.isOnline && service.isInPerson) {
      return Icons.compare_arrows;
    } else if (service.isOnline) {
      return Icons.computer;
    } else if (service.isInPerson) {
      return Icons.person;
    } else {
      return Icons.help_outline;
    }
  }

  String _getServiceMode() {
    if (service.isOnline && service.isInPerson) {
      return 'Online & In-Person';
    } else if (service.isOnline) {
      return 'Online';
    } else if (service.isInPerson) {
      return 'In-Person';
    } else {
      return 'Contact for details';
    }
  }
}
