/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:guardian/core/utils/logger.dart';

/// A mock analytics observer for navigation tracking
class AnalyticsObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    if (route.settings.name != null) {
      AnalyticsService.logScreenView(screenName: route.settings.name!);
    }
  }
}

/// A service for tracking app analytics without Firebase
class AnalyticsService {
  static bool _initialized = false;
  static bool _enabled = true;
  static AnalyticsObserver? _observer;
  static final List<Map<String, dynamic>> _events = [];

  /// Get analytics observer
  static AnalyticsObserver? get observer => _observer;

  /// Check if analytics is enabled
  static bool get isEnabled => _enabled;

  /// Get all logged events (for debugging)
  static List<Map<String, dynamic>> get events => _events;

  /// Initialize analytics service
  static Future<void> init() async {
    if (_initialized) return;

    try {
      _observer = AnalyticsObserver();
      _initialized = true;
      Logger.info('Analytics service initialized');
    } catch (e) {
      Logger.error('Error initializing analytics service', e);
    }
  }

  /// Enable analytics
  static void enable() {
    _enabled = true;
    Logger.info('Analytics enabled');
  }

  /// Disable analytics
  static void disable() {
    _enabled = false;
    Logger.info('Analytics disabled');
  }

  /// Log a custom event
  static Future<void> logEvent({
    required String name,
    Map<String, dynamic>? parameters,
  }) async {
    if (!_initialized || !_enabled) return;

    try {
      final event = {
        'name': name,
        'parameters': parameters,
        'timestamp': DateTime.now().toIso8601String(),
      };

      _events.add(event);

      if (kDebugMode) {
        Logger.info('Analytics event logged: $name');
        if (parameters != null) {
          Logger.info('Parameters: $parameters');
        }
      }
    } catch (e) {
      Logger.error('Error logging analytics event', e);
    }
  }

  /// Log screen view
  static Future<void> logScreenView({
    required String screenName,
    String? screenClass,
  }) async {
    if (!_initialized || !_enabled) return;

    try {
      final event = {
        'name': 'screen_view',
        'parameters': {
          'screen_name': screenName,
          'screen_class': screenClass,
        },
        'timestamp': DateTime.now().toIso8601String(),
      };

      _events.add(event);

      if (kDebugMode) {
        Logger.info('Screen view logged: $screenName');
      }
    } catch (e) {
      Logger.error('Error logging screen view', e);
    }
  }

  /// Log user login
  static Future<void> logLogin({String? method}) async {
    if (!_initialized || !_enabled) return;

    try {
      final event = {
        'name': 'login',
        'parameters': {
          'method': method ?? 'email',
        },
        'timestamp': DateTime.now().toIso8601String(),
      };

      _events.add(event);

      if (kDebugMode) {
        Logger.info('Login logged with method: ${method ?? 'email'}');
      }
    } catch (e) {
      Logger.error('Error logging login', e);
    }
  }

  /// Log user signup
  static Future<void> logSignUp({String? method}) async {
    if (!_initialized || !_enabled) return;

    try {
      final event = {
        'name': 'sign_up',
        'parameters': {
          'method': method ?? 'email',
        },
        'timestamp': DateTime.now().toIso8601String(),
      };

      _events.add(event);

      if (kDebugMode) {
        Logger.info('Sign up logged with method: ${method ?? 'email'}');
      }
    } catch (e) {
      Logger.error('Error logging sign up', e);
    }
  }

  /// Log emergency alert
  static Future<void> logEmergencyAlert({
    required String alertId,
    required String triggerMethod,
    Map<String, dynamic>? additionalData,
  }) async {
    if (!_initialized || !_enabled) return;

    try {
      final parameters = <String, dynamic>{
        'alert_id': alertId,
        'trigger_method': triggerMethod,
      };

      if (additionalData != null) {
        parameters.addAll(additionalData);
      }

      final event = {
        'name': 'emergency_alert',
        'parameters': parameters,
        'timestamp': DateTime.now().toIso8601String(),
      };

      _events.add(event);

      if (kDebugMode) {
        Logger.info('Emergency alert logged: $alertId');
        Logger.info('Trigger method: $triggerMethod');
      }
    } catch (e) {
      Logger.error('Error logging emergency alert', e);
    }
  }

  /// Log incident report
  static Future<void> logIncidentReport({
    required String incidentId,
    required String category,
    required bool isAnonymous,
    Map<String, dynamic>? additionalData,
  }) async {
    if (!_initialized || !_enabled) return;

    try {
      final parameters = <String, dynamic>{
        'incident_id': incidentId,
        'category': category,
        'is_anonymous': isAnonymous,
      };

      if (additionalData != null) {
        parameters.addAll(additionalData);
      }

      final event = {
        'name': 'incident_report',
        'parameters': parameters,
        'timestamp': DateTime.now().toIso8601String(),
      };

      _events.add(event);

      if (kDebugMode) {
        Logger.info('Incident report logged: $incidentId');
        Logger.info('Category: $category, Anonymous: $isAnonymous');
      }
    } catch (e) {
      Logger.error('Error logging incident report', e);
    }
  }

  /// Set user ID
  static Future<void> setUserId(String userId) async {
    if (!_initialized || !_enabled) return;

    try {
      if (kDebugMode) {
        Logger.info('User ID set: $userId');
      }
    } catch (e) {
      Logger.error('Error setting user ID', e);
    }
  }

  /// Set user property
  static Future<void> setUserProperty({
    required String name,
    required String value,
  }) async {
    if (!_initialized || !_enabled) return;

    try {
      if (kDebugMode) {
        Logger.info('User property set: $name = $value');
      }
    } catch (e) {
      Logger.error('Error setting user property', e);
    }
  }

  /// Clear all events (for testing)
  static void clearEvents() {
    _events.clear();
    Logger.info('Analytics events cleared');
  }
}
