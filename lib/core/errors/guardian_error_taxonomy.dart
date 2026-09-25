/*
 * Guardian 2.0 - Women's Safety App
 * Error Taxonomy & Safe Structured Observability
 */

import 'dart:convert';
import 'package:guardian/core/utils/logger.dart';

/// Standardized error codes for Guardian safety, telemetry, and diagnostics.
enum GuardianErrorCode {
  locationPermissionDenied(
      'LOCATION_PERMISSION_DENIED', 'Location permission denied by user'),
  gpsDisabled('GPS_DISABLED', 'Device GPS / location services are disabled'),
  locationStale(
      'LOCATION_STALE', 'Location fix is stale or exceeds freshness threshold'),
  smsPermissionDenied(
      'SMS_PERMISSION_DENIED', 'SMS dispatch permission not granted'),
  smsSubmissionFailed('SMS_SUBMISSION_FAILED',
      'Failed to submit SMS alert to mobile radio subsystem'),
  networkUnavailable('NETWORK_UNAVAILABLE',
      'Network connectivity is unavailable; queued locally'),
  cloudQueued(
      'CLOUD_QUEUED', 'Operation queued in local outbox pending cloud sync'),
  authExpired(
      'AUTH_EXPIRED', 'Authentication token has expired and refresh failed'),
  sessionRevoked('SESSION_REVOKED',
      'Authenticated session has been revoked by server or user'),
  responderUnavailable('RESPONDER_UNAVAILABLE',
      'No verified responders currently available in geographic range'),
  navigationProviderFailed(
      'NAVIGATION_PROVIDER_FAILED', 'Routing or navigation map service failed');

  final String code;
  final String description;

  const GuardianErrorCode(this.code, this.description);
}

/// Typed Guardian exception preserving error taxonomy and user-facing clarity.
class GuardianException implements Exception {
  final GuardianErrorCode code;
  final String userMessage;
  final String? internalDetails;
  final bool retryable;
  final DateTime timestamp;

  GuardianException({
    required this.code,
    required this.userMessage,
    this.internalDetails,
    this.retryable = false,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now().toUtc();

  @override
  String toString() =>
      'GuardianException(code: ${code.code}, message: "$userMessage", details: "$internalDetails", retryable: $retryable)';
}

/// Structured safe diagnostics logger that strictly protects PII and credentials.
class GuardianSafeTelemetry {
  const GuardianSafeTelemetry._();

  /// Log a structured emergency lifecycle transition without leaking credentials or precise coordinates.
  static void logLifecycleEvent({
    required String? incidentId,
    required String? eventId,
    required String triggerType,
    required String stateTransition,
    String? deliveryChannel,
    int? attemptNumber,
    GuardianErrorCode? errorCode,
    String? safeNote,
  }) {
    final entry = <String, dynamic>{
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'incident_id': incidentId ?? 'unassigned',
      'event_id': eventId ?? 'unassigned',
      'trigger_type': triggerType,
      'state_transition': stateTransition,
      if (deliveryChannel != null) 'delivery_channel': deliveryChannel,
      if (attemptNumber != null) 'attempt_number': attemptNumber,
      if (errorCode != null) 'error_category': errorCode.code,
      if (safeNote != null) 'diagnostic_note': safeNote,
    };

    Logger.info('🛡️ [TELEMETRY] ${jsonEncode(entry)}');
  }

  /// Sanitize phone number to mask digits: e.g. +91*****1234
  static String sanitizePhone(String phone) {
    final trimmed = phone.trim();
    if (trimmed.length <= 4) return '****';
    final suffix = trimmed.substring(trimmed.length - 4);
    final prefix = trimmed.startsWith('+') ? trimmed.substring(0, 3) : '';
    return '$prefix*****$suffix';
  }
}
