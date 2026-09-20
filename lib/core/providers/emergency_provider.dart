/*
 * Guardian 2.0 - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * 
 * Emergency Provider - Riverpod state management for SOS
 */

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value;
import 'package:geolocator/geolocator.dart';
import 'package:guardian/core/database/guardian_database.dart';
import 'package:guardian/core/models/emergency_domain.dart';
import 'package:guardian/core/models/emergency_model.dart';
import 'package:guardian/core/providers/auth_provider.dart';
import 'package:guardian/core/providers/aws_incident_provider.dart';
import 'package:guardian/core/providers/contacts_provider.dart';
import 'package:guardian/core/providers/sos_settings_provider.dart';
import 'package:guardian/core/services/aws_auth_service.dart';
import 'package:guardian/core/services/aws_incident_service.dart';
import 'package:guardian/core/services/sos_service.dart';
import 'package:guardian/core/utils/location_utils.dart';
import 'package:guardian/core/utils/logger.dart';

/// Emergency state for the SOS system
enum SosState {
  idle, // No emergency
  countdown, // Countdown before trigger
  triggering, // Triggering emergency
  active, // Emergency is active
  responding, // Guardians responding
  resolving, // Resolving emergency
  error, // Error state
}

/// Emergency state holder
class EmergencyState {
  final SosState state;
  final Emergency? activeEmergency;
  final int countdownSeconds;
  final String? errorMessage;
  final List<String> notifiedContacts;
  final Position? currentLocation;
  final SosAlert? sosAlert;

  const EmergencyState({
    this.state = SosState.idle,
    this.activeEmergency,
    this.countdownSeconds = 0,
    this.errorMessage,
    this.notifiedContacts = const [],
    this.currentLocation,
    this.sosAlert,
  });

  EmergencyState copyWith({
    SosState? state,
    Emergency? activeEmergency,
    int? countdownSeconds,
    String? errorMessage,
    List<String>? notifiedContacts,
    Position? currentLocation,
    SosAlert? sosAlert,
  }) {
    return EmergencyState(
      state: state ?? this.state,
      activeEmergency: activeEmergency ?? this.activeEmergency,
      countdownSeconds: countdownSeconds ?? this.countdownSeconds,
      errorMessage: errorMessage,
      notifiedContacts: notifiedContacts ?? this.notifiedContacts,
      currentLocation: currentLocation ?? this.currentLocation,
      sosAlert: sosAlert ?? this.sosAlert,
    );
  }

  bool get isActive => state == SosState.active || state == SosState.responding;

  /// Get location link for sharing
  String? get locationLink => sosAlert?.locationLink;
}

/// Emergency state notifier
class EmergencyNotifier extends StateNotifier<EmergencyState> {
  final Ref _ref;
  final SosService _sosService = SosService.instance;
  String? _backendIncidentId;
  Future<void>? _activationInFlight;
  late final Future<void> ready;

  EmergencyNotifier(this._ref) : super(const EmergencyState()) {
    // Listen to SOS service updates
    _sosService.addAlertListener(_onAlertUpdate);
    _sosService.addLocationListener(_onLocationUpdate);
    ready = _restoreActiveIncident();
  }

