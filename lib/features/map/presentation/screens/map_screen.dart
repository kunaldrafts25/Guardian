/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:guardian/core/constants/app_colors.dart';
import 'package:guardian/core/constants/app_strings.dart';
import 'package:guardian/core/constants/app_typography.dart';
import 'package:guardian/core/services/maps_service.dart';
import 'package:guardian/core/utils/location_utils.dart';
import 'package:guardian/core/utils/logger.dart';
import 'package:guardian/core/widgets/emergency_button.dart';
import 'package:guardian/features/community/presentation/screens/report_incident_screen.dart';
import 'package:guardian/features/map/data/heatmap_data.dart';
import 'package:guardian/features/map/presentation/widgets/heatmap_overlay.dart';
import 'package:guardian/features/map/presentation/widgets/helper_marker.dart';
import 'package:guardian/features/map/presentation/widgets/safe_route_polyline.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final Completer<GoogleMapController> _controller = Completer();
  CameraPosition _initialCameraPosition = MapsService.defaultCameraPosition;
  final Set<Marker> _markers = {};
  final Set<Circle> _circles = {};
  bool _isLoading = true;
  bool _showSafeZones = true;
  bool _showDangerZones = true;
  bool _showNearbyUsers = true;
  bool _showHeatmap = false;
  bool _showSafeRoute = false;
  bool _showHelpers = false;

  // Heatmap data
  List<HeatmapPoint> _heatmapPoints = [];

  // Safe route data
  List<LatLng> _safeRoutePoints = [];
  LatLng? _destinationPoint;

  // Helpers data
  List<Map<String, dynamic>> _helpers = [];

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      final position = await LocationUtils.getCurrentPosition();
      if (position != null) {
        _updateCameraPosition(position);
        _addUserMarker(position);
        _addMockData(position);

        // Initialize heatmap data
        final latLng = LatLng(position.latitude, position.longitude);
        _heatmapPoints = HeatmapData.generateMockCrimeData(latLng, count: 15);

        // Initialize helpers data
        _helpers = HeatmapData.generateMockHelpers(latLng, count: 8);

        // Initialize safe route data (from current location to a random point)
        _destinationPoint = LatLng(
          position.latitude + 0.01,
          position.longitude + 0.01,
        );
        if (_destinationPoint != null) {
          _safeRoutePoints = HeatmapData.generateMockSafeRoute(
            latLng,
            _destinationPoint!,
          );
        }
      }
    } catch (e) {
      Logger.error('Error getting current location', e);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _updateCameraPosition(Position position) {
    _initialCameraPosition = CameraPosition(
      target: LatLng(position.latitude, position.longitude),
      zoom: 15,
    );
    _animateToPosition(position);
  }

  Future<void> _animateToPosition(Position position) async {
    final GoogleMapController controller = await _controller.future;
    controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(position.latitude, position.longitude),
          zoom: 15,
        ),
      ),
    );
  }

  void _addUserMarker(Position position) {
    setState(() {
      _markers.add(
        Marker(
          markerId: const MarkerId('user'),
          position: LatLng(position.latitude, position.longitude),
          infoWindow: const InfoWindow(title: 'Your Location'),
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        ),
      );
    });
  }

  void _addMockData(Position position) {
    // Add mock nearby users
    if (_showNearbyUsers) {
      _addMockNearbyUsers(position);
    }

    // Add mock safe zones
    if (_showSafeZones) {
      _addMockSafeZones(position);
    }

    // Add mock danger zones
    if (_showDangerZones) {
      _addMockDangerZones(position);
    }
  }

  void _addMockNearbyUsers(Position position) {
    // Add 5 mock nearby users
    for (int i = 0; i < 5; i++) {
      final double lat =
          position.latitude + (0.002 * (i % 3)) * (i % 2 == 0 ? 1 : -1);
      final double lng =
          position.longitude + (0.002 * (i % 2)) * (i % 2 == 0 ? -1 : 1);

      setState(() {
        _markers.add(
          Marker(
            markerId: MarkerId('user_$i'),
            position: LatLng(lat, lng),
            infoWindow: InfoWindow(title: 'User ${i + 1}'),
            icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueGreen),
          ),
        );
      });
    }
  }

  void _addMockSafeZones(Position position) {
    // Add 3 mock safe zones
    for (int i = 0; i < 3; i++) {
      final double lat =
          position.latitude + (0.005 * (i + 1)) * (i % 2 == 0 ? 1 : -1);
      final double lng =
          position.longitude + (0.005 * (i + 1)) * (i % 2 == 0 ? -1 : 1);

      setState(() {
        _circles.add(
          Circle(
            circleId: CircleId('safe_zone_$i'),
            center: LatLng(lat, lng),
            radius: 300, // 300 meters
            fillColor: AppColors.safeZone.withOpacity(0.3),
            strokeColor: AppColors.safeZone,
            strokeWidth: 1,
          ),
        );

        _markers.add(
          Marker(
            markerId: MarkerId('safe_zone_marker_$i'),
            position: LatLng(lat, lng),
            infoWindow: InfoWindow(title: 'Safe Zone ${i + 1}'),
            icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueGreen),
          ),
        );
      });
    }
  }

  void _addMockDangerZones(Position position) {
    // Add 2 mock danger zones
    for (int i = 0; i < 2; i++) {
      final double lat =
          position.latitude + (0.008 * (i + 1)) * (i % 2 == 0 ? -1 : 1);
      final double lng =
          position.longitude + (0.008 * (i + 1)) * (i % 2 == 0 ? 1 : -1);

      setState(() {
        _circles.add(
          Circle(
            circleId: CircleId('danger_zone_$i'),
            center: LatLng(lat, lng),
            radius: 200, // 200 meters
            fillColor: AppColors.dangerZone.withOpacity(0.3),
            strokeColor: AppColors.dangerZone,
            strokeWidth: 1,
          ),
        );

        _markers.add(
          Marker(
            markerId: MarkerId('danger_zone_marker_$i'),
            position: LatLng(lat, lng),
            infoWindow: InfoWindow(title: 'Danger Zone ${i + 1}'),
            icon:
                BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          ),
        );
      });
    }
  }

  void _toggleSafeZones(bool value) {
    setState(() {
      _showSafeZones = value;
      _markers.removeWhere(
          (marker) => marker.markerId.value.contains('safe_zone_marker'));
      _circles
          .removeWhere((circle) => circle.circleId.value.contains('safe_zone'));

      if (value) {
        LocationUtils.getCurrentPosition().then((position) {
          if (position != null) {
            _addMockSafeZones(position);
          }
        });
      }
    });
  }

  void _toggleDangerZones(bool value) {
    setState(() {
      _showDangerZones = value;
      _markers.removeWhere(
          (marker) => marker.markerId.value.contains('danger_zone_marker'));
      _circles.removeWhere(
          (circle) => circle.circleId.value.contains('danger_zone'));

      if (value) {
        LocationUtils.getCurrentPosition().then((position) {
          if (position != null) {
            _addMockDangerZones(position);
          }
        });
      }
    });
  }

  void _toggleNearbyUsers(bool value) {
    setState(() {
      _showNearbyUsers = value;
      _markers.removeWhere((marker) => marker.markerId.value.contains('user_'));

      if (value) {
        LocationUtils.getCurrentPosition().then((position) {
          if (position != null) {
            _addMockNearbyUsers(position);
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.map),
        actions: [
          IconButton(
            icon: const Icon(Icons.layers),
            onPressed: _showMapLayersDialog,
            tooltip: 'Map Layers',
          ),
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: () {
              // Implement current location functionality
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Going to current location'),
                  backgroundColor: AppColors.primary,
                ),
              );
            },
            tooltip: 'My Location',
          ),
        ],
      ),
      body: Stack(
        children: [
          // Google Map
          GoogleMap(
            initialCameraPosition: _initialCameraPosition,
            markers: _markers,
            circles: _circles,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            compassEnabled: true,
            onMapCreated: (GoogleMapController controller) {
              _controller.complete(controller);
            },
            onLongPress: null,
          ),

          // Heatmap overlay
          if (_showHeatmap && _heatmapPoints.isNotEmpty)
            HeatmapOverlay(
              points: _heatmapPoints,
              visible: _showHeatmap,
            ),

          // Safe route overlay
          if (_showSafeRoute && _safeRoutePoints.isNotEmpty)
            SafeRoutePolyline(
              routePoints: _safeRoutePoints,
              visible: _showSafeRoute,
              color: AppColors.primary,
              width: 5,
            ),

          // Helper markers
          if (_showHelpers && _helpers.isNotEmpty)
            HelperMarkers(
              helpers: _helpers,
              visible: _showHelpers,
              onHelperTap: _showHelperDetails,
            ),

          // Loading indicator
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),

          // Map legend (when advanced features are enabled)
          if (_showHeatmap || _showSafeRoute || _showHelpers)
            Positioned(
              top: 16,
              left: 16,
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_showHeatmap) ...[
                        _buildLegendItem('High Risk', AppColors.danger),
                        _buildLegendItem('Medium Risk', AppColors.warning),
                        _buildLegendItem('Low Risk', AppColors.safeZone),
                      ],
                      if (_showSafeRoute) ...[
                        _buildLegendItem('Safe Route', AppColors.primary),
                      ],
                      if (_showHelpers) ...[
                        _buildLegendItem('Safety Volunteer', AppColors.primary),
                        _buildLegendItem('Police', AppColors.secondary),
                        _buildLegendItem('Medical', AppColors.danger),
                      ],
                    ],
                  ),
                ),
              ),
            ),

          // Map controls
          Positioned(
            right: 16,
            bottom: 100,
            child: Column(
              children: [
                FloatingActionButton(
                  heroTag: 'btn_my_location',
                  mini: true,
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.primary,
                  onPressed: () {
                    LocationUtils.getCurrentPosition().then((position) {
                      if (position != null) {
                        _animateToPosition(position);
                      }
                    });
                  },
                  child: const Icon(Icons.my_location),
                ),
                const SizedBox(height: 8),
                FloatingActionButton(
                  heroTag: 'btn_report',
                  mini: true,
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.warning,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ReportIncidentScreen(),
                      ),
                    );
                  },
                  child: const Icon(Icons.report_problem),
                ),
              ],
            ),
          ),

          // Emergency button
          const Positioned(
            right: 16,
            bottom: 16,
            child: EmergencyButton(
              size: 60,
              showLabel: false,
            ),
          ),
        ],
      ),
    );
  }

  // Removed unused method

  /// Show helper details
  void _showHelperDetails(Map<String, dynamic> helper) {
    final String name = helper['name'] as String;
    final String type = helper['type'] as String;
    final double rating = helper['rating'] as double;
    final int distance = helper['distance'] as int;
    final bool isAvailable = helper['isAvailable'] as bool? ?? true;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: _getHelperColor(type, isAvailable),
                  child: Text(
                    name.substring(0, 1),
                    style: AppTypography.bodyMedium.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: AppTypography.heading4,
                      ),
                      Text(
                        _getHelperTypeLabel(type),
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isAvailable)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.safeZone.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      'Available',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.safeZone,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.textSecondary.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      'Unavailable',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildHelperInfoItem(
                  icon: Icons.star,
                  label: 'Rating',
                  value: rating.toStringAsFixed(1),
                ),
                _buildHelperInfoItem(
                  icon: Icons.location_on,
                  label: 'Distance',
                  value: '$distance m',
                ),
                _buildHelperInfoItem(
                  icon: Icons.access_time,
                  label: 'Response Time',
                  value: '~${(distance / 80).ceil()} min',
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (isAvailable) ...[
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Request sent to helper'),
                      backgroundColor: AppColors.primary,
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  minimumSize: const Size(double.infinity, 48),
                ),
                child: const Text('Request Assistance'),
              ),
            ] else ...[
              ElevatedButton(
                onPressed: null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.textSecondary,
                  disabledBackgroundColor:
                      AppColors.textSecondary.withOpacity(0.5),
                  minimumSize: const Size(double.infinity, 48),
                ),
                child: const Text('Helper Unavailable'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Build a helper info item with icon, label, and value
  Widget _buildHelperInfoItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(
          icon,
          color: AppColors.primary,
          size: 24,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: AppTypography.caption.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: AppTypography.bodyMedium.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  /// Get the color based on helper type
  Color _getHelperColor(String type, bool isAvailable) {
    if (!isAvailable) {
      return AppColors.textSecondary;
    }

    switch (type) {
      case 'police':
        return AppColors.secondary;
      case 'medical':
        return AppColors.danger;
      case 'security_guard':
        return AppColors.warning;
      case 'volunteer':
        return AppColors.primary;
      case 'community_member':
        return AppColors.accent;
      default:
        return AppColors.primary;
    }
  }

  /// Get a human-readable label for the helper type
  String _getHelperTypeLabel(String type) {
    switch (type) {
      case 'police':
        return 'Police Officer';
      case 'medical':
        return 'Medical Professional';
      case 'security_guard':
        return 'Security Guard';
      case 'volunteer':
        return 'Safety Volunteer';
      case 'community_member':
        return 'Community Member';
      default:
        return 'Helper';
    }
  }

  /// Build a legend item with a color box and label
  Widget _buildLegendItem(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: AppTypography.caption,
          ),
        ],
      ),
    );
  }

  void _showMapLayersDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(
              'Map Layers',
              style: AppTypography.heading3,
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Basic layers
                SwitchListTile(
                  title: const Text('Safe Zones'),
                  value: _showSafeZones,
                  activeColor: AppColors.safeZone,
                  onChanged: (value) {
                    setDialogState(() {
                      _showSafeZones = value;
                    });
                    _toggleSafeZones(value);
                  },
                ),
                SwitchListTile(
                  title: const Text('Danger Zones'),
                  value: _showDangerZones,
                  activeColor: AppColors.dangerZone,
                  onChanged: (value) {
                    setDialogState(() {
                      _showDangerZones = value;
                    });
                    _toggleDangerZones(value);
                  },
                ),
                SwitchListTile(
                  title: const Text('Nearby Users'),
                  value: _showNearbyUsers,
                  activeColor: AppColors.primary,
                  onChanged: (value) {
                    setDialogState(() {
                      _showNearbyUsers = value;
                    });
                    _toggleNearbyUsers(value);
                  },
                ),

                const Divider(),

                // Advanced layers
                Text(
                  'Advanced Features',
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),

                SwitchListTile(
                  title: const Text('Crime Heatmap'),
                  subtitle: const Text('View high-risk areas'),
                  value: _showHeatmap,
                  activeColor: AppColors.accent,
                  onChanged: (value) {
                    setDialogState(() {
                      _showHeatmap = value;
                    });
                    setState(() {
                      _showHeatmap = value;
                    });
                  },
                ),
                SwitchListTile(
                  title: const Text('Safe Route'),
                  subtitle: const Text('Show recommended safe path'),
                  value: _showSafeRoute,
                  activeColor: AppColors.primary,
                  onChanged: (value) {
                    setDialogState(() {
                      _showSafeRoute = value;
                    });
                    setState(() {
                      _showSafeRoute = value;
                    });
                  },
                ),
                SwitchListTile(
                  title: const Text('Safety Helpers'),
                  subtitle: const Text('Show nearby volunteers and officials'),
                  value: _showHelpers,
                  activeColor: AppColors.secondary,
                  onChanged: (value) {
                    setDialogState(() {
                      _showHelpers = value;
                    });
                    setState(() {
                      _showHelpers = value;
                    });
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text(
                  'Close',
                  style: AppTypography.buttonMedium,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
