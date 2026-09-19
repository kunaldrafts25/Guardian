/*
 * Guardian 2.0 - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * 
 * Settings Provider - Theme and Locale
 */

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:guardian/core/models/user_model.dart';

// Keys for SharedPreferences
const _themeModeKey = 'theme_mode';
const _localeKey = 'locale';
const _locationModeKey = 'location_mode';

// LocationMode is imported from user_model.dart

/// Shared preferences provider
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Initialize in main.dart');
});

/// Theme mode state
final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.system) {
    _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final themeIndex = prefs.getInt(_themeModeKey) ?? 0;
    state = ThemeMode.values[themeIndex];
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeModeKey, mode.index);
  }
}

/// Locale state
final localeProvider = StateNotifierProvider<LocaleNotifier, Locale>((ref) {
  return LocaleNotifier();
});

class LocaleNotifier extends StateNotifier<Locale> {
  LocaleNotifier() : super(const Locale('en', 'US')) {
    _loadLocale();
  }

  Future<void> _loadLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final localeString = prefs.getString(_localeKey);
    if (localeString != null) {
      final parts = localeString.split('_');
      state = Locale(parts[0], parts.length > 1 ? parts[1] : null);
    }
  }

  Future<void> setLocale(Locale locale) async {
    state = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _localeKey, '${locale.languageCode}_${locale.countryCode ?? ''}');
  }
}

/// Location mode state
final locationModeProvider =
    StateNotifierProvider<LocationModeNotifier, LocationMode>((ref) {
  return LocationModeNotifier();
});

class LocationModeNotifier extends StateNotifier<LocationMode> {
  LocationModeNotifier() : super(LocationMode.smart) {
    _loadLocationMode();
  }

  Future<void> _loadLocationMode() async {
    final prefs = await SharedPreferences.getInstance();
    final modeIndex = prefs.getInt(_locationModeKey) ?? 1; // Default: smart
    state = LocationMode.values[modeIndex];
  }

  Future<void> setLocationMode(LocationMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_locationModeKey, mode.index);
  }
}
