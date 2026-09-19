/*
 * Guardian - Women's Safety App
 * AWS Incident Riverpod State Management
 */

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:guardian/core/services/aws_incident_service.dart';
import 'package:guardian/core/utils/logger.dart';

class AwsIncidentState {
  final Map<String, dynamic>? currentIncident;
  final List<Map<String, dynamic>> timeline;
  final List<Map<String, dynamic>> nearbyResponders;
  final Map<String, dynamic>? activeMission;
  final bool isLoading;
  final String? errorMessage;
  final int verificationSecondsRemaining;

  const AwsIncidentState({
    this.currentIncident,
    this.timeline = const [],
    this.nearbyResponders = const [],
    this.activeMission,
    this.isLoading = false,
    this.errorMessage,
    this.verificationSecondsRemaining = 15,
  });

  String? get incidentId => currentIncident?['incident_id'] as String?;
  String get state => (currentIncident?['state'] as String?) ?? 'IDLE';
  String get eventType => (currentIncident?['event_type'] as String?) ?? 'None';
  String get agentDecision =>
      (currentIncident?['agent_decision'] as String?) ?? 'PENDING';
  String get agentRationale =>
      (currentIncident?['agent_rationale'] as String?) ?? '';
  double get riskScore =>
      (currentIncident?['risk_assessment']?['score'] as num?)?.toDouble() ??
      0.0;
  String get riskLevel =>
      (currentIncident?['risk_assessment']?['level'] as String?) ?? 'LOW';

  bool get isSuspected => state == 'SUSPECTED';
  bool get isVerifying => state == 'VERIFYING';
  bool get isResponding => state == 'RESPONDING';
  bool get isResolved => state == 'RESOLVED';
  bool get hasActiveIncident => currentIncident != null && !isResolved;
  bool get isCommunityDispatched =>
      agentDecision.contains('COMMUNITY') ||
      (currentIncident?['agent_rationale']?.toString().contains('community') ??
          false);

  AwsIncidentState copyWith({
    Map<String, dynamic>? currentIncident,
    List<Map<String, dynamic>>? timeline,
    List<Map<String, dynamic>>? nearbyResponders,
    Map<String, dynamic>? activeMission,
    bool? isLoading,
    String? errorMessage,
    int? verificationSecondsRemaining,
  }) {
    return AwsIncidentState(
      currentIncident: currentIncident ?? this.currentIncident,
      timeline: timeline ?? this.timeline,
      nearbyResponders: nearbyResponders ?? this.nearbyResponders,
      activeMission: activeMission ?? this.activeMission,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      verificationSecondsRemaining:
          verificationSecondsRemaining ?? this.verificationSecondsRemaining,
    );
  }
}

class AwsIncidentNotifier extends StateNotifier<AwsIncidentState> {
  final AwsIncidentService _service = AwsIncidentService.instance;
  Timer? _pollingTimer;
  Timer? _countdownTimer;

  AwsIncidentNotifier() : super(const AwsIncidentState());

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startPolling(String incidentId) {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      await pollStatus(incidentId);
    });
  }

  void _stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    state = state.copyWith(verificationSecondsRemaining: 15);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.verificationSecondsRemaining <= 1) {
        timer.cancel();
        _onCountdownExpired();
      } else {
        state = state.copyWith(
          verificationSecondsRemaining: state.verificationSecondsRemaining - 1,
        );
      }
    });
  }

  Future<void> _onCountdownExpired() async {
    final iid = state.incidentId;
    if (iid != null && state.isVerifying) {
      Logger.warning(
          '15s Verification timed out. Escalating to trusted contacts.');
      try {
        await _service.updateIncidentStatus(
          iid,
          'RESPONDING',
          actor: 'SYSTEM',
          note:
              'Verification timeout (15s elapsed without response). Escalating alert.',
        );
        await pollStatus(iid);
      } catch (e) {
        Logger.error('Failed to escalate on timeout', e);
      }
    }
  }

  /// Poll current incident & audit timeline from backend
  Future<void> pollStatus(String incidentId) async {
    try {
      final incident = await _service.getIncident(incidentId);
      final timeline = await _service.getIncidentTimeline(incidentId);

      final wasNotVerifying = !state.isVerifying;
      List<Map<String, dynamic>> responders = state.nearbyResponders;
      if (incident['state'] == 'RESPONDING' && responders.isEmpty) {
        responders = await _service.getNearbyResponders(incidentId);
      }

      state = state.copyWith(
        currentIncident: incident,
        timeline: timeline,
        nearbyResponders: responders,
      );

      // If state just changed to VERIFYING, begin 15s timer
      if (wasNotVerifying && state.isVerifying) {
        _startCountdown();
      }

      // If resolved, stop polling and countdown
      if (state.isResolved) {
        _stopPolling();
        _countdownTimer?.cancel();
      }
    } catch (e) {
      Logger.error('Error during incident poll', e);
    }
  }

  /// Query nearby Good Samaritan community responders
  Future<void> fetchNearbyResponders() async {
    final iid = state.incidentId;
    if (iid == null) return;
    try {
      final responders = await _service.getNearbyResponders(iid);
      state = state.copyWith(nearbyResponders: responders);
    } catch (e) {
      Logger.error('Failed to fetch nearby responders', e);
    }
  }

  /// Accept rescue mission as a community helper
  Future<Map<String, dynamic>?> acceptMission(
      {String responderId = 'resp_01'}) async {
    final iid = state.incidentId;
    if (iid == null) return null;
    try {
      final res = await _service.acceptMission(iid, responderId: responderId);
      state = state.copyWith(activeMission: res);
      await pollStatus(iid);
      return res;
    } catch (e) {
      Logger.error('Failed to accept rescue mission', e);
      return null;
    }
  }

  /// User confirms "I'M OK" (False alarm cancellation)

  Future<void> confirmImOk() async {
    final iid = state.incidentId;
    if (iid == null) return;

    _countdownTimer?.cancel();
    state = state.copyWith(isLoading: true);
    try {
      await _service.updateIncidentStatus(
        iid,
        'RESOLVED',
        actor: 'USER',
        note: "User tapped 'I'M OK'. Incident marked false alarm / resolved.",
      );
      await pollStatus(iid);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to confirm status: $e',
      );
    }
  }

  /// User confirms "I NEED HELP" (Immediate escalation)
  Future<void> escalateNeedHelp() async {
    final iid = state.incidentId;
    if (iid == null) return;

    _countdownTimer?.cancel();
    state = state.copyWith(isLoading: true);
    try {
      await _service.updateIncidentStatus(
        iid,
        'RESPONDING',
        actor: 'USER',
        note:
            "User confirmed emergency alert. Dispatching contacts immediately.",
      );
      await pollStatus(iid);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to escalate: $e',
      );
    }
  }

  /// Contact acknowledges alert
  Future<void> acknowledgeAlert() async {
    final iid = state.incidentId;
    if (iid == null) return;

    state = state.copyWith(isLoading: true);
    try {
      await _service.updateIncidentStatus(
        iid,
        'RESOLVED',
        actor: 'CONTACT',
        note: 'Trusted contact acknowledged emergency and arrived/called.',
      );
      await pollStatus(iid);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to acknowledge: $e',
      );
    }
  }

  /// Clear active incident from view
  void clearIncident() {
    _stopPolling();
    _countdownTimer?.cancel();
    state = const AwsIncidentState();
  }
}

final awsIncidentProvider =
    StateNotifierProvider<AwsIncidentNotifier, AwsIncidentState>((ref) {
  return AwsIncidentNotifier();
});
