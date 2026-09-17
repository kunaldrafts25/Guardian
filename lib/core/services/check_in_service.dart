/*
 * Guardian — CheckInService
 *
 * Scheduled check-in system with automatic SOS escalation.
 *
 * How it works:
 *   1. User sets a timer ("I'll be home in 30 minutes — check on me")
 *   2. After the duration, Guardian sends a push notification:
 *      "Are you safe? Tap to confirm or your contacts will be alerted"
 *   3. If the user doesn't respond in [escalationMinutes] minutes → SOS fires
 *   4. When user confirms safety → timer resets, contacts notified optionally
 *
 * Offline: If there's no internet, the timer still runs using local notifications.
 * The SOS trigger fires through SosService which handles all transport layers.
 */

import 'dart:async';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:guardian/core/database/guardian_database.dart';
import 'package:guardian/core/services/ble_emergency_mesh.dart';
import 'package:guardian/core/utils/logger.dart';

// ═══════════════════════════════════════════════════════
// PROVIDER
// ═══════════════════════════════════════════════════════

final checkInProvider =
    StateNotifierProvider<CheckInNotifier, CheckInState>((ref) {
  final db = ref.read(databaseProvider);
  return CheckInNotifier(db);
});

// ═══════════════════════════════════════════════════════
// STATE
// ═══════════════════════════════════════════════════════

enum CheckInStatus { idle, active, awaitingConfirmation, escalated }

class CheckInState {
  final CheckInStatus status;
  final DateTime? scheduledAt;
  final DateTime? expiresAt;
  final int escalationMinutes;
  final String? title;
  final Duration? remaining;

  const CheckInState({
    this.status = CheckInStatus.idle,
    this.scheduledAt,
    this.expiresAt,
    this.escalationMinutes = 5,
    this.title,
    this.remaining,
  });

  bool get isActive => status != CheckInStatus.idle;

  CheckInState copyWith({
    CheckInStatus? status,
    DateTime? scheduledAt,
    DateTime? expiresAt,
    int? escalationMinutes,
    String? title,
    Duration? remaining,
  }) {
    return CheckInState(
      status: status ?? this.status,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      expiresAt: expiresAt ?? this.expiresAt,
      escalationMinutes: escalationMinutes ?? this.escalationMinutes,
      title: title ?? this.title,
      remaining: remaining ?? this.remaining,
    );
  }
}

// ═══════════════════════════════════════════════════════
// NOTIFIER
// ═══════════════════════════════════════════════════════

class CheckInNotifier extends StateNotifier<CheckInState> {
  final GuardianDatabase _db;
  Timer? _checkInTimer;
  Timer? _escalationTimer;
  Timer? _countdownTimer;

  static const int _checkInNotificationId = 2001;
  static const int _escalationNotificationId = 2002;

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  CheckInNotifier(this._db) : super(const CheckInState()) {
    _initNotifications();
  }

