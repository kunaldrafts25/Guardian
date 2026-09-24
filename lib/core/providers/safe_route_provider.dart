/*
 * Guardian 2.0 - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * 
 * Safe Route Provider - Route navigation with OSRM (Open Source Routing Machine)
 */

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:guardian/core/config/map_routing_config.dart';
import 'package:guardian/core/utils/logger.dart';
import 'package:guardian/core/services/safety_service_bridge.dart';

/// Route information
class RouteInfo {
  final List<LatLng> polylinePoints;
  final String distance;
  final String duration;
  final String startAddress;
  final String endAddress;
  final List<String> steps;

  const RouteInfo({
    required this.polylinePoints,
    required this.distance,
    required this.duration,
    required this.startAddress,
    required this.endAddress,
    this.steps = const [],
  });
}

/// Safe route state
class SafeRouteState {
  final bool isLoading;
  final RouteInfo? currentRoute;
  final String? errorMessage;
  final LatLng? origin;
  final LatLng? destination;
  final String? destinationName;

  const SafeRouteState({
    this.isLoading = false,
    this.currentRoute,
    this.errorMessage,
    this.origin,
    this.destination,
    this.destinationName,
  });

  SafeRouteState copyWith({
    bool? isLoading,
    RouteInfo? currentRoute,
    String? errorMessage,
    LatLng? origin,
    LatLng? destination,
    String? destinationName,
  }) {
    return SafeRouteState(
      isLoading: isLoading ?? this.isLoading,
      currentRoute: currentRoute ?? this.currentRoute,
      errorMessage: errorMessage,
      origin: origin ?? this.origin,
      destination: destination ?? this.destination,
      destinationName: destinationName ?? this.destinationName,
    );
  }

  bool get hasRoute => currentRoute != null;
}

/// Safe route notifier — uses FREE OSRM routing (replaces Google Directions API)
class SafeRouteNotifier extends StateNotifier<SafeRouteState> {
  SafeRouteNotifier() : super(const SafeRouteState());

  /// Fetch walking route from OSRM (free, no API key needed)
  Future<void> fetchRoute({
    required LatLng origin,
    required LatLng destination,
    String? destinationName,
  }) async {
    state = state.copyWith(
      isLoading: true,
      origin: origin,
      destination: destination,
      destinationName: destinationName,
      errorMessage: null,
    );

    try {
      // OSRM uses lon,lat order
      final url = Uri.parse(
        '${MapRoutingConfig.osrmBaseUrl}/route/v1/foot/'
        '${origin.longitude},${origin.latitude};'
        '${destination.longitude},${destination.latitude}'
        '?overview=full&geometries=geojson&steps=false',
      );

      Logger.info('🗺️ Fetching route from OSRM (${MapRoutingConfig.osrmBaseUrl})');
      final response = await MapRoutingConfig.executeWithRetry(
        () => http.get(url).timeout(MapRoutingConfig.defaultRoutingTimeout),
        serviceName: 'OSRM',
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;

        if (data['code'] == 'Ok' && (data['routes'] as List).isNotEmpty) {
          final route = data['routes'][0] as Map<String, dynamic>;
          final geometry = route['geometry'] as Map<String, dynamic>;
          final coords = geometry['coordinates'] as List;

          final polylinePoints = coords.map((c) {
            final coord = c as List;
            return LatLng(coord[1] as double, coord[0] as double);
          }).toList();

          final distanceM = (route['distance'] as num).toDouble();
          final durationS = (route['duration'] as num).toInt();
          final distanceText = distanceM < 1000
              ? '${distanceM.round()} m'
              : '${(distanceM / 1000).toStringAsFixed(1)} km';
          final durationText = '${(durationS / 60).ceil()} min walk';

          final routeInfo = RouteInfo(
            polylinePoints: polylinePoints,
            distance: distanceText,
            duration: durationText,
            startAddress: 'Current Location',
            endAddress: destinationName ?? 'Destination',
            steps: [],
          );

          state = state.copyWith(
            isLoading: false,
            currentRoute: routeInfo,
          );

          // Sync polyline points to native foreground service for background route deviation detection
          SafetyServiceBridge().setActiveRoute(
            polylinePoints
                .map((p) => {'latitude': p.latitude, 'longitude': p.longitude})
                .toList(),
          );

          Logger.info('🗺️ OSRM route: $distanceText, $durationText');
          return;
        }
      }

      throw Exception('No route found (OSRM returned ${response.statusCode})');
    } catch (e) {
      Logger.warning('OSRM routing failed: $e. Activating resilient geodesic direct route fallback.');
      
      // Resilient fallback: Straight-line route so safety navigation & deviation tracking do not collapse
      final polylinePoints = [origin, destination];
      final distanceM = const Distance().as(LengthUnit.Meter, origin, destination);
      final distanceText = distanceM < 1000
          ? '${distanceM.round()} m (direct)'
          : '${(distanceM / 1000).toStringAsFixed(1)} km (direct)';
      final durationM = (distanceM / 80).ceil(); // ~4.8 km/h average walk

      final fallbackRoute = RouteInfo(
        polylinePoints: polylinePoints,
        distance: distanceText,
        duration: '$durationM min walk (direct)',
        startAddress: 'Current Location',
        endAddress: destinationName ?? 'Destination',
        steps: [],
      );

      state = state.copyWith(
        isLoading: false,
        currentRoute: fallbackRoute,
        errorMessage: 'Detailed turn-by-turn unavailable; direct emergency line active.',
      );

      // P0-07: Do NOT send geodesic fallbacks to the native deviation engine.
      // A straight line is not routable and will trigger false positive deviations.
      SafetyServiceBridge().clearActiveRoute();
    }
  }

