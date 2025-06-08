/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:guardian/core/constants/app_colors.dart';

/// A widget that displays a safe route polyline on a Google Map
class SafeRoutePolyline extends StatelessWidget {
  /// The route points to display
  final List<LatLng> routePoints;

  /// Whether to show the route
  final bool visible;

  /// The width of the polyline
  final int width;

  /// The color of the polyline
  final Color color;

  const SafeRoutePolyline({
    super.key,
    required this.routePoints,
    this.visible = true,
    this.width = 5,
    this.color = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    if (!visible || routePoints.isEmpty || routePoints.length < 2) {
      return const SizedBox.shrink();
    }

    // Convert route points to polylines
    final Set<Polyline> polylines = {};

    polylines.add(
      Polyline(
        polylineId: const PolylineId('safe_route'),
        points: routePoints,
        color: color,
        width: width,
        patterns: [
          PatternItem.dash(20),
          PatternItem.gap(10),
        ],
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
      ),
    );

    // Add markers for start and end points
    final Set<Marker> markers = {};

    // Start marker
    markers.add(
      Marker(
        markerId: const MarkerId('route_start'),
        position: routePoints.first,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: const InfoWindow(title: 'Start'),
      ),
    );

    // End marker
    markers.add(
      Marker(
        markerId: const MarkerId('route_end'),
        position: routePoints.last,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: const InfoWindow(title: 'Destination'),
      ),
    );

    return Stack(
      children: [
        // Render polylines on the map
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: routePoints.first,
            zoom: 15,
          ),
          polylines: polylines,
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
}
