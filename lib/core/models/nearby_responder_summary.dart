/*
 * Guardian - Women's Safety App
 * Nearby Responder Summary Model (Least-Privilege Privacy Architecture)
 */

class NearbyResponderSummary {
  final String incidentId;
  final int eligibleResponderCount;
  final int searchStage;
  final double radiusMeters;

  const NearbyResponderSummary({
    required this.incidentId,
    required this.eligibleResponderCount,
    this.searchStage = 1,
    this.radiusMeters = 1000.0,
  });

  factory NearbyResponderSummary.empty({String incidentId = ''}) =>
      NearbyResponderSummary(
        incidentId: incidentId,
        eligibleResponderCount: 0,
        searchStage: 1,
        radiusMeters: 1000.0,
      );

  bool get hasActiveResponders => eligibleResponderCount > 0;

  factory NearbyResponderSummary.fromJson(Map<String, dynamic> json) {
    return NearbyResponderSummary(
      incidentId: json['incident_id'] as String? ?? '',
      eligibleResponderCount:
          (json['eligible_responder_count'] as num?)?.toInt() ?? 0,
      searchStage: (json['search_stage'] as num?)?.toInt() ?? 1,
      radiusMeters: (json['radius_meters'] as num?)?.toDouble() ?? 1000.0,
    );
  }

  Map<String, dynamic> toJson() => {
        'incident_id': incidentId,
        'eligible_responder_count': eligibleResponderCount,
        'search_stage': searchStage,
        'radius_meters': radiusMeters,
      };
}
