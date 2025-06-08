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
import 'package:guardian/features/ngo_integration/data/models/ngo_model.dart';
import 'package:guardian/features/ngo_integration/data/ngo_repository.dart';
import 'package:guardian/features/ngo_integration/presentation/screens/volunteer_confirmation_screen.dart';

class VolunteerScreen extends StatefulWidget {
  final NGO ngo;

  const VolunteerScreen({
    super.key,
    required this.ngo,
  });

  @override
  State<VolunteerScreen> createState() => _VolunteerScreenState();
}

class _VolunteerScreenState extends State<VolunteerScreen> {
  final NGORepository _repository = sl<NGORepository>();
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _messageController = TextEditingController();

  String _selectedAvailability = 'Weekends';
  final List<String> _selectedInterests = [];
  bool _isLoading = false;

  final List<String> _availabilityOptions = [
    'Weekdays',
    'Weekends',
    'Evenings',
    'Flexible',
    'Full-time',
    'Part-time',
  ];

  List<String> _interestOptions = [];

  @override
  void initState() {
    super.initState();
    _loadInterestOptions();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _loadInterestOptions() {
    // In a real app, these would come from the NGO's volunteer opportunities
    if (widget.ngo.volunteerOpportunities != null &&
        widget.ngo.volunteerOpportunities!.isNotEmpty) {
      _interestOptions = widget.ngo.volunteerOpportunities!;
    } else {
      // Default options
      _interestOptions = [
        'Event Support',
        'Counseling',
        'Legal Support',
        'Administrative',
        'Outreach',
        'Education',
        'Crisis Response',
        'Fundraising',
      ];
    }
  }

  void _toggleInterest(String interest) {
    setState(() {
      if (_selectedInterests.contains(interest)) {
        _selectedInterests.remove(interest);
      } else {
        _selectedInterests.add(interest);
      }
    });
  }

  Future<void> _registerAsVolunteer() async {
    if (_formKey.currentState?.validate() != true) {
      return;
    }

    if (_selectedInterests.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one interest'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Register as volunteer
      final volunteerId = await _repository.registerAsVolunteer(
        ngoId: widget.ngo.id,
        name: _nameController.text,
        email: _emailController.text,
        phone: _phoneController.text,
        interests: _selectedInterests,
        availability: _selectedAvailability,
        message:
            _messageController.text.isNotEmpty ? _messageController.text : null,
      );

      if (volunteerId == null) {
        throw Exception('Failed to register as volunteer');
      }

      if (mounted) {
        // Navigate to confirmation screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => VolunteerConfirmationScreen(
              ngo: widget.ngo,
              volunteerId: volunteerId,
            ),
          ),
        );
      }
    } catch (e) {
      Logger.error('Failed to register as volunteer', e);

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to register: ${e.toString()}'),
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
        title: 'Volunteer Registration',
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // NGO Info
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
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
                          widget.ngo.logoUrl,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(
                              Icons.business,
                              size: 32,
                              color: AppColors.primary,
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.ngo.name,
                              style: AppTypography.heading4.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Volunteer Registration',
                              style: AppTypography.caption.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Personal Information
              Text(
                'Personal Information',
                style: AppTypography.heading4.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your email';
                  }
                  if (!value.contains('@') || !value.contains('.')) {
                    return 'Please enter a valid email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your phone number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Interests
              Text(
                'Areas of Interest',
                style: AppTypography.heading4.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Select all that apply',
                style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _interestOptions.map((interest) {
                  final isSelected = _selectedInterests.contains(interest);

                  return FilterChip(
                    label: Text(interest),
                    selected: isSelected,
                    onSelected: (_) => _toggleInterest(interest),
                    backgroundColor: Colors.white,
                    selectedColor: AppColors.primary.withOpacity(0.2),
                    checkmarkColor: AppColors.primary,
                    labelStyle: TextStyle(
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.textPrimary,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // Availability
              Text(
                'Availability',
                style: AppTypography.heading4.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedAvailability,
                decoration: const InputDecoration(
                  labelText: 'Select Availability',
                  border: OutlineInputBorder(),
                ),
                items: _availabilityOptions.map((availability) {
                  return DropdownMenuItem<String>(
                    value: availability,
                    child: Text(availability),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedAvailability = value;
                    });
                  }
                },
              ),
              const SizedBox(height: 24),

              // Message
              Text(
                'Message (Optional)',
                style: AppTypography.heading4.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _messageController,
                decoration: const InputDecoration(
                  labelText: 'Message',
                  hintText: 'Tell us why you want to volunteer...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 24),

              // Register Button
              CustomButton(
                text: 'Register as Volunteer',
                onPressed: _registerAsVolunteer,
                isLoading: _isLoading,
                type: ButtonType.primary,
                isFullWidth: true,
              ),
              const SizedBox(height: 16),

              // Disclaimer
              Text(
                'By registering, you agree to be contacted by the organization regarding volunteer opportunities.',
                style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
