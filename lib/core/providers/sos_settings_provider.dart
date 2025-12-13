/*
 * Guardian 2.0 - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * 
 * SOS Settings Provider - Configuration for SOS features
 */

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:guardian/core/utils/logger.dart';

/// SOS Settings state
class SosSettings {
  final bool shakeToSosEnabled;
  final int countdownSeconds;
  final bool soundEnabled;
  final bool vibrationEnabled;
  final String customMessage;
  final bool autoCallEmergency;
  final String emergencyNumber;

  const SosSettings({
    this.shakeToSosEnabled = true,
    this.countdownSeconds = 3,
    this.soundEnabled = true,
    this.vibrationEnabled = true,
    this.customMessage = '',
    this.autoCallEmergency = false,
    this.emergencyNumber = '112',
  });

  SosSettings copyWith({
    bool? shakeToSosEnabled,
    int? countdownSeconds,
    bool? soundEnabled,
    bool? vibrationEnabled,
    String? customMessage,
    bool? autoCallEmergency,
    String? emergencyNumber,
  }) {
    return SosSettings(
      shakeToSosEnabled: shakeToSosEnabled ?? this.shakeToSosEnabled,
      countdownSeconds: countdownSeconds ?? this.countdownSeconds,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
      customMessage: customMessage ?? this.customMessage,
      autoCallEmergency: autoCallEmergency ?? this.autoCallEmergency,
      emergencyNumber: emergencyNumber ?? this.emergencyNumber,
    );
  }

  /// Available countdown options
  static const List<int> countdownOptions = [3, 5, 10];

  /// Common emergency numbers
  static const Map<String, String> emergencyNumbers = {
    'Police (India)': '100',
    'Women Helpline (India)': '1091',
    'Emergency (India)': '112',
    'Ambulance (India)': '102',
  };
}

/// SOS Settings state notifier
class SosSettingsNotifier extends StateNotifier<SosSettings> {
  SosSettingsNotifier() : super(const SosSettings()) {
    _loadSettings();
  }

  static const String _keyShakeEnabled = 'sos_shake_enabled';
  static const String _keyCountdown = 'sos_countdown';
  static const String _keySoundEnabled = 'sos_sound_enabled';
  static const String _keyVibrationEnabled = 'sos_vibration_enabled';
  static const String _keyCustomMessage = 'sos_custom_message';
  static const String _keyAutoCall = 'sos_auto_call';
  static const String _keyEmergencyNumber = 'sos_emergency_number';

  /// Load settings from SharedPreferences
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      state = SosSettings(
        shakeToSosEnabled: prefs.getBool(_keyShakeEnabled) ?? true,
        countdownSeconds: prefs.getInt(_keyCountdown) ?? 3,
        soundEnabled: prefs.getBool(_keySoundEnabled) ?? true,
        vibrationEnabled: prefs.getBool(_keyVibrationEnabled) ?? true,
        customMessage: prefs.getString(_keyCustomMessage) ?? '',
        autoCallEmergency: prefs.getBool(_keyAutoCall) ?? false,
        emergencyNumber: prefs.getString(_keyEmergencyNumber) ?? '112',
      );
      
      Logger.info('⚙️ SOS settings loaded');
    } catch (e) {
      Logger.error('Failed to load SOS settings', e);
    }
  }

  /// Save a setting
  Future<void> _saveSetting(String key, dynamic value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      if (value is bool) {
        await prefs.setBool(key, value);
      } else if (value is int) {
        await prefs.setInt(key, value);
      } else if (value is String) {
        await prefs.setString(key, value);
      }
    } catch (e) {
      Logger.error('Failed to save setting $key', e);
    }
  }

  /// Toggle shake-to-SOS
  Future<void> setShakeToSosEnabled(bool enabled) async {
    state = state.copyWith(shakeToSosEnabled: enabled);
    await _saveSetting(_keyShakeEnabled, enabled);
    Logger.info('⚙️ Shake-to-SOS ${enabled ? "enabled" : "disabled"}');
  }

  /// Set countdown duration
  Future<void> setCountdownSeconds(int seconds) async {
    if (!SosSettings.countdownOptions.contains(seconds)) return;
    
    state = state.copyWith(countdownSeconds: seconds);
    await _saveSetting(_keyCountdown, seconds);
    Logger.info('⚙️ SOS countdown set to $seconds seconds');
  }

  /// Toggle sound
  Future<void> setSoundEnabled(bool enabled) async {
    state = state.copyWith(soundEnabled: enabled);
    await _saveSetting(_keySoundEnabled, enabled);
  }

  /// Toggle vibration
  Future<void> setVibrationEnabled(bool enabled) async {
    state = state.copyWith(vibrationEnabled: enabled);
    await _saveSetting(_keyVibrationEnabled, enabled);
  }

  /// Set custom message
  Future<void> setCustomMessage(String message) async {
    state = state.copyWith(customMessage: message);
    await _saveSetting(_keyCustomMessage, message);
    Logger.info('⚙️ Custom SOS message updated');
  }

  /// Toggle auto-call emergency
  Future<void> setAutoCallEmergency(bool enabled) async {
    state = state.copyWith(autoCallEmergency: enabled);
    await _saveSetting(_keyAutoCall, enabled);
  }

  /// Set emergency number
  Future<void> setEmergencyNumber(String number) async {
    state = state.copyWith(emergencyNumber: number);
    await _saveSetting(_keyEmergencyNumber, number);
  }

  /// Reset to defaults
  Future<void> resetToDefaults() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyShakeEnabled);
    await prefs.remove(_keyCountdown);
    await prefs.remove(_keySoundEnabled);
    await prefs.remove(_keyVibrationEnabled);
    await prefs.remove(_keyCustomMessage);
    await prefs.remove(_keyAutoCall);
    await prefs.remove(_keyEmergencyNumber);
    
    state = const SosSettings();
    Logger.info('⚙️ SOS settings reset to defaults');
  }
}

/// SOS Settings provider
final sosSettingsProvider = StateNotifierProvider<SosSettingsNotifier, SosSettings>((ref) {
  return SosSettingsNotifier();
});

/// Shake-to-SOS enabled provider
final shakeToSosEnabledProvider = Provider<bool>((ref) {
  return ref.watch(sosSettingsProvider).shakeToSosEnabled;
});

/// Countdown seconds provider
final sosCountdownSecondsProvider = Provider<int>((ref) {
  return ref.watch(sosSettingsProvider).countdownSeconds;
});
