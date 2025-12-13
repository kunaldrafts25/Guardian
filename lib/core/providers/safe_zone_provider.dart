/*
 * Guardian 2.0 - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * 
 * SafeZone Provider - Geofencing and safe zone management
 */

import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:guardian/core/models/safe_zone_model.dart';
import 'package:guardian/core/utils/logger.dart';

/// Safe zone state
class SafeZoneState {
  final List<SafeZone> zones;
  final bool isLoading;
  final String? errorMessage;
  final SafeZone? currentZone; // Zone user is currently in
  final bool isInSafeZone;

  const SafeZoneState({
    this.zones = const [],
    this.isLoading = false,
    this.errorMessage,
    this.currentZone,
    this.isInSafeZone = false,
  });

  SafeZoneState copyWith({
    List<SafeZone>? zones,
    bool? isLoading,
    String? errorMessage,
    SafeZone? currentZone,
    bool? isInSafeZone,
  }) {
    return SafeZoneState(
      zones: zones ?? this.zones,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      currentZone: currentZone,
      isInSafeZone: isInSafeZone ?? this.isInSafeZone,
    );
  }

  int get count => zones.length;
  static const int maxZones = 10;
  bool get canAddMore => zones.length < maxZones;
}

/// Safe zone notifier
class SafeZoneNotifier extends StateNotifier<SafeZoneState> {
  SafeZoneNotifier() : super(const SafeZoneState()) {
    // Start with empty zones - user will add their own
    // TODO: Load zones from Firestore for persistence
  }

  /// Add a new safe zone
  void addZone(SafeZone zone) {
    if (!state.canAddMore) {
      Logger.warning('Cannot add more than ${SafeZoneState.maxZones} zones');
      return;
    }
    
    state = state.copyWith(zones: [...state.zones, zone]);
    Logger.info('📍 Safe zone added: ${zone.name}');
  }

  /// Update a zone
  void updateZone(String id, SafeZone zone) {
    final index = state.zones.indexWhere((z) => z.id == id);
    if (index == -1) return;
    
    final updatedZones = [...state.zones];
    updatedZones[index] = zone;
    state = state.copyWith(zones: updatedZones);
    Logger.info('📍 Safe zone updated: ${zone.name}');
  }

  /// Remove a zone
  void removeZone(String id) {
    final zone = state.zones.firstWhere((z) => z.id == id, orElse: () => throw Exception('Zone not found'));
    final updatedZones = state.zones.where((z) => z.id != id).toList();
    state = state.copyWith(zones: updatedZones);
    Logger.info('📍 Safe zone removed: ${zone.name}');
  }

  /// Toggle zone active status
  void toggleZone(String id) {
    final index = state.zones.indexWhere((z) => z.id == id);
    if (index == -1) return;
    
    final zone = state.zones[index];
    final updatedZone = zone.copyWith(isActive: !zone.isActive);
    final updatedZones = [...state.zones];
    updatedZones[index] = updatedZone;
    state = state.copyWith(zones: updatedZones);
    Logger.info('📍 Safe zone ${updatedZone.isActive ? "enabled" : "disabled"}: ${zone.name}');
  }

  /// Check if position is in any safe zone
  SafeZone? checkPosition(double latitude, double longitude) {
    for (final zone in state.zones) {
      if (!zone.isActive) continue;
      
      final distance = _calculateDistance(
        latitude, longitude,
        zone.latitude, zone.longitude,
      );
      
      if (distance <= zone.radius) {
        if (state.currentZone?.id != zone.id) {
          Logger.info('📍 Entered safe zone: ${zone.name}');
        }
        state = state.copyWith(currentZone: zone, isInSafeZone: true);
        return zone;
      }
    }
    
    if (state.isInSafeZone) {
      Logger.info('📍 Left safe zone: ${state.currentZone?.name}');
      state = state.copyWith(currentZone: null, isInSafeZone: false);
    }
    return null;
  }

  /// Calculate distance between two coordinates (Haversine formula)
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const earthRadius = 6371000.0; // meters
    
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) * cos(_toRadians(lat2)) *
        sin(dLon / 2) * sin(dLon / 2);
    
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    
    return earthRadius * c;
  }

  double _toRadians(double degrees) => degrees * pi / 180;
}

/// Safe zone provider
final safeZoneProvider = StateNotifierProvider<SafeZoneNotifier, SafeZoneState>((ref) {
  return SafeZoneNotifier();
});

/// Is user in safe zone provider
final isInSafeZoneProvider = Provider<bool>((ref) {
  return ref.watch(safeZoneProvider).isInSafeZone;
});

/// Current safe zone provider
final currentSafeZoneProvider = Provider<SafeZone?>((ref) {
  return ref.watch(safeZoneProvider).currentZone;
});

/// Safe zone count provider
final safeZoneCountProvider = Provider<int>((ref) {
  return ref.watch(safeZoneProvider).count;
});
