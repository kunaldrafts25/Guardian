import 'dart:convert';
/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:guardian/core/utils/logger.dart';

class AppLocalizations {
  final Locale locale;
  Map<String, dynamic> _localizedStrings = {};

  AppLocalizations(this.locale);

  // Helper method to keep the code in the widgets concise
  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  // Static member to have a simple access to the delegate from the MaterialApp
  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  Future<bool> load() async {
    try {
      // Load the language JSON file from the "assets/translations" folder
      String jsonString =
          await rootBundle.loadString('assets/translations/${locale.languageCode}.json');
      Map<String, dynamic> jsonMap = json.decode(jsonString);

      _localizedStrings = jsonMap;
      Logger.info('Loaded translations for ${locale.languageCode}');
      return true;
    } catch (e) {
      Logger.error('Error loading translations for ${locale.languageCode}', e);
      // If the language file couldn't be loaded, use English as fallback
      if (locale.languageCode != 'en') {
        try {
          String jsonString = await rootBundle.loadString('assets/translations/en.json');
          Map<String, dynamic> jsonMap = json.decode(jsonString);
          _localizedStrings = jsonMap;
          Logger.info('Loaded fallback translations (en)');
          return true;
        } catch (e) {
          Logger.error('Error loading fallback translations', e);
          return false;
        }
      }
      return false;
    }
  }

  // This method will be called from every widget which needs a localized text
  String translate(String key) {
    List<String> keys = key.split('.');
    dynamic value = _localizedStrings;

    for (String k in keys) {
      if (value == null || value is! Map) {
        return key;
      }
      value = value[k];
    }

    return value?.toString() ?? key;
  }
}

// LocalizationsDelegate is a factory for a set of localized resources
class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    // Include all supported language codes here
    return ['en', 'hi', 'mr', 'ta', 'bn'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    // AppLocalizations class is where the JSON loading actually runs
    AppLocalizations localizations = AppLocalizations(locale);
    await localizations.load();
    return localizations;
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

// Extension method for easier access to translations
extension TranslateX on BuildContext {
  String tr(String key) {
    return AppLocalizations.of(this).translate(key);
  }
}

