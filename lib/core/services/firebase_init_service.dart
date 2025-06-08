/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'package:guardian/core/utils/logger.dart';
import 'package:guardian/core/services/mock_data_service.dart';
import 'package:guardian/core/services/mock_auth_service.dart';

/// A mock service for initializing backend services
class FirebaseInitService {
  static bool _initialized = false;

  /// Initialize mock services
  static Future<bool> initializeFirebase() async {
    if (_initialized) {
      Logger.info('Mock services already initialized');
      return true;
    }

    try {
      // Initialize mock data service
      await MockDataService.initialize();

      // Initialize mock auth service
      await MockAuthService.initialize();

      _initialized = true;
      Logger.info('Mock services initialized successfully');
      return true;
    } catch (e) {
      Logger.error('Error initializing mock services', e);
      return false;
    }
  }

  /// Get FCM token (mock implementation)
  static Future<String?> getFCMToken() async {
    return 'mock-fcm-token-${DateTime.now().millisecondsSinceEpoch}';
  }
}
