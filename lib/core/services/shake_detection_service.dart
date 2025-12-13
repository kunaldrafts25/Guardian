/*
 * Guardian 2.0 - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * 
 * Shake Detection Service - Trigger SOS by shaking device
 */

import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:guardian/core/utils/logger.dart';

/// Shake detection callback
typedef ShakeCallback = void Function();

/// Shake Detection Service
/// 
/// Detects rapid shaking motion to trigger SOS.
/// Requires 3 shakes within 2 seconds to activate.
class ShakeDetectionService {
  static ShakeDetectionService? _instance;
  static ShakeDetectionService get instance => _instance ??= ShakeDetectionService._();

  ShakeDetectionService._();

  StreamSubscription<AccelerometerEvent>? _subscription;
  ShakeCallback? _onShake;
  
  bool _isEnabled = false;
  bool _isListening = false;
  
  // Shake detection parameters
  static const double _shakeThreshold = 15.0; // m/s²
  static const int _shakesRequired = 3;
  static const Duration _shakeWindow = Duration(seconds: 2);
  static const Duration _cooldown = Duration(seconds: 5);
  
  final List<DateTime> _shakeTimestamps = [];
  DateTime? _lastTrigger;

  /// Start listening for shakes
  void startListening({required ShakeCallback onShake}) {
    if (_isListening) return;
    
    _onShake = onShake;
    _isEnabled = true;
    _isListening = true;
    
    // Web doesn't support accelerometer
    if (kIsWeb) {
      Logger.info('📱 Shake detection not available on web');
      return;
    }
    
    _subscription = accelerometerEvents.listen(_onAccelerometerEvent);
    Logger.info('📱 Shake detection started');
  }

  /// Stop listening for shakes
  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
    _isListening = false;
    _shakeTimestamps.clear();
    Logger.info('📱 Shake detection stopped');
  }

  /// Enable/disable shake detection
  void setEnabled(bool enabled) {
    _isEnabled = enabled;
    Logger.info('📱 Shake detection ${enabled ? "enabled" : "disabled"}');
  }

  /// Check if shake detection is enabled
  bool get isEnabled => _isEnabled;

  /// Check if currently listening
  bool get isListening => _isListening;

  void _onAccelerometerEvent(AccelerometerEvent event) {
    if (!_isEnabled) return;
    
    // Check cooldown
    if (_lastTrigger != null) {
      final sinceLastTrigger = DateTime.now().difference(_lastTrigger!);
      if (sinceLastTrigger < _cooldown) return;
    }
    
    // Calculate magnitude of acceleration
    final magnitude = sqrt(
      event.x * event.x + 
      event.y * event.y + 
      event.z * event.z
    );
    
    // Check if exceeds threshold (accounting for gravity ~9.8)
    if (magnitude > _shakeThreshold) {
      _registerShake();
    }
  }

  void _registerShake() {
    final now = DateTime.now();
    
    // Remove old timestamps outside window
    _shakeTimestamps.removeWhere((time) => 
      now.difference(time) > _shakeWindow
    );
    
    // Add current shake
    _shakeTimestamps.add(now);
    
    Logger.debug('📱 Shake detected (${_shakeTimestamps.length}/$_shakesRequired)');
    
    // Check if enough shakes
    if (_shakeTimestamps.length >= _shakesRequired) {
      _triggerSos();
    }
  }

  void _triggerSos() {
    _lastTrigger = DateTime.now();
    _shakeTimestamps.clear();
    
    Logger.info('🚨 SHAKE SOS TRIGGERED!');
    _onShake?.call();
  }

  /// Dispose resources
  void dispose() {
    stopListening();
    _instance = null;
  }
}
