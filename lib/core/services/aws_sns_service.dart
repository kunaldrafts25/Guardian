/*
 * Guardian — AWS SNS Push Notification Service (Flutter)
 * Replaces firebase_messaging + FcmService with AWS SNS.
 *
 * Flow:
 *   1. On app launch → get device token (FCM token on Android, APNS on iOS)
 *   2. POST /users/{id}/device → backend registers with SNS → returns endpoint ARN
 *   3. When SOS fired → backend sends targeted push via SNS to all circle members
 *   4. flutter_local_notifications displays foreground notifications
 */

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:guardian/core/services/aws_auth_service.dart';
import 'package:guardian/core/utils/logger.dart';

// ─── Optional: keep FCM just for the device token (not for notification delivery)
// The token is sent to SNS which does the actual delivery.
import 'package:firebase_messaging/firebase_messaging.dart';

/// AWS SNS Notification Service — replaces FcmService
class AwsSnsService {
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static void Function(String location)? _routeHandler;
  static String? _pendingLocation;
  static String? _deviceToken;
  static String? get deviceToken => _deviceToken;

  static void configureNavigation(void Function(String location) handler) {
    _routeHandler = handler;
    final pending = _pendingLocation;
    if (pending != null && AwsAuthService.instance.isSignedIn) {
      _pendingLocation = null;
      handler(pending);
    }
  }

  /// Initialize local notification display + register device with SNS
  static Future<void> initialize() async {
    try {
      // 1. Setup local notification display
      await _setupLocalNotifications();

      // 2. Get device token (FCM on Android, APNS on iOS)
      await _fetchAndRegisterDeviceToken();

      Logger.info('AwsSnsService: initialized');
    } catch (e) {
      Logger.warning('AwsSnsService: init error (non-critical): $e');
    }
  }

  // ─── Local Notification Display ──────────────────────────────────────────

  static Future<void> _setupLocalNotifications() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _localNotifications.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Android notification channel
    if (!kIsWeb && Platform.isAndroid) {
      const channel = AndroidNotificationChannel(
        'guardian_sos',
        'Guardian SOS Alerts',
        description: 'Emergency SOS and safety notifications',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      );
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }
  }

  /// Show a local notification (for foreground display)
  static Future<void> showLocalNotification({
    required String title,
    required String body,
    String? payload,
    int id = 0,
  }) async {
    try {
      await _localNotifications.show(
        id,
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'guardian_sos',
            'Guardian SOS Alerts',
            channelDescription: 'Emergency SOS and safety notifications',
            importance: Importance.max,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: payload,
      );
    } catch (e) {
      Logger.warning('Local notification error: $e');
    }
  }

  // ─── Device Token Registration ────────────────────────────────────────────

  static Future<void> _fetchAndRegisterDeviceToken() async {
    // On web: no push token needed
    if (kIsWeb) return;

    try {
      // Request FCM/APNS permission
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        criticalAlert: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        _deviceToken = await messaging.getToken();
        Logger.info('Device push token obtained');

        // Register with AWS SNS via backend
        await _registerWithSns();

        // Listen for token refresh
        messaging.onTokenRefresh.listen((token) async {
          _deviceToken = token;
          await _registerWithSns();
          Logger.info('Device token refreshed and re-registered with SNS');
        });

        // Handle foreground FCM messages (backend still sends raw FCM via SNS)
        FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
        FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);
        final initialMessage = await messaging.getInitialMessage();
        if (initialMessage != null) {
          _handleNotificationTap(initialMessage);
        }
      }
    } catch (e) {
      // FCM init failure is not critical — SMS fallback still works
      Logger.warning('Device token error (SMS fallback active): $e');
    }
  }

  static Future<void> _registerWithSns() async {
    if (_deviceToken == null) return;
    final userId = AwsAuthService.instance.currentUserId;
    if (userId == null) return;

    final platform = Platform.isIOS ? 'ios' : 'android';
    final arn = await AwsAuthService.instance.registerDevice(
      _deviceToken!,
      platform: platform,
    );
    Logger.info(arn == null
        ? 'SNS endpoint registration unavailable'
        : 'SNS endpoint registered');
  }

  // ─── Message Handlers ─────────────────────────────────────────────────────

  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final title = message.notification?.title ?? 'Guardian';
    final body = message.notification?.body ?? '';
    final type = message.data['type'] as String? ?? '';

    // Show local notification for foreground messages
    await showLocalNotification(
      title: title,
      body: body,
      payload: jsonEncode({'type': type, ...message.data}),
      id: message.hashCode,
    );
  }

  static void _handleNotificationTap(RemoteMessage message) {
    final type = message.data['type'] as String? ?? '';
    _navigateForType(type, message.data);
  }

  static void _onNotificationTapped(NotificationResponse response) {
    final payload = response.payload ?? '';
    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map) {
        final data = Map<String, dynamic>.from(decoded);
        _navigateForType(data['type'] as String? ?? '', data);
        return;
      }
    } catch (_) {
      // Notifications created by older app versions contain only the type.
    }
    _navigateForType(payload, const {});
  }

  static void _navigateForType(String type, Map<String, dynamic> data) {
    final location = notificationLocation(type, data);
    final handler = _routeHandler;
    if (handler == null || !AwsAuthService.instance.isSignedIn) {
      _pendingLocation = location;
      return;
    }
    handler(location);
  }

  @visibleForTesting
  static String notificationLocation(
    String type,
    Map<String, dynamic> data,
  ) {
    final incidentId = data['incident_id']?.toString();
    final missionId = data['mission_id']?.toString();
    return switch (type) {
      'sos' || 'sos_alert' => incidentId == null
          ? '/emergency'
          : '/incidents/${Uri.encodeComponent(incidentId)}',
      'responder_invitation' => missionId == null
          ? '/responder/inbox'
          : '/responder/mission/${Uri.encodeComponent(missionId)}',
      'rescue_accepted' => incidentId == null
          ? '/dashboard'
          : '/incidents/${Uri.encodeComponent(incidentId)}',
      'sos_resolved' => incidentId == null
          ? '/dashboard'
          : '/incidents/${Uri.encodeComponent(incidentId)}',
      _ => '/dashboard',
    };
  }

  // ─── SNS Push Helpers (via backend) ───────────────────────────────────────
}
