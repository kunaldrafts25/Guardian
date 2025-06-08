/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:math';

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
      // In a real app, this would use a geocoding service
      // For this mock implementation, we'll return a fake address

      // Generate a somewhat realistic address based on coordinates
      final random =
          Random(position.latitude.toInt() + position.longitude.toInt());

      final streets = [
        'Main Street',
        'Park Avenue',
        'Oak Lane',
        'Maple Road',
        'Cedar Street',
        'Pine Avenue',
        'Elm Boulevard',
        'River Road',
        'Lake Drive',
        'Mountain View',
      ];

      final cities = [
        'Springfield',
        'Riverside',
        'Oakville',
        'Maplewood',
        'Cedarville',
        'Pineville',
        'Elmwood',
        'Riverdale',
        'Lakeside',
        'Hillcrest',
      ];

      final streetNumber = random.nextInt(200) + 1;
      final street = streets[random.nextInt(streets.length)];
      final city = cities[random.nextInt(cities.length)];

      return '$streetNumber $street, $city';
    } catch (e) {
      return null;
    }
  }
}
