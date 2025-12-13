/*
 * Guardian 2.0 - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * 
 * Notification Service - SMS and Push Notifications
 */

import 'package:guardian/core/models/user_model.dart';
import 'package:guardian/core/utils/logger.dart';

/// Notification type
enum NotificationType {
  sosAlert,
  sosResolved,
  safeArrival,
  exitSafeZone,
  checkInReminder,
  guardianRequest,
}

/// Notification result
class NotificationResult {
  final bool success;
  final int sentCount;
  final List<String> failedContacts;
  final String? errorMessage;

  const NotificationResult({
    required this.success,
    this.sentCount = 0,
    this.failedContacts = const [],
    this.errorMessage,
  });
}

/// Notification Service
/// 
/// In production, this would integrate with:
/// - Twilio for SMS
/// - Firebase Cloud Messaging (FCM) for push notifications
/// - Email services for email alerts
/// 
/// For development, notifications are logged to console.
class NotificationService {
  NotificationService._();

  /// Send SOS alert to emergency contacts
  static Future<NotificationResult> sendSosAlert({
    required String userName,
    required List<EmergencyContact> contacts,
    required double latitude,
    required double longitude,
    String? customMessage,
  }) async {
    Logger.info('🚨 SENDING SOS ALERT');
    Logger.info('   From: $userName');
    Logger.info('   Location: $latitude, $longitude');
    Logger.info('   Contacts: ${contacts.length}');

    int sentCount = 0;
    final List<String> failed = [];

    for (final contact in contacts) {
      try {
        // In production: Send via Twilio SMS + FCM Push
        await _sendSms(
          phone: contact.phone,
          message: _buildSosMessage(userName, latitude, longitude, customMessage),
        );
        await _sendPush(
          title: '🚨 SOS ALERT',
          body: '$userName needs help! Tap for location.',
          data: {
            'type': 'sos',
            'lat': latitude.toString(),
            'lng': longitude.toString(),
          },
        );
        sentCount++;
        Logger.info('   ✅ Notified: ${contact.name} (${contact.phone})');
      } catch (e) {
        failed.add(contact.name);
        Logger.error('   ❌ Failed: ${contact.name}', e);
      }
    }

    return NotificationResult(
      success: sentCount > 0,
      sentCount: sentCount,
      failedContacts: failed,
    );
  }

  /// Send safe arrival notification
  static Future<NotificationResult> sendSafeArrival({
    required String userName,
    required List<EmergencyContact> contacts,
  }) async {
    Logger.info('✅ SENDING SAFE ARRIVAL');
    Logger.info('   From: $userName');

    int sentCount = 0;

    for (final contact in contacts) {
      try {
        await _sendSms(
          phone: contact.phone,
          message: '✅ $userName has arrived safely.',
        );
        sentCount++;
        Logger.info('   ✅ Notified: ${contact.name}');
      } catch (e) {
        Logger.error('   ❌ Failed: ${contact.name}', e);
      }
    }

    return NotificationResult(success: sentCount > 0, sentCount: sentCount);
  }

  /// Send SOS resolved notification
  static Future<NotificationResult> sendSosResolved({
    required String userName,
    required List<EmergencyContact> contacts,
    String resolution = 'safe',
  }) async {
    Logger.info('✅ SENDING SOS RESOLVED');
    Logger.info('   From: $userName');
    Logger.info('   Resolution: $resolution');

    int sentCount = 0;

    for (final contact in contacts) {
      try {
        await _sendSms(
          phone: contact.phone,
          message: '✅ $userName is now safe. The emergency has been resolved.',
        );
        await _sendPush(
          title: '✅ Emergency Resolved',
          body: '$userName is safe now.',
          data: {'type': 'sos_resolved'},
        );
        sentCount++;
        Logger.info('   ✅ Notified: ${contact.name}');
      } catch (e) {
        Logger.error('   ❌ Failed: ${contact.name}', e);
      }
    }

    return NotificationResult(success: sentCount > 0, sentCount: sentCount);
  }

