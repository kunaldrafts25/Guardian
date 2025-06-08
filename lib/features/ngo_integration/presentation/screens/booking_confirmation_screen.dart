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
import 'package:guardian/features/ngo_integration/presentation/screens/my_bookings_screen.dart';
import 'package:intl/intl.dart';

class BookingConfirmationScreen extends StatelessWidget {
  final NGO ngo;
  final NGOService service;
  final DateTime appointmentDate;
  final String bookingId;

  const BookingConfirmationScreen({
    super.key,
    required this.ngo,
    required this.service,
    required this.appointmentDate,
    required this.bookingId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Booking Confirmation',
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
              'Booking Confirmed!',
              style: AppTypography.heading2.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your service booking has been confirmed.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Booking details
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  _buildInfoRow('Booking ID', bookingId),
                  const SizedBox(height: 8),
                  _buildInfoRow(
                    'Date & Time',
                    DateFormat('MMM dd, yyyy - h:mm a').format(appointmentDate),
                  ),
                  const SizedBox(height: 8),
                  _buildInfoRow('Organization', ngo.name),
                  const SizedBox(height: 8),
                  _buildInfoRow('Service', service.name),
                  const SizedBox(height: 8),
                  _buildInfoRow(
                    'Cost',
                    service.isFree
                        ? 'Free'
                        : '${service.cost} ${service.currency}',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Contact information
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
                    'Contact Information',
                    style: AppTypography.bodyLarge.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (ngo.phoneNumber != null) ...[
                    _buildContactRow(
                      Icons.phone,
                      ngo.phoneNumber!,
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (ngo.email != null) ...[
                    _buildContactRow(
                      Icons.email,
                      ngo.email!,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Next steps
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.info.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Next Steps',
                    style: AppTypography.bodyLarge.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'The organization will contact you to confirm your appointment. Please make sure to arrive on time for your scheduled appointment.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: CustomButton(
                    text: 'View My Bookings',
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const MyBookingsScreen(),
                        ),
                      );
                    },
                    type: ButtonType.outline,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: CustomButton(
                    text: 'Done',
                    onPressed: () {
                      Navigator.popUntil(
                        context,
                        (route) => route.isFirst,
                      );
                    },
                    type: ButtonType.primary,
                  ),
                ),
              ],
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

  Widget _buildContactRow(IconData icon, String value) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: AppColors.primary,
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: AppTypography.bodyMedium,
        ),
      ],
    );
  }
}
