/*
 * Guardian 2.0 - Safety Architecture & Emergency Configuration
 * Centralized Safety Parameters and System Invariants
 */

/// Centralized configuration for Guardian emergency response, responder lifecycle,
/// and location freshness thresholds.
abstract final class EmergencyConfig {
  // ─── Responder Availability & Heartbeat ──────────────────────────────────
  /// Interval between responder availability heartbeat updates sent to backend
  static const Duration responderHeartbeatInterval = Duration(seconds: 60);

  /// Server TTL for responder availability after last received heartbeat
  static const Duration responderAvailabilityTtl = Duration(seconds: 300);

  /// Maximum simultaneously active/accepted responders per emergency incident
  static const int maxAcceptedResponders = 2;

  // ─── Location Freshness Thresholds ────────────────────────────────────────
  /// Maximum age for a location to be classified as FRESH (client UI quality)
  static const Duration freshLocationMaxAge = Duration(seconds: 15);

  /// Maximum horizontal accuracy in meters for a location to be classified as FRESH
  static const double freshLocationMaxAccuracyMeters = 50.0;

  /// Maximum age for an ACCEPTABLE location
  static const Duration acceptableLocationMaxAge = Duration(seconds: 60);

  /// Maximum horizontal accuracy in meters for an ACCEPTABLE location
  static const double acceptableLocationMaxAccuracyMeters = 100.0;

  /// Maximum age before a location is marked STALE
  static const Duration staleLocationMaxAge = Duration(seconds: 120);

  /// Backend server freshness threshold for responder navigation grants (30s)
  static const int backendFreshnessThresholdSeconds = 30;

  // ─── Escalation Stages (Radial Expansion Ladder) ─────────────────────────
  /// Escalation stage radius limits in meters: Stage 1 (1km), Stage 2 (2km), Stage 3 (5km), Stage 4 (10km)
  static const List<double> escalationRadiusLadderMeters = [
    1000.0,
    2000.0,
    5000.0,
    10000.0,
  ];

  /// Invitation timeouts corresponding to each escalation stage (seconds)
  static const List<int> escalationTimeoutSeconds = [
    60,
    90,
    120,
    180,
  ];

  // ─── Offline Synchronization & Durability ────────────────────────────────
  /// Periodic timer for checking and retrying queued offline incidents
  static const Duration offlineOutboxRetryInterval = Duration(seconds: 30);

  /// Maximum retry count before manual user intervention / notification
  static const int maxOfflineRetries = 10;
}
