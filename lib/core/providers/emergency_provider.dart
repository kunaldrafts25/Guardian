import 'dart:async';

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
import 'package:guardian/core/models/emergency_location.dart';
import 'package:guardian/core/models/sms_delivery_state.dart';
import 'package:guardian/core/models/emergency_model.dart';
import 'package:guardian/core/providers/auth_provider.dart';
import 'package:guardian/core/providers/aws_incident_provider.dart';
import 'package:guardian/core/providers/contacts_provider.dart';
import 'package:guardian/core/providers/sos_settings_provider.dart';
import 'package:guardian/core/services/aws_auth_service.dart';
import 'package:guardian/core/services/aws_incident_service.dart';
import 'package:guardian/core/services/cloud_incident_binding_service.dart';
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

/// Explicit emergency lifecycle semantics (P2 requirement 2)
enum EmergencyLifecycleStage {
  idle,
  localEmergencyActive,
  cloudQueued,
  cloudDelivering,
  cloudAcknowledged,
  contactDeliveryPending,
  responderSearching,
  responderInvited,
  responderAccepted,
  responderEnRoute,
  responderArrived,
  resolved,
  failedOrPartial,
}

/// Emergency state holder
class EmergencyState {
  final SosState state;
  final EmergencyLifecycleStage lifecycleStage;
  final Emergency? activeEmergency;
  final int countdownSeconds;
  final String? errorMessage;
  final List<String> dispatchedContacts;
  final Position? currentLocation;
  final SosAlert? sosAlert;

  const EmergencyState({
    this.state = SosState.idle,
    this.lifecycleStage = EmergencyLifecycleStage.idle,
    this.activeEmergency,
    this.countdownSeconds = 0,
    this.errorMessage,
    List<String>? dispatchedContacts,
    List<String>? notifiedContacts,
    this.currentLocation,
    this.sosAlert,
  }) : dispatchedContacts = dispatchedContacts ?? notifiedContacts ?? const [];

  @Deprecated('Use dispatchedContacts instead')
  List<String> get notifiedContacts => dispatchedContacts;

