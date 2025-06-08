/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'package:flutter/material.dart';
import 'package:guardian/core/constants/app_colors.dart';
import 'package:guardian/core/constants/app_typography.dart';
import 'package:guardian/core/widgets/custom_button.dart';

class CompanionWalkScreen extends StatefulWidget {
  const CompanionWalkScreen({super.key});

  @override
  State<CompanionWalkScreen> createState() => _CompanionWalkScreenState();
}

class _CompanionWalkScreenState extends State<CompanionWalkScreen> {
  bool _isWalkActive = false;
  String _selectedContact = 'Mom';
  String _estimatedTime = '15 min';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Companion Walk'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Text(
                'Companion Walk',
                style: AppTypography.heading2,
              ),
              const SizedBox(height: 8),
              Text(
                'Share your journey with trusted contacts who can monitor your progress in real-time.',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),

              // Map placeholder
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.map,
                        size: 48,
                        color: AppColors.primary.withOpacity(0.5),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Map will appear here',
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Walk details
              if (!_isWalkActive) ...[
                // Contact selection
                Text(
                  'Select Contact',
                  style: AppTypography.heading4,
                ),
                const SizedBox(height: 8),
                _buildContactSelector(),
                const SizedBox(height: 16),

                // Estimated time
                Text(
                  'Estimated Time',
                  style: AppTypography.heading4,
                ),
                const SizedBox(height: 8),
                _buildTimeSelector(),
                const SizedBox(height: 24),

                // Start button
                CustomButton(
                  text: 'Start Companion Walk',
                  onPressed: () {
                    setState(() {
                      _isWalkActive = true;
                    });
                  },
                  type: ButtonType.primary,
                  isFullWidth: true,
                ),
              ] else ...[
                // Active walk info
                Card(
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
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.directions_walk,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Walk in Progress',
                                  style: AppTypography.heading4,
                                ),
                                Text(
                                  'Sharing with $_selectedContact',
                                  style: AppTypography.bodyMedium.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildInfoItem(
                              icon: Icons.timer,
                              label: 'Time',
                              value: '12:35',
                            ),
                            _buildInfoItem(
                              icon: Icons.speed,
                              label: 'Speed',
                              value: '4.2 km/h',
                            ),
                            _buildInfoItem(
                              icon: Icons.straighten,
                              label: 'Distance',
                              value: '0.8 km',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // End button
                CustomButton(
                  text: 'End Walk',
                  onPressed: () {
                    setState(() {
                      _isWalkActive = false;
                    });
                  },
                  type: ButtonType.outline,
                  isFullWidth: true,
                ),
                const SizedBox(height: 16),

                // Emergency button
                CustomButton(
                  text: 'Emergency Alert',
                  onPressed: () {
                    // TODO: Implement emergency alert
                  },
                  type: ButtonType.primary,
                  isFullWidth: true,
                  icon: Icons.warning,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContactSelector() {
    return Card(
      elevation: 0,
      color: AppColors.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppColors.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: DropdownButton<String>(
          value: _selectedContact,
          isExpanded: true,
          underline: const SizedBox(),
          icon: const Icon(Icons.arrow_drop_down),
          items: ['Mom', 'Dad', 'Sister', 'Friend', 'Emergency Contact']
              .map((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(value),
            );
          }).toList(),
          onChanged: (String? newValue) {
            if (newValue != null) {
              setState(() {
                _selectedContact = newValue;
              });
            }
          },
        ),
      ),
    );
  }

  Widget _buildTimeSelector() {
    return Card(
      elevation: 0,
      color: AppColors.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppColors.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: DropdownButton<String>(
          value: _estimatedTime,
          isExpanded: true,
          underline: const SizedBox(),
          icon: const Icon(Icons.arrow_drop_down),
          items: ['5 min', '10 min', '15 min', '20 min', '30 min', '45 min', '60 min']
              .map((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(value),
            );
          }).toList(),
          onChanged: (String? newValue) {
            if (newValue != null) {
              setState(() {
                _estimatedTime = newValue;
              });
            }
          },
        ),
      ),
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(
          icon,
          color: AppColors.primary,
          size: 24,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: AppTypography.caption.copyWith(
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
}
