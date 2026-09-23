/*
 * Guardian 2.0 - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * 
 * SOS Trigger Provider - Manages all SOS trigger sources
 * 
 * Integrates:
 * - Shake detection
 * - Multi-tap screen detection (5 taps)
 * - Voice command triggers
 */

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:guardian/core/providers/emergency_provider.dart';
import 'package:guardian/core/providers/sos_settings_provider.dart';
import 'package:guardian/core/services/shake_detection_service.dart';
import 'package:guardian/core/services/voice_recognition_service.dart';
import 'package:guardian/core/services/sos_service.dart';
import 'package:guardian/core/services/safety_service_bridge.dart';
import 'package:guardian/core/utils/logger.dart';

/// State for SOS triggers
class SosTriggerState {
  final bool shakeDetectionActive;
  final bool voiceDetectionActive;
  final bool isEnabled;
  final int shakeCount;
  final int tapCount;
  final DateTime? lastTapTime;

  const SosTriggerState({
    this.shakeDetectionActive = false,
    this.voiceDetectionActive = false,
    this.isEnabled = true,
    this.shakeCount = 0,
    this.tapCount = 0,
    this.lastTapTime,
  });

  SosTriggerState copyWith({
    bool? shakeDetectionActive,
    bool? voiceDetectionActive,
    bool? isEnabled,
    int? shakeCount,
    int? tapCount,
    DateTime? lastTapTime,
  }) {
    return SosTriggerState(
      shakeDetectionActive: shakeDetectionActive ?? this.shakeDetectionActive,
      voiceDetectionActive: voiceDetectionActive ?? this.voiceDetectionActive,
      isEnabled: isEnabled ?? this.isEnabled,
      shakeCount: shakeCount ?? this.shakeCount,
      tapCount: tapCount ?? this.tapCount,
      lastTapTime: lastTapTime ?? this.lastTapTime,
    );
  }
}

/// SOS Trigger Notifier - Central hub for all SOS triggers
class SosTriggerNotifier extends StateNotifier<SosTriggerState> {
  final Ref _ref;
  ShakeDetectionService? _shakeService;
  VoiceRecognitionService? _voiceService;
  SafetyServiceBridge? _bridge;

  // Multi-tap settings
  static const int _tapsRequired = 5;
  static const Duration _tapWindow = Duration(seconds: 2);

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
      } else if (source == 'hardware_power_panic' || source == 'fall_detected') {
        unawaited(_ref.read(emergencyProvider.notifier).triggerFromHardwarePanic());
      } else if (source == 'shake_sos') {
        _triggerSosIfNotActive(SosTriggerSource.shake);
      } else {
        _triggerSosIfNotActive(SosTriggerSource.button);
      }
    };
    _bridge!.onRouteDeviation = (deviationMeters) {
      Logger.warning('🚨 Route deviation received: ${deviationMeters.round()}m');
      _triggerSosIfNotActive(SosTriggerSource.button);
    };
    _bridge!.onAnomalyDetected = (type, data) {
      Logger.warning('🚨 Anomaly detected: $type, data: $data');
      if (type == 'fall_detected') {
        unawaited(_ref.read(emergencyProvider.notifier).triggerFromHardwarePanic());
      } else if (type == 'shake_sos') {
        _triggerSosIfNotActive(SosTriggerSource.shake);
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

  // ============ VOICE DETECTION ============

  /// Start voice recognition
  Future<void> startVoiceDetection() async {
    if (kIsWeb) return;
    if (state.voiceDetectionActive) return;

    _voiceService = VoiceRecognitionService.instance;

    final started = await _voiceService!.startListening(
      onTrigger: _onVoiceTriggerDetected,
    );

    if (started) {
      state = state.copyWith(voiceDetectionActive: true);
      Logger.info('🎤 ✅ Voice-to-SOS ACTIVATED');
    }
  }

  /// Stop voice recognition
  Future<void> stopVoiceDetection() async {
    await _voiceService?.stopListening();
    state = state.copyWith(voiceDetectionActive: false);
    Logger.info('🎤 Voice-to-SOS deactivated');
  }

  /// Handle voice trigger
  void _onVoiceTriggerDetected(String phrase) {
    Logger.info('🚨🚨🚨 VOICE TRIGGER: "$phrase" - Triggering SOS...');
    _triggerSosIfNotActive(SosTriggerSource.voiceCommand);
  }

  // ============ MULTI-TAP DETECTION ============

  /// Register a screen tap - call this from UI
  void registerTap() {
    final now = DateTime.now();
    final lastTap = state.lastTapTime;

    // Reset if tap window expired
    if (lastTap == null || now.difference(lastTap) > _tapWindow) {
      state = state.copyWith(tapCount: 1, lastTapTime: now);
      Logger.debug('👆 Tap 1/$_tapsRequired');
      return;
    }

    // Increment tap count
    final newCount = state.tapCount + 1;
    state = state.copyWith(tapCount: newCount, lastTapTime: now);
    Logger.info('👆 Tap $newCount/$_tapsRequired');

    // Check if threshold reached
    if (newCount >= _tapsRequired) {
      Logger.info('🚨🚨🚨 MULTI-TAP TRIGGERED ($newCount taps)!');
      state = state.copyWith(tapCount: 0, lastTapTime: null);
      _triggerSosIfNotActive(SosTriggerSource.button);
    }
  }

  /// Reset tap counter
  void resetTapCount() {
    state = state.copyWith(tapCount: 0, lastTapTime: null);
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
      stopVoiceDetection();
    }
  }

  @override
  void dispose() {
    _shakeService?.dispose();
    _voiceService?.dispose();
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

/// Voice detection active provider
final voiceDetectionActiveProvider = Provider<bool>((ref) {
  return ref.watch(sosTriggerProvider).voiceDetectionActive;
});
