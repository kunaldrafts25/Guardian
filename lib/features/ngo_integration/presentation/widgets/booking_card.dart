/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'package:flutter/material.dart';
import 'package:guardian/core/constants/app_colors.dart';
import 'package:guardian/core/constants/app_typography.dart';
import 'package:guardian/features/ngo_integration/data/models/ngo_model.dart';
import 'package:intl/intl.dart';

/// A card widget for displaying a service booking
class BookingCard extends StatelessWidget {
  /// The booking data to display
  final Map<String, dynamic> booking;

  /// Callback when the cancel button is pressed
  final VoidCallback onCancel;

  const BookingCard({
    super.key,
    required this.booking,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final service = NGOService.fromMap(booking['service']);
    final ngo = NGO.fromMap(booking['ngo']);
    final appointmentDate = DateTime.parse(booking['appointmentDate']);
    final status = booking['status'] as String;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
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
                        size: 20,
                        color: AppColors.primary,
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ngo.name,
                        style: AppTypography.bodyLarge.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        service.name,
                        style: AppTypography.bodyMedium,
                      ),
                    ],
                  ),
                ),
                _buildStatusBadge(status),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),

            // Booking details
            _buildInfoRow(
              'Appointment',
              DateFormat('MMM dd, yyyy - h:mm a').format(appointmentDate),
              Icons.calendar_today,
            ),
            const SizedBox(height: 8),
            _buildInfoRow(
              'Booking ID',
              booking['id'],
              Icons.confirmation_number,
            ),
            const SizedBox(height: 8),
            _buildInfoRow(
              'Cost',
              service.isFree ? 'Free' : '${service.cost} ${service.currency}',
              Icons.monetization_on,
            ),
            if (booking['notes'] != null) ...[
              const SizedBox(height: 8),
              _buildInfoRow(
                'Notes',
                booking['notes'],
                Icons.note,
              ),
            ],
            const SizedBox(height: 16),

            // Action buttons
            if (status != 'cancelled')
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onCancel,
                  icon: const Icon(Icons.cancel),
                  label: const Text('Cancel Booking'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: const BorderSide(color: AppColors.danger),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String label;

    switch (status.toLowerCase()) {
      case 'confirmed':
        color = AppColors.success;
        label = 'Confirmed';
        break;
      case 'pending':
        color = AppColors.warning;
        label = 'Pending';
        break;
      case 'cancelled':
        color = AppColors.danger;
        label = 'Cancelled';
        break;
      case 'completed':
        color = AppColors.info;
        label = 'Completed';
        break;
      default:
        color = AppColors.textSecondary;
        label = status;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
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

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 16,
          color: AppColors.textSecondary,
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: AppTypography.bodyMedium,
          ),
        ),
      ],
    );
  }
}
