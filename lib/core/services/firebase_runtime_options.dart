import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

abstract final class FirebaseRuntimeOptions {
  static const _apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const _projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const _senderId =
      String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
  static const _androidAppId =
      String.fromEnvironment('FIREBASE_ANDROID_APP_ID');
  static const _iosAppId = String.fromEnvironment('FIREBASE_IOS_APP_ID');
  static const _storageBucket =
      String.fromEnvironment('FIREBASE_STORAGE_BUCKET');
  static const _iosBundleId = String.fromEnvironment(
    'FIREBASE_IOS_BUNDLE_ID',
    defaultValue: 'com.company.guardian',
  );

  static bool get isConfigured {
    final appId =
        defaultTargetPlatform == TargetPlatform.iOS ? _iosAppId : _androidAppId;
    return _apiKey.isNotEmpty &&
        _projectId.isNotEmpty &&
        _senderId.isNotEmpty &&
        appId.isNotEmpty;
  }

  /// Initializes Firebase from explicit build-time values when supplied.
  /// Otherwise, it uses the native Android/iOS Firebase configuration.
  static Future<FirebaseApp> initialize() {
    return isConfigured
        ? Firebase.initializeApp(options: current)
        : Firebase.initializeApp();
  }

  static FirebaseOptions get current {
    if (!isConfigured) {
      throw StateError('Firebase push configuration is not available.');
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return FirebaseOptions(
        apiKey: _apiKey,
        appId: _iosAppId,
        messagingSenderId: _senderId,
        projectId: _projectId,
        storageBucket: _storageBucket.isEmpty ? null : _storageBucket,
        iosBundleId: _iosBundleId,
      );
    }
    return FirebaseOptions(
      apiKey: _apiKey,
      appId: _androidAppId,
      messagingSenderId: _senderId,
      projectId: _projectId,
      storageBucket: _storageBucket.isEmpty ? null : _storageBucket,
    );
  }
}
