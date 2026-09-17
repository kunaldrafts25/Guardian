/*
 * Guardian 2.0 - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * 
 * Safe Route Provider - Route navigation with Google Directions API
 */

import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:guardian/core/utils/logger.dart';

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

  static const String _osrmBase = 'https://router.project-osrm.org';

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
        '$_osrmBase/route/v1/foot/'
        '${origin.longitude},${origin.latitude};'
        '${destination.longitude},${destination.latitude}'
        '?overview=full&geometries=geojson&steps=false',
      );

      Logger.info('🗺️ Fetching route from OSRM (free)');
      final response = await http.get(url).timeout(const Duration(seconds: 10));

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

          Logger.info('🗺️ OSRM route: $distanceText, $durationText');
          return;
        }
      }

      throw Exception('No route found (OSRM)');
    } catch (e) {
      Logger.warning('OSRM routing failed, using fallback: $e');

      // Always fallback to straight-line estimate
      final fallbackRoute = _generateFallbackRoute(origin, destination, destinationName);
      state = state.copyWith(
        isLoading: false,
        currentRoute: fallbackRoute,
        errorMessage: 'Using estimated route',
      );
    }
  }

  /// Generate a fallback straight-line route when API is unavailable
  RouteInfo _generateFallbackRoute(LatLng origin, LatLng destination, String? destinationName) {
    // Calculate distance using Haversine formula
    const earthRadius = 6371.0; // km
    final dLat = _toRadians(destination.latitude - origin.latitude);
    final dLng = _toRadians(destination.longitude - origin.longitude);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(origin.latitude)) * math.cos(_toRadians(destination.latitude)) *
        math.sin(dLng / 2) * math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    final distance = earthRadius * c;
    
    // Estimate walking time (5 km/h average)
    final walkingMinutes = (distance / 5 * 60).round();
    
    // Generate intermediate points for smoother line
    final points = <LatLng>[];
    const segments = 20;
    for (var i = 0; i <= segments; i++) {
      final t = i / segments;
      points.add(LatLng(
        origin.latitude + (destination.latitude - origin.latitude) * t,
        origin.longitude + (destination.longitude - origin.longitude) * t,
      ));
    }
    
    String distanceText;
    if (distance < 1) {
      distanceText = '${(distance * 1000).toInt()} m';
    } else {
      distanceText = '${distance.toStringAsFixed(1)} km';
    }
    
    String durationText;
    if (walkingMinutes < 60) {
      durationText = '$walkingMinutes min';
    } else {
      final hours = walkingMinutes ~/ 60;
      final mins = walkingMinutes % 60;
      durationText = '$hours h $mins min';
    }
    
    return RouteInfo(
      polylinePoints: points,
      distance: distanceText,
      duration: durationText,
      startAddress: 'Your location',
      endAddress: destinationName ?? 'Destination',
      steps: ['Walk towards ${destinationName ?? "destination"} (estimated)'],
    );
  }

  double _toRadians(double degrees) => degrees * math.pi / 180;

  /// Decode Google's encoded polyline format
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
final safeRouteProvider = StateNotifierProvider<SafeRouteNotifier, SafeRouteState>((ref) {
  return SafeRouteNotifier();
});

/// Current route polyline provider (for map display)
final routePolylinesProvider = Provider<List<Polyline>>((ref) {
  final routeState = ref.watch(safeRouteProvider);
  
  if (!routeState.hasRoute) {
    return [];
  }
  
  return [
    Polyline(
      points: routeState.currentRoute!.polylinePoints,
      color: const Color(0xFF4CAF50), // Green for safe route
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
    Marker(
      point: points.first,
      width: 40,
      height: 40,
      child: const Icon(Icons.my_location, color: Colors.green, size: 28),
    ),
    Marker(
      point: points.last,
      width: 40,
      height: 40,
      child: const Icon(Icons.location_on, color: Colors.red, size: 36),
    ),
  ];
});

