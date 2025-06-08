/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'package:flutter/material.dart';
import 'package:guardian/core/constants/app_colors.dart';
import 'package:guardian/core/constants/app_typography.dart';
import 'package:guardian/core/widgets/custom_app_bar.dart';
import 'package:guardian/core/widgets/custom_button.dart';
import 'package:guardian/features/ngo_integration/data/models/ngo_model.dart';
import 'package:intl/intl.dart';

class DonationConfirmationScreen extends StatelessWidget {
  final NGO ngo;
  final double amount;
  final String currency;
  final String donationId;

  const DonationConfirmationScreen({
    super.key,
    required this.ngo,
    required this.amount,
    required this.currency,
    required this.donationId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Donation Confirmation',
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Success icon
            const Icon(
              Icons.check_circle,
              size: 80,
              color: AppColors.success,
            ),
            const SizedBox(height: 24),

            // Thank you message
            Text(
              'Thank You!',
              style: AppTypography.heading2.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your donation to ${ngo.name} has been processed successfully.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Donation details
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  _buildInfoRow('Donation ID', donationId),
                  const SizedBox(height: 8),
                  _buildInfoRow(
                    'Date',
                    DateFormat('MMM dd, yyyy').format(DateTime.now()),
                  ),
                  const SizedBox(height: 8),
                  _buildInfoRow('Organization', ngo.name),
                  const SizedBox(height: 8),
                  _buildInfoRow(
                    'Amount',
                    '$currency ${amount.toStringAsFixed(2)}',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Impact message
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your Impact',
                    style: AppTypography.bodyLarge.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your donation will help ${ngo.name} continue their important work in ${_getNGOTypeLabel(ngo.type)}. Thank you for your generosity and support.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Receipt info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Receipt',
                    style: AppTypography.bodyLarge.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'A receipt has been sent to your email address. You can also access your donation history in the app.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Action button
            CustomButton(
              text: 'Done',
              onPressed: () {
                Navigator.popUntil(
                  context,
                  (route) => route.isFirst,
                );
              },
              type: ButtonType.primary,
              isFullWidth: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: AppTypography.bodyMedium.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  String _getNGOTypeLabel(NGOType type) {
    switch (type) {
      case NGOType.womenSafety:
        return 'women\'s safety';
      case NGOType.crisisSupport:
        return 'crisis support';
      case NGOType.legalAid:
        return 'legal aid';
      case NGOType.mentalHealth:
        return 'mental health support';
      case NGOType.communitySafety:
        return 'community safety';
      case NGOType.other:
        return 'their mission';
    }
  }
}
