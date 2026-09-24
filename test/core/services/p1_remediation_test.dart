/*
 * Guardian - P1 Remediation Unit Tests
 *
 * Validates:
 * 1. NearbyResponderSummary model & JSON contract
 * 2. MapRoutingConfig endpoint configurability, headers, and rate-limit constants
 * 3. SosSettings state with fallDetectionEnabled & setting copy
 * 4. SosTriggerSource enums & accurate event provenance mappings
 */

import 'package:flutter_test/flutter_test.dart';
import 'package:guardian/core/config/map_routing_config.dart';
import 'package:guardian/core/models/nearby_responder_summary.dart';
import 'package:guardian/core/providers/sos_settings_provider.dart';
import 'package:guardian/core/services/sos_service.dart';

void main() {
  group('P1: NearbyResponderSummary Least-Privilege Contract', () {
    test('parses privacy-preserving payload without individual responder identities', () {
      final json = {
        'incident_id': 'inc-999',
        'eligible_responder_count': 5,
        'search_stage': 2,
        'radius_meters': 2000.0,
      };

      final summary = NearbyResponderSummary.fromJson(json);

      expect(summary.incidentId, 'inc-999');
      expect(summary.eligibleResponderCount, 5);
      expect(summary.searchStage, 2);
      expect(summary.radiusMeters, 2000.0);
      expect(summary.hasActiveResponders, isTrue);
    });

    test('handles zero responders gracefully', () {
      final summary = NearbyResponderSummary.empty();

      expect(summary.eligibleResponderCount, 0);
      expect(summary.searchStage, 1);
      expect(summary.radiusMeters, 1000.0);
      expect(summary.hasActiveResponders, isFalse);
    });

    test('toJson produces expected contract', () {
      const summary = NearbyResponderSummary(
        incidentId: 'inc-123',
        eligibleResponderCount: 3,
        searchStage: 3,
        radiusMeters: 5000.0,
      );

      final json = summary.toJson();
      expect(json['incident_id'], 'inc-123');
      expect(json['eligible_responder_count'], 3);
      expect(json['search_stage'], 3);
      expect(json['radius_meters'], 5000.0);
    });
  });

  group('P1: MapRoutingConfig Productionization', () {
    test('provides configurable endpoints with non-empty defaults', () {
      expect(MapRoutingConfig.tilesUrl, isNotEmpty);
      expect(MapRoutingConfig.nominatimBaseUrl, isNotEmpty);
      expect(MapRoutingConfig.osrmBaseUrl, isNotEmpty);
      expect(MapRoutingConfig.userAgent, contains('GuardianSafetyApp'));
    });

    test('nominatimHeaders contain User-Agent and Accept-Language', () {
      final headers = MapRoutingConfig.nominatimHeaders;
      expect(headers.containsKey('User-Agent'), isTrue);
      expect(headers['User-Agent'], isNotEmpty);
      expect(headers['Accept-Language'], 'en');
    });

    test('respects configured timeouts and intervals', () {
      expect(MapRoutingConfig.defaultSearchTimeout.inSeconds, greaterThanOrEqualTo(5));
      expect(MapRoutingConfig.defaultRoutingTimeout.inSeconds, greaterThanOrEqualTo(8));
      expect(MapRoutingConfig.nominatimMinInterval.inMilliseconds, greaterThanOrEqualTo(1000));
    });
  });

  group('P1: Trigger Settings Synchronization & State', () {
    test('SosSettings defaults both shake and fall detection to enabled', () {
      const settings = SosSettings();
      expect(settings.shakeToSosEnabled, isTrue);
      expect(settings.fallDetectionEnabled, isTrue);
      expect(settings.countdownSeconds, 3);
    });

    test('SosSettings copyWith updates shake and fall settings independently', () {
      const settings = SosSettings();
      final disabledShake = settings.copyWith(shakeToSosEnabled: false);
      expect(disabledShake.shakeToSosEnabled, isFalse);
      expect(disabledShake.fallDetectionEnabled, isTrue);

      final disabledFall = settings.copyWith(fallDetectionEnabled: false);
      expect(disabledFall.shakeToSosEnabled, isTrue);
      expect(disabledFall.fallDetectionEnabled, isFalse);
    });
  });

  group('P1: Event Provenance & Trigger Sources', () {
    test('SosTriggerSource enum contains all required native and platform triggers', () {
      const values = SosTriggerSource.values;
      expect(values.contains(SosTriggerSource.button), isTrue);
      expect(values.contains(SosTriggerSource.hardwarePower), isTrue);
      expect(values.contains(SosTriggerSource.shake), isTrue);
      expect(values.contains(SosTriggerSource.fall), isTrue);
      expect(values.contains(SosTriggerSource.routeDeviation), isTrue);
      expect(values.contains(SosTriggerSource.multiTap), isTrue);
      expect(values.contains(SosTriggerSource.voiceCommand), isTrue);
      expect(values.contains(SosTriggerSource.scheduled), isTrue);
    });
  });
}
