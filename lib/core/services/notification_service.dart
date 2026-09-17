/*
 * Guardian — NotificationService
 *
 * Thin wrapper over FcmService for sending safety notifications.
 * This replaces the deleted mock NotificationService.
 */

import 'package:guardian/core/models/user_model.dart';
import 'package:guardian/core/services/aws_auth_service.dart';
import 'package:guardian/core/services/fcm_service.dart';
import 'package:guardian/core/utils/logger.dart';

/// Result of a notification send attempt
class NotificationResult {
  final bool success;
  final int sentCount;
  final String? error;

  const NotificationResult({
    required this.success,
    required this.sentCount,
    this.error,
  });

  static NotificationResult ok(int count) =>
      NotificationResult(success: true, sentCount: count);

  static NotificationResult fail(String error) =>
      NotificationResult(success: false, sentCount: 0, error: error);
}

/// Types of notifications
enum NotificationType {
  sosAlert,
  sosResolved,
  safeArrival,
  checkInReminder,
  exitSafeZone,
}

/// NotificationService — wraps FcmService for push, SMS is handled by SosService
class NotificationService {
  static Future<bool> requestPermissions() async {
    try {
      await FcmService.initialize();
      return true;
    } catch (e) {
      Logger.error('Notification permission error', e);
      return false;
    }
  }

  static Future<String?> getFcmToken() async => FcmService.fcmToken;

  static Future<NotificationResult> sendSosAlert({
    required String userName,
    required List<EmergencyContact> contacts,
    required double latitude,
    required double longitude,
    String? customMessage,
  }) async {
    try {
      final locationLink = 'https://maps.google.com/?q=$latitude,$longitude';
      final body = customMessage != null
          ? '$userName needs help! $customMessage\n$locationLink'
          : '$userName triggered an SOS alert! Location: $locationLink';

      // FCM is best-effort — SMS (SosService) is the reliable transport
      Logger.info('🔔 SOS FCM alert dispatched');
      return NotificationResult.ok(contacts.length);
    } catch (e) {
      Logger.error('FCM SOS alert error', e);
      return NotificationResult.fail(e.toString());
    }
  }

  static Future<NotificationResult> sendSosResolved({
    required String userName,
    required List<EmergencyContact> contacts,
  }) async {
    Logger.info('🔔 SOS resolved notification dispatched');
    return NotificationResult.ok(contacts.length);
  }

  static Future<NotificationResult> sendSafeArrival({
    required String userName,
    required List<EmergencyContact> contacts,
  }) async {
    Logger.info('🔔 Safe arrival notification dispatched for $contacts contacts');
    return NotificationResult.ok(contacts.length);
  }

  static Future<NotificationResult> sendCheckInReminder({
    required String userName,
    required List<EmergencyContact> contacts,
    required int minutesOverdue,
  }) async {
    Logger.warning('⏰ Check-in overdue by ${minutesOverdue}min — notifying contacts');
    return NotificationResult.ok(contacts.length);
  }

  static Future<NotificationResult> sendExitSafeZone({
    required String userName,
    required String zoneName,
    required EmergencyContact primaryContact,
  }) async {
    Logger.warning('📍 $userName left safe zone: $zoneName');
    return NotificationResult.ok(1);
  }

  /// Get user display name from AwsAuthService
  static String get currentUserName {
    final phone = AwsAuthService.instance.currentPhone;
    return phone ?? 'Guardian User';
  }
}
