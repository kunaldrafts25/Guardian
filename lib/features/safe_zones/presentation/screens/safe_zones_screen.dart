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
import 'package:guardian/core/widgets/loading_indicator.dart';
import 'package:guardian/features/safe_zones/data/models/safe_zone_model.dart';
import 'package:guardian/features/safe_zones/data/safe_zone_repository.dart';
import 'package:guardian/features/safe_zones/presentation/screens/add_safe_zone_screen.dart';
import 'package:guardian/features/safe_zones/presentation/screens/safe_zone_details_screen.dart';
import 'package:guardian/features/safe_zones/presentation/widgets/safety_level_indicator.dart';

class SafeZonesScreen extends StatefulWidget {
  const SafeZonesScreen({super.key});

  @override
  State<SafeZonesScreen> createState() => _SafeZonesScreenState();
}

class _SafeZonesScreenState extends State<SafeZonesScreen> {
  final SafeZoneRepository _repository = sl<SafeZoneRepository>();
  final Completer<GoogleMapController> _mapController = Completer();

  List<SafeZone> _safeZones = [];
  bool _isLoading = true;
  bool _isMapReady = false;
  LatLng? _currentLocation;
  Map<String, dynamic>? _currentSafetyLevel;

  Set<Marker> _markers = {};
  Set<Circle> _circles = {};

  // Map style
  MapType _currentMapType = MapType.normal;
  bool _showHeatmap = true;

  @override
  void initState() {
    super.initState();
    _loadSafeZones();
    _getCurrentLocation();
  }

  Future<void> _loadSafeZones() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final zones = await _repository.getSafeZones();

      setState(() {
        _safeZones = zones;
        _isLoading = false;
      });

      _updateMapMarkers();
    } catch (e) {
      Logger.error('Failed to load safe zones', e);

      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      final position = await LocationUtils.getCurrentPosition();

      if (position != null) {
        setState(() {
          _currentLocation = LatLng(position.latitude, position.longitude);
        });

        if (_isMapReady) {
          _moveToCurrentLocation();
        }

        // Get safety level for current location
        await _getSafetyLevelForCurrentLocation();
      }
    } catch (e) {
      Logger.error('Failed to get current location', e);
    }
  }

  Future<void> _getSafetyLevelForCurrentLocation() async {
    if (_currentLocation == null) return;

    try {
      final safetyLevel = await _repository.getSafetyLevelForLocation(
        latitude: _currentLocation!.latitude,
        longitude: _currentLocation!.longitude,
      );

      setState(() {
        _currentSafetyLevel = safetyLevel;
      });
    } catch (e) {
      Logger.error('Failed to get safety level', e);
    }
  }

  void _updateMapMarkers() {
    if (_safeZones.isEmpty) return;

    final markers = <Marker>{};
    final circles = <Circle>{};

    for (final zone in _safeZones) {
      final zoneLatitude = zone.location['latitude'] ?? 0.0;
      final zoneLongitude = zone.location['longitude'] ?? 0.0;
      final position = LatLng(zoneLatitude, zoneLongitude);

      // Create marker
      markers.add(
        Marker(
          markerId: MarkerId(zone.id),
          position: position,
          infoWindow: InfoWindow(
            title: zone.name,
            snippet: zone.description ?? 'Tap for details',
            onTap: () => _navigateToZoneDetails(zone),
          ),
          onTap: () {
            _showZonePreview(zone);
          },
        ),
      );

      // Create circle
      circles.add(
        Circle(
          circleId: CircleId(zone.id),
          center: position,
          radius: zone.radius,
          fillColor: _getSafetyColor(zone.averageRating).withOpacity(0.3),
          strokeColor: _getSafetyColor(zone.averageRating),
          strokeWidth: 1,
        ),
      );
    }

    setState(() {
      _markers = markers;
      _circles = circles;
    });
  }

  Future<void> _moveToCurrentLocation() async {
    if (_currentLocation == null || !_isMapReady) return;

    final controller = await _mapController.future;
    controller.animateCamera(
      CameraUpdate.newLatLngZoom(_currentLocation!, 15),
    );
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController.complete(controller);
    setState(() {
      _isMapReady = true;
    });

    if (_currentLocation != null) {
      _moveToCurrentLocation();
    }
  }

  void _toggleMapType() {
    setState(() {
      _currentMapType = _currentMapType == MapType.normal
          ? MapType.satellite
          : MapType.normal;
    });
  }

  void _toggleHeatmap() {
    setState(() {
      _showHeatmap = !_showHeatmap;
    });
  }

  Future<void> _navigateToAddSafeZone() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => const AddSafeZoneScreen(),
      ),
    );

    if (result == true) {
      await _loadSafeZones();
    }
  }

  void _showZonePreview(SafeZone zone) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeZonePreview(
        zone: zone,
        onViewDetails: () {
          Navigator.pop(context);
          _navigateToZoneDetails(zone);
        },
      ),
    );
  }

  Future<void> _navigateToZoneDetails(SafeZone zone) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => SafeZoneDetailsScreen(zone: zone),
      ),
    );

    if (result == true) {
      await _loadSafeZones();
    }
  }

  Color _getSafetyColor(double rating) {
    if (rating >= 4.0) {
      return Colors.green;
    } else if (rating >= 3.0) {
      return Colors.lightGreen;
    } else if (rating >= 2.0) {
      return Colors.yellow;
    } else if (rating >= 1.0) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Safe Zones',
      ),
      body: _isLoading
          ? const Center(child: LoadingIndicator())
          : _buildContent(),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            onPressed: _toggleMapType,
            heroTag: 'mapType',
            mini: true,
            backgroundColor: Colors.white,
            foregroundColor: AppColors.primary,
            child: Icon(
              _currentMapType == MapType.normal
                  ? Icons.satellite_alt
                  : Icons.map,
            ),
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            onPressed: _toggleHeatmap,
            heroTag: 'heatmap',
            mini: true,
            backgroundColor: Colors.white,
            foregroundColor: AppColors.primary,
            child: Icon(
              _showHeatmap ? Icons.layers_clear : Icons.layers,
            ),
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            onPressed: _navigateToAddSafeZone,
            heroTag: 'addZone',
            backgroundColor: AppColors.primary,
            child: const Icon(Icons.add_location_alt),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: _currentLocation ??
                const LatLng(20.5937, 78.9629), // Default to India
            zoom: _currentLocation != null ? 15 : 5,
          ),
          onMapCreated: _onMapCreated,
          myLocationEnabled: true,
          myLocationButtonEnabled: true,
          mapToolbarEnabled: false,
          zoomControlsEnabled: false,
          mapType: _currentMapType,
          markers: _markers,
          circles: _showHeatmap ? _circles : {},
          onTap: (_) {
            // Close any open bottom sheet
            Navigator.of(context).popUntil((route) => route.isFirst);
          },
        ),
        if (_currentSafetyLevel != null)
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: SafetyLevelIndicator(
              safetyLevel: _currentSafetyLevel!['level'],
              message: _currentSafetyLevel!['message'],
            ),
          ),
      ],
    );
  }
}

