/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'package:flutter/material.dart';
import 'package:guardian/core/constants/app_colors.dart';
import 'package:guardian/core/constants/app_typography.dart';
import 'package:guardian/core/utils/page_transitions.dart';
import 'package:guardian/features/companion/presentation/screens/companion_walk_screen.dart';
import 'package:guardian/features/dashboard/presentation/widgets/quick_access_fab.dart';

/// A row of quick access FABs for the dashboard
class QuickAccessRow extends StatelessWidget {
  const QuickAccessRow({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        Text(
          'Quick Access',
          style: AppTypography.heading4,
        ),
        const SizedBox(height: 16),

        // FABs Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            QuickAccessFab(
              icon: Icons.phone,
              label: 'Fake Call',
              color: AppColors.secondary,
              onTap: () => _showFakeCallDialog(context),
            ),
            QuickAccessFab(
              icon: Icons.directions_walk,
              label: 'Companion Walk',
              color: AppColors.primary,
              onTap: () => _navigateToCompanionWalk(context),
            ),
            QuickAccessFab(
              icon: Icons.share_location,
              label: 'Share Location',
              color: AppColors.accent,
              onTap: () => _showShareLocationDialog(context),
            ),
          ],
        ),
      ],
    );
  }

  void _showFakeCallDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Fake Call',
          style: AppTypography.heading3,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Schedule a fake call to your phone',
              style: AppTypography.bodyMedium,
            ),
            const SizedBox(height: 16),
            // Time selection
            Row(
              children: [
                const Icon(
                  Icons.access_time,
                  color: AppColors.secondary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Call in:',
                  style: AppTypography.bodyMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Time options
            Wrap(
              spacing: 8,
              children: [
                _buildTimeChip('Now', isSelected: true),
                _buildTimeChip('30s'),
                _buildTimeChip('1m'),
                _buildTimeChip('2m'),
              ],
            ),
            const SizedBox(height: 16),
            // Caller selection
            Row(
              children: [
                const Icon(
                  Icons.person,
                  color: AppColors.secondary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Caller:',
                  style: AppTypography.bodyMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Caller options
            Wrap(
              spacing: 8,
              children: [
                _buildCallerChip('Mom', isSelected: true),
                _buildCallerChip('Dad'),
                _buildCallerChip('Friend'),
                _buildCallerChip('Police'),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: AppTypography.buttonMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Implement fake call functionality
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Fake call scheduled'),
                  backgroundColor: AppColors.secondary,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.secondary,
            ),
            child: const Text('Schedule Call'),
          ),
        ],
      ),
    );
  }

  void _navigateToCompanionWalk(BuildContext context) {
    Navigator.of(context).push(
      PageTransitions.fadeSlide(
        page: const CompanionWalkScreen(),
        direction: SlideDirection.fromRight,
      ),
    );
  }

  void _showShareLocationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Share Location',
          style: AppTypography.heading3,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Share your current location with trusted contacts',
              style: AppTypography.bodyMedium,
            ),
            const SizedBox(height: 16),
            // Contact selection
            Text(
              'Select contacts:',
              style: AppTypography.bodyMedium.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            // Contact list (placeholder)
            _buildContactTile('Mom', isSelected: true),
            _buildContactTile('Dad', isSelected: true),
            _buildContactTile('Emergency Contact'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: AppTypography.buttonMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Implement share location functionality
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Location shared with selected contacts'),
                  backgroundColor: AppColors.accent,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
            ),
            child: const Text('Share Location'),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeChip(String time, {bool isSelected = false}) {
    return ChoiceChip(
      label: Text(time),
      selected: isSelected,
      selectedColor: AppColors.secondary.withOpacity(0.2),
      labelStyle: AppTypography.bodySmall.copyWith(
        color: isSelected ? AppColors.secondary : AppColors.textPrimary,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      onSelected: (_) {},
    );
  }

  Widget _buildCallerChip(String caller, {bool isSelected = false}) {
    return ChoiceChip(
      label: Text(caller),
      selected: isSelected,
      selectedColor: AppColors.secondary.withOpacity(0.2),
      labelStyle: AppTypography.bodySmall.copyWith(
        color: isSelected ? AppColors.secondary : AppColors.textPrimary,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      onSelected: (_) {},
    );
  }

  Widget _buildContactTile(String name, {bool isSelected = false}) {
    return CheckboxListTile(
      title: Text(
        name,
        style: AppTypography.bodyMedium,
      ),
      value: isSelected,
      onChanged: (_) {},
      activeColor: AppColors.accent,
      contentPadding: EdgeInsets.zero,
      dense: true,
    );
  }
}
