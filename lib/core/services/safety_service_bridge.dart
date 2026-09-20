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

  const ServiceLocation({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.timestamp,
  });

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

  static Future<bool> updateEmergencySnapshot({
    required int version,
    required String userName,
    required List<Map<String, String>> contacts,
    String? message,
  }) async {
    try {
      return await _serviceChannel.invokeMethod<bool>(
            'updateEmergencySnapshot',
            {
              'version': version,
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
        _lastLocation = ServiceLocation(
          latitude: (result['latitude'] as num).toDouble(),
          longitude: (result['longitude'] as num).toDouble(),
          accuracy: (result['accuracy'] as num).toDouble(),
          timestamp: DateTime.now(),
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
        _lastLocation = ServiceLocation(
          latitude: (args['latitude'] as num).toDouble(),
          longitude: (args['longitude'] as num).toDouble(),
          accuracy: (args['accuracy'] as num).toDouble(),
          timestamp: DateTime.now(),
        );
        onLocationUpdate?.call(_lastLocation!);
        break;

      case 'onServiceSosTrigger':
        final event = Map<String, dynamic>.from(call.arguments as Map? ?? {});
        final source = event['source'] as String? ?? 'unknown';
        Logger.info('🚨 SOS triggered from native service: $source');
        onSosTrigger?.call(event);
        break;

      default:
        Logger.debug('Unknown native call: ${call.method}');
    }
  }

  Future<void> _handleEmergencyCall(MethodCall call) async {
    switch (call.method) {
      case 'onHardwarePanic':
        Logger.info(
            '🚨 Hardware power button 3-tap panic received from native!');
        onHardwarePanic?.call(
          Map<String, dynamic>.from(call.arguments as Map? ?? {}),
        );
        break;

      case 'onTripleTap':
        // Legacy triple-tap from PowerButtonReceiver
        Logger.info('🚨 Triple tap SOS from PowerButtonReceiver');
        onSosTrigger?.call(const {'source': 'triple_tap'});
        break;

      default:
        Logger.debug('Unknown emergency channel call: ${call.method}');
    }
  }

  void dispose() {
    _serviceChannel.setMethodCallHandler(null);
  }
}
