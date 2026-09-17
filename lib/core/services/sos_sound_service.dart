/*
 * Guardian 2.0 - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * 
 * SOS Sound Service - Play alarm sounds during SOS
 */

import 'package:flutter/services.dart';
import 'package:guardian/core/utils/logger.dart';

/// SOS Sound Service
/// 
/// Plays system alarm sounds during SOS countdown and activation.
/// Uses Flutter's built-in SystemSound for cross-platform audio.
/// 
/// For louder alarms in the future, consider:
/// - audioplayers package for custom sound files
/// - Native platform channels for system alarm sounds
class SosSoundService {
  static SosSoundService? _instance;
  static SosSoundService get instance => _instance ??= SosSoundService._();

  SosSoundService._();

  bool _isPlaying = false;

  /// Play countdown beep (short sound)
  Future<void> playCountdownBeep() async {
    try {
      // Use system click sound
      await SystemSound.play(SystemSoundType.click);
      Logger.debug('🔊 Countdown beep');
    } catch (e) {
      Logger.error('Failed to play countdown beep', e);
    }
  }

  /// Play SOS activation sound (alert/alarm)
  Future<void> playSOSActivation() async {
    if (_isPlaying) return;
    _isPlaying = true;

    try {
      // Use system alert sound multiple times for attention
      for (int i = 0; i < 3; i++) {
        await SystemSound.play(SystemSoundType.alert);
        await Future.delayed(const Duration(milliseconds: 300));
      }
      Logger.info('🔊 SOS activation sound played');
    } catch (e) {
      Logger.error('Failed to play SOS activation sound', e);
    } finally {
      _isPlaying = false;
    }
  }

  /// Play safe confirmation sound
  Future<void> playSafeConfirmation() async {
    try {
      await SystemSound.play(SystemSoundType.click);
      await Future.delayed(const Duration(milliseconds: 100));
      await SystemSound.play(SystemSoundType.click);
      Logger.info('🔊 Safe confirmation sound played');
    } catch (e) {
      Logger.error('Failed to play safe confirmation sound', e);
    }
  }

  /// Stop any playing sounds
  void stop() {
    _isPlaying = false;
  }
}
