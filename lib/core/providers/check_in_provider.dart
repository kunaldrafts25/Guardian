import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:guardian/core/database/guardian_database.dart';
import 'package:guardian/core/providers/auth_provider.dart';
import 'package:guardian/core/providers/contacts_provider.dart';
import 'package:guardian/core/providers/emergency_provider.dart';
import 'package:guardian/core/services/aws_auth_service.dart';
import 'package:guardian/core/services/notification_service.dart';
import 'package:guardian/core/services/safety_service_bridge.dart';
import 'package:guardian/core/services/sos_service.dart';
import 'package:guardian/core/utils/logger.dart';
import 'package:uuid/uuid.dart';

enum CheckInStatus { idle, active, awaitingConfirmation, escalated }

class CheckInState {
  final CheckInStatus status;
  final int? localId;
  final String? operationId;
  final DateTime? targetTime;
  final DateTime? graceDeadline;
  final Duration? remainingTime;
  final String? destination;
  final int escalationMinutes;
  final String? errorMessage;
  final bool nativeScheduled;
  final bool exactAlarm;

  const CheckInState({
    this.status = CheckInStatus.idle,
    this.localId,
    this.operationId,
    this.targetTime,
    this.graceDeadline,
    this.remainingTime,
    this.destination,
    this.escalationMinutes = 5,
    this.errorMessage,
    this.nativeScheduled = false,
    this.exactAlarm = false,
  });

  bool get isActive =>
      status == CheckInStatus.active ||
      status == CheckInStatus.awaitingConfirmation;
  bool get isOverdue =>
      status == CheckInStatus.awaitingConfirmation ||
      status == CheckInStatus.escalated;
  int get overdueMinutes => targetTime == null
      ? 0
      : DateTime.now().difference(targetTime!).inMinutes.clamp(0, 1 << 31);

  String get remainingTimeFormatted {
    final remaining = remainingTime;
    if (remaining == null) return '--:--';
    if (remaining <= Duration.zero) return 'Due now';
    final hours = remaining.inHours;
    final minutes = remaining.inMinutes % 60;
    return hours > 0 ? '${hours}h ${minutes}m' : '${remaining.inMinutes}m';
  }

  CheckInState copyWith({
    CheckInStatus? status,
    int? localId,
    String? operationId,
    DateTime? targetTime,
    DateTime? graceDeadline,
    Duration? remainingTime,
    String? destination,
    int? escalationMinutes,
    String? errorMessage,
    bool clearError = false,
    bool? nativeScheduled,
    bool? exactAlarm,
  }) =>
      CheckInState(
        status: status ?? this.status,
        localId: localId ?? this.localId,
        operationId: operationId ?? this.operationId,
        targetTime: targetTime ?? this.targetTime,
        graceDeadline: graceDeadline ?? this.graceDeadline,
        remainingTime: remainingTime ?? this.remainingTime,
        destination: destination ?? this.destination,
        escalationMinutes: escalationMinutes ?? this.escalationMinutes,
        errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
        nativeScheduled: nativeScheduled ?? this.nativeScheduled,
        exactAlarm: exactAlarm ?? this.exactAlarm,
      );
}

class CheckInNotifier extends StateNotifier<CheckInState> {
  static const _reminderNotificationId = 2001;
  static const _channelId = 'guardian_checkin';

  final Ref _ref;
  final GuardianDatabase _database;
  final String _ownerUserId;
  final FlutterLocalNotificationsPlugin _notifications;
  final Uuid _uuid;
  Timer? _deadlineTimer;
  Timer? _graceTimer;
  Timer? _countdownTimer;
  Future<void>? _escalationInFlight;
  Future<void>? _nativeActionPoll;
  DateTime? _lastNativeActionPoll;
  late final Future<void> ready;

  CheckInNotifier(
    this._ref, {
    required GuardianDatabase database,
    required String ownerUserId,
    FlutterLocalNotificationsPlugin? notifications,
    Uuid uuid = const Uuid(),
  })  : _database = database,
        _ownerUserId = ownerUserId,
        _notifications = notifications ?? FlutterLocalNotificationsPlugin(),
        _uuid = uuid,
        super(const CheckInState()) {
    ready = _initialize();
  }

