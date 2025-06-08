/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'package:flutter/material.dart';
import 'package:guardian/core/constants/app_colors.dart';
import 'package:guardian/core/constants/app_typography.dart';
import 'package:guardian/core/di/service_locator.dart';
import 'package:guardian/core/utils/logger.dart';
import 'package:guardian/core/widgets/custom_app_bar.dart';
import 'package:guardian/core/widgets/loading_indicator.dart';
import 'package:guardian/features/ai_assistant/data/ai_repository.dart';
import 'package:guardian/features/ai_assistant/data/models/ai_model.dart';
import 'package:guardian/features/ai_assistant/presentation/widgets/advice_card.dart';
import 'package:intl/intl.dart';

class SafetyAdviceScreen extends StatefulWidget {
  const SafetyAdviceScreen({super.key});

  @override
  State<SafetyAdviceScreen> createState() => _SafetyAdviceScreenState();
}

class _SafetyAdviceScreenState extends State<SafetyAdviceScreen> {
  final AIRepository _repository = sl<AIRepository>();

  List<SafetyAdvice> _advice = [];
  bool _isLoading = true;
  String _selectedFilter = 'All';

  final List<String> _filters = [
    'All',
    'Unread',
    'Location',
    'Situation',
    'Emergency',
    'Travel',
    'General',
  ];

  @override
  void initState() {
    super.initState();
    _loadAdvice();
  }

  Future<void> _loadAdvice() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final advice = await _repository.getSafetyAdvice();

      setState(() {
        _advice = advice;
        _isLoading = false;
      });
    } catch (e) {
      Logger.error('Failed to load safety advice', e);

      setState(() {
        _isLoading = false;
      });
    }
  }

  List<SafetyAdvice> _getFilteredAdvice() {
    if (_selectedFilter == 'All') {
      return _advice;
    } else if (_selectedFilter == 'Unread') {
      return _advice.where((advice) => !advice.isRead).toList();
    } else {
      // Filter by type
      final type = _getAdviceTypeFromFilter(_selectedFilter);
      return _advice.where((advice) => advice.type == type).toList();
    }
  }

  AdviceType _getAdviceTypeFromFilter(String filter) {
    switch (filter.toLowerCase()) {
      case 'location':
        return AdviceType.location;
      case 'situation':
        return AdviceType.situation;
      case 'emergency':
        return AdviceType.emergency;
      case 'travel':
        return AdviceType.travel;
      case 'general':
      default:
        return AdviceType.general;
    }
  }

  Future<void> _viewAdvice(SafetyAdvice advice) async {
    try {
      // Mark advice as read
      if (!advice.isRead) {
        await _repository.markAdviceAsRead(advice.id);

        // Update local state
        setState(() {
          final index = _advice.indexWhere((a) => a.id == advice.id);
          if (index >= 0) {
            _advice[index] = advice.copyWith(isRead: true);
          }
        });
      }

      // Navigate to advice details
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => _AdviceDetailsScreen(advice: advice),
          ),
        );
      }
    } catch (e) {
      Logger.error('Failed to view advice', e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Safety Advice',
      ),
      body: Column(
        children: [
          // Filters
          SizedBox(
            height: 50,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _filters.length,
              itemBuilder: (context, index) {
                final filter = _filters[index];
                final isSelected = filter == _selectedFilter;

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(filter),
                    selected: isSelected,
                    selectedColor: AppColors.primary.withOpacity(0.2),
                    labelStyle: AppTypography.bodyMedium.copyWith(
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.textPrimary,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _selectedFilter = filter;
                        });
                      }
                    },
                  ),
                );
              },
            ),
          ),

          // Advice list
          Expanded(
            child: _isLoading
                ? const Center(child: LoadingIndicator())
                : _buildAdviceList(),
          ),
        ],
      ),
    );
  }

  Widget _buildAdviceList() {
    final filteredAdvice = _getFilteredAdvice();

    if (filteredAdvice.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.info_outline,
              size: 64,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 16),
            Text(
              'No advice found',
              style: AppTypography.heading4.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _selectedFilter == 'All'
                  ? 'You don\'t have any safety advice yet'
                  : 'No $_selectedFilter advice available',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAdvice,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: filteredAdvice.length,
        itemBuilder: (context, index) {
          final advice = filteredAdvice[index];

          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: AdviceCard(
              advice: advice,
              onTap: () => _viewAdvice(advice),
            ),
          );
        },
      ),
    );
  }
}

class _AdviceDetailsScreen extends StatelessWidget {
  final SafetyAdvice advice;

  const _AdviceDetailsScreen({
    required this.advice,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: advice.title,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _buildTypeIcon(),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            advice.title,
                            style: AppTypography.heading3.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Generated on ${DateFormat('MMM dd, yyyy').format(advice.createdAt)}',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildRiskLevelIndicator(),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Content
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Safety Advice',
                      style: AppTypography.heading4.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      advice.content,
                      style: AppTypography.bodyLarge,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Tags
            if (advice.tags.isNotEmpty) ...[
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tags',
                        style: AppTypography.heading4.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: advice.tags.map((tag) {
                          return Chip(
                            label: Text(tag),
                            backgroundColor: AppColors.primary.withOpacity(0.1),
                            labelStyle: AppTypography.caption.copyWith(
                              color: AppColors.primary,
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Location context
            if (advice.locationContext != null) ...[
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Location Context',
                        style: AppTypography.heading4.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (advice.locationContext!.containsKey('address') &&
                          advice.locationContext!['address'] != null) ...[
                        _buildInfoRow(
                          'Address',
                          advice.locationContext!['address'] as String,
                        ),
                        const SizedBox(height: 8),
                      ],
                      if (advice.locationContext!.containsKey('safetyLevel') &&
                          advice.locationContext!['safetyLevel'] != null) ...[
                        _buildInfoRow(
                          'Safety Level',
                          _formatSafetyLevel(
                            advice.locationContext!['safetyLevel'] as String,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Disclaimer
            Text(
              'This advice is generated by AI and should be used as a general guideline. Always use your best judgment in safety situations.',
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeIcon() {
    IconData icon;
    Color color;

    switch (advice.type) {
      case AdviceType.location:
        icon = Icons.location_on;
        color = Colors.blue;
        break;
      case AdviceType.situation:
        icon = Icons.psychology;
        color = Colors.purple;
        break;
      case AdviceType.emergency:
        icon = Icons.warning;
        color = Colors.red;
        break;
      case AdviceType.travel:
        icon = Icons.directions_car;
        color = Colors.green;
        break;
      case AdviceType.general:
      default:
        icon = Icons.info;
        color = Colors.orange;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        color: color,
        size: 24,
      ),
    );
  }

  Widget _buildRiskLevelIndicator() {
    Color color;
    String label;

    switch (advice.riskLevel) {
      case RiskLevel.high:
        color = Colors.red;
        label = 'High Risk';
        break;
      case RiskLevel.medium:
        color = Colors.orange;
        label = 'Medium Risk';
        break;
      case RiskLevel.low:
      default:
        color = Colors.green;
        label = 'Low Risk';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color),
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

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: AppTypography.bodyMedium.copyWith(
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

  String _formatSafetyLevel(String level) {
    switch (level) {
      case 'very_safe':
        return 'Very Safe';
      case 'safe':
        return 'Safe';
      case 'moderate':
        return 'Moderate';
      case 'caution':
        return 'Caution';
      case 'unsafe':
        return 'Unsafe';
      case 'very_unsafe':
        return 'Very Unsafe';
      default:
        return level;
    }
  }
}