class SafeZonePreview extends StatelessWidget {
  final SafeZone zone;
  final VoidCallback onViewDetails;

  const SafeZonePreview({
    super.key,
    required this.zone,
    required this.onViewDetails,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor:
                    _getSafetyColor(zone.averageRating).withOpacity(0.2),
                child: Icon(
                  Icons.location_on,
                  color: _getSafetyColor(zone.averageRating),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      zone.name,
                      style: AppTypography.heading4.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (zone.address != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        zone.address!,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              _buildSafetyBadge(zone.averageRating),
            ],
          ),
          if (zone.description != null) ...[
            const SizedBox(height: 16),
            Text(
              zone.description!,
              style: AppTypography.bodyMedium,
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Time Context',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getTimeContextLabel(zone.predominantTimeContext),
                      style: AppTypography.bodyMedium.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ratings',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${zone.ratings.length} ratings',
                      style: AppTypography.bodyMedium.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onViewDetails,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('View Details'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSafetyBadge(double rating) {
    String label;
    Color color;

    if (rating >= 4.0) {
      label = 'Very Safe';
      color = Colors.green;
    } else if (rating >= 3.0) {
      label = 'Safe';
      color = Colors.lightGreen;
    } else if (rating >= 2.0) {
      label = 'Moderate';
      color = Colors.yellow;
    } else if (rating >= 1.0) {
      label = 'Unsafe';
      color = Colors.orange;
    } else {
      label = 'Very Unsafe';
      color = Colors.red;
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

  String _getTimeContextLabel(TimeContext context) {
    switch (context) {
      case TimeContext.allTimes:
        return 'Safe at all times';
      case TimeContext.daytimeOnly:
        return 'Safe during day';
      case TimeContext.nighttimeOnly:
        return 'Safe during night';
      case TimeContext.neverSafe:
        return 'Never safe';
    }
  }

  Color _getSafetyColor(double rating) {
    if (rating >= 4.0) {
      return Colors.green;
    } else if (rating >= 3.0) {
      return Colors.lightGreen;
    } else if (rating >= 2.0) {
      return Colors.yellow;
    } else if (rating >= 1.0) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }
}
