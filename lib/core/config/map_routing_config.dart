/*
 * Guardian - Map & Routing Production Configuration
 *
 * Provides configurable endpoints, retry policies, rate-limiting,
 * and resilient fallbacks for geospatial services (Tiles, Nominatim, OSRM).
 */

import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:guardian/core/utils/logger.dart';

class MapRoutingConfig {
  static const String defaultTilesUrl = String.fromEnvironment(
    'GUARDIAN_MAP_TILES_URL',
    defaultValue: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
  );

  static const String defaultNominatimUrl = String.fromEnvironment(
    'GUARDIAN_NOMINATIM_URL',
    defaultValue: 'https://nominatim.openstreetmap.org',
  );

  static const String defaultOsrmUrl = String.fromEnvironment(
    'GUARDIAN_OSRM_URL',
    defaultValue: 'https://router.project-osrm.org',
  );

  static const String defaultUserAgent = String.fromEnvironment(
    'GUARDIAN_MAP_USER_AGENT',
    defaultValue: 'GuardianSafetyApp/2.0 (safety-support@guardian-safety.app; production-emergency)',
  );

  // Runtime overrides (e.g. for self-hosted instances in enterprise / testing)
  static String tilesUrl = defaultTilesUrl;
  static String nominatimBaseUrl = defaultNominatimUrl;
  static String osrmBaseUrl = defaultOsrmUrl;
  static String userAgent = defaultUserAgent;

  static const Duration defaultSearchTimeout = Duration(seconds: 8);
  static const Duration defaultRoutingTimeout = Duration(seconds: 10);
  static const int maxRetries = 2;

  // Rate-limiting compliance: Minimum interval between Nominatim requests (OSM policy: <= 1 req/sec)
  static DateTime _lastNominatimRequestTime = DateTime.fromMillisecondsSinceEpoch(0);
  static const Duration nominatimMinInterval = Duration(milliseconds: 1050);

  /// Standard compliant HTTP headers for OpenStreetMap / Nominatim
  static Map<String, String> get nominatimHeaders => {
        'User-Agent': userAgent,
        'Accept-Language': 'en',
      };

  /// Throttled GET request adhering to Nominatim usage policy with exponential backoff retry
  static Future<http.Response> throttledNominatimGet(
    Uri uri, {
    Duration timeout = defaultSearchTimeout,
  }) async {
    final now = DateTime.now();
    final elapsed = now.difference(_lastNominatimRequestTime);
    if (elapsed < nominatimMinInterval) {
      final waitMs = (nominatimMinInterval - elapsed).inMilliseconds;
      await Future.delayed(Duration(milliseconds: waitMs));
    }
    _lastNominatimRequestTime = DateTime.now();

    return executeWithRetry(
      () => http.get(uri, headers: nominatimHeaders).timeout(timeout),
      serviceName: 'Nominatim',
    );
  }

  /// Resilient HTTP execution with exponential backoff retries for routing / geocoding
  static Future<http.Response> executeWithRetry(
    Future<http.Response> Function() action, {
    required String serviceName,
    int retries = maxRetries,
  }) async {
    int attempts = 0;
    Duration backoff = const Duration(milliseconds: 500);

    while (true) {
      attempts++;
      final start = DateTime.now();
      try {
        final response = await action();
        final duration = DateTime.now().difference(start).inMilliseconds;
        Logger.info('🗺️ [$serviceName] HTTP ${response.statusCode} (${duration}ms)');

        if (response.statusCode >= 500 && attempts <= retries) {
          Logger.warning('🗺️ [$serviceName] Server error ${response.statusCode}, retrying attempt $attempts/$retries after ${backoff.inMilliseconds}ms');
          await Future.delayed(backoff);
          backoff *= 2;
          continue;
        }
        return response;
      } catch (e) {
        final duration = DateTime.now().difference(start).inMilliseconds;
        if (attempts <= retries) {
          Logger.warning('🗺️ [$serviceName] Request failed (${duration}ms): $e. Retrying attempt $attempts/$retries after ${backoff.inMilliseconds}ms');
          await Future.delayed(backoff);
          backoff *= 2;
        } else {
          Logger.error('🗺️ [$serviceName] All $attempts attempts failed (${duration}ms)', e);
          rethrow;
        }
      }
    }
  }
}
