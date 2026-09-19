import 'package:flutter_test/flutter_test.dart';
import 'package:guardian/core/models/emergency_domain.dart';

void main() {
  group('EmergencyStateMachine', () {
    test('allows an incident to progress through a real response', () {
      const path = [
        EmergencyIncidentState.triggered,
        EmergencyIncidentState.localDispatching,
        EmergencyIncidentState.cloudAccepted,
        EmergencyIncidentState.communityOffered,
        EmergencyIncidentState.respondersAccepted,
        EmergencyIncidentState.respondersEnRoute,
        EmergencyIncidentState.helpArrived,
        EmergencyIncidentState.resolved,
      ];

      for (var index = 0; index < path.length - 1; index++) {
        expect(
          EmergencyStateMachine.canTransition(path[index], path[index + 1]),
          isTrue,
        );
      }
    });

    test('does not allow a terminal incident to reopen', () {
      for (final terminal in [
        EmergencyIncidentState.resolved,
        EmergencyIncidentState.cancelled,
        EmergencyIncidentState.expired,
      ]) {
        expect(terminal.isTerminal, isTrue);
        expect(
          EmergencyStateMachine.canTransition(
            terminal,
            EmergencyIncidentState.cloudAccepted,
          ),
          isFalse,
        );
      }
    });

    test('throws for an invalid lifecycle regression', () {
      expect(
        () => EmergencyStateMachine.validateTransition(
          EmergencyIncidentState.respondersEnRoute,
          EmergencyIncidentState.triggered,
        ),
        throwsStateError,
      );
    });
  });

  test('delivery terminal states have explicit semantics', () {
    expect(DeliveryState.queued.isTerminal, isFalse);
    expect(DeliveryState.accepted.isTerminal, isFalse);
    expect(DeliveryState.delivered.isTerminal, isTrue);
    expect(DeliveryState.acknowledged.isTerminal, isTrue);
    expect(DeliveryState.failed.isTerminal, isTrue);
    expect(DeliveryState.unknown.isTerminal, isFalse);
  });
}
