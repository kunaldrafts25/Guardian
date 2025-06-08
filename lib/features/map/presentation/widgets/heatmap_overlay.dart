/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:guardian/core/constants/app_colors.dart';
import 'package:guardian/features/map/data/heatmap_data.dart';

/// A widget that displays a heatmap overlay on a Google Map
class HeatmapOverlay extends StatelessWidget {
  /// The heatmap points to display
  final List<HeatmapPoint> points;

  /// Whether to show the heatmap
  final bool visible;

  const HeatmapOverlay({
    super.key,
    required this.points,
    this.visible = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!visible || points.isEmpty) {
      return const SizedBox.shrink();
    }

    // Convert heatmap points to circles
    final Set<Circle> circles = {};

    for (final point in points) {
      // Calculate color based on intensity
      final Color color = _getColorForIntensity(point.intensity);

      circles.add(
        Circle(
          circleId: CircleId('heatmap_${point.location.latitude}_${point.location.longitude}'),
          center: point.location,
          radius: point.radius,
          fillColor: color.withOpacity(0.5),
          strokeColor: color.withOpacity(0.8),
          strokeWidth: 1,
        ),
      );
    }

    return Stack(
      children: [
        // Render circles on the map
        GoogleMap(
          initialCameraPosition: const CameraPosition(
            target: LatLng(0, 0),
            zoom: 15,
          ),
          circles: circles,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          myLocationButtonEnabled: false,
          compassEnabled: false,
          mapType: MapType.none,
        ),
      ],
    );
  }

  /// Get color for intensity value (0.0 to 1.0)
  Color _getColorForIntensity(double intensity) {
    // Use a gradient from green (safe) to red (danger)
    if (intensity < 0.3) {
      // Green to yellow gradient for low intensity
      return Color.lerp(
        AppColors.safeZone,
        AppColors.warning,
        intensity / 0.3,
      ) ?? AppColors.safeZone;
    } else if (intensity < 0.7) {
      // Yellow to orange gradient for medium intensity
      return Color.lerp(
        AppColors.warning,
        AppColors.accent,
        (intensity - 0.3) / 0.4,
      ) ?? AppColors.warning;
    } else {
      // Orange to red gradient for high intensity
      return Color.lerp(
        AppColors.accent,
        AppColors.danger,
        (intensity - 0.7) / 0.3,
      ) ?? AppColors.danger;
    }
  }
}