  Future<void> _initialize() async {
    if (_ownerUserId.isEmpty) return;
    try {
      await _notifications.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(),
        ),
        onDidReceiveNotificationResponse: _onNotificationResponse,
      );
      final launch = await _notifications.getNotificationAppLaunchDetails();
      final row = await _database.getActiveCheckIn(_ownerUserId);
      if (!mounted || row == null) return;
      if (await _applyPendingNativeActions(row)) return;
      _restore(row);
      final response = launch?.notificationResponse;
      if (launch?.didNotificationLaunchApp == true && response != null) {
        scheduleMicrotask(() => _onNotificationResponse(response));
      }
    } catch (error, stackTrace) {
      Logger.error('Failed to restore check-in', error, stackTrace);
      if (mounted) {
        state = state.copyWith(errorMessage: 'Check-in could not be restored.');
      }
    }
  }

  Future<bool> _applyPendingNativeActions(LocalCheckIn row) async {
    final actions = await SafetyServiceBridge.getPendingCheckInActions();
    for (final action in actions) {
      if (action['operation_id'] != row.operationId ||
          action['action'] != 'safe') {
        continue;
      }
      final changed = await _database.transitionCheckIn(
        id: row.id,
        fromStatuses: const ['active', 'awaiting_confirmation'],
        status: 'arrived',
        confirmedAt: DateTime.fromMillisecondsSinceEpoch(
          (action['occurred_at_ms'] as num?)?.toInt() ??
              DateTime.now().millisecondsSinceEpoch,
        ),
      );
      if (changed) {
        await SafetyServiceBridge.acknowledgeCheckInAction(
          action['action_id'] as String,
        );
        return true;
      }
    }
    return false;
  }

  void _restore(LocalCheckIn row) {
    final graceDeadline = row.graceDeadlineAt ??
        row.scheduledAt.add(Duration(minutes: row.escalationMinutes));
    state = CheckInState(
      status: row.status == 'awaiting_confirmation'
          ? CheckInStatus.awaitingConfirmation
          : CheckInStatus.active,
      localId: row.id,
      operationId: row.operationId,
      targetTime: row.scheduledAt,
      graceDeadline: graceDeadline,
      remainingTime: row.scheduledAt.difference(DateTime.now()),
      destination: row.location,
      escalationMinutes: row.escalationMinutes,
    );
    unawaited(_scheduleNative(row.operationId, row.scheduledAt, graceDeadline));
    _evaluateAndSchedule();
  }

  Future<void> _scheduleNative(
    String operationId,
    DateTime deadline,
    DateTime graceDeadline,
  ) async {
    final result = await SafetyServiceBridge.scheduleCheckIn(
      operationId: operationId,
      deadline: deadline,
      graceDeadline: graceDeadline,
    );
    if (mounted && state.operationId == operationId) {
      state = state.copyWith(
        nativeScheduled: result.scheduled,
        exactAlarm: result.exact,
      );
    }
  }

  Future<void> startTimer({
    required Duration duration,
    String? destination,
    int escalationMinutes = 5,
  }) async {
    await ready;
    if (duration <= Duration.zero) {
      throw ArgumentError.value(duration, 'duration', 'Must be positive');
    }
    if (escalationMinutes < 1 || escalationMinutes > 60) {
      throw RangeError.range(escalationMinutes, 1, 60, 'escalationMinutes');
    }
    _cancelTimers();
    final now = DateTime.now();
    final deadline = now.add(duration);
    final graceDeadline = deadline.add(Duration(minutes: escalationMinutes));
    final operationId = _uuid.v4();
    final id = await _database.createCheckIn(LocalCheckInsCompanion.insert(
      ownerUserId: Value(_ownerUserId),
      operationId: Value(operationId),
      title: 'Guardian Check-in',
      scheduledAt: deadline,
      graceDeadlineAt: Value(graceDeadline),
      status: const Value('active'),
      escalationMinutes: Value(escalationMinutes),
      location: Value(destination),
      updatedAt: Value(now),
    ));
    if (!mounted) return;
    state = CheckInState(
      status: CheckInStatus.active,
      localId: id,
      operationId: operationId,
      targetTime: deadline,
      graceDeadline: graceDeadline,
      remainingTime: duration,
      destination: destination,
      escalationMinutes: escalationMinutes,
    );
    await _scheduleNative(operationId, deadline, graceDeadline);
    _evaluateAndSchedule();
  }

  void _evaluateAndSchedule() {
    _cancelTimers();
    final now = DateTime.now();
    final deadline = state.targetTime;
    final graceDeadline = state.graceDeadline;
    if (deadline == null || graceDeadline == null) return;
    if (!now.isBefore(graceDeadline)) {
      scheduleMicrotask(_escalate);
      return;
    }
    if (!now.isBefore(deadline)) {
      scheduleMicrotask(_enterGracePeriod);
      return;
    }
    _deadlineTimer = Timer(deadline.difference(now), _enterGracePeriod);
    _startCountdown();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _updateRemaining();
    _countdownTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _updateRemaining(),
    );
  }

  void _updateRemaining() {
    final deadline = state.targetTime;
    if (!mounted || deadline == null) return;
    final remaining = deadline.difference(DateTime.now());
    state = state.copyWith(
      remainingTime: remaining.isNegative ? Duration.zero : remaining,
    );
    final now = DateTime.now();
    if (_lastNativeActionPoll == null ||
        now.difference(_lastNativeActionPoll!) >= const Duration(seconds: 5)) {
      _lastNativeActionPoll = now;
      _nativeActionPoll ??= _pollNativeSafeAction().whenComplete(() {
        _nativeActionPoll = null;
      });
    }
  }

  Future<void> _pollNativeSafeAction() async {
    final operationId = state.operationId;
    if (operationId == null) return;
    final actions = await SafetyServiceBridge.getPendingCheckInActions();
    for (final action in actions) {
      if (action['operation_id'] == operationId && action['action'] == 'safe') {
        final changed = await checkIn();
        if (changed) {
          await SafetyServiceBridge.acknowledgeCheckInAction(
            action['action_id'] as String,
          );
        }
        return;
      }
    }
  }

  Future<void> _enterGracePeriod() async {
    final id = state.localId;
    final graceDeadline = state.graceDeadline;
    if (id == null || graceDeadline == null || !mounted) return;
    if (state.status == CheckInStatus.active) {
      final changed = await _database.transitionCheckIn(
        id: id,
        fromStatuses: const ['active'],
        status: 'awaiting_confirmation',
      );
      if (!changed) return;
    }
    state = state.copyWith(
      status: CheckInStatus.awaitingConfirmation,
      remainingTime: Duration.zero,
    );
    if (!state.nativeScheduled ||
        kIsWeb ||
        defaultTargetPlatform != TargetPlatform.android) {
      await _showReminder();
    }
    final delay = graceDeadline.difference(DateTime.now());
    if (delay <= Duration.zero) {
      await _escalate();
    } else {
      _graceTimer = Timer(delay, _escalate);
    }
  }

  Future<void> _showReminder() async {
    try {
      await _notifications.show(
        _reminderNotificationId,
        'Safety check-in due',
        'Confirm you are safe within ${state.escalationMinutes} minutes or SOS will activate.',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            'Guardian Check-In',
            channelDescription: 'Safety check-in confirmations',
            importance: Importance.max,
            priority: Priority.high,
            actions: [
              AndroidNotificationAction(
                'confirm_safe',
                "I'm safe",
                cancelNotification: true,
              ),
              AndroidNotificationAction(
                'trigger_sos',
                'Need help',
                cancelNotification: true,
              ),
            ],
          ),
          iOS:
              DarwinNotificationDetails(categoryIdentifier: 'CHECKIN_CATEGORY'),
        ),
        payload: state.operationId,
      );
    } catch (error) {
      Logger.warning('Could not show check-in reminder: $error');
    }
  }

  void _onNotificationResponse(NotificationResponse response) {
    if (response.actionId == 'confirm_safe') {
      unawaited(checkIn().then((_) {}));
    } else if (response.actionId == 'trigger_sos') {
      unawaited(_escalate());
    }
  }

  Future<void> _escalate() {
    final inFlight = _escalationInFlight;
    if (inFlight != null) return inFlight;
    final operation = _performEscalation();
    _escalationInFlight = operation;
    return operation.whenComplete(() {
      if (identical(_escalationInFlight, operation)) {
        _escalationInFlight = null;
      }
    });
  }

  Future<void> _performEscalation() async {
    final id = state.localId;
    if (id == null || state.status == CheckInStatus.escalated) return;
    await _ref
        .read(emergencyProvider.notifier)
        .triggerEmergency(source: SosTriggerSource.scheduled);
    final emergency = _ref.read(emergencyProvider);
    if (!emergency.isActive || emergency.sosAlert == null) {
      state = state.copyWith(
        errorMessage:
            'Automatic SOS could not activate. Use the SOS button now.',
      );
      return;
    }
    final changed = await _database.transitionCheckIn(
      id: id,
      fromStatuses: const ['active', 'awaiting_confirmation'],
      status: 'escalated',
      escalationAlertId: emergency.sosAlert!.id,
    );
    if (changed && mounted) {
      _cancelTimers();
      await SafetyServiceBridge.cancelScheduledCheckIn();
      await _notifications.cancel(_reminderNotificationId);
      state = state.copyWith(status: CheckInStatus.escalated, clearError: true);
    }
  }

  Future<bool> checkIn() async {
    await ready;
    final id = state.localId;
    if (id == null || state.status == CheckInStatus.escalated) return false;
    final changed = await _database.transitionCheckIn(
      id: id,
      fromStatuses: const ['active', 'awaiting_confirmation'],
      status: 'arrived',
      confirmedAt: DateTime.now(),
    );
    if (!changed) return false;
    _cancelTimers();
    await SafetyServiceBridge.cancelScheduledCheckIn();
    await _notifications.cancel(_reminderNotificationId);
    state = const CheckInState();

    final contacts = _ref.read(contactsProvider).contacts;
    if (contacts.isNotEmpty) {
      final result = await NotificationService.sendSafeArrival(
        userName: NotificationService.currentUserName,
        contacts: contacts,
      );
      if (!result.success) {
        Logger.warning(
            'Safe-arrival notification was not accepted: ${result.error}');
      }
    }
    return true;
  }

  Future<void> cancelTimer() async {
    await ready;
    final id = state.localId;
    if (id != null && state.status != CheckInStatus.escalated) {
      await _database.transitionCheckIn(
        id: id,
        fromStatuses: const ['active', 'awaiting_confirmation'],
        status: 'cancelled',
      );
    }
    _cancelTimers();
    await SafetyServiceBridge.cancelScheduledCheckIn();
    await _notifications.cancel(_reminderNotificationId);
    if (mounted) state = const CheckInState();
  }

  Future<void> extendTimer(Duration extension) async {
    await ready;
    final id = state.localId;
    final currentDeadline = state.targetTime;
    if (id == null || currentDeadline == null || extension <= Duration.zero) {
      return;
    }
    final newDeadline = currentDeadline.add(extension);
    final newGrace =
        newDeadline.add(Duration(minutes: state.escalationMinutes));
    final changed = await _database.extendCheckIn(
      id: id,
      scheduledAt: newDeadline,
      graceDeadlineAt: newGrace,
    );
    if (!changed || !mounted) return;
    await _notifications.cancel(_reminderNotificationId);
    state = state.copyWith(
      status: CheckInStatus.active,
      targetTime: newDeadline,
      graceDeadline: newGrace,
      remainingTime: newDeadline.difference(DateTime.now()),
      clearError: true,
    );
    await _scheduleNative(state.operationId!, newDeadline, newGrace);
    _evaluateAndSchedule();
  }

  void _cancelTimers() {
    _deadlineTimer?.cancel();
    _graceTimer?.cancel();
    _countdownTimer?.cancel();
    _deadlineTimer = null;
    _graceTimer = null;
    _countdownTimer = null;
  }

  @override
  void dispose() {
    _cancelTimers();
    super.dispose();
  }
}

final checkInProvider =
    StateNotifierProvider<CheckInNotifier, CheckInState>((ref) {
  ref.watch(currentUserProvider);
  return CheckInNotifier(
    ref,
    database: ref.read(databaseProvider),
    ownerUserId: AwsAuthService.instance.currentUserId ?? '',
  );
});

final isCheckInActiveProvider =
    Provider<bool>((ref) => ref.watch(checkInProvider).isActive);

final isOverdueProvider =
    Provider<bool>((ref) => ref.watch(checkInProvider).isOverdue);

class CheckInPresets {
  static const durations = [
    Duration(minutes: 15),
    Duration(minutes: 30),
    Duration(minutes: 45),
    Duration(hours: 1),
    Duration(hours: 2),
  ];

  static String formatDuration(Duration duration) => duration.inHours >= 1
      ? '${duration.inHours} hour${duration.inHours > 1 ? 's' : ''}'
      : '${duration.inMinutes} min';
}