  EmergencyState copyWith({
    SosState? state,
    EmergencyLifecycleStage? lifecycleStage,
    Emergency? activeEmergency,
    int? countdownSeconds,
    String? errorMessage,
    List<String>? dispatchedContacts,
    List<String>? notifiedContacts,
    Position? currentLocation,
    SosAlert? sosAlert,
  }) {
    return EmergencyState(
      state: state ?? this.state,
      lifecycleStage: lifecycleStage ?? this.lifecycleStage,
      activeEmergency: activeEmergency ?? this.activeEmergency,
      countdownSeconds: countdownSeconds ?? this.countdownSeconds,
      errorMessage: errorMessage,
      dispatchedContacts:
          dispatchedContacts ?? notifiedContacts ?? this.dispatchedContacts,
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
  StreamSubscription<CloudIncidentBinding>? _cloudBindingSubscription;
  late final Future<void> ready;

  EmergencyNotifier(this._ref) : super(const EmergencyState()) {
    // Listen to SOS service updates
    _sosService.addAlertListener(_onAlertUpdate);
    _sosService.addLocationListener(_onLocationUpdate);
    _cloudBindingSubscription =
        CloudIncidentBindingService.instance.stream.listen(
      (binding) => unawaited(_onCloudIncidentBound(binding)),
    );
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

    final cloudId = alert.cloudIncidentId;
    EmergencyLifecycleStage restoredStage;
    if (alert.status == 'resolved' || alert.status == 'cancelled') {
      restoredStage = EmergencyLifecycleStage.resolved;
    } else if (cloudId != null && cloudId.isNotEmpty) {
      restoredStage = EmergencyLifecycleStage.cloudAcknowledged;
    } else {
      final outboxOps = await database.getDueOutboxOperations(
        ownerUserId: userId,
        limit: 50,
      );
      final hasPending = outboxOps.any((op) => op.aggregateId == alert.alertId);
      if (hasPending) {
        restoredStage = EmergencyLifecycleStage.cloudQueued;
      } else {
        restoredStage = EmergencyLifecycleStage.localEmergencyActive;
      }
    }

    state = EmergencyState(
      state: SosState.active,
      lifecycleStage: restoredStage,
      activeEmergency: Emergency(
        id: alert.cloudIncidentId ?? alert.alertId,
        userId: alert.userId,
        status: EmergencyStatus.active,
        latitude: alert.latitude,
        longitude: alert.longitude,
        startedAt: alert.startedAt,
        dispatchedContacts: restoredAlert.contactStatuses
            .where((status) => status.smsAcceptedByDevice)
            .map((status) => status.contact.phone)
            .toList(),
      ),
      sosAlert: restoredAlert,
      currentLocation: position,
      dispatchedContacts: restoredAlert.contactStatuses
          .where((status) => status.smsAcceptedByDevice)
          .map((status) => status.contact.name)
          .toList(),
    );
    Logger.info(
        'Restored active emergency ${alert.alertId} from local storage');
  }

  SosTriggerSource _sourceFromStoredValue(String value) => switch (value) {
        'ANDROID_POWER_GESTURE' ||
        'hardware_power_panic' =>
          SosTriggerSource.hardwarePower,
        'ANDROID_SHAKE' || 'shake_sos' => SosTriggerSource.shake,
        'ANDROID_FALL' || 'fall_detected' => SosTriggerSource.fall,
        'VOICE_SOS' || 'voice_sos' => SosTriggerSource.voiceCommand,
        'CHECK_IN_EXPIRED' || 'check_in_expired' => SosTriggerSource.scheduled,
        'ROUTE_DEVIATION' ||
        'route_deviation' ||
        'ROUTE_DEVIATION_TIMEOUT' ||
        'ROUTE_DEVIATION_USER_SOS' =>
          SosTriggerSource.routeDeviation,
        'MULTI_TAP' || 'triple_tap' => SosTriggerSource.multiTap,
        _ => SosTriggerSource.button,
      };

  @override
  void dispose() {
    _sosService.removeAlertListener(_onAlertUpdate);
    _sosService.removeLocationListener(_onLocationUpdate);
    _cloudBindingSubscription?.cancel();
    super.dispose();
  }

  Future<void> _onCloudIncidentBound(CloudIncidentBinding binding) async {
    final currentUserId = AwsAuthService.instance.currentUserId;
    final activeAlert = state.sosAlert;
    if (!mounted ||
        currentUserId == null ||
        currentUserId != binding.ownerUserId ||
        activeAlert == null ||
        activeAlert.id != binding.localAlertId ||
        !state.isActive) {
      return;
    }

    _backendIncidentId = binding.cloudIncidentId;
    state = state.copyWith(
      lifecycleStage: EmergencyLifecycleStage.cloudAcknowledged,
    );
    _ref
        .read(awsIncidentProvider.notifier)
        .startPolling(binding.cloudIncidentId);
    unawaited(
      _ref
          .read(awsIncidentProvider.notifier)
          .pollStatus(binding.cloudIncidentId),
    );

    final latest = state.currentLocation ?? activeAlert.currentLocation;
    if (latest != null) {
      await _pushLocationToCloud(latest, force: true);
    }
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

  DateTime? _lastLocationPushAt;

  /// Handle location updates (live monotonic upstream location propagation).
  void _onLocationUpdate(Position position) {
    state = state.copyWith(currentLocation: position);
    unawaited(_pushLocationToCloud(position));
  }

  Future<void> _pushLocationToCloud(
    Position position, {
    bool force = false,
  }) async {
    final cloudId = _backendIncidentId;
    if (cloudId == null || !state.isActive) return;

    final now = DateTime.now();
    if (!force &&
        _lastLocationPushAt != null &&
        now.difference(_lastLocationPushAt!).inSeconds < 5) {
      return;
    }
    _lastLocationPushAt = now;

    final emergencyLocation = EmergencyLocation.fromFix(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracy: position.accuracy,
      capturedAt: position.timestamp,
      receivedAt: now.toUtc(),
      source: 'gps_stream',
    );
    try {
      await AwsIncidentService.instance.updateIncidentLocation(
        incidentId: cloudId,
        location: emergencyLocation.toJson(),
      );
    } catch (error) {
      Logger.warning('Failed to push live emergency location: $error');
    }
  }

  Future<String?> _persistAndIngestAlert({
    required SosAlert alert,
    required String userId,
    required String eventType,
    required Map<String, dynamic> motionData,
  }) async {
    final location = alert.currentLocation ?? alert.initialLocation;
    final database = _ref.read(databaseProvider);
    final acceptedLocalDispatches = alert.contactStatuses
        .where((status) => status.deliveryState.isLocalOsAccepted)
        .length;
    final evidencedMotionData = <String, dynamic>{
      ...motionData,
      'local_sms_accepted_count': acceptedLocalDispatches,
      'local_sms_delivery': alert.contactStatuses
          .map((status) => <String, dynamic>{
                'contact_id': status.contact.id,
                'state': status.deliveryState.serialized,
              })
          .toList(),
      'event_occurred_at': alert.startedAt.toUtc().toIso8601String(),
    };
    final emergencyLocation = location != null
        ? EmergencyLocation.fromFix(
            latitude: location.latitude,
            longitude: location.longitude,
            accuracy: location.accuracy,
            capturedAt: location.timestamp,
            receivedAt: DateTime.now().toUtc(),
            source: 'initial_sos',
          )
        : null;
    final cloudLocation = emergencyLocation?.toJson();
    if (cloudLocation != null) {
      cloudLocation['timezone_offset'] =
          DateTime.now().timeZoneOffset.inSeconds;
    }
    final cloudPayload = <String, dynamic>{
      'event_type': eventType,
      if (cloudLocation != null) 'location': cloudLocation,
      'motion_data': evidencedMotionData,
    };
    state = state.copyWith(lifecycleStage: EmergencyLifecycleStage.cloudQueued);
    try {
      final queued = await database.queueAlertForCloud(
        ownerUserId: userId,
        alertId: alert.id,
        eventType: eventType,
        occurredAt: alert.startedAt,
        cloudPayload: cloudPayload,
        deliveryAttempts: alert.contactStatuses.map((contactStatus) {
          final isOsAccepted = contactStatus.deliveryState.isLocalOsAccepted;
          final isComposer =
              contactStatus.deliveryState == SmsDeliveryState.composerOpened;
          final accepted = isOsAccepted;
          return LocalDeliveryAttemptsCompanion.insert(
            attemptId: '${alert.id}:sms:${contactStatus.contact.id}',
            incidentId: alert.id,
            channel: 'sms',
            recipientRef: contactStatus.contact.id,
            status: isComposer
                ? 'composer_opened'
                : (accepted
                    ? DeliveryState.accepted.name
                    : DeliveryState.failed.name),
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
          smsSent: Value(alert.contactStatuses
              .any((item) => item.deliveryState.isLocalOsAccepted)),
          smsCount: Value(alert.contactStatuses
              .where((item) => item.deliveryState.isLocalOsAccepted)
              .length),
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

    state =
        state.copyWith(lifecycleStage: EmergencyLifecycleStage.cloudDelivering);
    try {
      final incident = await AwsIncidentService.instance.createIncident(
        eventId: alert.id,
        eventType: eventType,
        location: cloudLocation,
        motionData: evidencedMotionData,
      );
      final cloudIncidentId = incident['incident_id'] as String?;
      if (cloudIncidentId == null || cloudIncidentId.isEmpty) {
        throw const FormatException('Incident response has no incident_id');
      }
      _backendIncidentId = cloudIncidentId;
      await database.recordCloudIncidentCreated(
        alertId: alert.id,
        cloudIncidentId: cloudIncidentId,
      );
      await database.markOutboxSucceeded('${alert.id}:createIncident');
      state = state.copyWith(
          lifecycleStage: EmergencyLifecycleStage.cloudAcknowledged);
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

      // Use the cached AWS identity, or fallback to local emergency identity for offline SOS safety
      final awsAuth = AwsAuthService.instance;
      final realUid = awsAuth.currentUserId ?? 'offline_user';
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
        lifecycleStage: _backendIncidentId != null
            ? EmergencyLifecycleStage.cloudAcknowledged
            : EmergencyLifecycleStage.cloudQueued,
        activeEmergency: emergency,
        sosAlert: alert,
        currentLocation: alert.currentLocation,
        dispatchedContacts: alert.contactStatuses
            .where((c) => c.smsAcceptedByDevice)
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
        eventType: 'ANDROID_POWER_GESTURE',
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
    final nativeOwnerId = event['owner_user_id']?.toString();
    if (nativeOwnerId == null ||
        nativeOwnerId.isEmpty ||
        nativeOwnerId != userId) {
      Logger.warning(
          'Refusing native emergency replay across account boundary.');
      return false;
    }
    await _ref.read(contactsProvider.notifier).ready;
    final contacts = _ref.read(contactsProvider).contacts;
    final acceptedContactIds =
        (event['accepted_contact_ids'] as List? ?? const [])
            .map((value) => value.toString())
            .toSet();
    final failedContactIds = (event['failed_contact_ids'] as List? ?? const [])
        .map((value) => value.toString())
        .toSet();
    final occurredAt = DateTime.fromMillisecondsSinceEpoch(
      (event['occurred_at_ms'] as num?)?.toInt() ??
          DateTime.now().millisecondsSinceEpoch,
    );
    final latitude = (event['latitude'] as num?)?.toDouble();
    final longitude = (event['longitude'] as num?)?.toDouble();
    final nativeSource = event['source'] as String? ?? 'ANDROID_POWER_GESTURE';
    final triggerSource = switch (nativeSource) {
      'ANDROID_POWER_GESTURE' ||
      'hardware_power_panic' =>
        SosTriggerSource.hardwarePower,
      'ANDROID_SHAKE' || 'shake_sos' => SosTriggerSource.shake,
      'ANDROID_FALL' || 'fall_detected' => SosTriggerSource.fall,
      'VOICE_SOS' || 'voice_sos' => SosTriggerSource.voiceCommand,
      'CHECK_IN_EXPIRED' || 'check_in_expired' => SosTriggerSource.scheduled,
      'ROUTE_DEVIATION' || 'route_deviation' => SosTriggerSource.routeDeviation,
      'MULTI_TAP' || 'triple_tap' => SosTriggerSource.multiTap,
      _ => SosTriggerSource.hardwarePower,
    };
    final eventType = switch (nativeSource) {
      'ANDROID_POWER_GESTURE' ||
      'hardware_power_panic' =>
        'ANDROID_POWER_GESTURE',
      'ANDROID_SHAKE' || 'shake_sos' => 'ANDROID_SHAKE',
      'ANDROID_FALL' || 'fall_detected' => 'ANDROID_FALL',
      'VOICE_SOS' || 'voice_sos' => 'VOICE_SOS',
      'CHECK_IN_EXPIRED' || 'check_in_expired' => 'CHECK_IN_EXPIRED',
      'ROUTE_DEVIATION' || 'route_deviation' => 'ROUTE_DEVIATION',
      'ROUTE_DEVIATION_TIMEOUT' => 'ROUTE_DEVIATION_TIMEOUT',
      'ROUTE_DEVIATION_USER_SOS' => 'ROUTE_DEVIATION_USER_SOS',
      'MULTI_TAP' || 'triple_tap' => 'MULTI_TAP',
      _ => nativeSource,
    };
    final locationTimeMs = (event['location_time_ms'] as num?)?.toInt();
    final capturedAt = locationTimeMs != null && locationTimeMs > 0
        ? DateTime.fromMillisecondsSinceEpoch(locationTimeMs)
        : occurredAt;

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
            timestamp:
                capturedAt, // P0-03: Use actual GPS capture time, not SOS trigger time
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
        final wasAccepted = acceptedContactIds.contains(contact.id);
        final wasFailed = failedContactIds.contains(contact.id);

        // P2-01: Accurately reconstruct SmsDeliveryState
        return ContactAlertStatus(
          contact: contact,
          smsAcceptedByDevice: wasAccepted,
          deliveryState: wasAccepted
              ? SmsDeliveryState.osAccepted
              : (wasFailed
                  ? SmsDeliveryState.failed
                  : SmsDeliveryState.notAttempted),
          dispatchedAt: wasAccepted ? occurredAt : null,
          error: wasAccepted
              ? null
              : (wasFailed
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
        'trigger_source': nativeSource,
        'native_dispatch': true,
        'snapshot_version': event['snapshot_version'],
        'event_occurred_at': occurredAt.toUtc().toIso8601String(),
        if (event['sensor_evidence'] is Map)
          ...Map<String, dynamic>.from(event['sensor_evidence'] as Map),
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
            .where((contact) => acceptedContactIds.contains(contact.id))
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
        SosTriggerSource.hardwarePower => 'ANDROID_POWER_GESTURE',
        SosTriggerSource.shake => 'ANDROID_SHAKE',
        SosTriggerSource.fall => 'ANDROID_FALL',
        SosTriggerSource.voiceCommand => 'VOICE_SOS',
        SosTriggerSource.scheduled => 'CHECK_IN_EXPIRED',
        SosTriggerSource.routeDeviation => 'ROUTE_DEVIATION',
        SosTriggerSource.multiTap => 'MULTI_TAP',
        SosTriggerSource.widget => 'MANUAL_SOS',
        SosTriggerSource.button => 'MANUAL_SOS',
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

  /// Update emergency lifecycle stage
  void updateLifecycleStage(EmergencyLifecycleStage stage) {
    if (state.lifecycleStage != stage) {
      state = state.copyWith(lifecycleStage: stage);
    }
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
