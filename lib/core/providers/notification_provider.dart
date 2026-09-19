/*
 * Guardian 2.0 - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * 
 * Notification Provider - State management for notifications
 */

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:guardian/core/models/user_model.dart';
import 'package:guardian/core/services/notification_service.dart';
import 'package:guardian/core/utils/logger.dart';

/// Notification state
class NotificationState {
  final bool permissionsGranted;
  final String? fcmToken;
  final bool isSending;
  final NotificationResult? lastResult;
  final List<NotificationLog> history;

  const NotificationState({
    this.permissionsGranted = false,
    this.fcmToken,
    this.isSending = false,
    this.lastResult,
    this.history = const [],
  });

  NotificationState copyWith({
    bool? permissionsGranted,
    String? fcmToken,
    bool? isSending,
    NotificationResult? lastResult,
    List<NotificationLog>? history,
  }) {
    return NotificationState(
      permissionsGranted: permissionsGranted ?? this.permissionsGranted,
      fcmToken: fcmToken ?? this.fcmToken,
      isSending: isSending ?? this.isSending,
      lastResult: lastResult ?? this.lastResult,
      history: history ?? this.history,
    );
  }
}

/// Notification log entry
class NotificationLog {
  final NotificationType type;
  final DateTime timestamp;
  final int contactsNotified;
  final bool success;

  const NotificationLog({
    required this.type,
    required this.timestamp,
    required this.contactsNotified,
    required this.success,
  });
}

/// Notification notifier
class NotificationNotifier extends StateNotifier<NotificationState> {
  NotificationNotifier() : super(const NotificationState()) {
    _initialize();
  }

  Future<void> _initialize() async {
    final granted = await NotificationService.requestPermissions();
    final token = await NotificationService.getFcmToken();

    state = state.copyWith(
      permissionsGranted: granted,
      fcmToken: token,
    );
  }

  /// Send SOS alert to all contacts
  Future<NotificationResult> sendSosAlert({
    required String userName,
    required List<EmergencyContact> contacts,
    required double latitude,
    required double longitude,
    String? customMessage,
  }) async {
    state = state.copyWith(isSending: true);

    final result = await NotificationService.sendSosAlert(
      userName: userName,
      contacts: contacts,
      latitude: latitude,
      longitude: longitude,
      customMessage: customMessage,
    );

    _addToHistory(NotificationType.sosAlert, result);
    state = state.copyWith(isSending: false, lastResult: result);

    return result;
  }

  /// Send SOS resolved notification
  Future<NotificationResult> sendSosResolved({
    required String userName,
    required List<EmergencyContact> contacts,
  }) async {
    state = state.copyWith(isSending: true);

    final result = await NotificationService.sendSosResolved(
      userName: userName,
      contacts: contacts,
    );

    _addToHistory(NotificationType.sosResolved, result);
    state = state.copyWith(isSending: false, lastResult: result);

    return result;
  }

  /// Send safe arrival notification
  Future<NotificationResult> sendSafeArrival({
    required String userName,
    required List<EmergencyContact> contacts,
  }) async {
    state = state.copyWith(isSending: true);

    final result = await NotificationService.sendSafeArrival(
      userName: userName,
      contacts: contacts,
    );

    _addToHistory(NotificationType.safeArrival, result);
    state = state.copyWith(isSending: false, lastResult: result);

    return result;
  }

  /// Send exit safe zone notification
  Future<NotificationResult> sendExitSafeZone({
    required String userName,
    required String zoneName,
    required EmergencyContact primaryContact,
  }) async {
    final result = await NotificationService.sendExitSafeZone(
      userName: userName,
      zoneName: zoneName,
      primaryContact: primaryContact,
    );

    _addToHistory(NotificationType.exitSafeZone, result);
    state = state.copyWith(lastResult: result);

    return result;
  }

  void _addToHistory(NotificationType type, NotificationResult result) {
    final log = NotificationLog(
      type: type,
      timestamp: DateTime.now(),
      contactsNotified: result.sentCount,
      success: result.success,
    );

    final updatedHistory = [log, ...state.history].take(50).toList();
    state = state.copyWith(history: updatedHistory);
  }

  /// Clear notification history
  void clearHistory() {
    state = state.copyWith(history: []);
    Logger.info('🔔 Notification history cleared');
  }
}

/// Notification provider
final notificationProvider =
    StateNotifierProvider<NotificationNotifier, NotificationState>((ref) {
  return NotificationNotifier();
});

/// Is sending notification provider
final isSendingNotificationProvider = Provider<bool>((ref) {
  return ref.watch(notificationProvider).isSending;
});

/// Notification history provider
final notificationHistoryProvider = Provider<List<NotificationLog>>((ref) {
  return ref.watch(notificationProvider).history;
});