  Future<void> _restoreActiveIncident() async {
    final userId = AwsAuthService.instance.currentUserId;
    if (userId == null) return;
    await _ref.read(contactsProvider.notifier).ready;
    final database = _ref.read(databaseProvider);
    final alert = await database.getActiveAlert(userId);
    if (alert == null || !mounted) return;

    final contacts = _ref.read(contactsProvider).contacts;
    final attempts = await database.getDeliveryAttempts(alert.alertId);
    final attemptsByRecipient = {
      for (final attempt in attempts) attempt.recipientRef: attempt,
    };
    final position = alert.latitude != null && alert.longitude != null
        ? Position(
            latitude: alert.latitude!,
            longitude: alert.longitude!,
            accuracy: alert.accuracy ?? 0,
            altitude: 0,
            heading: 0,
            speed: 0,
            speedAccuracy: 0,
            altitudeAccuracy: 0,
            headingAccuracy: 0,
            timestamp: alert.startedAt,
          )
        : null;
    final restoredAlert = SosAlert(
      id: alert.alertId,
      source: _sourceFromStoredValue(alert.source),
      status: SosAlertStatus.active,
      startedAt: alert.startedAt,
      initialLocation: position,
      currentLocation: position,
      customMessage: alert.customMessage,
      contactStatuses: contacts.map((contact) {
        final attempt = attemptsByRecipient[contact.id];
        final accepted = attempt != null &&
            const {'accepted', 'delivered', 'acknowledged'}
                .contains(attempt.status);
        return ContactAlertStatus(
          contact: contact,
          smsSent: accepted,
          sentAt: accepted ? attempt.updatedAt : null,
          error: attempt?.failureCode,
        );
      }).toList(),
    );
    _backendIncidentId = alert.cloudIncidentId;
    _sosService.restoreActiveAlert(restoredAlert);
    state = EmergencyState(
      state: SosState.active,
      activeEmergency: Emergency(
        id: alert.cloudIncidentId ?? alert.alertId,
        userId: alert.userId,
        status: EmergencyStatus.active,
        latitude: alert.latitude,
        longitude: alert.longitude,
        startedAt: alert.startedAt,
        notifiedContacts: restoredAlert.contactStatuses
            .where((status) => status.smsSent)
            .map((status) => status.contact.phone)
            .toList(),
      ),
      sosAlert: restoredAlert,
      currentLocation: position,
      notifiedContacts: restoredAlert.contactStatuses
          .where((status) => status.smsSent)
          .map((status) => status.contact.name)
          .toList(),
    );
    Logger.info(
        'Restored active emergency ${alert.alertId} from local storage');
  }

  SosTriggerSource _sourceFromStoredValue(String value) => switch (value) {
        'hardware_power_panic' => SosTriggerSource.hardwarePower,
        'shake_sos' => SosTriggerSource.shake,
        'voice_sos' => SosTriggerSource.voiceCommand,
        'check_in_expired' => SosTriggerSource.scheduled,
        _ => SosTriggerSource.button,
      };

  @override
  void dispose() {
    _sosService.removeAlertListener(_onAlertUpdate);
    _sosService.removeLocationListener(_onLocationUpdate);
    super.dispose();
  }

  /// Handle SOS alert updates
  void _onAlertUpdate(SosAlert alert) {
    state = state.copyWith(
      sosAlert: alert,
      currentLocation: alert.currentLocation,
      notifiedContacts: alert.contactStatuses
          .where((c) => c.smsSent)
          .map((c) => c.contact.name)
          .toList(),
    );
  }

  /// Handle location updates
  void _onLocationUpdate(Position position) {
    state = state.copyWith(currentLocation: position);
  }

