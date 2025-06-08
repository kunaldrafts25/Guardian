/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:guardian/core/constants/app_colors.dart';
import 'package:guardian/core/constants/app_typography.dart';
import 'package:guardian/core/di/service_locator.dart';
import 'package:guardian/core/utils/logger.dart';
import 'package:guardian/core/utils/location_utils.dart';
import 'package:guardian/core/widgets/custom_app_bar.dart';
import 'package:guardian/core/widgets/custom_button.dart';
import 'package:guardian/core/widgets/loading_indicator.dart';
import 'package:guardian/features/safe_zones/data/safe_zone_repository.dart';

class AddSafeZoneScreen extends StatefulWidget {
  const AddSafeZoneScreen({super.key});

  @override
  State<AddSafeZoneScreen> createState() => _AddSafeZoneScreenState();
}

class _AddSafeZoneScreenState extends State<AddSafeZoneScreen> {
  final SafeZoneRepository _repository = sl<SafeZoneRepository>();
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _addressController = TextEditingController();
  final _radiusController = TextEditingController(text: '100');

  final Completer<GoogleMapController> _mapController = Completer();

  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _isMapReady = false;
  LatLng? _currentLocation;
  LatLng? _selectedLocation;

  Set<Marker> _markers = {};
  Set<Circle> _circles = {};

  final List<String> _tagOptions = [
    'Residential',
    'Commercial',
    'Educational',
    'Public Transport',
    'Park',
    'Hospital',
    'Police Station',
    'Shopping',
    'Entertainment',
    'Other',
  ];

  final List<String> _selectedTags = [];

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    _radiusController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final position = await LocationUtils.getCurrentPosition();

      if (position != null) {
        final latLng = LatLng(position.latitude, position.longitude);

        setState(() {
          _currentLocation = latLng;
          _selectedLocation = latLng;
          _isLoading = false;
        });

        if (_isMapReady) {
          _moveToLocation(latLng);
          _updateMarkerAndCircle(latLng);
        }

        // Try to get address
        final address = await LocationUtils.getAddressFromPosition(position);
        if (address != null) {
          setState(() {
            _addressController.text = address;
          });
        }
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      Logger.error('Failed to get current location', e);

      setState(() {
        _isLoading = false;
      });
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController.complete(controller);
    setState(() {
      _isMapReady = true;
    });

    if (_selectedLocation != null) {
      _moveToLocation(_selectedLocation!);
      _updateMarkerAndCircle(_selectedLocation!);
    }
  }

  Future<void> _moveToLocation(LatLng location) async {
    if (!_isMapReady) return;

    final controller = await _mapController.future;
    controller.animateCamera(
      CameraUpdate.newLatLngZoom(location, 15),
    );
  }

  void _updateMarkerAndCircle(LatLng location) {
    final radius = double.tryParse(_radiusController.text) ?? 100.0;

    setState(() {
      _markers = {
        Marker(
          markerId: const MarkerId('selected_location'),
          position: location,
          draggable: true,
          onDragEnd: (newPosition) {
            setState(() {
              _selectedLocation = newPosition;
            });
            _updateMarkerAndCircle(newPosition);
          },
        ),
      };

      _circles = {
        Circle(
          circleId: const CircleId('zone_radius'),
          center: location,
          radius: radius,
          fillColor: AppColors.primary.withOpacity(0.2),
          strokeColor: AppColors.primary,
          strokeWidth: 1,
        ),
      };
    });
  }

  void _onMapTap(LatLng location) {
    setState(() {
      _selectedLocation = location;
    });

    _updateMarkerAndCircle(location);
  }

  void _toggleTag(String tag) {
    setState(() {
      if (_selectedTags.contains(tag)) {
        _selectedTags.remove(tag);
      } else {
        _selectedTags.add(tag);
      }
    });
  }

  Future<void> _createSafeZone() async {
    if (_formKey.currentState?.validate() != true) {
      return;
    }

    if (_selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a location on the map'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final radius = double.tryParse(_radiusController.text) ?? 100.0;

      final zoneId = await _repository.createSafeZone(
        name: _nameController.text,
        description: _descriptionController.text.isNotEmpty
            ? _descriptionController.text
            : null,
        latitude: _selectedLocation!.latitude,
        longitude: _selectedLocation!.longitude,
        radius: radius,
        address:
            _addressController.text.isNotEmpty ? _addressController.text : null,
        tags: _selectedTags,
      );

      if (zoneId == null) {
        throw Exception('Failed to create safe zone');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Safe zone created successfully'),
            backgroundColor: AppColors.success,
          ),
        );

        Navigator.pop(context, true);
      }
    } catch (e) {
      Logger.error('Failed to create safe zone', e);

      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create safe zone: ${e.toString()}'),
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
        title: 'Add Safe Zone',
      ),
      body: _isLoading
          ? const Center(child: LoadingIndicator())
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                // Map
                SizedBox(
                  height: 200,
                  child: GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target:
                          _currentLocation ?? const LatLng(20.5937, 78.9629),
                      zoom: 15,
                    ),
                    onMapCreated: _onMapCreated,
                    myLocationEnabled: true,
                    myLocationButtonEnabled: true,
                    mapToolbarEnabled: false,
                    zoomControlsEnabled: true,
                    markers: _markers,
                    circles: _circles,
                    onTap: _onMapTap,
                  ),
                ),

                // Form
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Zone Details',
                          style: AppTypography.heading4.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Name
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Zone Name',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter a name for the zone';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Description
                        TextFormField(
                          controller: _descriptionController,
                          decoration: const InputDecoration(
                            labelText: 'Description (Optional)',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 3,
                        ),
                        const SizedBox(height: 16),

                        // Address
                        TextFormField(
                          controller: _addressController,
                          decoration: const InputDecoration(
                            labelText: 'Address (Optional)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Radius
                        TextFormField(
                          controller: _radiusController,
                          decoration: const InputDecoration(
                            labelText: 'Radius (meters)',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter a radius';
                            }

                            final radius = double.tryParse(value);
                            if (radius == null || radius <= 0) {
                              return 'Please enter a valid radius';
                            }

                            return null;
                          },
                          onChanged: (_) {
                            if (_selectedLocation != null) {
                              _updateMarkerAndCircle(_selectedLocation!);
                            }
                          },
                        ),
                        const SizedBox(height: 24),

                        // Tags
                        Text(
                          'Tags (Optional)',
                          style: AppTypography.heading4.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _tagOptions.map((tag) {
                            final isSelected = _selectedTags.contains(tag);

                            return FilterChip(
                              label: Text(tag),
                              selected: isSelected,
                              onSelected: (_) => _toggleTag(tag),
                              selectedColor: AppColors.primary.withOpacity(0.2),
                              checkmarkColor: AppColors.primary,
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Submit Button
        Padding(
          padding: const EdgeInsets.all(16),
          child: CustomButton(
            text: 'Create Safe Zone',
            onPressed: _createSafeZone,
            isLoading: _isSubmitting,
            type: ButtonType.primary,
            isFullWidth: true,
          ),
        ),
      ],
    );
  }
}
