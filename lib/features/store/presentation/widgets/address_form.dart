/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'package:flutter/material.dart';

/// A form widget for collecting shipping address information
class AddressForm extends StatelessWidget {
  /// Form key for validation
  final GlobalKey<FormState> formKey;

  /// Controller for the name field
  final TextEditingController nameController;

  /// Controller for the address field
  final TextEditingController addressController;

  /// Controller for the city field
  final TextEditingController cityController;

  /// Controller for the state field
  final TextEditingController stateController;

  /// Controller for the zip code field
  final TextEditingController zipController;

  /// Controller for the phone number field
  final TextEditingController phoneController;

  const AddressForm({
    super.key,
    required this.formKey,
    required this.nameController,
    required this.addressController,
    required this.cityController,
    required this.stateController,
    required this.zipController,
    required this.phoneController,
  });

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        children: [
          // Full Name
          TextFormField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: 'Full Name',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.person),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your full name';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Address
          TextFormField(
            controller: addressController,
            decoration: const InputDecoration(
              labelText: 'Address',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.home),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your address';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // City and State
          Row(
            children: [
              // City
              Expanded(
                child: TextFormField(
                  controller: cityController,
                  decoration: const InputDecoration(
                    labelText: 'City',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.location_city),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your city';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 16),

              // State
              Expanded(
                child: TextFormField(
                  controller: stateController,
                  decoration: const InputDecoration(
                    labelText: 'State',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.map),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your state';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Zip Code
          TextFormField(
            controller: zipController,
            decoration: const InputDecoration(
              labelText: 'Zip Code',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.pin),
            ),
            keyboardType: TextInputType.number,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your zip code';
              }

              if (value.length < 5) {
                return 'Please enter a valid zip code';
              }

              return null;
            },
          ),
          const SizedBox(height: 16),

          // Phone Number
          TextFormField(
            controller: phoneController,
            decoration: const InputDecoration(
              labelText: 'Phone Number',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.phone),
            ),
            keyboardType: TextInputType.phone,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your phone number';
              }

              if (value.length < 10) {
                return 'Please enter a valid phone number';
              }

              return null;
            },
          ),
        ],
      ),
    );
  }
}
