/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

// Mock Firebase options file
// This file is used to provide mock Firebase configuration

import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:guardian/core/utils/logger.dart';

/// Mock Firebase options class
///
/// This class provides mock Firebase options for development without Firebase
class DefaultFirebaseOptions {
  // Mock method to simulate Firebase options
  static Map<String, dynamic> get currentPlatform {
    try {
      if (kIsWeb) {
        return web;
      }
      switch (defaultTargetPlatform) {
        case TargetPlatform.android:
          return android;
        case TargetPlatform.iOS:
          return ios;
        case TargetPlatform.macOS:
          return macos;
        default:
          return android;
      }
    } catch (e) {
      Logger.error('Error getting mock Firebase options', e);
      return android;
    }
  }

  // Mock Firebase configuration for Web
  static const Map<String, dynamic> web = {
    'apiKey': 'mock-api-key',
    'appId': 'mock-app-id',
    'messagingSenderId': 'mock-sender-id',
    'projectId': 'mock-project-id',
    'authDomain': 'mock-auth-domain',
    'storageBucket': 'mock-storage-bucket',
  };

  // Mock Firebase configuration for Android
  static const Map<String, dynamic> android = {
    'apiKey': 'mock-api-key',
    'appId': 'mock-app-id',
    'messagingSenderId': 'mock-sender-id',
    'projectId': 'mock-project-id',
    'storageBucket': 'mock-storage-bucket',
  };

  // Mock Firebase configuration for iOS
  static const Map<String, dynamic> ios = {
    'apiKey': 'mock-api-key',
    'appId': 'mock-app-id',
    'messagingSenderId': 'mock-sender-id',
    'projectId': 'mock-project-id',
    'storageBucket': 'mock-storage-bucket',
    'iosClientId': 'mock-ios-client-id',
    'iosBundleId': 'com.company.guardian',
  };

  // Mock Firebase configuration for macOS
  static const Map<String, dynamic> macos = {
    'apiKey': 'mock-api-key',
    'appId': 'mock-app-id',
    'messagingSenderId': 'mock-sender-id',
    'projectId': 'mock-project-id',
    'storageBucket': 'mock-storage-bucket',
    'iosClientId': 'mock-ios-client-id',
    'iosBundleId': 'com.company.guardian',
  };
}
