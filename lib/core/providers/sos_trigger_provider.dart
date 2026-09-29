/*
 * Guardian 2.0 - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * 
 * SOS Trigger Provider - Manages all SOS trigger sources
 * 
 * Integrates:
 * - Shake detection
 */

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:guardian/core/providers/emergency_provider.dart';
import 'package:guardian/core/providers/sos_settings_provider.dart';
import 'package:guardian/core/services/shake_detection_service.dart';
import 'package:guardian/core/services/sos_service.dart';
import 'package:guardian/core/services/safety_service_bridge.dart';
import 'package:guardian/core/utils/logger.dart';

/// State for SOS triggers
class SosTriggerState {
  final bool shakeDetectionActive;
  final bool isEnabled;
  final int shakeCount;

  const SosTriggerState({
    this.shakeDetectionActive = false,
    this.isEnabled = true,
    this.shakeCount = 0,
  });

  SosTriggerState copyWith({
    bool? shakeDetectionActive,
    bool? isEnabled,
    int? shakeCount,
  }) {
    return SosTriggerState(
      shakeDetectionActive: shakeDetectionActive ?? this.shakeDetectionActive,
      isEnabled: isEnabled ?? this.isEnabled,
      shakeCount: shakeCount ?? this.shakeCount,
    );
  }
}

/// SOS Trigger Notifier - Central hub for all SOS triggers
class SosTriggerNotifier extends StateNotifier<SosTriggerState> {
  final Ref _ref;
  ShakeDetectionService? _shakeService;
  SafetyServiceBridge? _bridge;

  SosTriggerNotifier(this._ref) : super(const SosTriggerState()) {
    Logger.info('🔧 SosTriggerNotifier initializing...');
    _initializeTriggers();
    _wireHardwarePanic();
  }

  /// Wire the hardware 3-tap power button panic to the real emergency flow.
  /// When SafetyForegroundService fires onHardwarePanic, we bypass countdown
  /// and call triggerFromHardwarePanic() immediately.
  void _wireHardwarePanic() {
    if (kIsWeb) return;
    _bridge = SafetyServiceBridge();
    _bridge!.onHardwarePanic = (event) {
      Logger.info(
          '🚨 Hardware panic received — triggering immediate CRITICAL SOS');
      if (event['event_id'] != null) {
        unawaited(_ingestNativeEvent(event));
      } else {
        unawaited(
            _ref.read(emergencyProvider.notifier).triggerFromHardwarePanic());
      }
    };
    _bridge!.onSosTrigger = (event) {
      final source = event['source'] as String? ?? 'unknown';
      Logger.info('🚨 Native service SOS trigger: $source');
      if (event['event_id'] != null) {
        unawaited(_ingestNativeEvent(event));
      } else if (source == 'ANDROID_POWER_GESTURE' ||
          source == 'hardware_power_panic' ||
          source == 'ANDROID_FALL' ||
          source == 'fall_detected') {
        unawaited(
            _ref.read(emergencyProvider.notifier).triggerFromHardwarePanic());
      } else if (source == 'ANDROID_SHAKE' || source == 'shake_sos') {
        _triggerSosIfNotActive(SosTriggerSource.shake);
      } else if (source == 'ROUTE_DEVIATION' || source == 'route_deviation') {
        _triggerSosIfNotActive(SosTriggerSource.routeDeviation);
      } else if (source == 'MULTI_TAP' || source == 'triple_tap') {
        _triggerSosIfNotActive(SosTriggerSource.multiTap);
      } else {
        _triggerSosIfNotActive(SosTriggerSource.button);
      }
    };
    _bridge!.onRouteDeviation = (deviationMeters) {
      Logger.warning(
          '⚠️ Route deviation evidence received: ${deviationMeters.round()}m. '
          'Native confirmation policy owns escalation.');
    };
    _bridge!.onAnomalyDetected = (type, data) {
      Logger.warning('🚨 Anomaly detected: $type, data: $data');

      // P0-01: Native now emits trigger_authority=false for onAnomalyDetected to prevent double triggers.
      // Canonical trigger is handled by onSosTrigger.
      final bool hasAuthority = data['trigger_authority'] as bool? ?? true;
      if (!hasAuthority) {
        Logger.info('ℹ️ Anomaly evidence only — skipping emergency trigger');
        return;
      }

      if (type == 'ANDROID_FALL' || type == 'fall_detected') {
        unawaited(
            _ref.read(emergencyProvider.notifier).triggerFromHardwarePanic());
      } else if (type == 'ANDROID_SHAKE' || type == 'shake_sos') {
        _triggerSosIfNotActive(SosTriggerSource.shake);
      } else if (type == 'ROUTE_DEVIATION' || type == 'route_deviation') {
        _triggerSosIfNotActive(SosTriggerSource.routeDeviation);
      }
    };
    unawaited(_replayNativeEvents());
  }

