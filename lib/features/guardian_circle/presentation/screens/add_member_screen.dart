/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'package:flutter/material.dart';
import 'package:guardian/core/constants/app_colors.dart';
import 'package:guardian/core/constants/app_typography.dart';
import 'package:guardian/core/utils/logger.dart';
import 'package:guardian/core/widgets/custom_app_bar.dart';
import 'package:guardian/core/widgets/custom_button.dart';
import 'package:guardian/features/guardian_circle/data/guardian_circle_repository.dart';
import 'package:guardian/features/guardian_circle/data/models/guardian_circle_model.dart';

class AddMemberScreen extends StatefulWidget {
  final String circleId;

  const AddMemberScreen({
    super.key,
    required this.circleId,
  });

  @override
  State<AddMemberScreen> createState() => _AddMemberScreenState();
}

class _AddMemberScreenState extends State<AddMemberScreen> {
  final GuardianCircleRepository _repository = GuardianCircleRepository();
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _relationshipController = TextEditingController();

  bool _isLoading = false;
  GuardianMemberRole _selectedRole = GuardianMemberRole.member;

  final List<String> _relationshipOptions = [
    'Family',
    'Friend',
    'Colleague',
    'Neighbor',
    'Other',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _relationshipController.dispose();
    super.dispose();
  }

  Future<void> _addMember() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final success = await _repository.addMemberToCircle(
        circleId: widget.circleId,
        name: _nameController.text,
        phoneNumber: _phoneController.text,
        email: _emailController.text.isNotEmpty ? _emailController.text : null,
        relationship: _relationshipController.text.isNotEmpty
            ? _relationshipController.text
            : null,
        role: _selectedRole,
      );

      if (!success) {
        throw Exception('Failed to add member');
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      Logger.error('Failed to add member', e);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add member: ${e.toString()}'),
            backgroundColor: AppColors.danger,
          ),
        );

        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Add Guardian',
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add a trusted contact to your guardian circle. They will be notified in emergencies and can help you when needed.',
                style: AppTypography.bodyLarge,
              ),
              const SizedBox(height: 24),

              // Name
              Text(
                'Name',
                style: AppTypography.heading4.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  hintText: 'Enter contact name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Phone Number
              Text(
                'Phone Number',
                style: AppTypography.heading4.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  hintText: 'Enter phone number',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a phone number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Email (Optional)
              Text(
                'Email (Optional)',
                style: AppTypography.heading4.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  hintText: 'Enter email address',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),

              // Relationship
              Text(
                'Relationship',
                style: AppTypography.heading4.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                ),
                hint: const Text('Select relationship'),
                value: _relationshipController.text.isNotEmpty
                    ? _relationshipController.text
                    : null,
                items: _relationshipOptions.map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    _relationshipController.text = value;
                  }
                },
              ),
              const SizedBox(height: 16),

              // Role
              Text(
                'Role',
                style: AppTypography.heading4.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<GuardianMemberRole>(
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                ),
                value: _selectedRole,
                items: GuardianMemberRole.values.map((GuardianMemberRole role) {
                  return DropdownMenuItem<GuardianMemberRole>(
                    value: role,
                    child: Text(role == GuardianMemberRole.admin
                        ? 'Admin (Can manage circle)'
                        : 'Member (Can respond to alerts)'),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedRole = value;
                    });
                  }
                },
              ),
              const SizedBox(height: 32),

              // Add Button
              CustomButton(
                text: 'Add Guardian',
                onPressed: _addMember,
                isLoading: _isLoading,
                type: ButtonType.primary,
                isFullWidth: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

