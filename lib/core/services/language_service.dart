/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:guardian/core/utils/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A service for managing app language
class LanguageService extends ChangeNotifier {
  static const String _languageKey = 'app_language';

  Locale _locale = const Locale('en', 'US');

  /// Get current locale
  Locale get locale => _locale;

  /// Get current language code
  String get languageCode => _locale.languageCode;

  /// Get current language code (alias for languageCode)
  String get currentLanguageCode => _locale.languageCode;

  /// Get current country code
  String? get countryCode => _locale.countryCode;

  /// Get supported locales
  List<Locale> get supportedLocales => [
    const Locale('en', 'US'), // English
    const Locale('hi', 'IN'), // Hindi
    const Locale('mr', 'IN'), // Marathi
    const Locale('ta', 'IN'), // Tamil
    const Locale('bn', 'IN'), // Bengali
  ];

  /// Get supported languages
  List<Language> get supportedLanguages => [
    Language(code: 'en', name: 'English', countryCode: 'US'),
    Language(code: 'hi', name: 'हिंदी', countryCode: 'IN'),
    Language(code: 'mr', name: 'मराठी', countryCode: 'IN'),
    Language(code: 'ta', name: 'தமிழ்', countryCode: 'IN'),
    Language(code: 'bn', name: 'বাংলা', countryCode: 'IN'),
  ];

  /// Initialize language service
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final languageCode = prefs.getString('${_languageKey}_code');
      final countryCode = prefs.getString('${_languageKey}_country');

      if (languageCode != null) {
        _locale = Locale(languageCode, countryCode);
      } else {
        // Use device locale if available and supported
        final deviceLocale = PlatformDispatcher.instance.locale;
        if (isSupported(deviceLocale)) {
          _locale = deviceLocale;
        }
      }

      Logger.info('Language initialized: ${_locale.languageCode}_${_locale.countryCode}');
    } catch (e) {
      Logger.error('Error initializing language', e);
    }
  }

  /// Set locale
  Future<void> setLocale(Locale locale) async {
    if (!isSupported(locale)) {
      Logger.warning('Unsupported locale: ${locale.languageCode}_${locale.countryCode}');
      return;
    }

    if (_locale == locale) return;

    try {
      _locale = locale;
      notifyListeners();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('${_languageKey}_code', locale.languageCode);
      if (locale.countryCode != null) {
        await prefs.setString('${_languageKey}_country', locale.countryCode!);
      }

      Logger.info('Language changed to: ${locale.languageCode}_${locale.countryCode}');
    } catch (e) {
      Logger.error('Error setting locale', e);
    }
  }

  /// Set language by code
  Future<void> setLanguage(String languageCode, [String? countryCode]) async {
    final locale = Locale(languageCode, countryCode);
    await setLocale(locale);
  }

  /// Check if locale is supported
  bool isSupported(Locale locale) {
    return supportedLocales.any((supportedLocale) =>
      supportedLocale.languageCode == locale.languageCode);
  }

  /// Get language name by code
  String getLanguageName(String languageCode) {
    final language = supportedLanguages.firstWhere(
      (lang) => lang.code == languageCode,
      orElse: () => Language(code: languageCode, name: languageCode),
    );
    return language.name;
  }
}

/// Language model
class Language {
  final String code;
  final String name;
  final String? countryCode;

  Language({
    required this.code,
    required this.name,
    this.countryCode,
  });
}

