/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:guardian/core/services/mock_auth_service.dart';
import 'package:guardian/core/services/mock_data_service.dart';
import 'package:guardian/core/utils/logger.dart';
// Removed unused import: import 'package:guardian/core/utils/location_utils.dart';
import 'package:guardian/features/safe_zones/data/models/safe_zone_model.dart';

/// Repository for handling Safe Zone functionality
class SafeZoneRepository {
  static const String _safeZonesCollection = 'safe_zones';
  static const String _ratingsCollection = 'safety_ratings';

  /// Stream controller for safe zone updates
  final StreamController<SafeZone> _safeZoneController =
      StreamController<SafeZone>.broadcast();

  /// Stream of safe zone updates
  Stream<SafeZone> get safeZoneStream => _safeZoneController.stream;

  /// Get all safe zones
  Future<List<SafeZone>> getSafeZones() async {
    try {
      final zones = await MockDataService.getCollection(_safeZonesCollection);

      return zones.map((zone) => SafeZone.fromMap(zone)).toList();
    } catch (e) {
      Logger.error('Failed to get safe zones', e);
      return [];
    }
  }

  /// Get safe zones near a location
  Future<List<SafeZone>> getSafeZonesNearLocation({
    required double latitude,
    required double longitude,
    double radiusInKm = 5.0,
  }) async {
    try {
      final allZones = await getSafeZones();

      // Filter zones by distance
      return allZones.where((zone) {
        final zoneLatitude = zone.location['latitude'] ?? 0.0;
        final zoneLongitude = zone.location['longitude'] ?? 0.0;

        final distanceInMeters = Geolocator.distanceBetween(
          latitude,
          longitude,
          zoneLatitude,
          zoneLongitude,
        );

        // Convert to kilometers
        final distanceInKm = distanceInMeters / 1000;

        return distanceInKm <= radiusInKm;
      }).toList();
    } catch (e) {
      Logger.error('Failed to get safe zones near location', e);
      return [];
    }
  }

  /// Get a specific safe zone by ID
  Future<SafeZone?> getSafeZone(String id) async {
    try {
      final zoneData =
          await MockDataService.getDocument(_safeZonesCollection, id);

      if (zoneData == null) {
        return null;
      }

      return SafeZone.fromMap(zoneData);
    } catch (e) {
      Logger.error('Failed to get safe zone', e);
      return null;
    }
  }

  /// Create a new safe zone
  Future<String?> createSafeZone({
    required String name,
    String? description,
    required double latitude,
    required double longitude,
    double radius = 100.0,
    String? address,
    List<String> tags = const [],
  }) async {
    try {
      final user = MockAuthService.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Create initial rating
      final initialRating = SafetyRating(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: user.uid,
        rating: SafetyRatingLevel.safe,
        timeContext: TimeContext.allTimes,
        comment: 'Initial rating',
      );

      // Create safe zone
      final zone = SafeZone(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        description: description,
        location: {
          'latitude': latitude,
          'longitude': longitude,
        },
        radius: radius,
        address: address,
        ratings: [initialRating],
        averageRating: 3.0, // Safe
        predominantTimeContext: TimeContext.allTimes,
        createdBy: user.uid,
        tags: tags,
      );

      final zoneId = await MockDataService.addDocument(
        _safeZonesCollection,
        zone.toMap(),
      );

      if (zoneId.isNotEmpty) {
        // Notify listeners
        _safeZoneController.add(zone);
      }

      return zoneId;
    } catch (e) {
      Logger.error('Failed to create safe zone', e);
      return null;
    }
  }

  /// Update an existing safe zone
  Future<bool> updateSafeZone(SafeZone zone) async {
    try {
      final success = await MockDataService.updateDocument(
        _safeZonesCollection,
        zone.id,
        zone.toMap(),
      );

      if (success) {
        // Notify listeners
        _safeZoneController.add(zone);
      }

      return success;
    } catch (e) {
      Logger.error('Failed to update safe zone', e);
      return false;
    }
  }

  /// Delete a safe zone
  Future<bool> deleteSafeZone(String id) async {
    try {
      return await MockDataService.deleteDocument(_safeZonesCollection, id);
    } catch (e) {
      Logger.error('Failed to delete safe zone', e);
      return false;
    }
  }

  /// Add a rating to a safe zone
  Future<bool> addRatingToZone({
    required String zoneId,
    required SafetyRatingLevel rating,
    required TimeContext timeContext,
    String? comment,
    String? incidentType,
    bool isAnonymous = false,
  }) async {
    try {
      final user = MockAuthService.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Get the zone
      final zone = await getSafeZone(zoneId);
      if (zone == null) {
        throw Exception('Zone not found');
      }

      // Create new rating
      final newRating = SafetyRating(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: isAnonymous ? 'anonymous' : user.uid,
        rating: rating,
        timeContext: timeContext,
        comment: comment,
        incidentType: incidentType,
        isAnonymous: isAnonymous,
      );

      // Add rating to database
      await MockDataService.addDocument(
        _ratingsCollection,
        newRating.toMap(),
      );

      // Update zone with new rating
      final updatedRatings = List<SafetyRating>.from(zone.ratings)
        ..add(newRating);

      // Calculate new average rating
      final totalRating = updatedRatings.fold<double>(
        0,
        (sum, r) => sum + _getRatingValue(r.rating),
      );
      final newAverageRating = totalRating / updatedRatings.length;

      // Determine predominant time context
      final timeContextCounts = <TimeContext, int>{};
      for (final r in updatedRatings) {
        timeContextCounts[r.timeContext] =
            (timeContextCounts[r.timeContext] ?? 0) + 1;
      }

      TimeContext predominantContext = zone.predominantTimeContext;
      int maxCount = 0;

      timeContextCounts.forEach((context, count) {
        if (count > maxCount) {
          maxCount = count;
          predominantContext = context;
        }
      });

      // Update zone
      final updatedZone = zone.copyWith(
        ratings: updatedRatings,
        averageRating: newAverageRating,
        predominantTimeContext: predominantContext,
        updatedAt: DateTime.now(),
      );

      final success = await updateSafeZone(updatedZone);

      return success;
    } catch (e) {
      Logger.error('Failed to add rating to zone', e);
      return false;
    }
  }

