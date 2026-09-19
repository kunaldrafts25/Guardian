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

  EmergencyNotifier(this._ref) : super(const EmergencyState()) {
    // Listen to SOS service updates
    _sosService.addAlertListener(_onAlertUpdate);
    _sosService.addLocationListener(_onLocationUpdate);
  }

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
    final cloudPayload = <String, dynamic>{
      'event_type': eventType,
      if (location != null)
        'location': {
          'latitude': location.latitude,
          'longitude': location.longitude,
          'accuracy': location.accuracy,
        },
      'motion_data': motionData,
    };
    try {
      await database.queueAlertForCloud(
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
    } catch (error) {
      Logger.error('Could not durably queue the SOS', error);
      rethrow;
    }

    try {
      final incident = await AwsIncidentService.instance.createIncident(
        eventId: alert.id,
        userId: userId,
        eventType: eventType,
        location: location != null
            ? {
                'latitude': location.latitude,
                'longitude': location.longitude,
                'accuracy': location.accuracy,
              }
            : null,
        motionData: motionData,
      );
      await database.markAlertSynced(alert.id);
      await database.markOutboxSucceeded('${alert.id}:createIncident');
      return incident['incident_id'] as String?;
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
      {SosTriggerSource source = SosTriggerSource.button}) async {
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
        eventType:
            source == SosTriggerSource.shake ? 'shake_sos' : 'sos_button',
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
          '✅ Emergency activated. ${alert.notifiedCount}/${contacts.length} contacts notified.');

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
  Future<void> triggerFromHardwarePanic() async {
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
        source: SosTriggerSource.button,
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
          '✅ Hardware panic escalated. ${alert.notifiedCount} contacts notified.');
    } catch (e) {
      Logger.error('Error triggering hardware panic', e);
      state = state.copyWith(
        state: SosState.error,
        errorMessage: 'Hardware panic escalation failed: $e',
      );
    }
  }

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

      if (_backendIncidentId != null) {
        await AwsIncidentService.instance.updateIncidentStatus(
          _backendIncidentId!,
          'RESOLVED',
          note: 'User marked the emergency as safe',
        );
      }

      await _sosService.markAsSafe();
      final localAlertId = state.sosAlert?.id;
      if (localAlertId != null) {
        await _ref.read(databaseProvider).markAlertResolved(
              localAlertId,
              DateTime.now(),
            );
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
