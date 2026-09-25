/*
 * Guardian 2.0 - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * 
 * Location Provider - Riverpod state management for location
 */

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:guardian/core/models/user_model.dart';
import 'package:guardian/core/services/location_service.dart';
import 'package:guardian/core/utils/logger.dart';

// Re-export LocationMode for convenience
export 'package:guardian/core/models/user_model.dart' show LocationMode;

/// Current location state
class LocationState {
  final Position? position;
  final bool isEnabled;
  final bool hasPermission;
  final bool isLoading;
  final String? errorMessage;
  final DateTime? lastUpdated;

  const LocationState({
    this.position,
    this.isEnabled = false,
    this.hasPermission = false,
    this.isLoading = false,
    this.errorMessage,
    this.lastUpdated,
  });

  LocationState copyWith({
    Position? position,
    bool? isEnabled,
    bool? hasPermission,
    bool? isLoading,
    String? errorMessage,
    DateTime? lastUpdated,
  }) {
    return LocationState(
      position: position ?? this.position,
      isEnabled: isEnabled ?? this.isEnabled,
      hasPermission: hasPermission ?? this.hasPermission,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  bool get hasLocation => position != null;

  String get displayCoordinates {
    if (position == null) return 'Location unavailable';
    return '${position!.latitude.toStringAsFixed(6)}, ${position!.longitude.toStringAsFixed(6)}';
  }
}

/// Location state notifier
class LocationNotifier extends StateNotifier<LocationState> {
  StreamSubscription<Position>? _positionSubscription;

  LocationNotifier() : super(const LocationState()) {
    _initialize();
  }

  Future<void> _initialize() async {
    state = state.copyWith(isLoading: true);

    try {
      final isEnabled = await LocationService.isLocationServiceEnabled();
      final hasPermission = await LocationService.requestLocationPermission();

      state = state.copyWith(
        isEnabled: isEnabled,
        hasPermission: hasPermission,
        isLoading: false,
      );

      if (isEnabled && hasPermission) {
        await refreshLocation();
      }
    } catch (e) {
      Logger.error('Error initializing location', e);
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to initialize location: $e',
      );
    }
  }

  /// Refresh current location
  Future<void> refreshLocation() async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final position = await LocationService.getCurrentLocation();

      if (position != null) {
        Logger.info('Location fix refreshed');
        state = state.copyWith(
          position: position,
          isLoading: false,
          lastUpdated: DateTime.now(),
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Unable to get location',
        );
      }
    } catch (e) {
      Logger.error('Error refreshing location', e);
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Location error: $e',
      );
    }
  }

  /// Start location stream
  void startTracking() {
    _positionSubscription?.cancel();
    _positionSubscription = LocationService.getLocationStream().listen(
      (position) {
        Logger.info('📍 Location stream update');
        state = state.copyWith(
          position: position,
          lastUpdated: DateTime.now(),
        );
      },
      onError: (e) {
        Logger.error('Location stream error', e);
        state = state.copyWith(errorMessage: 'Tracking error: $e');
      },
    );
  }

  /// Stop location tracking
  void stopTracking() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
  }

  /// Request permission
  Future<bool> requestPermission() async {
    final granted = await LocationService.requestLocationPermission();
    state = state.copyWith(hasPermission: granted);
    return granted;
  }

  /// Open location settings
  Future<void> openSettings() async {
    await LocationService.openLocationSettings();
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    super.dispose();
  }
}

/// Location provider
final locationProvider =
    StateNotifierProvider<LocationNotifier, LocationState>((ref) {
  return LocationNotifier();
});

/// Current position provider (convenience)
final currentPositionProvider = Provider<Position?>((ref) {
  return ref.watch(locationProvider).position;
});

/// Is location available
final hasLocationProvider = Provider<bool>((ref) {
  return ref.watch(locationProvider).hasLocation;
});

/// Location mode display info
Map<String, dynamic> getLocationModeInfo(LocationMode mode) {
  switch (mode) {
    case LocationMode.ghost:
      return {
        'name': 'Ghost Mode',
        'description': 'Location shared only during emergencies',
        'icon': 'visibility_off',
        'color': 'grey',
      };
    case LocationMode.smart:
      return {
        'name': 'Smart Mode',
        'description': 'Auto-share at night or in risky areas',
        'icon': 'auto_awesome',
        'color': 'blue',
      };
    case LocationMode.guardian:
      return {
        'name': 'Guardian Mode',
        'description': 'Always visible to trusted contacts',
        'icon': 'visibility',
        'color': 'green',
      };
  }
}
