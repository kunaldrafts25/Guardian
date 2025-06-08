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

class EmergencyContactsScreen extends StatefulWidget {
  const EmergencyContactsScreen({super.key});

  @override
  State<EmergencyContactsScreen> createState() => _EmergencyContactsScreenState();
}

class _EmergencyContactsScreenState extends State<EmergencyContactsScreen> {
  final _authRepository = AuthRepository();
  List<Map<String, dynamic>> _contacts = [];
  bool _isLoading = true;

  // Helper method to show success message
  void _showSuccessMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.success,
      ),
    );
  }

  // Helper method to show error message
  void _showErrorMessage(String message, dynamic error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$message: $error'),
        backgroundColor: AppColors.danger,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    try {
      final userData = await _authRepository.getUserData();
      if (userData != null && mounted) {
        setState(() {
          _contacts = List<Map<String, dynamic>>.from(userData['emergencyContacts'] ?? []);
          _isLoading = false;
        });
      }
    } catch (e) {
      // Show error message
      _showErrorMessage('Error loading contacts', e);

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showAddContactDialog() {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final relationshipController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Emergency Contact'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CustomTextField(
                  label: 'Name',
                  hint: 'Enter contact name',
                  controller: nameController,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  label: 'Phone Number',
                  hint: 'Enter phone number',
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a phone number';
                    }
                    if (!RegExp(r'^\+?[0-9]{10,15}$').hasMatch(value)) {
                      return 'Please enter a valid phone number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  label: 'Relationship',
                  hint: 'E.g., Family, Friend, etc.',
                  controller: relationshipController,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                Navigator.of(context).pop();

                try {
                  await _authRepository.addEmergencyContact(
                    name: nameController.text.trim(),
                    phoneNumber: phoneController.text.trim(),
                    relationship: relationshipController.text.trim(),
                  );

                  // Reload contacts
                  _loadContacts();

                  // Show success message
                  _showSuccessMessage('Contact added successfully');
                } catch (e) {
                  // Show error message
                  _showErrorMessage('Error adding contact', e);
                }
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _removeContact(String phoneNumber) async {
    try {
      await _authRepository.removeEmergencyContact(phoneNumber);

      // Reload contacts
      _loadContacts();

      // Show success message
      _showSuccessMessage('Contact removed successfully');
    } catch (e) {
      // Show error message
      _showErrorMessage('Error removing contact', e);
    }
  }

  void _showRemoveContactDialog(Map<String, dynamic> contact) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Contact'),
        content: Text('Are you sure you want to remove ${contact['name']} from your emergency contacts?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _removeContact(contact['phone']);
            },
            child: const Text(
              'Remove',
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.emergencyContacts),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'These contacts will be notified in case of an emergency.',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                Expanded(
                  child: _contacts.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.contacts,
                                size: 64,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'No emergency contacts added yet',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 24),
                              CustomButton(
                                text: 'Add Contact',
                                onPressed: _showAddContactDialog,
                                type: ButtonType.outline,
                                isFullWidth: false,
                                width: 200,
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _contacts.length,
                          itemBuilder: (context, index) {
                            final contact = _contacts[index];
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: AppColors.primary,
                                child: Text(
                                  contact['name'][0],
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              title: Text(contact['name']),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(contact['phone']),
                                  if (contact['relationship'] != null && contact['relationship'].isNotEmpty)
                                    Text(
                                      contact['relationship'],
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                ],
                              ),
                              trailing: IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: AppColors.danger,
                                ),
                                onPressed: () => _showRemoveContactDialog(contact),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddContactDialog,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add),
      ),
    );
  }
}
