/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:guardian/core/constants/app_colors.dart';
import 'package:guardian/core/utils/api_keys.dart';
import 'package:guardian/core/utils/location_utils.dart';
import 'package:guardian/core/utils/logger.dart';
import 'package:http/http.dart' as http;

/// A service for Google Maps functionality
class MapsService {
  static final Map<String, BitmapDescriptor> _markerCache = {};
  static final Map<String, dynamic> _locationCache = {};
  static const Duration _cacheDuration = Duration(minutes: 15);
  /// Default camera position (India)
  static const CameraPosition defaultCameraPosition = CameraPosition(
    target: LatLng(20.5937, 78.9629),
    zoom: 5,
  );

  /// Get current location and return as LatLng
  static Future<LatLng?> getCurrentLatLng() async {
    try {
      final position = await LocationUtils.getCurrentPosition();
      if (position != null) {
        return LatLng(position.latitude, position.longitude);
      }
      return null;
    } catch (e) {
      Logger.error('Error getting current location', e);
      return null;
    }
  }

  /// Get camera position for current location
  static Future<CameraPosition?> getCurrentCameraPosition({double zoom = 15}) async {
    final latLng = await getCurrentLatLng();
    if (latLng != null) {
      return CameraPosition(
        target: latLng,
        zoom: zoom,
      );
    }
    return null;
  }