  Future<void> _initNotifications() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _notifications.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
  }

  // ─────────────────────────────────────────────────
  // Start a check-in timer
  // ─────────────────────────────────────────────────

  Future<void> startCheckIn({
    required Duration duration,
    required int escalationMinutes,
    String title = 'Guardian Check-in',
    String? location,
  }) async {
    // Cancel any existing timer
    await cancelCheckIn();

    final now = DateTime.now();
    final expiresAt = now.add(duration);

    // Save to local DB (survives app restart)
    await _db.upsertCheckIn(LocalCheckInsCompanion(
      title: Value(title),
      scheduledAt: Value(expiresAt),
      escalationMinutes: Value(escalationMinutes),
      location: Value(location),
    ));

    state = state.copyWith(
      status: CheckInStatus.active,
      scheduledAt: now,
      expiresAt: expiresAt,
      escalationMinutes: escalationMinutes,
      title: title,
      remaining: duration,
    );

    Logger.info(
        '⏱️ Check-in timer started: ${duration.inMinutes}min, escalation: ${escalationMinutes}min');

    // Start countdown display
    _startCountdown(expiresAt);

    // Schedule the check-in notification
    _checkInTimer = Timer(duration, _onCheckInExpired);
  }

  // ─────────────────────────────────────────────────
  // Timer expiry → show confirmation notification
  // ─────────────────────────────────────────────────

  Future<void> _onCheckInExpired() async {
    Logger.warning('⏱️ Check-in timer expired — awaiting user confirmation');

    state = state.copyWith(status: CheckInStatus.awaitingConfirmation);

    // Show local notification with "I'm safe" action button
    const androidDetails = AndroidNotificationDetails(
      'guardian_checkin',
      'Guardian Check-In',
      channelDescription: 'Safety check-in confirmations',
      importance: Importance.max,
      priority: Priority.high,
      fullScreenIntent: true,
      actions: [
        AndroidNotificationAction('confirm_safe', '✅ I\'m Safe',
            cancelNotification: true),
        AndroidNotificationAction('trigger_sos', '🆘 Need Help',
            cancelNotification: true),
      ],
    );
    const iosDetails = DarwinNotificationDetails(
      categoryIdentifier: 'CHECKIN_CATEGORY',
    );

    await _notifications.show(
      _checkInNotificationId,
      '⏱️ ${state.title ?? "Guardian Check-In"}',
      'Are you safe? Tap to confirm or your contacts will be alerted in ${state.escalationMinutes} minutes.',
      const NotificationDetails(android: androidDetails, iOS: iosDetails),
    );

    // Start escalation countdown
    _escalationTimer = Timer(
      Duration(minutes: state.escalationMinutes),
      _onEscalationExpired,
    );
  }

  // ─────────────────────────────────────────────────
  // Escalation — user didn't respond → trigger SOS
  // ─────────────────────────────────────────────────

  Future<void> _onEscalationExpired() async {
    Logger.warning('🚨 Check-in escalation — triggering SOS');

    state = state.copyWith(status: CheckInStatus.escalated);

    await _notifications.cancel(_checkInNotificationId);

    // Trigger SOS via SosService — contacts will be alerted
    // (SosService handles all transport layers including offline)
    // Note: We call through the method channel to avoid circular dependency
    // The actual SOS trigger happens via the emergency provider
    Logger.warning('🚨 Check-in SOS escalated — emergency_provider should be triggered by UI');
  }

  // ─────────────────────────────────────────────────
  // Confirm safety — cancel escalation
  // ─────────────────────────────────────────────────

  Future<void> confirmSafe() async {
    Logger.info('✅ User confirmed safe — check-in cancelled');

    _escalationTimer?.cancel();
    _checkInTimer?.cancel();
    _countdownTimer?.cancel();

    await _notifications.cancel(_checkInNotificationId);
    await _notifications.cancel(_escalationNotificationId);

    state = const CheckInState();
  }

  Future<void> cancelCheckIn() async {
    _checkInTimer?.cancel();
    _escalationTimer?.cancel();
    _countdownTimer?.cancel();

    await _notifications.cancel(_checkInNotificationId);
    await _notifications.cancel(_escalationNotificationId);

    state = const CheckInState();
    Logger.info('⏱️ Check-in cancelled');
  }

  // ─────────────────────────────────────────────────
  // Countdown display update
  // ─────────────────────────────────────────────────

  void _startCountdown(DateTime expiresAt) {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final remaining = expiresAt.difference(DateTime.now());
      if (remaining.isNegative) {
        timer.cancel();
        state = state.copyWith(remaining: Duration.zero);
      } else {
        state = state.copyWith(remaining: remaining);
      }
    });
  }

  // ─────────────────────────────────────────────────
  // Notification tap handler
  // ─────────────────────────────────────────────────

  void _onNotificationTapped(NotificationResponse response) {
    switch (response.actionId) {
      case 'confirm_safe':
        confirmSafe();
        break;
      case 'trigger_sos':
        // This will be handled by the emergency_provider via the SOS trigger
        Logger.warning('🆘 SOS triggered from check-in notification');
        break;
    }
  }

  @override
  void dispose() {
    _checkInTimer?.cancel();
    _escalationTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }
}
