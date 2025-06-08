/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'dart:io' show Platform;

/// A utility class for managing API keys
class ApiKeys {
  /// Google Maps API key for Android
  static const String googleMapsAndroid = 'AIzaSyDGqK9Iy_hWEPd_Gv0nnUQqP9xBXHwj1Oc';

  /// Google Maps API key for iOS
  static const String googleMapsIOS = 'AIzaSyDGqK9Iy_hWEPd_Gv0nnUQqP9xBXHwj1Oc';

  /// Get the appropriate Google Maps API key based on platform
  static String get googleMaps {
    if (Platform.isAndroid) {
      return googleMapsAndroid;
    } else if (Platform.isIOS) {
      return googleMapsIOS;
    } else {
      return googleMapsAndroid; // Default to Android key
    }
  }
}
