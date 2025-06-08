/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'package:flutter/material.dart';
import 'package:guardian/core/constants/app_colors.dart';
import 'package:guardian/core/constants/app_strings.dart';

class SafetyStatusCard extends StatelessWidget {
  final bool isSafetyModeEnabled;
  final Function(bool) onToggleSafetyMode;

  const SafetyStatusCard({
    super.key,
    required this.isSafetyModeEnabled,
    required this.onToggleSafetyMode,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isSafetyModeEnabled ? Icons.shield : Icons.shield_outlined,
                  color: isSafetyModeEnabled ? AppColors.success : AppColors.textSecondary,
                  size: 28,
                ),
                const SizedBox(width: 12),
                const Text(
                  AppStrings.safetyStatus,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isSafetyModeEnabled ? 'Safety Mode Enabled' : 'Safety Mode Disabled',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: isSafetyModeEnabled ? AppColors.success : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isSafetyModeEnabled
                          ? 'Your location is being monitored'
                          : 'Enable safety mode when traveling',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                Switch(
                  value: isSafetyModeEnabled,
                  onChanged: onToggleSafetyMode,
                  activeColor: AppColors.success,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStatusItem(
                  icon: Icons.location_on,
                  label: AppStrings.locationStatus,
                  status: 'Active',
                  isActive: true,
                ),
                _buildStatusItem(
                  icon: Icons.battery_full,
                  label: AppStrings.batteryStatus,
                  status: '85%',
                  isActive: true,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusItem({
    required IconData icon,
    required String label,
    required String status,
    required bool isActive,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          color: isActive ? AppColors.success : AppColors.danger,
          size: 16,
        ),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            Text(
              status,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isActive ? AppColors.success : AppColors.danger,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
