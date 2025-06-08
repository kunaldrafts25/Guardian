/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'package:flutter/material.dart';
import 'package:guardian/core/constants/app_colors.dart';
import 'package:guardian/core/constants/app_strings.dart';
import 'package:guardian/core/widgets/custom_button.dart';
import 'package:guardian/core/widgets/custom_text_field.dart';
import 'package:guardian/features/auth/data/auth_repository.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _authRepository = AuthRepository();
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      final userData = await _authRepository.getUserData();
      if (userData != null && mounted) {
        setState(() {
          _nameController.text = userData['name'] ?? '';
          _emailController.text = userData['email'] ?? '';
          _phoneController.text = userData['phoneNumber'] ?? '';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading profile: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    try {
      await _authRepository.updateUserProfile(
        name: _nameController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating profile: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.profile),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Profile picture
                    const CircleAvatar(
                      radius: 50,
                      backgroundColor: AppColors.primary,
                      child: Icon(
                        Icons.person,
                        size: 50,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () {
                        // TODO: Implement profile picture upload
                      },
                      child: const Text('Change Profile Picture'),
                    ),
                    const SizedBox(height: 24),

                    // Profile form
                    CustomTextField(
                      label: AppStrings.name,
                      hint: 'Enter your full name',
                      controller: _nameController,
                      prefixIcon: const Icon(Icons.person),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      label: AppStrings.email,
                      hint: 'Enter your email',
                      controller: _emailController,
                      prefixIcon: const Icon(Icons.email),
                      enabled: false, // Email cannot be changed
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      label: AppStrings.phoneNumber,
                      hint: 'Enter your phone number',
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      prefixIcon: const Icon(Icons.phone),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your phone number';
                        }
                        if (!RegExp(r'^\+?[0-9]{10,15}$').hasMatch(value)) {
                          return 'Please enter a valid phone number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 32),
                    CustomButton(
                      text: 'Save Profile',
                      onPressed: _saveProfile,
                      isLoading: _isSaving,
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