  Future<String?> _persistAndIngestAlert({
    required SosAlert alert,
    required String userId,
    required String eventType,
    required Map<String, dynamic> motionData,
  }) async {
    final location = alert.currentLocation ?? alert.initialLocation;
    final database = _ref.read(databaseProvider);
    final acceptedLocalDispatches =
        alert.contactStatuses.where((status) => status.smsSent).length;
    final evidencedMotionData = <String, dynamic>{
      ...motionData,
      'local_sms_accepted_count': acceptedLocalDispatches,
    };
    final cloudPayload = <String, dynamic>{
      'event_type': eventType,
      if (location != null)
        'location': {
          'latitude': location.latitude,
          'longitude': location.longitude,
          'accuracy': location.accuracy,
        },
      'motion_data': evidencedMotionData,
    };
    try {
      final queued = await database.queueAlertForCloud(
        alertId: alert.id,
        eventType: eventType,
        occurredAt: alert.startedAt,
        cloudPayload: cloudPayload,
        deliveryAttempts: alert.contactStatuses.map((contactStatus) {
          final accepted = contactStatus.smsSent;
          return LocalDeliveryAttemptsCompanion.insert(
            attemptId: '${alert.id}:sms:${contactStatus.contact.id}',
            incidentId: alert.id,
            channel: 'sms',
            recipientRef: contactStatus.contact.id,
            status: accepted
                ? DeliveryState.accepted.name
                : DeliveryState.failed.name,
            failureCode: Value(accepted
                ? null
                : (contactStatus.error ?? 'sms_dispatch_failed')),
            queuedAt: alert.startedAt,
            updatedAt: DateTime.now(),
          );
        }).toList(),
        alert: LocalAlertsCompanion.insert(
          alertId: alert.id,
          userId: userId,
          source: eventType,
          status: 'active',
          latitude: Value(location?.latitude),
          longitude: Value(location?.longitude),
          accuracy: Value(location?.accuracy),
          customMessage: Value(alert.customMessage),
          startedAt: alert.startedAt,
          smsSent: Value(alert.contactStatuses.any((item) => item.smsSent)),
          smsCount:
              Value(alert.contactStatuses.where((item) => item.smsSent).length),
          syncedToCloud: const Value(false),
        ),
      );
      if (!queued) {
        throw StateError('The incident is already in a terminal state');
      }
    } catch (error) {
      Logger.error('Could not durably queue the SOS', error);
      rethrow;
    }

    try {
      final incident = await AwsIncidentService.instance.createIncident(
        eventId: alert.id,
        eventType: eventType,
        location: location != null
            ? {
                'latitude': location.latitude,
                'longitude': location.longitude,
                'accuracy': location.accuracy,
              }
            : null,
        motionData: evidencedMotionData,
      );
      final cloudIncidentId = incident['incident_id'] as String?;
      if (cloudIncidentId == null || cloudIncidentId.isEmpty) {
        throw const FormatException('Incident response has no incident_id');
      }
      await database.recordCloudIncidentCreated(
        alertId: alert.id,
        cloudIncidentId: cloudIncidentId,
      );
      await database.markOutboxSucceeded('${alert.id}:createIncident');
      _ref.read(awsIncidentProvider.notifier).startPolling(cloudIncidentId);
      await _ref.read(awsIncidentProvider.notifier).pollStatus(cloudIncidentId);
      return cloudIncidentId;
    } catch (error) {
      await database.markOutboxRetry(
        operationId: '${alert.id}:createIncident',
        previousAttemptCount: 0,
        error: error.toString(),
      );
      Logger.warning(
          'AWS incident ingestion failed; alert remains queued: $error');
      return null;
    }
  }

  /// Start countdown before triggering SOS
  void startCountdown() {
    final settings = _ref.read(sosSettingsProvider);
    state = state.copyWith(
      state: SosState.countdown,
      countdownSeconds: settings.countdownSeconds,
    );
  }

  /// Update countdown
  void updateCountdown(int seconds) {
    if (seconds <= 0) {
      triggerEmergency();
    } else {
      state = state.copyWith(countdownSeconds: seconds);
    }
  }

  /// Cancel countdown
  void cancelCountdown() {
    state = const EmergencyState();
  }

  /// Trigger the emergency with real location and SMS
  Future<void> triggerEmergency(
      {SosTriggerSource source = SosTriggerSource.button}) {
    final inFlight = _activationInFlight;
    if (inFlight != null) {
      Logger.warning('Emergency activation already in progress; joining it');
      return inFlight;
    }
    if (state.isActive) {
      Logger.warning('Emergency already active; duplicate trigger ignored');
      return Future.value();
    }
    final operation = _triggerEmergency(source);
    _activationInFlight = operation;
    return operation.whenComplete(() {
      if (identical(_activationInFlight, operation)) {
        _activationInFlight = null;
      }
    });
  }

