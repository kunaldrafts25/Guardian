/*
 * Guardian walking-route provider.
 *
 * Google Routes supplies ordinary walking geometry/distance/duration through
 * the authenticated Guardian backend. Guardian does not label provider routes
 * "safe"; safety state and route-deviation policy remain Guardian-owned.
 */

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:guardian/core/services/aws_auth_service.dart';
import 'package:guardian/core/services/safety_service_bridge.dart';
import 'package:guardian/core/utils/logger.dart';
import 'package:latlong2/latlong.dart';

class RouteInfo {
  final List<LatLng> polylinePoints;
  final String distance;
  final String duration;
  final String startAddress;
  final String endAddress;
  final List<String> steps;
  final String provider;
  final bool authoritativeGeometry;

  const RouteInfo({
    required this.polylinePoints,
    required this.distance,
    required this.duration,
    required this.startAddress,
    required this.endAddress,
    this.steps = const [],
    this.provider = 'google_routes',
    this.authoritativeGeometry = true,
  });
}

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

class SafeRouteNotifier extends StateNotifier<SafeRouteState> {
  SafeRouteNotifier() : super(const SafeRouteState());

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
      final response = await AwsAuthService.instance.post(
        '/maps/routes/walking',
        {
          'origin': {
            'latitude': origin.latitude,
            'longitude': origin.longitude,
          },
          'destination': {
            'latitude': destination.latitude,
            'longitude': destination.longitude,
          },
        },
      );

      final encoded = response['encoded_polyline']?.toString() ?? '';
      final polylinePoints = _decodePolyline(encoded);
      if (polylinePoints.length < 2) {
        throw StateError('Route geometry is unavailable.');
      }

      final distanceMeters = (response['distance_meters'] as num?)?.toDouble() ?? 0;
      final durationSeconds = _durationSeconds(response['duration']?.toString() ?? '');
      final distanceText = distanceMeters < 1000
          ? '${distanceMeters.round()} m'
          : '${(distanceMeters / 1000).toStringAsFixed(1)} km';
      final durationText = durationSeconds <= 0
          ? 'Walking route'
          : '${(durationSeconds / 60).ceil()} min walk';

      final routeInfo = RouteInfo(
        polylinePoints: polylinePoints,
        distance: distanceText,
        duration: durationText,
        startAddress: 'Current Location',
        endAddress: destinationName ?? 'Destination',
        provider: response['provider']?.toString() ?? 'google_routes',
        authoritativeGeometry:
            response['geometry_type']?.toString() == 'authoritative_route',
      );

      state = state.copyWith(
        isLoading: false,
        currentRoute: routeInfo,
        errorMessage: null,
      );

      if (routeInfo.authoritativeGeometry) {
        await SafetyServiceBridge().setActiveRoute(
          polylinePoints
              .map(
                (point) => {
                  'latitude': point.latitude,
                  'longitude': point.longitude,
                },
              )
              .toList(),
        );
      } else {
        await SafetyServiceBridge().clearActiveRoute();
      }
      Logger.info('Google walking route loaded');
    } catch (error) {
      Logger.warning('Walking route provider unavailable: $error');

      // A direct geodesic line is display-only degraded guidance. It is never
      // armed in the native deviation detector because it is not routable road
      // or pedestrian geometry.
      final distanceMeters =
          const Distance().as(LengthUnit.Meter, origin, destination);
      final routeInfo = RouteInfo(
        polylinePoints: [origin, destination],
        distance: distanceMeters < 1000
            ? '${distanceMeters.round()} m direct'
            : '${(distanceMeters / 1000).toStringAsFixed(1)} km direct',
        duration: 'Routing unavailable',
        startAddress: 'Current Location',
        endAddress: destinationName ?? 'Destination',
        provider: 'degraded_direct_line',
        authoritativeGeometry: false,
      );
      state = state.copyWith(
        isLoading: false,
        currentRoute: routeInfo,
        errorMessage:
            'Walking directions are temporarily unavailable. The displayed line is not a navigable route.',
      );
      await SafetyServiceBridge().clearActiveRoute();
    }
  }

  int _durationSeconds(String value) {
    if (!value.endsWith('s')) return 0;
    final raw = value.substring(0, value.length - 1);
    return double.tryParse(raw)?.round() ?? 0;
  }

  List<LatLng> _decodePolyline(String encoded) {
    if (encoded.isEmpty) return const [];
    final points = <LatLng>[];
    var index = 0;
    var latitude = 0;
    var longitude = 0;

    while (index < encoded.length) {
      int shift = 0;
      int result = 0;
      int byte;
      do {
        if (index >= encoded.length) {
          throw const FormatException('Truncated encoded polyline');
        }
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1f) << shift;
        shift += 5;
      } while (byte >= 0x20);
      latitude += (result & 1) != 0 ? ~(result >> 1) : result >> 1;

      shift = 0;
      result = 0;
      do {
        if (index >= encoded.length) {
          throw const FormatException('Truncated encoded polyline');
        }
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1f) << shift;
        shift += 5;
      } while (byte >= 0x20);
      longitude += (result & 1) != 0 ? ~(result >> 1) : result >> 1;

      points.add(LatLng(latitude / 1e5, longitude / 1e5));
    }
    return points;
  }

  void clearRoute() {
    state = const SafeRouteState();
    SafetyServiceBridge().clearActiveRoute();
    Logger.info('Walking route cleared');
  }

  void setDestination(LatLng destination, String name) {
    state = state.copyWith(
      destination: destination,
      destinationName: name,
    );
  }
}

final safeRouteProvider =
    StateNotifierProvider<SafeRouteNotifier, SafeRouteState>((ref) {
  return SafeRouteNotifier();
});
