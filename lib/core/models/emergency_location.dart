/*
 * Guardian - Women's Safety App
 * Canonical Emergency Location Model & Freshness Policy (P0-03)
 */

enum LocationFreshness {
  fresh,
  stale,
  unknown,
  unavailable,
}

/// Explicit emergency freshness policy:
/// - FRESH: age <= 30 seconds AND accuracy <= 50 meters
/// - STALE: age > 30 seconds OR accuracy > 50 meters
/// - UNKNOWN: missing/invalid timestamp or clock discrepancy
/// - UNAVAILABLE: no location fix
class EmergencyLocation {
  final double latitude;
  final double longitude;
  final double accuracy;
  final DateTime capturedAt;
  final DateTime receivedAt;
  final String source;
  final LocationFreshness freshness;

  const EmergencyLocation({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.capturedAt,
    required this.receivedAt,
    required this.source,
    required this.freshness,
  });

  int get ageSeconds {
    final diff = receivedAt.difference(capturedAt).inSeconds;
    return diff < 0 ? 0 : diff;
  }

  bool get isFresh => freshness == LocationFreshness.fresh;
  bool get isStale => freshness == LocationFreshness.stale;
  bool get isUsableForEmergency =>
      freshness == LocationFreshness.fresh || freshness == LocationFreshness.stale;

  static LocationFreshness calculateFreshness({
    required DateTime? capturedAt,
    required DateTime receivedAt,
    required double accuracy,
  }) {
    if (capturedAt == null || capturedAt.millisecondsSinceEpoch <= 0) {
      return LocationFreshness.unknown;
    }
    final age = receivedAt.difference(capturedAt).inSeconds;
    if (age < -60) {
      // Hardware clock is in the future beyond normal jitter
      return LocationFreshness.unknown;
    }
    // Standard policy: 30 seconds threshold, 50m accuracy
    if (age <= 30 && accuracy <= 50.0) {
      return LocationFreshness.fresh;
    }
    return LocationFreshness.stale;
  }

  factory EmergencyLocation.fromFix({
    required double latitude,
    required double longitude,
    required double accuracy,
    required DateTime? capturedAt,
    DateTime? receivedAt,
    String source = 'gps',
  }) {
    final rx = receivedAt ?? DateTime.now().toUtc();
    final cap = capturedAt ?? rx;
    final freshness = capturedAt == null
        ? LocationFreshness.unknown
        : calculateFreshness(
            capturedAt: cap,
            receivedAt: rx,
            accuracy: accuracy,
          );

    return EmergencyLocation(
      latitude: latitude,
      longitude: longitude,
      accuracy: accuracy,
      capturedAt: cap,
      receivedAt: rx,
      source: source,
      freshness: freshness,
    );
  }

  Map<String, dynamic> toJson() => {
        'latitude': latitude,
        'longitude': longitude,
        'accuracy': accuracy,
        'captured_at': capturedAt.toIso8601String(),
        'received_at': receivedAt.toIso8601String(),
        'source': source,
        'age_seconds': ageSeconds,
        'freshness': freshness.name.toUpperCase(),
      };

  factory EmergencyLocation.fromJson(Map<String, dynamic> json) {
    final cap = json['captured_at'] != null
        ? DateTime.tryParse(json['captured_at'] as String) ?? DateTime.now().toUtc()
        : DateTime.now().toUtc();
    final rx = json['received_at'] != null
        ? DateTime.tryParse(json['received_at'] as String) ?? DateTime.now().toUtc()
        : DateTime.now().toUtc();
    final freshnessStr = (json['freshness'] as String?)?.toLowerCase();
    final freshness = LocationFreshness.values.firstWhere(
      (e) => e.name == freshnessStr,
      orElse: () => calculateFreshness(
        capturedAt: cap,
        receivedAt: rx,
        accuracy: (json['accuracy'] as num?)?.toDouble() ?? 999.0,
      ),
    );

    return EmergencyLocation(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      accuracy: (json['accuracy'] as num?)?.toDouble() ?? 0.0,
      capturedAt: cap,
      receivedAt: rx,
      source: (json['source'] as String?) ?? 'unknown',
      freshness: freshness,
    );
  }

  String get googleMapsLink =>
      'https://maps.google.com/?q=$latitude,$longitude';
}
