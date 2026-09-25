import 'package:flutter_test/flutter_test.dart';
import 'package:guardian/core/models/emergency_location.dart';

void main() {
  group('EmergencyLocation Freshness Policy (P0-03)', () {
    test('current GPS fix within 30s and accuracy <= 50m is FRESH', () {
      final now = DateTime.now().toUtc();
      final capturedAt = now.subtract(const Duration(seconds: 5));

      final location = EmergencyLocation.fromFix(
        latitude: 19.0760,
        longitude: 72.8777,
        accuracy: 12.0,
        capturedAt: capturedAt,
        receivedAt: now,
        source: 'gps',
      );

      expect(location.freshness, LocationFreshness.fresh);
      expect(location.isUsableForEmergency, isTrue);
      expect(location.ageSeconds, inInclusiveRange(4.0, 7.0));
      expect(location.capturedAt, capturedAt);
      expect(location.receivedAt, now);
    });

    test(
        'cached GPS fix older than 30s is STALE and preserves true capture time',
        () {
      final now = DateTime.now().toUtc();
      // 5 minutes old cached fix
      final capturedAt = now.subtract(const Duration(minutes: 5));

      final location = EmergencyLocation.fromFix(
        latitude: 19.0760,
        longitude: 72.8777,
        accuracy: 15.0,
        capturedAt: capturedAt,
        receivedAt: now,
        source: 'last_known',
      );

      // Invariant: cannot become fresh merely because it was retrieved now
      expect(location.freshness, LocationFreshness.stale);
      expect(location.ageSeconds, greaterThanOrEqualTo(299.0));
      expect(location.capturedAt, capturedAt);
      expect(location.source, 'last_known');
    });

    test('fix with poor accuracy (> 50m) is degraded to STALE', () {
      final now = DateTime.now().toUtc();
      final capturedAt = now.subtract(const Duration(seconds: 2));

      final location = EmergencyLocation.fromFix(
        latitude: 19.0760,
        longitude: 72.8777,
        accuracy: 120.0, // 120m accuracy is insufficient for precision rescue
        capturedAt: capturedAt,
        receivedAt: now,
        source: 'cell_tower',
      );

      expect(location.freshness, LocationFreshness.stale);
    });

    test('json serialization preserves captured_at, received_at, and freshness',
        () {
      final now = DateTime.now().toUtc();
      final capturedAt = now.subtract(const Duration(seconds: 10));

      final location = EmergencyLocation.fromFix(
        latitude: 19.0760,
        longitude: 72.8777,
        accuracy: 8.0,
        capturedAt: capturedAt,
        receivedAt: now,
        source: 'gps',
      );

      final json = location.toJson();
      expect(json['latitude'], 19.0760);
      expect(json['longitude'], 72.8777);
      expect(json['accuracy'], 8.0);
      expect(json['captured_at'], capturedAt.toIso8601String());
      expect(json['received_at'], now.toIso8601String());
      expect(json['freshness'], 'FRESH');
      expect(json['source'], 'gps');

      final restored = EmergencyLocation.fromJson(json);
      expect(restored.latitude, 19.0760);
      expect(
          restored.capturedAt.toIso8601String(), capturedAt.toIso8601String());
      expect(restored.freshness, LocationFreshness.fresh);
    });
  });
}
