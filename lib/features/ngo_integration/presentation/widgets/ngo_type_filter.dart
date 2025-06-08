/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'package:flutter/material.dart';
import 'package:guardian/core/constants/app_colors.dart';
import 'package:guardian/core/constants/app_typography.dart';
import 'package:guardian/features/ngo_integration/data/models/ngo_model.dart';

/// A filter widget for NGO types
class NGOTypeFilter extends StatelessWidget {
  /// Currently selected NGO type
  final NGOType? selectedType;

  /// Callback when a type is selected
  final Function(NGOType?) onTypeSelected;

  const NGOTypeFilter({
    super.key,
    required this.selectedType,
    required this.onTypeSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          // All filter
          _buildFilterChip(
            label: 'All',
            isSelected: selectedType == null,
            onSelected: (selected) {
              if (selected) {
                onTypeSelected(null);
              }
            },
          ),

          // Type filters
          ...NGOType.values.map((type) {
            return _buildFilterChip(
              label: _getNGOTypeLabel(type),
              isSelected: selectedType == type,
              onSelected: (selected) {
                if (selected) {
                  onTypeSelected(type);
                }
              },
            );
          }),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required Function(bool) onSelected,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        selectedColor: AppColors.primary.withOpacity(0.2),
        labelStyle: AppTypography.bodyMedium.copyWith(
          color: isSelected ? AppColors.primary : AppColors.textPrimary,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        onSelected: onSelected,
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