  /// Create a custom marker from an asset with caching
  static Future<BitmapDescriptor> createMarkerFromAsset(String assetPath) async {
    // Check if marker is already in cache
    if (_markerCache.containsKey(assetPath)) {
      Logger.info('Using cached marker for $assetPath');
      return _markerCache[assetPath]!;
    }

    try {
      // For now, use different default markers based on the asset path
      // This is a workaround until BitmapDescriptor.asset is available
      BitmapDescriptor marker;

      if (assetPath.contains('hospital')) {
        marker = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
      } else if (assetPath.contains('police')) {
        marker = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
      } else if (assetPath.contains('safe')) {
        marker = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
      } else if (assetPath.contains('danger')) {
        marker = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);
      } else {
        marker = BitmapDescriptor.defaultMarker;
      }

      // Cache the marker
      _markerCache[assetPath] = marker;

      return marker;
    } catch (e) {
      Logger.error('Error creating marker from asset', e);
      return BitmapDescriptor.defaultMarker;
    }
  }

  /// Create a custom marker with text with caching
  static Future<BitmapDescriptor> createMarkerWithText({
    required String text,
    Color backgroundColor = AppColors.primary,
    Color textColor = Colors.white,
    double width = 80,
    double height = 80,
  }) async {
    // Create a cache key based on parameters
    final cacheKey = 'marker_text_${text}_${backgroundColor.value}_${textColor.value}_${width}_$height';

    // Check if marker is already in cache
    if (_markerCache.containsKey(cacheKey)) {
      Logger.info('Using cached text marker for "$text"');
      return _markerCache[cacheKey]!;
    }

    try {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final paint = Paint()..color = backgroundColor;
      final textPainter = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            color: textColor,
            fontSize: 30,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );

      // Draw circle background
      canvas.drawCircle(Offset(width / 2, height / 2), width / 2, paint);

      // Draw text
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          (width - textPainter.width) / 2,
          (height - textPainter.height) / 2,
        ),
      );

      // Convert to image
      final img = await recorder.endRecording().toImage(
        width.toInt(),
        height.toInt(),
      );
      final data = await img.toByteData(format: ui.ImageByteFormat.png);

      if (data != null) {
        // Use colored markers based on the text content
        // This is a workaround until BitmapDescriptor.bytes is available
        BitmapDescriptor marker;

        final lowerText = text.toLowerCase();
        if (lowerText.contains('sos') || lowerText.contains('emergency')) {
          marker = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
        } else if (lowerText.contains('safe') || lowerText.contains('home')) {
          marker = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
        } else if (lowerText.contains('warning') || lowerText.contains('caution')) {
          marker = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow);
        } else if (backgroundColor == AppColors.primary) {
          marker = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet);
        } else {
          marker = BitmapDescriptor.defaultMarker;
        }

        // Cache the marker
        _markerCache[cacheKey] = marker;

        return marker;
      } else {
        return BitmapDescriptor.defaultMarker;
      }
    } catch (e) {
      Logger.error('Error creating marker with text', e);
      return BitmapDescriptor.defaultMarker;
    }
  }

  /// Get address from coordinates using Google Maps Geocoding API with caching
  static Future<String?> getAddressFromCoordinates(
    LatLng coordinates, {
    bool forceRefresh = false,
  }) async {
    // Create a cache key based on coordinates
    final cacheKey = 'address_${coordinates.latitude}_${coordinates.longitude}';

    // Check if we have a valid cached result
    if (!forceRefresh && _locationCache.containsKey(cacheKey)) {
      final cachedData = _locationCache[cacheKey];
      final timestamp = cachedData['timestamp'] as DateTime;

      // If cache is still valid (within cache duration)
      if (DateTime.now().difference(timestamp) < _cacheDuration) {
        Logger.info('Using cached address data');
        return cachedData['data'] as String?;
      }
    }

    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json?latlng=${coordinates.latitude},${coordinates.longitude}&key=${ApiKeys.googleMaps}',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK' && data['results'].isNotEmpty) {
          final address = data['results'][0]['formatted_address'] as String;

          // Cache the result
          _locationCache[cacheKey] = {
            'data': address,
            'timestamp': DateTime.now(),
          };

          return address;
        }
      }

      return null;
    } catch (e) {
      Logger.error('Error getting address from coordinates', e);
      return null;
    }
  }

  /// Get directions between two points with caching
  static Future<Map<String, dynamic>?> getDirections(
    LatLng origin,
    LatLng destination, {
    bool forceRefresh = false,
  }) async {
    // Create a cache key based on origin and destination
    final cacheKey = 'directions_${origin.latitude}_${origin.longitude}_${destination.latitude}_${destination.longitude}';

    // Check if we have a valid cached result
    if (!forceRefresh && _locationCache.containsKey(cacheKey)) {
      final cachedData = _locationCache[cacheKey];
      final timestamp = cachedData['timestamp'] as DateTime;

      // If cache is still valid (within cache duration)
      if (DateTime.now().difference(timestamp) < _cacheDuration) {
        Logger.info('Using cached directions data');
        return cachedData['data'] as Map<String, dynamic>?;
      }
    }

    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json?origin=${origin.latitude},${origin.longitude}&destination=${destination.latitude},${destination.longitude}&key=${ApiKeys.googleMaps}',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK') {
          // Cache the result
          _locationCache[cacheKey] = {
            'data': data,
            'timestamp': DateTime.now(),
          };

          return data;
        }
      }

      return null;
    } catch (e) {
      Logger.error('Error getting directions', e);
      return null;
    }
  }

  /// Get polyline points from directions response
  static List<LatLng> decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;

      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);

      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;

      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);

      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }

    return points;
  }

  /// Get nearby places (hospitals, police stations, etc.) with caching
  static Future<List<Map<String, dynamic>>> getNearbyPlaces(
    double latitude,
    double longitude,
    String type, {
    int radius = 5000,
    bool forceRefresh = false,
  }) async {
    // Create a cache key based on parameters
    final cacheKey = 'nearby_${latitude}_${longitude}_${type}_$radius';

    // Check if we have a valid cached result
    if (!forceRefresh && _locationCache.containsKey(cacheKey)) {
      final cachedData = _locationCache[cacheKey];
      final timestamp = cachedData['timestamp'] as DateTime;

      // If cache is still valid (within cache duration)
      if (DateTime.now().difference(timestamp) < _cacheDuration) {
        Logger.info('Using cached nearby places data for $type');
        return List<Map<String, dynamic>>.from(cachedData['data']);
      }
    }

    try {
      final url =
          'https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=$latitude,$longitude&radius=$radius&type=$type&key=${ApiKeys.googleMaps}';

      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          final results = List<Map<String, dynamic>>.from(data['results']);

          // Cache the results
          _locationCache[cacheKey] = {
            'data': results,
            'timestamp': DateTime.now(),
          };

          return results;
        }
      }
      return [];
    } catch (e) {
      Logger.error('Error getting nearby places', e);
      return [];
    }
  }

  /// Clear all cached data
  static void clearCache() {
    _locationCache.clear();
    _markerCache.clear();
    Logger.info('Maps service cache cleared');
  }

  /// Clear location cache
  static void clearLocationCache() {
    _locationCache.clear();
    Logger.info('Maps service location cache cleared');
  }

  /// Clear marker cache
  static void clearMarkerCache() {
    _markerCache.clear();
    Logger.info('Maps service marker cache cleared');
  }

  /// Clear specific cache entry
  static void clearCacheEntry(String key) {
    if (_locationCache.containsKey(key)) {
      _locationCache.remove(key);
      Logger.info('Maps service location cache entry cleared: $key');
    }

    if (_markerCache.containsKey(key)) {
      _markerCache.remove(key);
      Logger.info('Maps service marker cache entry cleared: $key');
    }
  }

  /// Get static map URL
  static String getStaticMapUrl({
    required LatLng center,
    int zoom = 15,
    int width = 600,
    int height = 300,
    List<LatLng> markers = const [],
    List<List<LatLng>> paths = const [],
  }) {
    const baseUrl = 'https://maps.googleapis.com/maps/api/staticmap';
    final centerParam = 'center=${center.latitude},${center.longitude}';
    final zoomParam = 'zoom=$zoom';
    final sizeParam = 'size=${width}x$height';
    final keyParam = 'key=${ApiKeys.googleMaps}';

    String markersParam = '';
    if (markers.isNotEmpty) {
      markersParam = markers.map((marker) =>
        'markers=color:red|${marker.latitude},${marker.longitude}'
      ).join('&');
    }

    String pathsParam = '';
    if (paths.isNotEmpty) {
      pathsParam = paths.map((path) {
        final pathPoints = path.map((point) =>
          '${point.latitude},${point.longitude}'
        ).join('|');
        return 'path=color:0x0000ff|weight:5|$pathPoints';
      }).join('&');
    }

    final params = [centerParam, zoomParam, sizeParam, keyParam];
    if (markersParam.isNotEmpty) params.add(markersParam);
    if (pathsParam.isNotEmpty) params.add(pathsParam);

    return '$baseUrl?${params.join('&')}';
  }

  /// Calculate bounds for a list of points
  static LatLngBounds calculateBounds(List<LatLng> points) {
    if (points.isEmpty) {
      // Default bounds (world)
      return LatLngBounds(
        southwest: const LatLng(-90, -180),
        northeast: const LatLng(90, 180),
      );
    }

    double minLat = 90;
    double maxLat = -90;
    double minLng = 180;
    double maxLng = -180;

    for (final point in points) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }
}