  Future<void> _triggerEmergency(SosTriggerSource source) async {
    await ready;
    if (state.isActive) return;
    state = state.copyWith(state: SosState.triggering);

    try {
      // Never race an SOS against one-time contact restoration.
      await _ref.read(contactsProvider.notifier).ready;
      final contactsState = _ref.read(contactsProvider);
      final contacts = contactsState.contacts;

      // Get custom message from settings
      final settings = _ref.read(sosSettingsProvider);

      Logger.info('🚨 SOS TRIGGERED via ${source.name}');

      // Use the same AWS identity that the protected incident API authorizes.
      final awsAuth = AwsAuthService.instance;
      final realUid = awsAuth.currentUserId;
      if (realUid == null) {
        throw StateError('Authentication is required for SOS');
      }
      final realName = awsAuth.currentUser?.displayName ??
          awsAuth.currentPhone ??
          'Guardian';

      // Trigger SOS via the unified service
      final alert = await _sosService.triggerSos(
        contacts: contacts,
        source: source,
        customMessage:
            settings.customMessage.isNotEmpty ? settings.customMessage : null,
        userName: realName,
      );

      if (alert == null) {
        throw Exception('Failed to create SOS alert');
      }

      _backendIncidentId = await _persistAndIngestAlert(
        alert: alert,
        userId: realUid,
        eventType: _eventTypeForSource(source),
        motionData: {'trigger_source': source.name},
      );

      final emergency = Emergency(
        id: _backendIncidentId ?? alert.id,
        userId: realUid,
        status: EmergencyStatus.active,
        startedAt: alert.startedAt,
        notifiedContacts: contacts.map((c) => c.phone).toList(),
      );

      state = state.copyWith(
        state: SosState.active,
        activeEmergency: emergency,
        sosAlert: alert,
        currentLocation: alert.currentLocation,
        notifiedContacts: alert.contactStatuses
            .where((c) => c.smsSent)
            .map((c) => c.contact.name)
            .toList(),
      );

      Logger.info(
          'Emergency active. ${alert.notifiedCount}/${contacts.length} SMS dispatches accepted by the device.');

      // Auto-call emergency services if enabled
      if (settings.autoCallEmergency) {
        await _sosService.callEmergencyServices(
            number: settings.emergencyNumber);
      }
    } catch (e) {
      Logger.error('Error triggering emergency', e);
      state = state.copyWith(
        state: SosState.error,
        errorMessage: 'Failed to trigger emergency: $e',
      );
    }
  }

  /// Trigger SOS from shake detection
  Future<void> triggerFromShake() async {
    await triggerEmergency(source: SosTriggerSource.shake);
  }

  /// Trigger SOS from hardware power button 3-tap (covert panic)
  /// NO countdown — fires immediately with CRITICAL risk classification.
  /// Bypasses all verification delays to protect against active assault.
  Future<void> triggerFromHardwarePanic() {
    final inFlight = _activationInFlight;
    if (inFlight != null) {
      Logger.warning('Emergency activation already in progress; joining it');
      return inFlight;
    }
    if (state.isActive) return Future.value();
    final operation = _triggerFromHardwarePanic();
    _activationInFlight = operation;
    return operation.whenComplete(() {
      if (identical(_activationInFlight, operation)) {
        _activationInFlight = null;
      }
    });
  }

  Future<void> _triggerFromHardwarePanic() async {
    await ready;
    if (state.isActive) return;
    Logger.info(
        '🚨 HARDWARE POWER BUTTON PANIC — Immediate CRITICAL escalation');
    state = state.copyWith(state: SosState.triggering);

    try {
      await _ref.read(contactsProvider.notifier).ready;
      final contactsState = _ref.read(contactsProvider);
      final contacts = contactsState.contacts;
      final awsAuth = AwsAuthService.instance;
      final realUid = awsAuth.currentUserId;
      if (realUid == null) {
        throw StateError('Authentication is required for SOS');
      }
      final realName = awsAuth.currentUser?.displayName ??
          awsAuth.currentPhone ??
          'Guardian';

      // Trigger local SOS (SMS to contacts) — no waiting
      final alert = await _sosService.triggerSos(
        contacts: contacts,
        source: SosTriggerSource.hardwarePower,
        customMessage:
            '🚨 EMERGENCY — I need immediate help. This is a real danger alert.',
        userName: realName,
      );

      if (alert == null) {
        throw Exception('Failed to create hardware panic alert');
      }

      _backendIncidentId = await _persistAndIngestAlert(
        alert: alert,
        userId: realUid,
        eventType: 'hardware_power_panic',
        motionData: {'tap_count': 3, 'trigger': 'power_button'},
      );

      final emergency = Emergency(
        id: _backendIncidentId ?? alert.id,
        userId: realUid,
        status: EmergencyStatus.active,
        startedAt: alert.startedAt,
        notifiedContacts: contacts.map((c) => c.phone).toList(),
      );

      state = state.copyWith(
        state: SosState.active,
        activeEmergency: emergency,
        sosAlert: alert,
        currentLocation: alert.currentLocation,
        notifiedContacts: alert.contactStatuses
            .where((c) => c.smsSent)
            .map((c) => c.contact.name)
            .toList(),
      );

      Logger.info(
          'Hardware panic active. ${alert.notifiedCount} SMS dispatches accepted by the device.');
    } catch (e) {
      Logger.error('Error triggering hardware panic', e);
      state = state.copyWith(
        state: SosState.error,
        errorMessage: 'Hardware panic escalation failed: $e',
      );
    }
  }

