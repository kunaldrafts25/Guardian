/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'package:flutter/material.dart';
import 'package:guardian/core/constants/app_colors.dart';
import 'package:guardian/core/constants/app_typography.dart';
import 'package:guardian/features/guardian_mode/data/models/guardian_contact_model.dart';
import 'package:guardian/features/guardian_mode/data/models/guardian_session_model.dart';
import 'package:guardian/features/guardian_mode/presentation/widgets/movement_indicator.dart';

/// A card widget for displaying the status of an active guardian session
class GuardianStatusCard extends StatelessWidget {
  /// The active session
  final GuardianSession session;

  /// The guardian contacts for this session
  final List<GuardianContact> guardians;

  const GuardianStatusCard({
    super.key,
    required this.session,
    required this.guardians,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: AppColors.success,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Live Guardian Mode Active',
                style: AppTypography.heading4.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                _formatDuration(DateTime.now().difference(session.startTime)),
                style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildStatusItem(
                icon: Icons.battery_full,
                label: 'Battery',
                value: '${session.batteryLevel}%',
                color: _getBatteryColor(session.batteryLevel),
              ),
              const SizedBox(width: 16),
              _buildStatusItem(
                icon: Icons.favorite,
                label: 'Heart Rate',
                value: session.heartRate != null
                    ? '${session.heartRate} bpm'
                    : 'N/A',
                color: _getHeartRateColor(session.heartRate),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Movement',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    MovementIndicator(
                      movementPattern: session.movementPattern,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Monitoring Guardians (${guardians.length})',
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: guardians.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Tooltip(
                    message: guardians[index].name,
                    child: CircleAvatar(
                      radius: 16,
                      backgroundColor: AppColors.primary.withOpacity(0.2),
                      child: Text(
                        guardians[index].name.isNotEmpty
                            ? guardians[index].name[0].toUpperCase()
                            : '?',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                icon,
                size: 16,
                color: color,
              ),
              const SizedBox(width: 4),
              Text(
                value,
                style: AppTypography.bodyMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getBatteryColor(int level) {
    if (level <= 20) {
      return AppColors.danger;
    } else if (level <= 40) {
      return AppColors.warning;
    } else {
      return AppColors.success;
    }
  }

  Color _getHeartRateColor(int? rate) {
    if (rate == null) {
      return AppColors.textSecondary;
    } else if (rate < 60 || rate > 100) {
      return AppColors.warning;
    } else {
      return AppColors.success;
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return '${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds';
  }
}
