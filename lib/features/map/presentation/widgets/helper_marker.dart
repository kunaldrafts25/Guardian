/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:guardian/core/constants/app_colors.dart';
import 'package:guardian/core/constants/app_typography.dart';

/// A widget that displays a helper marker on the map
class HelperMarker extends StatelessWidget {
  /// The helper data
  final Map<String, dynamic> helper;

  /// Callback when the marker is tapped
  final Function(Map<String, dynamic>)? onTap;

  const HelperMarker({
    super.key,
    required this.helper,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (onTap != null) {
          onTap!(helper);
        }
      },
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: _getHelperColor(),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Text(
            _getInitials(),
            style: AppTypography.bodySmall.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  /// Get the color based on helper type
  Color _getHelperColor() {
    final String type = helper['type'] as String;
    final bool isAvailable = helper['isAvailable'] as bool? ?? true;

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

  /// Get the initials from the helper name
  String _getInitials() {
    final String name = helper['name'] as String;
    final List<String> nameParts = name.split(' ');

    if (nameParts.length > 1) {
      return '${nameParts[0][0]}${nameParts[1][0]}';
    } else if (name.isNotEmpty) {
      return name[0];
    } else {
      return '?';
    }
  }
}

/// A widget that displays a list of helper markers on the map
class HelperMarkers extends StatelessWidget {
  /// The list of helpers
  final List<Map<String, dynamic>> helpers;

  /// Whether to show the helpers
  final bool visible;

  /// Callback when a helper marker is tapped
  final Function(Map<String, dynamic>)? onHelperTap;

  const HelperMarkers({
    super.key,
    required this.helpers,
    this.visible = true,
    this.onHelperTap,
  });

  @override
  Widget build(BuildContext context) {
    if (!visible || helpers.isEmpty) {
      return const SizedBox.shrink();
    }

    // Convert helpers to markers
    final Set<Marker> markers = {};

    for (final helper in helpers) {
      final LatLng location = helper['location'] as LatLng;
      final String id = helper['id'] as String;
      final String name = helper['name'] as String;
      final String type = helper['type'] as String;
      final bool isAvailable = helper['isAvailable'] as bool? ?? true;

      markers.add(
        Marker(
          markerId: MarkerId(id),
          position: location,
          infoWindow: InfoWindow(
            title: name,
            snippet: '${_getHelperTypeLabel(type)} ${isAvailable ? '(Available)' : '(Unavailable)'}',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(_getHelperHue(type, isAvailable)),
          onTap: () {
            if (onHelperTap != null) {
              onHelperTap!(helper);
            }
          },
        ),
      );
    }

    return Stack(
      children: [
        // Render markers on the map
        GoogleMap(
          initialCameraPosition: const CameraPosition(
            target: LatLng(0, 0),
            zoom: 15,
          ),
          markers: markers,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          myLocationButtonEnabled: false,
          compassEnabled: false,
          mapType: MapType.none,
        ),
      ],
    );
  }

  /// Get the hue for the marker based on helper type
  double _getHelperHue(String type, bool isAvailable) {
    if (!isAvailable) {
      return BitmapDescriptor.hueAzure; // Using hueAzure instead of hueGrey which doesn't exist
    }

    switch (type) {
      case 'police':
        return BitmapDescriptor.hueBlue;
      case 'medical':
        return BitmapDescriptor.hueRed;
      case 'security_guard':
        return BitmapDescriptor.hueYellow;
      case 'volunteer':
        return BitmapDescriptor.hueViolet;
      case 'community_member':
        return BitmapDescriptor.hueCyan;
      default:
        return BitmapDescriptor.hueAzure;
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
}
