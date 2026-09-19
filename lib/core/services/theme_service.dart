/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:guardian/core/constants/app_theme.dart';
import 'package:guardian/core/utils/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Theme mode enum
enum ThemeMode {
  system,
  light,
  dark,
}

/// A service for managing app theme
class ThemeService extends ChangeNotifier {
  static const String _themeKey = 'theme_mode';

  ThemeMode _themeMode = ThemeMode.system;

  /// Get current theme mode
  ThemeMode get themeMode => _themeMode;

  /// Get current theme data
  ThemeData get themeData {
    if (_themeMode == ThemeMode.dark ||
        (_themeMode == ThemeMode.system && _isDarkMode)) {
      return AppTheme.darkTheme;
    } else {
      return AppTheme.lightTheme;
    }
  }

  /// Check if dark mode is enabled
  bool get isDarkMode {
    if (_themeMode == ThemeMode.system) {
      return _isDarkMode;
    }
    return _themeMode == ThemeMode.dark;
  }

  /// Check if system is in dark mode
  bool get _isDarkMode {
    final brightness =
        SchedulerBinding.instance.platformDispatcher.platformBrightness;
    return brightness == Brightness.dark;
  }

  /// Initialize theme service
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeModeIndex = prefs.getInt(_themeKey);

      if (themeModeIndex != null &&
          themeModeIndex >= 0 &&
          themeModeIndex < ThemeMode.values.length) {
        _themeMode = ThemeMode.values[themeModeIndex];
      }

      Logger.info('Theme initialized: $_themeMode');
    } catch (e) {
      Logger.error('Error initializing theme', e);
    }
  }

  /// Set theme mode
  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;

    try {
      _themeMode = mode;
      notifyListeners();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_themeKey, mode.index);

      Logger.info('Theme changed to: $mode');
    } catch (e) {
      Logger.error('Error setting theme mode', e);
    }
  }

  /// Toggle between light and dark mode
  Future<void> toggleTheme() async {
    if (_themeMode == ThemeMode.light) {
      await setThemeMode(ThemeMode.dark);
    } else {
      await setThemeMode(ThemeMode.light);
    }
  }
}