  // ignore: unused_element
  /// Decode Google's encoded polyline format
  // ignore: unused_element
  List<LatLng> _decodePolyline(String encoded) {
    final List<LatLng> points = [];
    int index = 0;
    int lat = 0;
    int lng = 0;

    while (index < encoded.length) {
      // Decode latitude
      int shift = 0;
      int result = 0;
      int byte;
      do {
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1f) << shift;
        shift += 5;
      } while (byte >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      // Decode longitude
      shift = 0;
      result = 0;
      do {
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1f) << shift;
        shift += 5;
      } while (byte >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1e5, lng / 1e5));
    }

    return points;
  }

  /// Clear current route
  void clearRoute() {
    state = const SafeRouteState();
    SafetyServiceBridge().clearActiveRoute();
    Logger.info('🗺️ Route cleared');
  }

  /// Set destination without fetching route yet
  void setDestination(LatLng destination, String name) {
    state = state.copyWith(
      destination: destination,
      destinationName: name,
    );
  }
}

/// Safe route provider
final safeRouteProvider =
    StateNotifierProvider<SafeRouteNotifier, SafeRouteState>((ref) {
  return SafeRouteNotifier();
});

/// Current route polyline provider (for map display)
final routePolylinesProvider = Provider<List<Polyline>>((ref) {
  final routeState = ref.watch(safeRouteProvider);

  if (!routeState.hasRoute) {
    return [];
  }

  return [
    // Outer casing / shadow line
    Polyline(
      points: routeState.currentRoute!.polylinePoints,
      color: const Color(0xFF173A2C).withValues(alpha: 0.35),
      strokeWidth: 8,
    ),
    // Core safe walking line in signature deep forest green
    Polyline(
      points: routeState.currentRoute!.polylinePoints,
      color: const Color(0xFF244D3C),
      strokeWidth: 5,
    ),
  ];
});

/// Route markers provider (start and end)
final routeMarkersProvider = Provider<List<Marker>>((ref) {
  final routeState = ref.watch(safeRouteProvider);

  if (!routeState.hasRoute) {
    return [];
  }

  final points = routeState.currentRoute!.polylinePoints;
  if (points.isEmpty) return [];

  return [
    // Origin marker
    Marker(
      point: points.first,
      width: 32,
      height: 32,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF244D3C),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Center(
          child: Icon(Icons.circle, color: Colors.white, size: 10),
        ),
      ),
    ),
    // Destination marker
    Marker(
      point: points.last,
      width: 40,
      height: 40,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF39705A),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF39705A).withValues(alpha: 0.4),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: const Center(
          child: Icon(Icons.flag_rounded, color: Colors.white, size: 20),
        ),
      ),
    ),
  ];
});