  /// Imports an emergency already dispatched by Android while Flutter was not
  /// running. This path journals/cloud-syncs the native event and deliberately
  /// does not send SMS again.
  Future<bool> ingestNativeEmergencyEvent(Map<String, dynamic> event) async {
    await ready;
    final eventId = event['event_id'] as String?;
    if (eventId == null || eventId.isEmpty) return false;
    final database = _ref.read(databaseProvider);
    if (await database.getAlert(eventId) != null) return true;
    if (state.isActive) return false;

    final userId = AwsAuthService.instance.currentUserId;
    if (userId == null) return false;
    await _ref.read(contactsProvider.notifier).ready;
    final contacts = _ref.read(contactsProvider).contacts;
    final accepted = (event['accepted_phones'] as List? ?? const [])
        .map((value) => _normalizedPhone(value.toString()))
        .toSet();
    final failed = (event['failed_phones'] as List? ?? const [])
        .map((value) => _normalizedPhone(value.toString()))
        .toSet();
    final occurredAt = DateTime.fromMillisecondsSinceEpoch(
      (event['occurred_at_ms'] as num?)?.toInt() ??
          DateTime.now().millisecondsSinceEpoch,
    );
    final latitude = (event['latitude'] as num?)?.toDouble();
    final longitude = (event['longitude'] as num?)?.toDouble();
    final nativeSource = event['source'] as String? ?? 'hardware_power_panic';
    final isCheckIn = nativeSource.startsWith('check_in_');
    final triggerSource =
        isCheckIn ? SosTriggerSource.scheduled : SosTriggerSource.hardwarePower;
    final eventType = isCheckIn ? 'check_in_expired' : 'hardware_power_panic';
    final position = latitude != null && longitude != null
        ? Position(
            latitude: latitude,
            longitude: longitude,
            accuracy: (event['accuracy'] as num?)?.toDouble() ?? 0,
            altitude: 0,
            heading: 0,
            speed: 0,
            speedAccuracy: 0,
            altitudeAccuracy: 0,
            headingAccuracy: 0,
            timestamp: occurredAt,
          )
        : null;
    final alert = SosAlert(
      id: eventId,
      source: triggerSource,
      status: SosAlertStatus.active,
      startedAt: occurredAt,
      initialLocation: position,
      currentLocation: position,
      contactStatuses: contacts.map((contact) {
        final phone = _normalizedPhone(contact.phone);
        final wasAccepted = accepted.contains(phone);
        return ContactAlertStatus(
          contact: contact,
          smsSent: wasAccepted,
          sentAt: wasAccepted ? occurredAt : null,
          error: wasAccepted
              ? null
              : (failed.contains(phone)
                  ? 'native_sms_dispatch_failed'
                  : 'not_in_native_snapshot'),
        );
      }).toList(),
    );
    _sosService.restoreActiveAlert(alert);
    _backendIncidentId = await _persistAndIngestAlert(
      alert: alert,
      userId: userId,
      eventType: eventType,
      motionData: {
        'trigger': nativeSource,
        'native_dispatch': true,
        'snapshot_version': event['snapshot_version'],
      },
    );
    state = EmergencyState(
      state: SosState.active,
      activeEmergency: Emergency(
        id: _backendIncidentId ?? eventId,
        userId: userId,
        status: EmergencyStatus.active,
        latitude: latitude,
        longitude: longitude,
        startedAt: occurredAt,
        notifiedContacts: contacts
            .where(
                (contact) => accepted.contains(_normalizedPhone(contact.phone)))
            .map((contact) => contact.phone)
            .toList(),
      ),
      sosAlert: alert,
      currentLocation: position,
      notifiedContacts: alert.contactStatuses
          .where((status) => status.smsSent)
          .map((status) => status.contact.name)
          .toList(),
    );
    return true;
  }

