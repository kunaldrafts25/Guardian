/*
 * Guardian — SafetyServiceBridge
 *
 * Dart-side wrapper for the Android SafetyForegroundService method channel.
 * Controls the background service, receives location updates, and provides
 * the always-available last-known location for SOS alerts.
 *
 * Riverpod provider: safetyServiceProvider
 */

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:guardian/core/models/emergency_location.dart';
import 'package:guardian/core/utils/logger.dart';

// ═══════════════════════════════════════════════════════
// PROVIDER
// ═══════════════════════════════════════════════════════

final safetyServiceProvider = Provider<SafetyServiceBridge>((ref) {
  final bridge = SafetyServiceBridge();
  ref.onDispose(bridge.dispose);
  return bridge;
});

// ═══════════════════════════════════════════════════════
// STATE
// ═══════════════════════════════════════════════════════

class ServiceLocation {
  final double latitude;
  final double longitude;
  final double accuracy;
  final DateTime timestamp;
  final DateTime? capturedAt;
  final String source;
  final LocationFreshness freshness;

  const ServiceLocation({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.timestamp,
    this.capturedAt,
    this.source = 'native_service',
    this.freshness = LocationFreshness.fresh,
  });

  EmergencyLocation toEmergencyLocation() => EmergencyLocation.fromFix(
        latitude: latitude,
        longitude: longitude,
        accuracy: accuracy,
        capturedAt: capturedAt ?? timestamp,
        receivedAt: DateTime.now().toUtc(),
        source: source,
      );

  String get googleMapsLink =>
      'https://maps.google.com/?q=$latitude,$longitude';
}

class NativeCheckInScheduleResult {
  final bool scheduled;
  final bool exact;

  const NativeCheckInScheduleResult({
    required this.scheduled,
    required this.exact,
  });
}

// ═══════════════════════════════════════════════════════
// BRIDGE
// ═══════════════════════════════════════════════════════

class SafetyServiceBridge {
  static const _serviceChannel = MethodChannel('com.guardian/service');
  static const _emergencyChannel = MethodChannel('com.guardian/emergency');

  ServiceLocation? _lastLocation;
  ServiceLocation? get lastLocation => _lastLocation;

  /// Callback fired when service sends a location update
  void Function(ServiceLocation)? onLocationUpdate;

  /// Callback fired when service triggers an SOS (e.g. notification SOS button)
  void Function(Map<String, dynamic> event)? onSosTrigger;

  /// Callback fired when hardware 3-tap power button panic is detected
  void Function(Map<String, dynamic> event)? onHardwarePanic;

  /// Callback fired when user deviates significantly from active route
  void Function(double deviationMeters)? onRouteDeviation;

  /// Callback fired when native sensors detect an anomaly (fall, impact, shake)
  void Function(String type, Map<String, dynamic> data)? onAnomalyDetected;

  SafetyServiceBridge() {
    _serviceChannel.setMethodCallHandler(_handleNativeCall);
    _emergencyChannel.setMethodCallHandler(_handleEmergencyCall);
  }

  // ─────────────────────────────────────────────────
  // Service Control
  // ─────────────────────────────────────────────────

  /// Start the Android SafetyForegroundService
  Future<bool> startService() async {
    try {
      final result =
          await _serviceChannel.invokeMethod<bool>('startSafetyService');
      Logger.info('🛡️ SafetyForegroundService started');
      return result ?? false;
    } on MissingPluginException {
      Logger.debug('🛡️ SafetyForegroundService not available (iOS/web)');
      return false;
    } catch (e) {
      Logger.error('🛡️ Failed to start SafetyForegroundService', e);
      return false;
    }
  }

  /// Stop the Android SafetyForegroundService
  Future<bool> stopService() async {
    try {
      final result =
          await _serviceChannel.invokeMethod<bool>('stopSafetyService');
      Logger.info('🛡️ SafetyForegroundService stopped');
      return result ?? false;
    } catch (e) {
      Logger.error('🛡️ Failed to stop service', e);
      return false;
    }
  }

