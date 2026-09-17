/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:guardian/core/constants/app_colors.dart';
import 'package:guardian/features/map/data/heatmap_data.dart';

/// A widget that displays a heatmap overlay on flutter_map
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

    return CircleLayer(
      circles: points.map((point) {
        final Color color = _getColorForIntensity(point.intensity);
        return CircleMarker(
          point: point.location,
          radius: point.radius,
          useRadiusInMeter: true,
          color: color.withValues(alpha: 0.35),
          borderColor: color.withValues(alpha: 0.7),
          borderStrokeWidth: 1.5,
        );
      }).toList(),
    );
  }

  /// Get color for intensity value (0.0 to 1.0)
  Color _getColorForIntensity(double intensity) {
    if (intensity < 0.3) {
      return Color.lerp(
        AppColors.safeZone,
        AppColors.warning,
        intensity / 0.3,
      ) ?? AppColors.safeZone;
    } else if (intensity < 0.7) {
      return Color.lerp(
        AppColors.warning,
        AppColors.accent,
        (intensity - 0.3) / 0.4,
      ) ?? AppColors.warning;
    } else {
      return Color.lerp(
        AppColors.accent,
        AppColors.danger,
        (intensity - 0.7) / 0.3,
      ) ?? AppColors.danger;
    }
  }
}
