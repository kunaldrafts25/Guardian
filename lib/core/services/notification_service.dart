import 'package:guardian/core/models/user_model.dart';
import 'package:guardian/core/services/aws_auth_service.dart';
import 'package:guardian/core/services/aws_sns_service.dart';
import 'package:guardian/core/utils/logger.dart';

class NotificationResult {
  final bool success;
  final int sentCount;
  final String? error;

  const NotificationResult({
    required this.success,
    required this.sentCount,
    this.error,
  });

  static NotificationResult fail(String error) =>
      NotificationResult(success: false, sentCount: 0, error: error);
}

enum NotificationType {
  sosAlert,
  sosResolved,
  safeArrival,
  checkInReminder,
  exitSafeZone,
}

class NotificationService {
  static Future<bool> requestPermissions() async {
    try {
      await AwsSnsService.initialize();
      return AwsSnsService.deviceToken != null;
    } catch (error) {
      Logger.error('Notification initialization failed', error);
      return false;
    }
  }

  static Future<String?> getFcmToken() async => AwsSnsService.deviceToken;

  static Future<NotificationResult> _notifyContacts(
    String type, {
    int? minutesOverdue,
    String? zoneName,
  }) async {
    try {
      final response = await AwsAuthService.instance.post(
        '/notifications/contacts',
        {
          'notification_type': type,
          if (minutesOverdue != null) 'minutes_overdue': minutesOverdue,
          if (zoneName != null) 'zone_name': zoneName,
        },
      );
      final sent = (response['sent_count'] as num?)?.toInt() ?? 0;
      final success = response['success'] == true;
      return NotificationResult(
        success: success,
        sentCount: sent,
        error: success ? null : 'One or more contact notifications failed',
      );
    } catch (error) {
      Logger.error('Contact notification failed', error);
      return NotificationResult.fail(error.toString());
    }
  }

  /// SOS delivery is owned by the incident pipeline and native SMS transport.
  static Future<NotificationResult> sendSosAlert({
    required String userName,
    required List<EmergencyContact> contacts,
    required double latitude,
    required double longitude,
    String? customMessage,
  }) async =>
      NotificationResult.fail(
          'Use the SOS incident pipeline for emergency alerts');

  static Future<NotificationResult> sendSosResolved({
    required String userName,
    required List<EmergencyContact> contacts,
  }) =>
      _notifyContacts('sos_resolved');

  static Future<NotificationResult> sendSafeArrival({
    required String userName,
    required List<EmergencyContact> contacts,
  }) =>
      _notifyContacts('safe_arrival');

  static Future<NotificationResult> sendCheckInReminder({
    required String userName,
    required List<EmergencyContact> contacts,
    required int minutesOverdue,
  }) =>
      _notifyContacts('check_in_overdue', minutesOverdue: minutesOverdue);

  static Future<NotificationResult> sendExitSafeZone({
    required String userName,
    required String zoneName,
    required EmergencyContact primaryContact,
  }) =>
      _notifyContacts('safe_zone_exit', zoneName: zoneName);

  static String get currentUserName =>
      AwsAuthService.instance.currentUser?.displayName ??
      AwsAuthService.instance.currentPhone ??
      'Guardian User';
}
