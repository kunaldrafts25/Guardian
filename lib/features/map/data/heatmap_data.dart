/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'package:google_maps_flutter/google_maps_flutter.dart';

/// A class to represent a heatmap point with intensity
class HeatmapPoint {
  /// The location of the heatmap point
  final LatLng location;
  
  /// The intensity of the heatmap point (0.0 to 1.0)
  final double intensity;
  
  /// The radius of the heatmap point in meters
  final double radius;
  
  HeatmapPoint({
    required this.location,
    required this.intensity,
    this.radius = 100.0,
  });
}

/// A class to generate mock heatmap data
class HeatmapData {
  /// Generate mock crime heatmap data around a center point
  static List<HeatmapPoint> generateMockCrimeData(LatLng center, {int count = 10}) {
    final List<HeatmapPoint> points = [];
    
    // Generate random points around the center
    for (int i = 0; i < count; i++) {
      // Create a grid of points with varying intensities
      final double latOffset = (i % 3 - 1) * 0.005 + (i > 5 ? 0.003 : -0.003);
      final double lngOffset = (i % 2 - 0.5) * 0.008 + (i > 7 ? 0.004 : -0.004);
      
      // Intensity decreases as we move away from certain "hotspots"
      double intensity = 0.0;
      
      // Create a few hotspots
      if (i % 5 == 0) {
        intensity = 0.9; // High intensity hotspot
      } else if (i % 3 == 0) {
        intensity = 0.7; // Medium intensity
      } else {
        intensity = 0.4; // Lower intensity
      }
      
      // Add some randomness to the intensity
      intensity = (intensity * 0.8) + (i % 10) * 0.02;
      
      // Clamp intensity between 0.0 and 1.0
      intensity = intensity.clamp(0.0, 1.0);
      
      // Create the heatmap point
      points.add(
        HeatmapPoint(
          location: LatLng(
            center.latitude + latOffset,
            center.longitude + lngOffset,
          ),
          intensity: intensity,
          radius: 150.0 + (i % 5) * 30.0, // Varying radius
        ),
      );
    }
    
    return points;
  }
  
  /// Generate mock safe route points between two locations
  static List<LatLng> generateMockSafeRoute(LatLng start, LatLng end) {
    // In a real app, this would call a routing API with safety parameters
    // For now, we'll create a simple route with a few waypoints
    
    final List<LatLng> route = [];
    
    // Add start point
    route.add(start);
    
    // Calculate midpoints with slight deviation to simulate a real route
    final double latDiff = end.latitude - start.latitude;
    final double lngDiff = end.longitude - start.longitude;
    
    // Add some waypoints
    route.add(LatLng(
      start.latitude + latDiff * 0.25 + 0.001,
      start.longitude + lngDiff * 0.25 - 0.002,
    ));
    
    route.add(LatLng(
      start.latitude + latDiff * 0.5 - 0.0015,
      start.longitude + lngDiff * 0.5 + 0.001,
    ));
    
    route.add(LatLng(
      start.latitude + latDiff * 0.75 + 0.002,
      start.longitude + lngDiff * 0.75 + 0.0005,
    ));
    
    // Add end point
    route.add(end);
    
    return route;
  }
  
  /// Generate mock nearby helpers data
  static List<Map<String, dynamic>> generateMockHelpers(LatLng center, {int count = 5}) {
    final List<Map<String, dynamic>> helpers = [];
    
    final List<String> helperTypes = [
      'volunteer',
      'police',
      'security_guard',
      'medical',
      'community_member',
    ];
    
    final List<String> names = [
      'Priya S.',
      'Rahul K.',
      'Ananya M.',
      'Vikram P.',
      'Neha G.',
      'Sanjay R.',
      'Meera T.',
      'Arjun D.',
    ];
    
    // Generate random helpers around the center
    for (int i = 0; i < count; i++) {
      // Create a scattered distribution of helpers
      final double latOffset = (i % 3 - 1) * 0.003 + (i > 3 ? 0.002 : -0.002);
      final double lngOffset = (i % 2 - 0.5) * 0.004 + (i > 2 ? 0.003 : -0.003);
      
      // Select helper type and name
      final String helperType = helperTypes[i % helperTypes.length];
      final String name = names[i % names.length];
      
      // Create the helper data
      helpers.add({
        'id': 'helper_$i',
        'name': name,
        'type': helperType,
        'rating': 4.0 + (i % 5) * 0.2,
        'distance': 200 + (i * 50),
        'location': LatLng(
          center.latitude + latOffset,
          center.longitude + lngOffset,
        ),
        'isAvailable': i % 4 != 0, // Some helpers are unavailable
      });
    }
    
    return helpers;
  }
}