  /// Check if service is running
  Future<bool> isRunning() async {
    try {
      return await _serviceChannel.invokeMethod<bool>('isServiceRunning') ??
          false;
    } catch (_) {
      return false;
    }
  }

  Future<bool?> isBatteryOptimizationIgnored() async {
    try {
      return await _serviceChannel
          .invokeMethod<bool>('isBatteryOptimizationIgnored');
    } on MissingPluginException {
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<bool> setActiveRoute(List<Map<String, double>> points) async {
    try {
      return await _serviceChannel.invokeMethod<bool>(
            'setActiveRoute',
            {'points': points},
          ) ??
          false;
    } on MissingPluginException {
      return false;
    } catch (e) {
      Logger.error('Failed to sync active route to service', e);
      return false;
    }
  }

  Future<bool> clearActiveRoute() async {
    try {
      return await _serviceChannel.invokeMethod<bool>('clearActiveRoute') ??
          false;
    } on MissingPluginException {
      return false;
    } catch (e) {
      Logger.error('Failed to clear active route in service', e);
      return false;
    }
  }

  /// Synchronize trigger settings with the native platform service
  static Future<bool> syncSafetySettings({
    required bool shakeEnabled,
    required bool fallEnabled,
  }) async {
    try {
      return await _serviceChannel.invokeMethod<bool>(
            'updateSafetySettings',
            {
              'shake_enabled': shakeEnabled,
              'fall_enabled': fallEnabled,
            },
          ) ??
          false;
    } on MissingPluginException {
      return false;
    } catch (e) {
      Logger.error('Failed to sync safety settings to native', e);
      return false;
    }
  }

  /// Get trigger settings cached on the native platform service
  static Future<Map<String, bool>> getSafetySettings() async {
    try {
      final result = await _serviceChannel.invokeMapMethod<String, dynamic>(
        'getSafetySettings',
      );
      if (result != null) {
        return {
          'shake_enabled': result['shake_enabled'] == true,
          'fall_enabled': result['fall_enabled'] == true,
        };
      }
      return {'shake_enabled': true, 'fall_enabled': true};
    } on MissingPluginException {
      return {'shake_enabled': true, 'fall_enabled': true};
    } catch (e) {
      Logger.error('Failed to get native safety settings', e);
      return {'shake_enabled': true, 'fall_enabled': true};
    }
  }

  static Future<bool> updateEmergencySnapshot({
    required int version,
    required String userId,
    required String userName,
    required List<Map<String, String>> contacts,
    String? message,
  }) async {
    try {
      return await _serviceChannel.invokeMethod<bool>(
            'updateEmergencySnapshot',
            {
              'version': version,
              'user_id': userId,
              'user_name': userName,
              'contacts': contacts,
              if (message != null && message.isNotEmpty) 'message': message,
            },
          ) ??
          false;
    } on MissingPluginException {
      return false;
    } catch (error) {
      Logger.error('Failed to update native emergency snapshot', error);
      return false;
    }
  }

  static Future<bool> updateEmergencyAuth({
    required String userId,
    required String accessToken,
    String? refreshToken,
    required String sessionId,
    required String apiEndpoint,
  }) async {
    if (accessToken.isEmpty || sessionId.isEmpty || apiEndpoint.isEmpty) {
      return false;
    }
    try {
      return await _serviceChannel.invokeMethod<bool>(
            'updateEmergencyAuth',
            {
              'user_id': userId,
              'access_token': accessToken,
              if (refreshToken != null && refreshToken.isNotEmpty)
                'refresh_token': refreshToken,
              'session_id': sessionId,
              'api_endpoint': apiEndpoint,
            },
          ) ??
          false;
    } on MissingPluginException {
      return false;
    } catch (error) {
      Logger.error('Failed to update native emergency auth', error);
      return false;
    }
  }

  static Future<bool> clearEmergencySnapshot() async {
    try {
      return await _serviceChannel
              .invokeMethod<bool>('clearEmergencySnapshot') ??
          false;
    } on MissingPluginException {
      return false;
    } catch (error) {
      Logger.error('Failed to clear native emergency snapshot', error);
      return false;
    }
  }

  static Future<NativeCheckInScheduleResult> scheduleCheckIn({
    required String operationId,
    required DateTime deadline,
    required DateTime graceDeadline,
  }) async {
    try {
      final result = await _serviceChannel.invokeMapMethod<String, dynamic>(
        'scheduleCheckIn',
        {
          'operationId': operationId,
          'deadlineMs': deadline.millisecondsSinceEpoch,
          'graceDeadlineMs': graceDeadline.millisecondsSinceEpoch,
        },
      );
      return NativeCheckInScheduleResult(
        scheduled: result?['scheduled'] == true,
        exact: result?['exact'] == true,
      );
    } on MissingPluginException {
      return const NativeCheckInScheduleResult(scheduled: false, exact: false);
    }
  }

  static Future<void> cancelScheduledCheckIn() async {
    try {
      await _serviceChannel.invokeMethod<void>('cancelCheckIn');
    } on MissingPluginException {
      // Native scheduling is Android-only.
    }
  }

  static Future<List<Map<String, dynamic>>> getPendingCheckInActions() async {
    try {
      final actions = await _serviceChannel
              .invokeListMethod<dynamic>('getPendingCheckInActions') ??
          const [];
      return actions
          .whereType<Map>()
          .map((action) => Map<String, dynamic>.from(action))
          .toList();
    } on MissingPluginException {
      return const [];
    }
  }

  static Future<bool> acknowledgeCheckInAction(String actionId) async {
    try {
      return await _serviceChannel.invokeMethod<bool>(
            'acknowledgeCheckInAction',
            {'actionId': actionId},
          ) ??
          false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Atomically converge Flutter and AlarmManager check-in expiry onto the
  /// same Android native operation/event. Returns the canonical native event.
  static Future<Map<String, dynamic>?> triggerCheckInEmergency(
    String operationId,
  ) async {
    try {
      final event = await _serviceChannel.invokeMapMethod<String, dynamic>(
        'triggerCheckInEmergency',
        {'operationId': operationId},
      );
      return event == null ? null : Map<String, dynamic>.from(event);
    } on MissingPluginException {
      return null;
    } catch (error) {
      Logger.error('Failed to trigger canonical native check-in emergency', error);
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getPendingNativeEmergencyEvents() async {
    try {
      final events = await _serviceChannel
              .invokeListMethod<dynamic>('getPendingNativeEmergencyEvents') ??
          const [];
      return events
          .whereType<Map>()
          .map((event) => Map<String, dynamic>.from(event))
          .toList();
    } on MissingPluginException {
      return const [];
    }
  }

  Future<bool> acknowledgeNativeEmergencyEvent(String eventId) async {
    try {
      return await _serviceChannel.invokeMethod<bool>(
            'acknowledgeNativeEmergencyEvent',
            {'eventId': eventId},
          ) ??
          false;
    } on MissingPluginException {
      return false;
    }
  }

  // ─────────────────────────────────────────────────
  // Location
  // ─────────────────────────────────────────────────

  /// Get the last location cached by the foreground service
  /// This is always available as long as the service has been running
  Future<ServiceLocation?> getLastServiceLocation() async {
    try {
      final result = await _serviceChannel.invokeMethod<Map>('getLastLocation');
      if (result != null) {
        final timeMs = result['time_ms'] as num?;
        final rx = DateTime.now().toUtc();
        final cap = timeMs != null
            ? DateTime.fromMillisecondsSinceEpoch(timeMs.toInt(), isUtc: true)
            : rx;
        final accuracy = (result['accuracy'] as num).toDouble();
        final freshness = EmergencyLocation.calculateFreshness(
          capturedAt: timeMs != null ? cap : null,
          receivedAt: rx,
          accuracy: accuracy,
        );
        _lastLocation = ServiceLocation(
          latitude: (result['latitude'] as num).toDouble(),
          longitude: (result['longitude'] as num).toDouble(),
          accuracy: accuracy,
          timestamp: cap,
          capturedAt: cap,
          source: (result['provider'] as String?) ?? 'cached',
          freshness: freshness,
        );
        return _lastLocation;
      }
      return null;
    } on MissingPluginException {
      return null;
    } catch (e) {
      Logger.error('Failed to get service location', e);
      return null;
    }
  }

  // ─────────────────────────────────────────────────
  // Native → Dart callbacks
  // ─────────────────────────────────────────────────

  Future<void> _handleNativeCall(MethodCall call) async {
    switch (call.method) {
      case 'onLocationUpdate':
        final args = call.arguments as Map;
        final timeMs = args['time_ms'] as num?;
        final rx = DateTime.now().toUtc();
        final cap = timeMs != null
            ? DateTime.fromMillisecondsSinceEpoch(timeMs.toInt(), isUtc: true)
            : rx;
        final accuracy = (args['accuracy'] as num).toDouble();
        final freshness = EmergencyLocation.calculateFreshness(
          capturedAt: timeMs != null ? cap : null,
          receivedAt: rx,
          accuracy: accuracy,
        );
        _lastLocation = ServiceLocation(
          latitude: (args['latitude'] as num).toDouble(),
          longitude: (args['longitude'] as num).toDouble(),
          accuracy: accuracy,
          timestamp: cap,
          capturedAt: cap,
          source: (args['provider'] as String?) ?? 'gps',
          freshness: freshness,
        );
        onLocationUpdate?.call(_lastLocation!);
        break;

      case 'onServiceSosTrigger':
        final event = Map<String, dynamic>.from(call.arguments as Map? ?? {});
        final source = event['source'] as String? ?? 'unknown';
        Logger.info('🚨 SOS triggered from native service: $source');
        onSosTrigger?.call(event);
        break;

      case 'onRouteDeviation':
        final args = call.arguments as Map;
        final deviation = (args['deviation_meters'] as num?)?.toDouble() ?? 0.0;
        Logger.warning(
            '🚨 Route deviation received from native: ${deviation.round()}m');
        onRouteDeviation?.call(deviation);
        break;

      case 'onAnomalyDetected':
        final args = call.arguments as Map;
        final type = args['type'] as String? ?? 'unknown';
        final data = Map<String, dynamic>.from(args['data'] as Map? ?? {});
        Logger.warning('🚨 Native anomaly detected: $type, data: $data');
        onAnomalyDetected?.call(type, data);
        break;

      default:
        Logger.debug('Unknown native call: ${call.method}');
    }
  }

  Future<void> _handleEmergencyCall(MethodCall call) async {
    switch (call.method) {
      case 'onNativeEmergencyEvent':
        final event = Map<String, dynamic>.from(call.arguments as Map? ?? {});
        final source = event['source'] as String? ?? 'unknown';
        Logger.info('🚨 Native emergency event received: $source');
        onSosTrigger?.call(event);
        break;

      case 'onHardwarePanic':
        Logger.info(
            '🚨 Hardware power button 3-tap panic received from native!');
        onHardwarePanic?.call(
          Map<String, dynamic>.from(call.arguments as Map? ?? {}),
        );
        break;

      case 'onTripleTap':
        final args = call.arguments as Map?;
        final src = args?['source'] as String? ?? 'MULTI_TAP';
        Logger.info('🚨 Multi-tap SOS from PowerButtonReceiver: $src');
        onSosTrigger?.call({'source': src});
        break;

      default:
        Logger.debug('Unknown emergency channel call: ${call.method}');
    }
  }

  void dispose() {
    _serviceChannel.setMethodCallHandler(null);
  }
}
