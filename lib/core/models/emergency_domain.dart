/// Canonical incident lifecycle used by the mobile persistence layer.
///
/// Delivery attempts are tracked separately because SMS, cloud ingestion and
/// push delivery can progress independently.
enum EmergencyIncidentState {
  triggered,
  localDispatching,
  cloudPending,
  cloudAccepted,
  contactsNotified,
  communityOffered,
  respondersAccepted,
  respondersEnRoute,
  helpArrived,
  degraded,
  escalatedToEmergencyServices,
  resolved,
  cancelled,
  expired;

  bool get isTerminal => switch (this) {
        resolved || cancelled || expired => true,
        _ => false,
      };
}

enum EmergencyTriggerType {
  manual,
  hardwarePower,
  shake,
  voice,
  checkInExpired,
  safeZone,
  sensor;
}

enum EmergencySeverity { low, elevated, high, critical }

enum LocationQuality { unavailable, stale, low, usable, precise }

enum EmergencyActorType { user, device, responder, service, operator }

enum DeliveryState {
  queued,
  accepted,
  delivered,
  acknowledged,
  failed,
  unknown;

  bool get isTerminal => switch (this) {
        delivered || acknowledged || failed => true,
        _ => false,
      };
}

enum OutboxOperationState { pending, processing, succeeded, superseded, failed }

/// Rejects lifecycle regressions while permitting independent delivery events
/// to be appended without changing the current incident state.
class EmergencyStateMachine {
  const EmergencyStateMachine._();

  static const Map<EmergencyIncidentState, Set<EmergencyIncidentState>>
      _allowed = {
    EmergencyIncidentState.triggered: {
      EmergencyIncidentState.localDispatching,
      EmergencyIncidentState.cloudPending,
      EmergencyIncidentState.cloudAccepted,
      EmergencyIncidentState.degraded,
      EmergencyIncidentState.resolved,
      EmergencyIncidentState.cancelled,
    },
    EmergencyIncidentState.localDispatching: {
      EmergencyIncidentState.cloudPending,
      EmergencyIncidentState.cloudAccepted,
      EmergencyIncidentState.contactsNotified,
      EmergencyIncidentState.degraded,
      EmergencyIncidentState.escalatedToEmergencyServices,
      EmergencyIncidentState.resolved,
      EmergencyIncidentState.cancelled,
    },
    EmergencyIncidentState.cloudPending: {
      EmergencyIncidentState.cloudAccepted,
      EmergencyIncidentState.contactsNotified,
      EmergencyIncidentState.degraded,
      EmergencyIncidentState.resolved,
      EmergencyIncidentState.cancelled,
    },
    EmergencyIncidentState.cloudAccepted: {
      EmergencyIncidentState.contactsNotified,
      EmergencyIncidentState.communityOffered,
      EmergencyIncidentState.respondersAccepted,
      EmergencyIncidentState.degraded,
      EmergencyIncidentState.escalatedToEmergencyServices,
      EmergencyIncidentState.resolved,
      EmergencyIncidentState.cancelled,
      EmergencyIncidentState.expired,
    },
    EmergencyIncidentState.contactsNotified: {
      EmergencyIncidentState.communityOffered,
      EmergencyIncidentState.respondersAccepted,
      EmergencyIncidentState.degraded,
      EmergencyIncidentState.escalatedToEmergencyServices,
      EmergencyIncidentState.resolved,
      EmergencyIncidentState.cancelled,
      EmergencyIncidentState.expired,
    },
    EmergencyIncidentState.communityOffered: {
      EmergencyIncidentState.respondersAccepted,
      EmergencyIncidentState.degraded,
      EmergencyIncidentState.escalatedToEmergencyServices,
      EmergencyIncidentState.resolved,
      EmergencyIncidentState.cancelled,
      EmergencyIncidentState.expired,
    },
    EmergencyIncidentState.respondersAccepted: {
      EmergencyIncidentState.respondersEnRoute,
      EmergencyIncidentState.degraded,
      EmergencyIncidentState.escalatedToEmergencyServices,
      EmergencyIncidentState.resolved,
      EmergencyIncidentState.cancelled,
      EmergencyIncidentState.expired,
    },
    EmergencyIncidentState.respondersEnRoute: {
      EmergencyIncidentState.helpArrived,
      EmergencyIncidentState.degraded,
      EmergencyIncidentState.escalatedToEmergencyServices,
      EmergencyIncidentState.resolved,
      EmergencyIncidentState.cancelled,
      EmergencyIncidentState.expired,
    },
    EmergencyIncidentState.helpArrived: {
      EmergencyIncidentState.resolved,
      EmergencyIncidentState.cancelled,
    },
    EmergencyIncidentState.degraded: {
      EmergencyIncidentState.cloudPending,
      EmergencyIncidentState.cloudAccepted,
      EmergencyIncidentState.contactsNotified,
      EmergencyIncidentState.communityOffered,
      EmergencyIncidentState.respondersAccepted,
      EmergencyIncidentState.respondersEnRoute,
      EmergencyIncidentState.helpArrived,
      EmergencyIncidentState.escalatedToEmergencyServices,
      EmergencyIncidentState.resolved,
      EmergencyIncidentState.cancelled,
      EmergencyIncidentState.expired,
    },
    EmergencyIncidentState.escalatedToEmergencyServices: {
      EmergencyIncidentState.respondersAccepted,
      EmergencyIncidentState.respondersEnRoute,
      EmergencyIncidentState.helpArrived,
      EmergencyIncidentState.degraded,
      EmergencyIncidentState.resolved,
      EmergencyIncidentState.cancelled,
    },
    EmergencyIncidentState.resolved: {},
    EmergencyIncidentState.cancelled: {},
    EmergencyIncidentState.expired: {},
  };

  static bool canTransition(
    EmergencyIncidentState from,
    EmergencyIncidentState to,
  ) =>
      from == to || (_allowed[from]?.contains(to) ?? false);

  static void validateTransition(
    EmergencyIncidentState from,
    EmergencyIncidentState to,
  ) {
    if (!canTransition(from, to)) {
      throw StateError(
          'Invalid emergency transition: ${from.name} -> ${to.name}');
    }
  }
}
