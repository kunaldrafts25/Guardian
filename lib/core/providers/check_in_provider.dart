/*
 * Guardian 2.0 - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * 
 * Check-In Timer Provider - "I'll be home by X" feature
 */

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:guardian/core/providers/contacts_provider.dart';
import 'package:guardian/core/services/notification_service.dart';
import 'package:guardian/core/services/aws_auth_service.dart';
import 'package:guardian/core/utils/logger.dart';

/// Check-in timer state
class CheckInState {
  final bool isActive;
  final DateTime? targetTime;
  final Duration? remainingTime;
  final String? destination;
  final bool isOverdue;
  final int overdueMinutes;

  const CheckInState({
    this.isActive = false,
    this.targetTime,
    this.remainingTime,
    this.destination,
    this.isOverdue = false,
    this.overdueMinutes = 0,
  });

  CheckInState copyWith({
    bool? isActive,
    DateTime? targetTime,
    Duration? remainingTime,
    String? destination,
    bool? isOverdue,
    int? overdueMinutes,
  }) {
    return CheckInState(
      isActive: isActive ?? this.isActive,
      targetTime: targetTime ?? this.targetTime,
      remainingTime: remainingTime ?? this.remainingTime,
      destination: destination ?? this.destination,
      isOverdue: isOverdue ?? this.isOverdue,
      overdueMinutes: overdueMinutes ?? this.overdueMinutes,
    );
  }

  /// Format remaining time for display
  String get remainingTimeFormatted {
    if (remainingTime == null) return '--:--';

    final hours = remainingTime!.inHours;
    final minutes = remainingTime!.inMinutes % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }
}

/// Check-in timer notifier
class CheckInNotifier extends StateNotifier<CheckInState> {
  final Ref _ref;
  Timer? _timer;
  Timer? _overdueTimer;

  CheckInNotifier(this._ref) : super(const CheckInState());

  /// Start a check-in timer
  void startTimer({
    required Duration duration,
    String? destination,
  }) {
    _timer?.cancel();
    _overdueTimer?.cancel();

    final targetTime = DateTime.now().add(duration);

    state = CheckInState(
      isActive: true,
      targetTime: targetTime,
      remainingTime: duration,
      destination: destination,
      isOverdue: false,
      overdueMinutes: 0,
    );

    Logger.info('⏰ Check-in timer started: ${duration.inMinutes} minutes');
    if (destination != null) {
      Logger.info('   Destination: $destination');
    }

    // Update remaining time every minute
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      _updateRemainingTime();
    });
  }

  void _updateRemainingTime() {
    if (!state.isActive || state.targetTime == null) return;

    final now = DateTime.now();
    final remaining = state.targetTime!.difference(now);

    if (remaining.isNegative) {
      // Timer expired - user is overdue
      _handleOverdue(remaining.abs());
    } else {
      state = state.copyWith(remainingTime: remaining);
    }
  }

  void _handleOverdue(Duration overdueBy) {
    final overdueMinutes = overdueBy.inMinutes;

    state = state.copyWith(
      isOverdue: true,
      overdueMinutes: overdueMinutes,
      remainingTime: Duration.zero,
    );

    Logger.warning('⏰ CHECK-IN OVERDUE by $overdueMinutes minutes!');

    // Send notification to contacts if overdue by 5+ minutes
    if (overdueMinutes >= 5 && overdueMinutes % 5 == 0) {
      _notifyContacts(overdueMinutes);
    }
  }

  Future<void> _notifyContacts(int minutesOverdue) async {
    final contacts = _ref.read(contactsProvider).contacts;

    if (contacts.isEmpty) {
      Logger.warning('⏰ No contacts to notify about overdue check-in');
      return;
    }

    final profile = await AwsAuthService.instance.getUserProfile();
    final userName = profile?['display_name'] as String? ??
        profile?['displayName'] as String? ??
        'Guardian';
    await NotificationService.sendCheckInReminder(
      userName: userName,
      contacts: contacts,
      minutesOverdue: minutesOverdue,
    );
  }

  /// Check in (arrived safely)
  Future<void> checkIn() async {
    if (!state.isActive) return;

    _timer?.cancel();
    _overdueTimer?.cancel();

    Logger.info('✅ User checked in safely');

    // Notify contacts of safe arrival
    final contacts = _ref.read(contactsProvider).contacts;
    if (contacts.isNotEmpty) {
      final profile = await AwsAuthService.instance.getUserProfile();
      final userName = profile?['display_name'] as String? ??
          profile?['displayName'] as String? ??
          'Guardian';
      await NotificationService.sendSafeArrival(
        userName: userName,
        contacts: contacts,
      );
    }

    state = const CheckInState();
  }

  /// Cancel timer
  void cancelTimer() {
    _timer?.cancel();
    _overdueTimer?.cancel();
    state = const CheckInState();
    Logger.info('⏰ Check-in timer cancelled');
  }

  /// Extend timer by duration
  void extendTimer(Duration extension) {
    if (!state.isActive || state.targetTime == null) return;

    final newTarget = state.targetTime!.add(extension);
    final remaining = newTarget.difference(DateTime.now());

    state = state.copyWith(
      targetTime: newTarget,
      remainingTime: remaining,
      isOverdue: false,
      overdueMinutes: 0,
    );

    Logger.info('⏰ Timer extended by ${extension.inMinutes} minutes');
  }

  @override
  void dispose() {
    _timer?.cancel();
    _overdueTimer?.cancel();
    super.dispose();
  }
}

/// Check-in provider
final checkInProvider =
    StateNotifierProvider<CheckInNotifier, CheckInState>((ref) {
  return CheckInNotifier(ref);
});

/// Is check-in active provider
final isCheckInActiveProvider = Provider<bool>((ref) {
  return ref.watch(checkInProvider).isActive;
});

/// Is overdue provider
final isOverdueProvider = Provider<bool>((ref) {
  return ref.watch(checkInProvider).isOverdue;
});

/// Preset durations for check-in
class CheckInPresets {
  static const List<Duration> durations = [
    Duration(minutes: 15),
    Duration(minutes: 30),
    Duration(minutes: 45),
    Duration(hours: 1),
    Duration(hours: 2),
  ];

  static String formatDuration(Duration duration) {
    if (duration.inHours >= 1) {
      return '${duration.inHours} hour${duration.inHours > 1 ? 's' : ''}';
    }
    return '${duration.inMinutes} min';
  }
}
