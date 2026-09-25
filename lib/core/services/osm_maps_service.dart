/*
 * Guardian - Women's Safety App
 * OpenStreetMap Maps Service — 100% FREE, No API Key Required
 *
 * Services used (all free, no account needed):
 *   - Map tiles:    OpenStreetMap (tile.openstreetmap.org) — free
 *   - Geocoding:    Nominatim (nominatim.openstreetmap.org) — free
 *   - Routing:      OSRM (router.project-osrm.org) — free
 *   - Safety data:  Overpass API (overpass-api.de) — free
 *
 * For map rendering in Flutter: use flutter_map (not google_maps_flutter)
 * Add to pubspec.yaml:
 *   flutter_map: ^6.1.0
 *   latlong2: ^0.9.0
 */

import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:guardian/core/config/map_routing_config.dart';
import 'package:guardian/core/utils/logger.dart';

/// Represents a lat/long coordinate (compatible with flutter_map's LatLng)
class LatLng {
  final double latitude;
  final double longitude;
  const LatLng(this.latitude, this.longitude);

  @override
  String toString() => '($latitude, $longitude)';
}

/// Result of a geocoding / reverse geocoding operation
class GeocodingResult {
  final String displayName;
  final String? street;
  final String? city;
  final String? state;
  final String? country;
  final LatLng coordinates;

  const GeocodingResult({
    required this.displayName,
    required this.coordinates,
    this.street,
    this.city,
    this.state,
    this.country,
  });
}

/// A walking/driving route
class RouteResult {
  final List<LatLng> points;
  final double distanceMeters;
  final int durationSeconds;
  final String summary;

  const RouteResult({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.summary,
  });

  String get distanceText {
    if (distanceMeters < 1000) {
      return '${distanceMeters.round()} m';
    }
    return '${(distanceMeters / 1000).toStringAsFixed(1)} km';
  }

  String get durationText {
    final mins = (durationSeconds / 60).ceil();
    if (mins < 60) return '$mins min';
    final hrs = mins ~/ 60;
    final rem = mins % 60;
    return '$hrs h ${rem > 0 ? '$rem min' : ''}';
  }
}

/// Free OpenStreetMap-based Maps Service
/// Drop-in replacement for Google Maps APIs at zero cost.
class OsmMapsService {
  static String get _nominatimBase => MapRoutingConfig.nominatimBaseUrl;
  static String get _osrmBase => MapRoutingConfig.osrmBaseUrl;
  static const String _overpassBase = 'https://overpass-api.de/api/interpreter';

  // Simple cache to reduce repeated API hits
  static final Map<String, _CacheEntry> _cache = {};
  static const _cacheDuration = Duration(minutes: 20);

  // ─── Geocoding ─────────────────────────────────────────────────────────

