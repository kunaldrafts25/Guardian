/*
 * Guardian - P1 Remediation Unit Tests
 *
 * Validates:
 * 1. NearbyResponderSummary model & JSON contract
 * 2. Provider-neutral route state and truthful degraded geometry semantics
 * 3. SosSettings state with fallDetectionEnabled & setting copy
 * 4. SosTriggerSource enums & accurate event provenance mappings
 */

import 'package:flutter_test/flutter_test.dart';
import 'package:guardian/core/models/nearby_responder_summary.dart';
import 'package:guardian/core/providers/safe_route_provider.dart';
import 'package:latlong2/latlong.dart';
import 'package:guardian/core/providers/sos_settings_provider.dart';
import 'package:guardian/core/services/sos_service.dart';

void main() {
  group('P1: NearbyResponderSummary Least-Privilege Contract', () {
    test(
        'parses privacy-preserving payload without individual responder identities',
        () {
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

  group('P1: Route Provider Truthfulness', () {
    test('authoritative route geometry is explicitly represented', () {
      const route = RouteInfo(
        polylinePoints: [
          LatLng(18.5204, 73.8567),
          LatLng(18.5210, 73.8572),
        ],
        distance: '100 m',
        duration: '2 min walk',
        startAddress: 'Current Location',
        endAddress: 'Destination',
        provider: 'google_routes',
        authoritativeGeometry: true,
      );

      expect(route.provider, 'google_routes');
      expect(route.authoritativeGeometry, isTrue);
    });

    test('degraded direct line is distinguishable from a routable path', () {
      const route = RouteInfo(
        polylinePoints: [
          LatLng(18.5204, 73.8567),
          LatLng(18.5300, 73.8660),
        ],
        distance: '1.4 km direct',
        duration: 'Routing unavailable',
        startAddress: 'Current Location',
        endAddress: 'Destination',
        provider: 'degraded_direct_line',
        authoritativeGeometry: false,
      );

      expect(route.authoritativeGeometry, isFalse);
      expect(route.provider, 'degraded_direct_line');
    });
  });

  group('P1: Trigger Settings Synchronization & State', () {
    test('SosSettings defaults both shake and fall detection to enabled', () {
      const settings = SosSettings();
      expect(settings.shakeToSosEnabled, isTrue);
      expect(settings.fallDetectionEnabled, isTrue);
      expect(settings.countdownSeconds, 3);
    });

    test('SosSettings copyWith updates shake and fall settings independently',
        () {
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
    test(
        'SosTriggerSource enum contains all required native and platform triggers',
        () {
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
