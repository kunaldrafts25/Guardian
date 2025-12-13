/*
 * Guardian 2.0 - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * 
 * Fake Call Service - Simulate incoming call to escape situations
 */

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:guardian/core/utils/logger.dart';

/// Fake caller preset
class FakeCaller {
  final String name;
  final String number;
  final String? photoUrl;

  const FakeCaller({
    required this.name,
    required this.number,
    this.photoUrl,
  });

  static const mom = FakeCaller(name: 'Mom', number: '+91 98765 43210');
  static const dad = FakeCaller(name: 'Dad', number: '+91 98765 43211');
  static const boss = FakeCaller(name: 'Boss', number: '+91 98765 43212');
  static const friend = FakeCaller(name: 'Best Friend', number: '+91 98765 43213');

  static const List<FakeCaller> presets = [mom, dad, boss, friend];
}

/// Fake Call Service
class FakeCallService {
  FakeCallService._();

  static Timer? _delayTimer;
  static bool _isCallActive = false;

  /// Schedule a fake call
  static void scheduleCall({
    required FakeCaller caller,
    required Duration delay,
    required VoidCallback onRing,
  }) {
    _delayTimer?.cancel();
    
    Logger.info('📞 Fake call scheduled from ${caller.name} in ${delay.inSeconds}s');
    
    _delayTimer = Timer(delay, () {
      _isCallActive = true;
      Logger.info('📞 FAKE CALL INCOMING: ${caller.name}');
      onRing();
    });
  }

  /// Cancel scheduled call
  static void cancelScheduledCall() {
    _delayTimer?.cancel();
    _delayTimer = null;
    Logger.info('📞 Scheduled fake call cancelled');
  }

  /// End active call
  static void endCall() {
    _isCallActive = false;
    Logger.info('📞 Fake call ended');
  }

  /// Check if call is active
  static bool get isCallActive => _isCallActive;

  /// Get delay options
  static List<Duration> get delayOptions => const [
    Duration(seconds: 10),
    Duration(seconds: 30),
    Duration(minutes: 1),
    Duration(minutes: 2),
    Duration(minutes: 5),
  ];

  /// Format delay for display
  static String formatDelay(Duration delay) {
    if (delay.inMinutes >= 1) {
      return '${delay.inMinutes} min';
    }
    return '${delay.inSeconds} sec';
  }
}
