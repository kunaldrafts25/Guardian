/*
 * Guardian 2.0 - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * 
 * FCM Service - Firebase Cloud Messaging for push notifications
 */

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:guardian/core/utils/logger.dart';

// Notification route constants — matches app_router.dart route names
const String _kEmergencyRoute = '/emergency';
const String _kDashboardRoute = '/dashboard';

/// FCM Service for push notifications
class FcmService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static String? _fcmToken;
  static String? get fcmToken => _fcmToken;

  /// Navigator key — set this from main.dart or app.dart
  /// so FCM can navigate without a BuildContext.
  static GlobalKey<NavigatorState>? navigatorKey;

  /// Initialize FCM
  static Future<void> initialize() async {
    try {
      // Request permission
      final settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: true,
        provisional: false,
        sound: true,
      );

      Logger.info('🔔 FCM permission: ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        
        // Get FCM token
        _fcmToken = await _messaging.getToken();
        Logger.info('🔔 FCM Token: ${_fcmToken?.substring(0, 20)}...');

        // Save token to Firestore
        await _saveTokenToFirestore(_fcmToken);

        // Listen for token refresh
        _messaging.onTokenRefresh.listen((token) async {
          _fcmToken = token;
          await _saveTokenToFirestore(token);
          Logger.info('🔔 FCM Token refreshed');
        });

        // Initialize local notifications for foreground
        await _initializeLocalNotifications();

        // Handle foreground messages
        FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

        // Handle notification tap when app is in background
        FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

        // Check for initial message (app opened from terminated state)
        final initialMessage = await _messaging.getInitialMessage();
        if (initialMessage != null) {
          _handleNotificationTap(initialMessage);
        }
      }
    } catch (e) {
      Logger.error('🔔 FCM initialization error', e);
    }
  }

  /// Save FCM token to Firestore for the current user
  static Future<void> _saveTokenToFirestore(String? token) async {
    if (token == null) return;
    
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'fcmTokens': FieldValue.arrayUnion([token]),
        'lastTokenUpdate': FieldValue.serverTimestamp(),
      });
      Logger.info('🔔 FCM token saved to Firestore');
    } catch (e) {
      // User document might not exist yet
      Logger.warning('🔔 Could not save FCM token: $e');
    }
  }

  /// Initialize local notifications for foreground display
  static Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        Logger.info('🔔 Local notification tapped: ${response.payload}');
      },
    );

    // Create Android notification channel
    if (!kIsWeb && Platform.isAndroid) {
      const channel = AndroidNotificationChannel(
        'guardian_sos',
        'SOS Alerts',
        description: 'Emergency SOS notifications',
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

  /// Handle foreground messages
  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    Logger.info('🔔 Foreground message: ${message.notification?.title}');

    final notification = message.notification;
    final android = message.notification?.android;

    if (notification != null) {
      await _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'guardian_sos',
            'SOS Alerts',
            channelDescription: 'Emergency SOS notifications',
            importance: Importance.max,
            priority: Priority.high,
            icon: android?.smallIcon ?? '@mipmap/ic_launcher',
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: message.data['type'],
      );
    }
  }

  /// Handle notification tap — navigates to the correct screen
  static void _handleNotificationTap(RemoteMessage message) {
    final type = message.data['type'];
    final alertId = message.data['alertId'] as String?;

    Logger.info('🔔 Notification tapped: type=$type');

    switch (type) {
      case 'sos':
      case 'sos_alert':
        // Navigate to emergency screen, passing the alert ID if available
        _navigateTo(_kEmergencyRoute, extra: alertId);
        break;
      case 'sos_resolved':
        // Navigate to dashboard and show "contact is safe" banner
        _navigateTo(_kDashboardRoute);
        break;
      case 'check_in':
        _navigateTo('/check-in');
        break;
      default:
        Logger.warning('🔔 Unhandled notification type: $type');
        _navigateTo(_kDashboardRoute);
    }
  }

  /// Navigate using the navigator key (works from static/background context)
  static void _navigateTo(String route, {Object? extra}) {
    final navigator = navigatorKey?.currentState;
    if (navigator == null) {
      Logger.warning('Cannot navigate: navigatorKey not set in FcmService');
      return;
    }
    navigator.pushNamed(route, arguments: extra);
  }

  /// Send push notification to a user's devices
  /// Note: In production, this should be done via Cloud Functions
  /// This is a placeholder that shows what data to send
  static Map<String, dynamic> buildNotificationPayload({
    required String title,
    required String body,
    required String type,
    Map<String, String>? data,
  }) {
    return {
      'notification': {
        'title': title,
        'body': body,
      },
      'data': {
        'type': type,
        ...?data,
      },
    };
  }

  /// Subscribe to topic for broadcast notifications
  static Future<void> subscribeToTopic(String topic) async {
    await _messaging.subscribeToTopic(topic);
    Logger.info('🔔 Subscribed to topic: $topic');
  }

  /// Unsubscribe from topic
  static Future<void> unsubscribeFromTopic(String topic) async {
    await _messaging.unsubscribeFromTopic(topic);
    Logger.info('🔔 Unsubscribed from topic: $topic');
  }
}