  /// Send exit safe zone notification
  static Future<NotificationResult> sendExitSafeZone({
    required String userName,
    required String zoneName,
    required EmergencyContact primaryContact,
  }) async {
    Logger.info('📍 SENDING EXIT SAFE ZONE ALERT');
    Logger.info('   From: $userName');
    Logger.info('   Zone: $zoneName');

    try {
      await _sendSms(
        phone: primaryContact.phone,
        message: '📍 $userName has left "$zoneName".',
      );
      Logger.info('   ✅ Notified: ${primaryContact.name}');
      return const NotificationResult(success: true, sentCount: 1);
    } catch (e) {
      Logger.error('   ❌ Failed to notify', e);
      return NotificationResult(
        success: false,
        failedContacts: [primaryContact.name],
        errorMessage: e.toString(),
      );
    }
  }

  /// Send check-in reminder
  static Future<void> sendCheckInReminder({
    required String userName,
    required List<EmergencyContact> contacts,
    required int minutesOverdue,
  }) async {
    Logger.info('⏰ SENDING CHECK-IN REMINDER');
    Logger.info('   For: $userName');
    Logger.info('   Overdue: $minutesOverdue minutes');

    for (final contact in contacts) {
      try {
        await _sendSms(
          phone: contact.phone,
          message: '⏰ $userName has not checked in and is $minutesOverdue minutes overdue. Please check on them.',
        );
        await _sendPush(
          title: '⏰ Check-In Overdue',
          body: '$userName is $minutesOverdue minutes overdue.',
          data: {'type': 'checkin_overdue'},
        );
        Logger.info('   ✅ Notified: ${contact.name}');
      } catch (e) {
        Logger.error('   ❌ Failed: ${contact.name}', e);
      }
    }
  }

  /// Build SOS message with location link
  static String _buildSosMessage(
    String userName,
    double lat,
    double lng,
    String? customMessage,
  ) {
    final locationUrl = 'https://maps.google.com/?q=$lat,$lng';
    var message = '🚨 SOS ALERT!\n'
        '$userName needs immediate help!\n'
        'Location: $locationUrl';
    
    if (customMessage != null && customMessage.isNotEmpty) {
      message += '\n\nMessage: $customMessage';
    }
    
    return message;
  }

  /// Send SMS (mock for dev, Twilio in production)
  static Future<void> _sendSms({
    required String phone,
    required String message,
  }) async {
    // DEV MODE: Log to console
    Logger.info('📱 SMS to $phone:');
    Logger.info('   $message');
    
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 100));
    
    // TODO: Production - Twilio integration
    // final response = await http.post(
    //   Uri.parse('https://api.twilio.com/...'),
    //   body: {'To': phone, 'Body': message},
    // );
  }

  /// Send Push Notification (mock for dev, FCM in production)
  static Future<void> _sendPush({
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    // DEV MODE: Log to console
    Logger.info('🔔 PUSH: $title');
    Logger.info('   $body');
    if (data != null) {
      Logger.info('   Data: $data');
    }
    
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 50));
    
    // TODO: Production - FCM integration
    // await FirebaseMessaging.instance.send(
    //   RemoteMessage(notification: RemoteNotification(title: title, body: body)),
    // );
  }

  /// Request notification permissions
  static Future<bool> requestPermissions() async {
    // TODO: Production - Request FCM permissions
    Logger.info('🔔 Notification permissions requested (dev mode: auto-granted)');
    return true;
  }

  /// Get FCM token for push notifications
  static Future<String?> getFcmToken() async {
    // TODO: Production - Get real FCM token
    Logger.info('🔔 FCM token requested (dev mode: mock token)');
    return 'dev-mode-fcm-token-${DateTime.now().millisecondsSinceEpoch}';
  }
}