  /// Get safe zones created by the current user
  Future<List<SafeZone>> getUserSafeZones() async {
    try {
      final user = MockAuthService.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final zones = await getSafeZones();

      return zones.where((zone) => zone.createdBy == user.uid).toList();
    } catch (e) {
      Logger.error('Failed to get user safe zones', e);
      return [];
    }
  }

  /// Get ratings submitted by the current user
  Future<List<SafetyRating>> getUserRatings() async {
    try {
      final user = MockAuthService.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final ratings = await MockDataService.getCollection(_ratingsCollection);

      return ratings
          .where((rating) => rating['userId'] == user.uid)
          .map((rating) => SafetyRating.fromMap(rating))
          .toList();
    } catch (e) {
      Logger.error('Failed to get user ratings', e);
      return [];
    }
  }

  /// Check if a location is in a safe zone
  Future<SafeZone?> isLocationInSafeZone({
    required double latitude,
    required double longitude,
  }) async {
    try {
      final zones = await getSafeZones();

      for (final zone in zones) {
        final zoneLatitude = zone.location['latitude'] ?? 0.0;
        final zoneLongitude = zone.location['longitude'] ?? 0.0;

        final distanceInMeters = Geolocator.distanceBetween(
          latitude,
          longitude,
          zoneLatitude,
          zoneLongitude,
        );

        if (distanceInMeters <= zone.radius) {
          return zone;
        }
      }

      return null;
    } catch (e) {
      Logger.error('Failed to check if location is in safe zone', e);
      return null;
    }
  }

  /// Get the safety level for a location
  Future<Map<String, dynamic>> getSafetyLevelForLocation({
    required double latitude,
    required double longitude,
  }) async {
    try {
      final nearbyZones = await getSafeZonesNearLocation(
        latitude: latitude,
        longitude: longitude,
        radiusInKm: 1.0,
      );

      if (nearbyZones.isEmpty) {
        return {
          'level': 'unknown',
          'score': 0.0,
          'message': 'No safety data available for this location',
        };
      }

      // Calculate weighted average based on distance
      double totalWeight = 0;
      double weightedSum = 0;

      for (final zone in nearbyZones) {
        final zoneLatitude = zone.location['latitude'] ?? 0.0;
        final zoneLongitude = zone.location['longitude'] ?? 0.0;

        final distanceInMeters = Geolocator.distanceBetween(
          latitude,
          longitude,
          zoneLatitude,
          zoneLongitude,
        );

        // Weight is inversely proportional to distance
        final weight = 1 / (distanceInMeters + 1);

        totalWeight += weight;
        weightedSum += zone.averageRating * weight;
      }

      final safetyScore = weightedSum / totalWeight;

      // Determine safety level
      String safetyLevel;
      String message;

      if (safetyScore >= 4.0) {
        safetyLevel = 'very_safe';
        message = 'This area is considered very safe by the community';
      } else if (safetyScore >= 3.0) {
        safetyLevel = 'safe';
        message = 'This area is considered safe by the community';
      } else if (safetyScore >= 2.0) {
        safetyLevel = 'moderate';
        message = 'This area has moderate safety concerns';
      } else if (safetyScore >= 1.0) {
        safetyLevel = 'unsafe';
        message = 'This area has safety concerns reported by the community';
      } else {
        safetyLevel = 'very_unsafe';
        message =
            'This area has serious safety concerns reported by the community';
      }

      // Check time context
      final now = DateTime.now();
      final hour = now.hour;

      // Night time (8 PM - 6 AM)
      final isNightTime = hour >= 20 || hour < 6;

      // Check if any nearby zones have time-specific safety concerns
      for (final zone in nearbyZones) {
        if (isNightTime &&
            zone.predominantTimeContext == TimeContext.daytimeOnly) {
          safetyLevel = 'caution';
          message = 'This area is reported to be less safe at night';
          break;
        } else if (!isNightTime &&
            zone.predominantTimeContext == TimeContext.nighttimeOnly) {
          safetyLevel = 'caution';
          message = 'This area has unusual daytime safety concerns';
          break;
        } else if (zone.predominantTimeContext == TimeContext.neverSafe) {
          safetyLevel = 'unsafe';
          message = 'This area has consistent safety concerns';
          break;
        }
      }

      return {
        'level': safetyLevel,
        'score': safetyScore,
        'message': message,
        'is_night_time': isNightTime,
        'nearby_zones': nearbyZones.length,
      };
    } catch (e) {
      Logger.error('Failed to get safety level for location', e);
      return {
        'level': 'error',
        'score': 0.0,
        'message': 'Failed to determine safety level',
      };
    }
  }

  /// Convert rating enum to numeric value
  double _getRatingValue(SafetyRatingLevel rating) {
    switch (rating) {
      case SafetyRatingLevel.verySafe:
        return 5.0;
      case SafetyRatingLevel.safe:
        return 4.0;
      case SafetyRatingLevel.moderate:
        return 3.0;
      case SafetyRatingLevel.unsafe:
        return 2.0;
      case SafetyRatingLevel.veryUnsafe:
        return 1.0;
    }
  }

  /// Dispose resources
  void dispose() {
    _safeZoneController.close();
  }
}
