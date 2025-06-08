/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'package:flutter/material.dart';
import 'package:guardian/core/constants/app_colors.dart';
import 'package:guardian/core/constants/app_strings.dart';
import 'package:guardian/core/constants/app_typography.dart';
import 'package:guardian/core/utils/location_utils.dart';
import 'package:guardian/core/widgets/emergency_button.dart';
import 'package:guardian/features/community/presentation/screens/report_incident_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  // Loading state
  bool _isLoading = false;

  // Map layer toggles
  bool _showSafeZones = true;
  bool _showDangerZones = true;
  bool _showNearbyUsers = true;
  final bool _showHeatmap = false;
  final bool _showSafeRoute = false;
  // Removed unused field: bool _showHelpers = false;

  @override
  void initState() {
    super.initState();
    _loadMapData();
  }

  /// Load map data
  Future<void> _loadMapData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get current location
      final position = await LocationUtils.getCurrentPosition();
      if (position != null && mounted) {
        // In a real implementation, we would update the map here
      }
    } catch (e) {
      // Handle error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to load map data'),
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

  /// Toggle safe zones
  void _toggleSafeZones(bool value) {
    setState(() {
      _showSafeZones = value;
    });
  }

  /// Toggle danger zones
  void _toggleDangerZones(bool value) {
    setState(() {
      _showDangerZones = value;
    });
  }

  /// Toggle nearby users
  void _toggleNearbyUsers(bool value) {
    setState(() {
      _showNearbyUsers = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.map),
        actions: [
          IconButton(
            onPressed: _showMapLayersDialog,
            icon: const Icon(Icons.layers),
            tooltip: 'Map Layers',
          ),
          IconButton(
            onPressed: () {
              // Get current location
              LocationUtils.getCurrentPosition();
            },
            icon: const Icon(Icons.my_location),
            tooltip: 'My Location',
          ),
        ],
      ),
      body: Stack(
        children: [
          // Mock Map (placeholder)
          Container(
            color: Colors.grey[200],
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.map,
                    size: 100,
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Map View',
                    style: AppTypography.heading3,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Google Maps integration removed',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_showSafeZones)
                    Chip(
                      label: const Text('Safe Zones Enabled'),
                      backgroundColor: AppColors.safeZone.withOpacity(0.3),
                    ),
                  if (_showDangerZones)
                    Chip(
                      label: const Text('Danger Zones Enabled'),
                      backgroundColor: AppColors.dangerZone.withOpacity(0.3),
                    ),
                  if (_showHeatmap)
                    Chip(
                      label: const Text('Heatmap Enabled'),
                      backgroundColor: AppColors.warning.withOpacity(0.3),
                    ),
                  if (_showSafeRoute)
                    Chip(
                      label: const Text('Safe Route Enabled'),
                      backgroundColor: AppColors.primary.withOpacity(0.3),
                    ),
                ],
              ),
            ),
          ),

          // Loading indicator
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(),
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
                    LocationUtils.getCurrentPosition();
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
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          );
        },
      ),
    );
  }
}