  /// Convert a text address / place name to coordinates.
  /// Example: "Mumbai" → LatLng(19.0760, 72.8777)
  static Future<GeocodingResult?> geocode(String query) async {
    final cacheKey = 'geo_$query';
    if (_cached(cacheKey) != null) return _cached(cacheKey) as GeocodingResult?;

    try {
      final url = Uri.parse(
        '$_nominatimBase/search?q=${Uri.encodeComponent(query)}&format=json&limit=1&addressdetails=1',
      );
      final resp = await MapRoutingConfig.throttledNominatimGet(
        url,
        timeout: MapRoutingConfig.defaultSearchTimeout,
      );

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as List;
        if (data.isNotEmpty) {
          final result =
              _parseNominatimResult(data.first as Map<String, dynamic>);
          _setCache(cacheKey, result);
          return result;
        }
      }
    } catch (e) {
      Logger.warning('OSM geocode error: $e');
    }
    return null;
  }

  /// Convert coordinates to a human-readable address.
  /// Example: LatLng(19.0760, 72.8777) → "Churchgate, Mumbai, India"
  static Future<GeocodingResult?> reverseGeocode(LatLng point) async {
    final cacheKey = 'rev_${point.latitude}_${point.longitude}';
    if (_cached(cacheKey) != null) return _cached(cacheKey) as GeocodingResult?;

    try {
      final url = Uri.parse(
        '$_nominatimBase/reverse?lat=${point.latitude}&lon=${point.longitude}&format=json&addressdetails=1',
      );
      final resp = await MapRoutingConfig.throttledNominatimGet(
        url,
        timeout: MapRoutingConfig.defaultSearchTimeout,
      );

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        if (data['display_name'] != null) {
          final result = _parseNominatimResult(data);
          _setCache(cacheKey, result);
          return result;
        }
      }
    } catch (e) {
      Logger.warning('OSM reverse geocode error: $e');
    }
    return null;
  }

  /// Shorthand: get just the display address string from coordinates.
  static Future<String?> getAddressFromCoordinates(LatLng point) async {
    final result = await reverseGeocode(point);
    return result?.displayName;
  }

  // ─── Routing (OSRM) ────────────────────────────────────────────────────

  /// Get walking route between two points using OSRM (free, open-source).
  /// Returns a list of LatLng waypoints to draw on the map.
  static Future<RouteResult?> getWalkingRoute(
      LatLng origin, LatLng destination) async {
    return _getRoute(origin, destination, profile: 'foot');
  }

  /// Get driving route between two points.
  static Future<RouteResult?> getDrivingRoute(
      LatLng origin, LatLng destination) async {
    return _getRoute(origin, destination, profile: 'car');
  }

  static Future<RouteResult?> _getRoute(
    LatLng origin,
    LatLng destination, {
    String profile = 'foot',
  }) async {
    final cacheKey =
        'route_${profile}_${origin.latitude}_${origin.longitude}_${destination.latitude}_${destination.longitude}';
    if (_cached(cacheKey) != null) return _cached(cacheKey) as RouteResult?;

    try {
      // OSRM uses longitude,latitude order
      final url = Uri.parse(
        '$_osrmBase/route/v1/$profile/'
        '${origin.longitude},${origin.latitude};'
        '${destination.longitude},${destination.latitude}'
        '?overview=full&geometries=geojson&steps=false',
      );

      final resp = await MapRoutingConfig.executeWithRetry(
        () => http.get(url).timeout(MapRoutingConfig.defaultRoutingTimeout),
        serviceName: 'OSRM',
      );

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        if (data['code'] == 'Ok' && (data['routes'] as List).isNotEmpty) {
          final route = data['routes'][0] as Map<String, dynamic>;
          final geometry = route['geometry'] as Map<String, dynamic>;
          final coords = geometry['coordinates'] as List;

          final points = coords.map((c) {
            final coord = c as List;
            return LatLng(coord[1] as double, coord[0] as double);
          }).toList();

          final result = RouteResult(
            points: points,
            distanceMeters: (route['distance'] as num).toDouble(),
            durationSeconds: (route['duration'] as num).round(),
            summary:
                '${((route['distance'] as num) / 1000).toStringAsFixed(1)} km — ${((route['duration'] as num) / 60).ceil()} min walk',
          );

          _setCache(cacheKey, result);
          return result;
        }
      }
    } catch (e) {
      Logger.warning(
          'OSRM routing error: $e. Returning direct geodesic fallback.');
      final distM = distanceBetween(origin, destination);
      return RouteResult(
        points: [origin, destination],
        distanceMeters: distM,
        durationSeconds: ((distM / 80) * 60).round(),
        summary:
            '${(distM / 1000).toStringAsFixed(1)} km (direct) — ${((distM / 80)).ceil()} min walk',
      );
    }
    return null;
  }

  // ─── Safety Places (Overpass API) ──────────────────────────────────────

  /// Find nearby hospitals, police stations, and safe places via Overpass API.
  /// Returns a list of place maps with name, lat, lng, type.
  static Future<List<Map<String, dynamic>>> getNearbyEmergencyPlaces(
    LatLng center, {
    int radiusMeters = 2000,
  }) async {
    final cacheKey =
        'places_${center.latitude}_${center.longitude}_$radiusMeters';
    if (_cached(cacheKey) != null) {
      return List<Map<String, dynamic>>.from(_cached(cacheKey) as List);
    }

    // Overpass QL query — finds hospitals, police stations, pharmacies
    final query = '''
[out:json][timeout:10];
(
  node["amenity"="hospital"](around:$radiusMeters,${center.latitude},${center.longitude});
  node["amenity"="police"](around:$radiusMeters,${center.latitude},${center.longitude});
  node["amenity"="pharmacy"](around:$radiusMeters,${center.latitude},${center.longitude});
  node["amenity"="fire_station"](around:$radiusMeters,${center.latitude},${center.longitude});
  node["shop"="supermarket"](around:$radiusMeters,${center.latitude},${center.longitude});
)->.searchResults;
.searchResults out body;
''';

    try {
      final resp = await http.post(
        Uri.parse(_overpassBase),
        body: query,
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      ).timeout(const Duration(seconds: 12));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final elements = data['elements'] as List? ?? [];

        final places = elements.map((e) {
          final el = e as Map<String, dynamic>;
          final tags = el['tags'] as Map<String, dynamic>? ?? {};
          final amenity =
              tags['amenity'] as String? ?? tags['shop'] as String? ?? 'place';
          return {
            'id': el['id'],
            'name': tags['name'] ?? tags['name:en'] ?? _amenityLabel(amenity),
            'latitude': el['lat'],
            'longitude': el['lon'],
            'type': amenity,
            'address': tags['addr:full'] ?? tags['addr:street'] ?? '',
            'phone': tags['phone'] ?? tags['contact:phone'] ?? '',
          };
        }).toList();

        _setCache(cacheKey, places);
        return places;
      }
    } catch (e) {
      Logger.warning('Overpass API error: $e');
    }
    return [];
  }

  /// Find dangerous areas (reported incidents) near a location.
  /// Uses Overpass API for CCTV coverage gaps as a proxy for safer routes.
  static Future<List<Map<String, dynamic>>> getSafeZoneInfrastructure(
    LatLng center, {
    int radiusMeters = 1500,
  }) async {
    final query = '''
[out:json][timeout:10];
(
  node["man_made"="surveillance"](around:$radiusMeters,${center.latitude},${center.longitude});
  node["highway"="street_lamp"](around:$radiusMeters,${center.latitude},${center.longitude});
  way["highway"~"pedestrian|footway|living_street"](around:$radiusMeters,${center.latitude},${center.longitude});
)->.infra;
.infra out body;
''';

    try {
      final resp = await http.post(
        Uri.parse(_overpassBase),
        body: query,
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      ).timeout(const Duration(seconds: 12));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final elements = data['elements'] as List? ?? [];
        return elements.where((e) => (e as Map)['lat'] != null).map((e) {
          final el = e as Map<String, dynamic>;
          final tags = el['tags'] as Map<String, dynamic>? ?? {};
          return {
            'id': el['id'],
            'latitude': el['lat'],
            'longitude': el['lon'],
            'type': tags['man_made'] ?? tags['highway'] ?? 'infrastructure',
            'name': tags['name'] ?? '',
          };
        }).toList();
      }
    } catch (e) {
      Logger.warning('Overpass safe zone query error: $e');
    }
    return [];
  }

  // ─── Distance Calculation ──────────────────────────────────────────────

  /// Haversine formula — great-circle distance in meters between two points.
  static double distanceBetween(LatLng a, LatLng b) {
    const R = 6371000.0; // Earth radius in meters
    final lat1 = _toRad(a.latitude);
    final lat2 = _toRad(b.latitude);
    final dLat = _toRad(b.latitude - a.latitude);
    final dLng = _toRad(b.longitude - a.longitude);

    final s = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(s), math.sqrt(1 - s));
    return R * c;
  }

  /// Bearing in degrees from point A to point B (0° = North, 90° = East)
  static double bearingBetween(LatLng from, LatLng to) {
    final lat1 = _toRad(from.latitude);
    final lat2 = _toRad(to.latitude);
    final dLon = _toRad(to.longitude - from.longitude);

    final y = math.sin(dLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);

    final bearing = math.atan2(y, x) * 180 / math.pi;
    return (bearing + 360) % 360;
  }

  // ─── Map Tile URLs (for flutter_map) ──────────────────────────────────

  /// Returns the OSM tile URL template for use with flutter_map's TileLayer.
  /// This replaces Google Maps tile rendering — completely free.
  static String get osmTileUrl => MapRoutingConfig.tilesUrl;

  /// Dark/night map tile — Carto Dark Matter (free)
  static String get darkTileUrl =>
      'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png';

  /// Humanitarian map — better for safety/emergency use
  static String get humanitarianTileUrl =>
      'https://tile-a.openstreetmap.fr/hot/{z}/{x}/{y}.png';

  /// Google Maps deep-link for navigation (opens native Google Maps)
  /// Free to use — no API key needed for deep-links
  static Uri googleMapsNavigationUri(LatLng destination, {String mode = 'w'}) {
    // mode: d=driving, w=walking, b=bicycling, l=transit
    return Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&destination=${destination.latitude},${destination.longitude}'
      '&travelmode=${_travelMode(mode)}',
    );
  }

  /// Apple Maps deep-link (iOS)
  static Uri appleMapsNavigationUri(LatLng destination) {
    return Uri.parse(
      'maps://maps.apple.com/?daddr=${destination.latitude},${destination.longitude}&dirflg=w',
    );
  }

  // ─── Internal Helpers ──────────────────────────────────────────────────

  static GeocodingResult _parseNominatimResult(Map<String, dynamic> data) {
    final address = data['address'] as Map<String, dynamic>? ?? {};
    return GeocodingResult(
      displayName: data['display_name'] as String? ?? 'Unknown location',
      coordinates: LatLng(
        double.tryParse(data['lat']?.toString() ?? '0') ?? 0,
        double.tryParse(data['lon']?.toString() ?? '0') ?? 0,
      ),
      street: address['road'] as String? ?? address['pedestrian'] as String?,
      city: address['city'] as String? ??
          address['town'] as String? ??
          address['village'] as String?,
      state: address['state'] as String?,
      country: address['country'] as String?,
    );
  }

  static String _amenityLabel(String amenity) {
    const labels = {
      'hospital': 'Hospital',
      'police': 'Police Station',
      'pharmacy': 'Pharmacy',
      'fire_station': 'Fire Station',
      'supermarket': 'Supermarket',
    };
    return labels[amenity] ?? amenity.replaceAll('_', ' ').toUpperCase();
  }

  static String _travelMode(String mode) {
    const modes = {
      'w': 'walking',
      'd': 'driving',
      'b': 'bicycling',
      'l': 'transit'
    };
    return modes[mode] ?? 'walking';
  }

  static double _toRad(double deg) => deg * math.pi / 180;

  static dynamic _cached(String key) {
    final entry = _cache[key];
    if (entry == null) return null;
    if (DateTime.now().difference(entry.timestamp) > _cacheDuration) {
      _cache.remove(key);
      return null;
    }
    return entry.value;
  }

  static void _setCache(String key, dynamic value) {
    _cache[key] = _CacheEntry(value, DateTime.now());
  }

  static void clearCache() => _cache.clear();
}

class _CacheEntry {
  final dynamic value;
  final DateTime timestamp;
  _CacheEntry(this.value, this.timestamp);
}
