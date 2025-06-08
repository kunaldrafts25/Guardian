/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:guardian/core/utils/logger.dart';

/// A service for handling location-related functionality
class LocationService {
  // Private constructor to prevent instantiation
  LocationService._();
  
  /// Get the current location
  static Future<Position?> getCurrentLocation() async {
    try {
      // Check if location services are enabled
      final serviceEnabled = await isLocationServiceEnabled();
      if (!serviceEnabled) {
        Logger.warning('Location services are disabled');
        return null;
      }
      
      // Check if we have permission
      final permissionGranted = await requestLocationPermission();
      if (!permissionGranted) {
        Logger.warning('Location permission denied');
        return null;
      }
      
      // Get the current position
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      Logger.error('Error getting current location', e);
      return null;
    }
  }
  
  /// Check if location services are enabled
  static Future<bool> isLocationServiceEnabled() async {
    try {
      return await Geolocator.isLocationServiceEnabled();
    } catch (e) {
      Logger.error('Error checking location service status', e);
      return false;
    }
  }
  
  /// Request location permission
  static Future<bool> requestLocationPermission() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      
      return permission == LocationPermission.whileInUse || 
             permission == LocationPermission.always;
    } catch (e) {
      Logger.error('Error requesting location permission', e);
      return false;
    }
  }
  
  /// Get a stream of location updates
  static Stream<Position> getLocationStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Update every 10 meters
      ),
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
  
  /// Get the last known position
  static Future<Position?> getLastKnownPosition() async {
    try {
      return await Geolocator.getLastKnownPosition();
    } catch (e) {
      Logger.error('Error getting last known position', e);
      return null;
    }
  }
  
  /// Open location settings
  static Future<bool> openLocationSettings() async {
    try {
      return await Geolocator.openLocationSettings();
    } catch (e) {
      Logger.error('Error opening location settings', e);
      return false;
    }
  }
  
  /// Open app settings
  static Future<bool> openAppSettings() async {
    try {
      return await Geolocator.openAppSettings();
    } catch (e) {
      Logger.error('Error opening app settings', e);
      return false;
    }
  }
}

