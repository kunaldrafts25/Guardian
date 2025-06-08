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
import 'package:guardian/core/widgets/custom_button.dart';
import 'package:guardian/features/safe_zones/data/models/safe_zone_model.dart';
import 'package:guardian/features/safe_zones/data/safe_zone_repository.dart';

class AddRatingScreen extends StatefulWidget {
  final String zoneId;

  const AddRatingScreen({
    super.key,
    required this.zoneId,
  });

  @override
  State<AddRatingScreen> createState() => _AddRatingScreenState();
}

class _AddRatingScreenState extends State<AddRatingScreen> {
  final SafeZoneRepository _repository = sl<SafeZoneRepository>();
  final _commentController = TextEditingController();

  bool _isLoading = false;
  SafetyRatingLevel _selectedRating = SafetyRatingLevel.safe;
  TimeContext _selectedTimeContext = TimeContext.allTimes;
  String? _selectedIncidentType;
  bool _isAnonymous = false;

  final List<String> _incidentTypes = [
    'Harassment',
    'Theft',
    'Assault',
    'Suspicious Activity',
    'Poor Lighting',
    'Isolated Area',
    'Traffic Safety',
    'Other',
  ];

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitRating() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final success = await _repository.addRatingToZone(
        zoneId: widget.zoneId,
        rating: _selectedRating,
        timeContext: _selectedTimeContext,
        comment:
            _commentController.text.isNotEmpty ? _commentController.text : null,
        incidentType: _selectedIncidentType,
        isAnonymous: _isAnonymous,
      );

      if (!success) {
        throw Exception('Failed to submit rating');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Rating submitted successfully'),
            backgroundColor: AppColors.success,
          ),
        );

        Navigator.pop(context, true);
      }
    } catch (e) {
      Logger.error('Failed to submit rating', e);

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit rating: ${e.toString()}'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Add Rating',
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'How would you rate this area?',
              style: AppTypography.heading4.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // Safety Rating
            _buildRatingSelector(),
            const SizedBox(height: 24),

            // Time Context
            Text(
              'When is this rating applicable?',
              style: AppTypography.heading4.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            _buildTimeContextSelector(),
            const SizedBox(height: 24),

            // Incident Type (if unsafe)
            if (_selectedRating == SafetyRatingLevel.unsafe ||
                _selectedRating == SafetyRatingLevel.veryUnsafe) ...[
              Text(
                'What type of incident or concern?',
                style: AppTypography.heading4.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Select incident type',
                ),
                value: _selectedIncidentType,
                items: _incidentTypes.map((type) {
                  return DropdownMenuItem<String>(
                    value: type,
                    child: Text(type),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedIncidentType = value;
                  });
                },
              ),
              const SizedBox(height: 24),
            ],

            // Comment
            Text(
              'Additional Comments (Optional)',
              style: AppTypography.heading4.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _commentController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Share your experience or observations...',
              ),
              maxLines: 4,
            ),
            const SizedBox(height: 16),

            // Anonymous Option
            CheckboxListTile(
              title: const Text('Submit Anonymously'),
              subtitle:
                  const Text('Your identity will not be shared with others'),
              value: _isAnonymous,
              onChanged: (value) {
                setState(() {
                  _isAnonymous = value ?? false;
                });
              },
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 24),

            // Submit Button
            CustomButton(
              text: 'Submit Rating',
              onPressed: _submitRating,
              isLoading: _isLoading,
              type: ButtonType.primary,
              isFullWidth: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildRatingOption(
          rating: SafetyRatingLevel.veryUnsafe,
          icon: Icons.sentiment_very_dissatisfied,
          label: 'Very Unsafe',
          color: Colors.red,
        ),
        _buildRatingOption(
          rating: SafetyRatingLevel.unsafe,
          icon: Icons.sentiment_dissatisfied,
          label: 'Unsafe',
          color: Colors.orange,
        ),
        _buildRatingOption(
          rating: SafetyRatingLevel.moderate,
          icon: Icons.sentiment_neutral,
          label: 'Moderate',
          color: Colors.yellow.shade700,
        ),
        _buildRatingOption(
          rating: SafetyRatingLevel.safe,
          icon: Icons.sentiment_satisfied,
          label: 'Safe',
          color: Colors.lightGreen,
        ),
        _buildRatingOption(
          rating: SafetyRatingLevel.verySafe,
          icon: Icons.sentiment_very_satisfied,
          label: 'Very Safe',
          color: Colors.green,
        ),
      ],
    );
  }

  Widget _buildRatingOption({
    required SafetyRatingLevel rating,
    required IconData icon,
    required String label,
    required Color color,
  }) {
    final isSelected = _selectedRating == rating;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedRating = rating;
        });
      },
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isSelected ? color.withOpacity(0.2) : Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? color : Colors.grey.shade300,
                width: 2,
              ),
            ),
            child: Icon(
              icon,
              color: isSelected ? color : Colors.grey,
              size: 28,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTypography.caption.copyWith(
              color: isSelected ? color : AppColors.textSecondary,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeContextSelector() {
    return Column(
      children: [
        RadioListTile<TimeContext>(
          title: const Text('Safe at all times'),
          value: TimeContext.allTimes,
          groupValue: _selectedTimeContext,
          onChanged: (value) {
            setState(() {
              _selectedTimeContext = value!;
            });
          },
          activeColor: AppColors.primary,
        ),
        RadioListTile<TimeContext>(
          title: const Text('Safe during daytime only'),
          value: TimeContext.daytimeOnly,
          groupValue: _selectedTimeContext,
          onChanged: (value) {
            setState(() {
              _selectedTimeContext = value!;
            });
          },
          activeColor: AppColors.primary,
        ),
        RadioListTile<TimeContext>(
          title: const Text('Safe during nighttime only'),
          value: TimeContext.nighttimeOnly,
          groupValue: _selectedTimeContext,
          onChanged: (value) {
            setState(() {
              _selectedTimeContext = value!;
            });
          },
          activeColor: AppColors.primary,
        ),
        RadioListTile<TimeContext>(
          title: const Text('Never safe'),
          value: TimeContext.neverSafe,
          groupValue: _selectedTimeContext,
          onChanged: (value) {
            setState(() {
              _selectedTimeContext = value!;
            });
          },
          activeColor: AppColors.primary,
        ),
      ],
    );
  }
}
