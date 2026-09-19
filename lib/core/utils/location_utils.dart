/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:permission_handler/permission_handler.dart';

class LocationUtils {
  /// Check if location services are enabled
  static Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  /// Request location permission
  static Future<bool> requestLocationPermission() async {
    final status = await Permission.location.request();
    return status.isGranted;
  }

  /// Check location permission status
  static Future<bool> checkLocationPermission() async {
    final status = await Permission.location.status;
    return status.isGranted;
  }

  /// Get current position
  static Future<Position?> getCurrentPosition() async {
    final isEnabled = await isLocationServiceEnabled();
    if (!isEnabled) {
      return null;
    }

    final hasPermission = await checkLocationPermission();
    if (!hasPermission) {
      final permissionGranted = await requestLocationPermission();
      if (!permissionGranted) {
        return null;
      }
    }

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  /// Calculate distance between two coordinates in meters
  static double calculateDistance(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) {
    return Geolocator.distanceBetween(
      startLatitude,
      startLongitude,
      endLatitude,
      endLongitude,
    );
  }

  /// Check if a user is within a certain radius (in meters)
  static bool isWithinRadius(
    double centerLatitude,
    double centerLongitude,
    double userLatitude,
    double userLongitude,
    double radius,
  ) {
    final distance = calculateDistance(
      centerLatitude,
      centerLongitude,
      userLatitude,
      userLongitude,
    );
    return distance <= radius;
  }

  /// Get address from position
  static Future<String?> getAddressFromPosition(Position position) async {
    try {
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placemarks.isEmpty) return null;

      final place = placemarks.first;
      final parts = <String?>[
        place.name,
        place.street,
        place.subLocality,
        place.locality,
        place.administrativeArea,
        place.postalCode,
        place.country,
      ]
          .whereType<String>()
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toList();

      return parts.isEmpty ? null : parts.toSet().join(', ');
    } catch (e) {
      return null;
    }
  }
}
