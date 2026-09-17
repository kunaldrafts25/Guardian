/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
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
    final String type = (helper['type'] as String?) ?? 'volunteer';
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
    final String name = (helper['name'] as String?) ?? 'H';
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

/// A widget that displays a list of helper markers on the map using flutter_map MarkerLayer
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

    return MarkerLayer(
      markers: helpers.map((helper) {
        final location = helper['location'] as LatLng;
        return Marker(
          point: location,
          width: 44,
          height: 44,
          child: HelperMarker(
            helper: helper,
            onTap: onHelperTap,
          ),
        );
      }).toList(),
    );
  }
}