  Future<void> _replayNativeEvents() async {
    final events = await _bridge!.getPendingNativeEmergencyEvents();
    for (final event in events) {
      final imported = await _ingestNativeEvent(event);
      if (!imported) break;
    }
  }

  Future<bool> _ingestNativeEvent(Map<String, dynamic> event) async {
    final eventId = event['event_id'] as String?;
    if (eventId == null || eventId.isEmpty) return false;
    final imported = await _ref
        .read(emergencyProvider.notifier)
        .ingestNativeEmergencyEvent(event);
    if (imported) {
      await _bridge!.acknowledgeNativeEmergencyEvent(eventId);
    }
    return imported;
  }

  /// Initialize all trigger sources based on settings
  void _initializeTriggers() {
    // Skip on web
    if (kIsWeb) {
      Logger.info('📱 SOS triggers not available on web');
      return;
    }

    final settings = _ref.read(sosSettingsProvider);
    Logger.info('📱 SOS Settings - Shake: ${settings.shakeToSosEnabled}');

    // Initialize shake detection
    if (settings.shakeToSosEnabled) {
      startShakeDetection();
    }

    // Listen for settings changes
    _ref.listen<SosSettings>(sosSettingsProvider, (previous, next) {
      Logger.info('📱 SOS Settings changed - Shake: ${next.shakeToSosEnabled}');
      if (previous?.shakeToSosEnabled != next.shakeToSosEnabled) {
        if (next.shakeToSosEnabled) {
          startShakeDetection();
        } else {
          stopShakeDetection();
        }
      }
    });
  }

  // ============ SHAKE DETECTION ============

  /// Start listening for shake gestures
  void startShakeDetection() {
    if (kIsWeb) return;
    if (state.shakeDetectionActive) {
      Logger.info('📱 Shake detection already active');
      return;
    }

    _shakeService = ShakeDetectionService.instance;
    _shakeService!.startListening(
      onShake: _onShakeDetected,
    );

    state = state.copyWith(shakeDetectionActive: true);
    Logger.info('📱 ✅ Shake-to-SOS ACTIVATED');
  }

  /// Stop shake detection
  void stopShakeDetection() {
    _shakeService?.stopListening();
    state = state.copyWith(shakeDetectionActive: false);
    Logger.info('📱 Shake-to-SOS deactivated');
  }

  /// Handle shake detection
  void _onShakeDetected() {
    Logger.info('🚨🚨🚨 SHAKE DETECTED! Triggering SOS...');
    _triggerSosIfNotActive(SosTriggerSource.shake);
  }

  // ============ COMMON TRIGGER LOGIC ============

  /// Trigger SOS if not already active
  void _triggerSosIfNotActive(SosTriggerSource source) {
    final emergencyState = _ref.read(emergencyProvider);

    if (emergencyState.isActive) {
      Logger.info('SOS already active, ignoring trigger');
      return;
    }

    if (emergencyState.state == SosState.countdown) {
      Logger.info('Countdown already in progress, ignoring trigger');
      return;
    }

    // Trigger SOS based on source
    switch (source) {
      case SosTriggerSource.shake:
        _ref.read(emergencyProvider.notifier).triggerFromShake();
        break;
      case SosTriggerSource.voiceCommand:
        _ref.read(emergencyProvider.notifier).triggerEmergency(
              source: SosTriggerSource.voiceCommand,
            );
        break;
      case SosTriggerSource.fall:
        unawaited(
            _ref.read(emergencyProvider.notifier).triggerFromHardwarePanic());
        break;
      case SosTriggerSource.routeDeviation:
        _ref.read(emergencyProvider.notifier).triggerEmergency(
              source: SosTriggerSource.routeDeviation,
            );
        break;
      case SosTriggerSource.multiTap:
        _ref.read(emergencyProvider.notifier).triggerEmergency(
              source: SosTriggerSource.multiTap,
            );
        break;
      default:
        _ref.read(emergencyProvider.notifier).triggerEmergency(source: source);
    }
  }

  /// Enable/disable all triggers
  void setEnabled(bool enabled) {
    state = state.copyWith(isEnabled: enabled);

    if (enabled) {
      final settings = _ref.read(sosSettingsProvider);
      if (settings.shakeToSosEnabled) {
        startShakeDetection();
      }
    } else {
      stopShakeDetection();
    }
  }

  @override
  void dispose() {
    _shakeService?.dispose();
    _bridge?.dispose();
    super.dispose();
  }
}

/// SOS Trigger provider
final sosTriggerProvider =
    StateNotifierProvider<SosTriggerNotifier, SosTriggerState>((ref) {
  return SosTriggerNotifier(ref);
});

/// Shake detection active provider
final shakeDetectionActiveProvider = Provider<bool>((ref) {
  return ref.watch(sosTriggerProvider).shakeDetectionActive;
});
