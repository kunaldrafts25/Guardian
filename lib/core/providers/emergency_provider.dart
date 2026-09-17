/*
 * Guardian 2.0 - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * 
 * Emergency Provider - Riverpod state management for SOS
 */

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:guardian/core/models/emergency_model.dart';
import 'package:guardian/core/providers/contacts_provider.dart';
import 'package:guardian/core/providers/sos_settings_provider.dart';
import 'package:guardian/core/services/aws_incident_service.dart';
import 'package:guardian/core/services/sos_service.dart';
import 'package:guardian/core/utils/location_utils.dart';
import 'package:guardian/core/utils/logger.dart';

/// Emergency state for the SOS system
enum SosState {
  idle,        // No emergency
  countdown,   // Countdown before trigger
  triggering,  // Triggering emergency
  active,      // Emergency is active
  responding,  // Guardians responding
  resolving,   // Resolving emergency
  error,       // Error state
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
  Future<void> triggerEmergency({SosTriggerSource source = SosTriggerSource.button}) async {
    state = state.copyWith(state: SosState.triggering);
    
    try {
      // Get emergency contacts from contacts provider
      final contactsState = _ref.read(contactsProvider);
      final contacts = contactsState.contacts;
      
      if (contacts.isEmpty) {
        Logger.warning('⚠️ No emergency contacts configured');
        state = state.copyWith(
          state: SosState.error,
          errorMessage: 'No emergency contacts configured. Please add contacts in Settings.',
        );
        return;
      }

      // Get custom message from settings
      final settings = _ref.read(sosSettingsProvider);
      
      Logger.info('🚨 SOS TRIGGERED via ${source.name}');
      
      // Get real user identity from Firebase Auth
      final firebaseUser = FirebaseAuth.instance.currentUser;
      final realName = firebaseUser?.displayName ?? firebaseUser?.email ?? 'Guardian User';
      final realUid = firebaseUser?.uid ?? 'anonymous';

      // Trigger SOS via the unified service
      final alert = await _sosService.triggerSos(
        contacts: contacts,
        source: source,
        customMessage: settings.customMessage.isNotEmpty ? settings.customMessage : null,
        userName: realName,
        userId: realUid,
      );
      
      if (alert == null) {
        throw Exception('Failed to create SOS alert');
      }
      
      // Create emergency record for UI
      final emergency = Emergency(
        id: alert.id,
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
      
      Logger.info('✅ Emergency activated. ${alert.notifiedCount}/${contacts.length} contacts notified.');
      
      // Forward incident to AWS Serverless / Agentic pipeline
      try {
        final loc = alert.currentLocation;
        AwsIncidentService.instance.createIncident(
          eventId: alert.id,
          userId: realUid,
          eventType: 'sos_button',
          location: loc != null
              ? {'latitude': loc.latitude, 'longitude': loc.longitude}
              : null,
          motionData: {'g_force': 2.5},
        ).catchError((e) {
          Logger.warning('AWS incident ingestion skipped (offline/unreachable): $e');
          return <String, dynamic>{};
        });
      } catch (e) {
        Logger.warning('Could not forward incident to AWS: $e');
      }

      // Auto-call emergency services if enabled
      if (settings.autoCallEmergency) {
        await _sosService.callEmergencyServices(number: settings.emergencyNumber);
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
    Logger.info('🚨 HARDWARE POWER BUTTON PANIC — Immediate CRITICAL escalation');
    state = state.copyWith(state: SosState.triggering);

    try {
      final contactsState = _ref.read(contactsProvider);
      final contacts = contactsState.contacts;
      // ignore: unused_local_variable
      final settings = _ref.read(sosSettingsProvider);
      final firebaseUser = FirebaseAuth.instance.currentUser;
      final realName = firebaseUser?.displayName ?? firebaseUser?.email ?? 'Guardian User';
      final realUid = firebaseUser?.uid ?? 'anonymous';

      // Trigger local SOS (SMS to contacts) — no waiting
      final alert = await _sosService.triggerSos(
        contacts: contacts,
        source: SosTriggerSource.button,
        customMessage: '🚨 EMERGENCY — I need immediate help. This is a real danger alert.',
        userName: realName,
        userId: realUid,
      );

      if (alert == null) throw Exception('Failed to create hardware panic alert');

      final emergency = Emergency(
        id: alert.id,
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
        notifiedContacts: alert.contactStatuses.where((c) => c.smsSent).map((c) => c.contact.name).toList(),
      );

      // Forward to AWS Agent as hardware_power_panic — immediate CRITICAL (0.98) score
      final loc = alert.currentLocation;
      AwsIncidentService.instance.createIncident(
        eventId: '${alert.id}_panic',
        userId: realUid,
        eventType: 'hardware_power_panic',
        location: loc != null ? {'latitude': loc.latitude, 'longitude': loc.longitude, 'is_isolated': true} : null,
        motionData: {'tap_count': 3, 'trigger': 'power_button'},
      ).catchError((e) {
        Logger.warning('AWS hardware panic incident ingestion failed (offline): $e');
        return <String, dynamic>{};
      });

      Logger.info('✅ Hardware panic escalated. ${alert.notifiedCount} contacts notified.');
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
      
      await _sosService.markAsSafe();
      
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
final emergencyProvider = StateNotifierProvider<EmergencyNotifier, EmergencyState>((ref) {
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
