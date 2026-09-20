import 'package:flutter_test/flutter_test.dart';
import 'package:guardian/core/services/aws_sns_service.dart';
import 'package:guardian/core/services/responder_service.dart';

void main() {
  test('responder mission parses coarse invitation evidence', () {
    final mission = ResponderMission.fromJson({
      'mission_id': 'incident#responder',
      'incident_id': 'incident',
      'status': 'INVITED',
      'invited_at': '2026-09-20T10:00:00Z',
      'invitation_expires_at': 1789900200,
      'invitation_delivery_status': 'PROVIDER_ACCEPTED',
      'approximate_location': {'latitude': 19.08, 'longitude': 72.88},
    });

    expect(mission.missionId, 'incident#responder');
    expect(mission.approximateLatitude, 19.08);
    expect(mission.deliveryStatus, 'PROVIDER_ACCEPTED');
    expect(mission.isTerminal, isFalse);
  });

  test('notification route carries encoded mission identity', () {
    final route = AwsSnsService.notificationLocation(
      'responder_invitation',
      const {'mission_id': 'incident#responder'},
    );

    expect(route, '/responder/mission/incident%23responder');
  });

  test('incident notifications route to persisted evidence', () {
    final route = AwsSnsService.notificationLocation(
      'rescue_accepted',
      const {'incident_id': 'incident/unsafe'},
    );

    expect(route, '/incidents/incident%2Funsafe');
  });
}
