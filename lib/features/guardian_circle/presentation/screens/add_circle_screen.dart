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
import 'package:guardian/features/guardian_circle/data/guardian_circle_repository.dart';

class AddCircleScreen extends StatefulWidget {
  const AddCircleScreen({super.key});

  @override
  State<AddCircleScreen> createState() => _AddCircleScreenState();
}

class _AddCircleScreenState extends State<AddCircleScreen> {
  final GuardianCircleRepository _repository = sl<GuardianCircleRepository>();
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _createCircle() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final circleId = await _repository.createGuardianCircle(
        name: _nameController.text,
        description: _descriptionController.text.isNotEmpty
            ? _descriptionController.text
            : null,
      );

      if (circleId == null) {
        throw Exception('Failed to create circle');
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      Logger.error('Failed to create circle', e);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create circle: ${e.toString()}'),
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
        title: 'Create Guardian Circle',
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Create a new guardian circle to add trusted contacts who can help you in emergencies.',
                style: AppTypography.bodyLarge,
              ),
              const SizedBox(height: 24),

              // Circle Name
              Text(
                'Circle Name',
                style: AppTypography.heading4.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  hintText: 'e.g., Family, Friends, Colleagues',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a name for your circle';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Description
              Text(
                'Description (Optional)',
                style: AppTypography.heading4.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  hintText: 'Describe the purpose of this circle',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 32),

              // Create Button
              CustomButton(
                text: 'Create Circle',
                onPressed: _createCircle,
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
