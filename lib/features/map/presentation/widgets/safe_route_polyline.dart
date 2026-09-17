/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:guardian/core/constants/app_colors.dart';

/// A widget that displays a safe route polyline on flutter_map
class SafeRoutePolyline extends StatelessWidget {
  /// The route points to display
  final List<LatLng> routePoints;

  /// Whether to show the route
  final bool visible;

  /// The width of the polyline
  final double width;

  /// The color of the polyline
  final Color color;

  const SafeRoutePolyline({
    super.key,
    required this.routePoints,
    this.visible = true,
    this.width = 5.0,
    this.color = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    if (!visible || routePoints.isEmpty || routePoints.length < 2) {
      return const SizedBox.shrink();
    }

    return PolylineLayer(
      polylines: [
        Polyline(
          points: routePoints,
          color: color,
          strokeWidth: width,
        ),
      ],
    );
  }
}
