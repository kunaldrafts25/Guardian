/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'package:flutter/material.dart';
import 'package:guardian/core/constants/app_colors.dart';
import 'package:guardian/core/constants/app_strings.dart';
import 'package:guardian/core/utils/location_utils.dart';
import 'package:guardian/core/utils/logger.dart';
import 'package:guardian/core/widgets/custom_button.dart';
import 'package:guardian/core/widgets/custom_text_field.dart';
import 'package:guardian/core/services/mock_emergency_service.dart';
import 'package:geolocator/geolocator.dart';

class ReportIncidentScreen extends StatefulWidget {
  const ReportIncidentScreen({super.key});

  @override
  State<ReportIncidentScreen> createState() => _ReportIncidentScreenState();
}

class _ReportIncidentScreenState extends State<ReportIncidentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _selectedCategory = 'Suspicious Activity';
  bool _isAnonymous = true;
  bool _isLoading = false;
  Position? _currentPosition;
  final List<String> _categories = [
    'Suspicious Activity',
    'Harassment',
    'Theft',
    'Infrastructure',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    try {
      final position = await LocationUtils.getCurrentPosition();
      if (position != null && mounted) {
        setState(() {
          _currentPosition = position;
        });
      }
    } catch (e) {
      Logger.error('Error getting current location', e);
    }
  }

  Future<void> _submitReport() async {
    if (!_formKey.currentState!.validate()) return;
    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to get your location. Please try again.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Report incident using mock emergency service
      final success = await EmergencyService.reportIncident(
        type: _selectedCategory,
        position: _currentPosition!,
        description: _descriptionController.text.trim(),
        isAnonymous: _isAnonymous,
      );

      if (!success) {
        throw Exception('Failed to report incident');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Incident reported successfully'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error reporting incident: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.reportIncident),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info text
              const Text(
                'Report an incident to help keep the community safe. Your report will be visible to other users in the area.',
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),

              // Title
              CustomTextField(
                label: 'Title',
                hint: 'Enter a brief title for the incident',
                controller: _titleController,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a title';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Description
              CustomTextField(
                label: 'Description',
                hint: 'Describe what happened in detail',
                controller: _descriptionController,
                maxLines: 5,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a description';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Category
              const Text(
                'Category',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.divider),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedCategory,
                    isExpanded: true,
                    items: _categories.map((category) {
                      return DropdownMenuItem<String>(
                        value: category,
                        child: Text(category),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedCategory = value;
                        });
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Anonymous reporting
              SwitchListTile(
                title: const Text('Report Anonymously'),
                subtitle: const Text(
                    'Your identity will not be shared with other users'),
                value: _isAnonymous,
                activeColor: AppColors.primary,
                contentPadding: EdgeInsets.zero,
                onChanged: (value) {
                  setState(() {
                    _isAnonymous = value;
                  });
                },
              ),
              const SizedBox(height: 24),

              // Location info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.info.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.location_on,
                      color: AppColors.info,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Location',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _currentPosition != null
                                ? 'Your current location will be used'
                                : 'Fetching your location...',
                            style: TextStyle(
                              fontSize: 14,
                              color: _currentPosition != null
                                  ? AppColors.textSecondary
                                  : AppColors.warning,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Submit button
              CustomButton(
                text: 'Submit Report',
                onPressed: _submitReport,
                isLoading: _isLoading,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