  String _normalizedPhone(String phone) {
    final trimmed = phone.trim();
    final digits = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
    return trimmed.startsWith('+') ? '+$digits' : digits;
  }

  /// Add a responder
  String _eventTypeForSource(SosTriggerSource source) => switch (source) {
        SosTriggerSource.hardwarePower => 'hardware_power_panic',
        SosTriggerSource.shake => 'shake_sos',
        SosTriggerSource.voiceCommand => 'voice_sos',
        SosTriggerSource.scheduled => 'check_in_expired',
        SosTriggerSource.widget => 'widget_sos',
        SosTriggerSource.button => 'sos_button',
      };

  /// Add a responder
  void addResponder(String responderId) {
    Logger.info('🙋 Responder joined: $responderId');
    state = state.copyWith(state: SosState.responding);
  }

  /// Cancel the emergency (mark as safe)
  Future<void> cancelEmergency() async {
    state = state.copyWith(state: SosState.resolving);

    try {
      Logger.info('🚫 Emergency cancelled by user');

      final localAlertId = state.sosAlert?.id;
      if (localAlertId != null) {
        await _ref.read(databaseProvider).transitionAlertToTerminal(
              alertId: localAlertId,
              terminalState: EmergencyIncidentState.resolved,
              occurredAt: DateTime.now(),
            );
      }

      await _sosService.markAsSafe();
      if (_backendIncidentId != null && localAlertId != null) {
        try {
          await AwsIncidentService.instance.updateIncidentStatus(
            _backendIncidentId!,
            'RESOLVED',
            note: 'User marked the emergency as safe',
          );
          await _ref
              .read(databaseProvider)
              .markOutboxSucceeded('$localAlertId:update:resolved');
        } catch (error) {
          Logger.warning('Cloud resolution remains queued for retry: $error');
        }
      }
      _backendIncidentId = null;

      state = const EmergencyState();
    } catch (e) {
      Logger.error('Error cancelling emergency', e);
      state = state.copyWith(
        state: SosState.error,
        errorMessage: 'Failed to cancel emergency: $e',
      );
    }
  }

  /// Resolve the emergency (marked as safe)
  Future<void> resolveEmergency() async {
    await cancelEmergency();
  }

  /// Call emergency services
  Future<void> callEmergencyServices() async {
    final settings = _ref.read(sosSettingsProvider);
    await _sosService.callEmergencyServices(number: settings.emergencyNumber);
  }

  /// Share current location
  Future<void> shareLocation() async {
    await _sosService.shareLiveLocation();
  }

  /// Get current location
  Future<Position?> getCurrentLocation() async {
    return await LocationUtils.getCurrentPosition();
  }

  /// Reset error state
  void clearError() {
    state = state.copyWith(state: SosState.idle, errorMessage: null);
  }
}

/// Emergency provider
final emergencyProvider =
    StateNotifierProvider<EmergencyNotifier, EmergencyState>((ref) {
  ref.watch(currentUserProvider);
  return EmergencyNotifier(ref);
});

/// Is emergency active
final isEmergencyActiveProvider = Provider<bool>((ref) {
  return ref.watch(emergencyProvider).isActive;
});

/// Current location during emergency
final emergencyLocationProvider = Provider<Position?>((ref) {
  return ref.watch(emergencyProvider).currentLocation;
});

/// Location link for sharing
final emergencyLocationLinkProvider = Provider<String?>((ref) {
  return ref.watch(emergencyProvider).locationLink;
});
