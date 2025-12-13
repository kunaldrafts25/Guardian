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
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
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

/// Safe route notifier
class SafeRouteNotifier extends StateNotifier<SafeRouteState> {
  SafeRouteNotifier() : super(const SafeRouteState());

  /// Get API key from environment
  String get _apiKey {
    // Try to get from dotenv first, then fallback
    try {
      return dotenv.env['GOOGLE_MAPS_API_KEY_WEB'] ?? '';
    } catch (e) {
      return '';
    }
  }

  /// Fetch route from Google Directions API
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
      final apiKey = _apiKey;
      if (apiKey.isEmpty) {
        throw Exception('Google Maps API key not configured');
      }

      // On web, CORS blocks direct API calls - use fallback route
      if (kIsWeb) {
        Logger.info('🗺️ Web platform detected - using estimated route');
        final fallbackRoute = _generateFallbackRoute(origin, destination, destinationName);
        state = state.copyWith(
          isLoading: false,
          currentRoute: fallbackRoute,
        );
        Logger.info('🗺️ Estimated route: ${fallbackRoute.distance}, ${fallbackRoute.duration}');
        return;
      }

      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json'
        '?origin=${origin.latitude},${origin.longitude}'
        '&destination=${destination.latitude},${destination.longitude}'
        '&mode=walking'  // Prefer walking for safety
        '&alternatives=true'  // Get alternative routes
        '&key=$apiKey'
      );

      Logger.info('🗺️ Fetching route from Directions API');
      
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['status'] == 'OK' && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final leg = route['legs'][0];
          
          // Decode polyline
          final polylinePoints = _decodePolyline(
            route['overview_polyline']['points'],
          );
          
          // Extract steps
          final steps = <String>[];
          for (final step in leg['steps']) {
            // Remove HTML tags from instructions
            final instruction = step['html_instructions']
                .replaceAll(RegExp(r'<[^>]*>'), '');
            steps.add(instruction);
          }
          
          final routeInfo = RouteInfo(
            polylinePoints: polylinePoints,
            distance: leg['distance']['text'],
            duration: leg['duration']['text'],
            startAddress: leg['start_address'],
            endAddress: leg['end_address'],
            steps: steps,
          );
          
          state = state.copyWith(
            isLoading: false,
            currentRoute: routeInfo,
          );
          
          Logger.info('🗺️ Route found: ${routeInfo.distance}, ${routeInfo.duration}');
        } else {
          throw Exception(data['status'] ?? 'No route found');
        }
      } else {
        throw Exception('Failed to fetch route: ${response.statusCode}');
      }
    } catch (e) {
      Logger.error('Failed to fetch route', e);
      
      // Fallback to estimated route on error
      if (state.origin != null && state.destination != null) {
        final fallbackRoute = _generateFallbackRoute(origin, destination, destinationName);
        state = state.copyWith(
          isLoading: false,
          currentRoute: fallbackRoute,
          errorMessage: 'Using estimated route (API unavailable)',
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          errorMessage: e.toString(),
        );
      }
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
final routePolylinesProvider = Provider<Set<Polyline>>((ref) {
  final routeState = ref.watch(safeRouteProvider);
  
  if (!routeState.hasRoute) {
    return {};
  }
  
  return {
    Polyline(
      polylineId: const PolylineId('safe_route'),
      points: routeState.currentRoute!.polylinePoints,
      color: const Color(0xFF4CAF50), // Green for safe route
      width: 5,
      patterns: [
        PatternItem.dash(20),
        PatternItem.gap(10),
      ],
    ),
  };
});

/// Route markers provider (start and end)
final routeMarkersProvider = Provider<Set<Marker>>((ref) {
  final routeState = ref.watch(safeRouteProvider);
  
  if (!routeState.hasRoute) {
    return {};
  }
  
  final points = routeState.currentRoute!.polylinePoints;
  if (points.isEmpty) return {};
  
  return {
    Marker(
      markerId: const MarkerId('route_start'),
      position: points.first,
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      infoWindow: InfoWindow(
        title: 'Start',
        snippet: routeState.currentRoute!.startAddress,
      ),
    ),
    Marker(
      markerId: const MarkerId('route_end'),
      position: points.last,
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      infoWindow: InfoWindow(
        title: routeState.destinationName ?? 'Destination',
        snippet: routeState.currentRoute!.duration,
      ),
    ),
  };
});
