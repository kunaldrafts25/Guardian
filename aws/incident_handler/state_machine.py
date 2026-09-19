"""Canonical Guardian incident lifecycle shared with the mobile domain model."""

from enum import Enum
from typing import Dict, FrozenSet


class IncidentState(str, Enum):
    TRIGGERED = "TRIGGERED"
    LOCAL_DISPATCHING = "LOCAL_DISPATCHING"
    CLOUD_PENDING = "CLOUD_PENDING"
    CLOUD_ACCEPTED = "CLOUD_ACCEPTED"
    CONTACTS_NOTIFIED = "CONTACTS_NOTIFIED"
    COMMUNITY_OFFERED = "COMMUNITY_OFFERED"
    RESPONDERS_ACCEPTED = "RESPONDERS_ACCEPTED"
    RESPONDERS_EN_ROUTE = "RESPONDERS_EN_ROUTE"
    HELP_ARRIVED = "HELP_ARRIVED"
    DEGRADED = "DEGRADED"
    ESCALATED_TO_EMERGENCY_SERVICES = "ESCALATED_TO_EMERGENCY_SERVICES"
    RESOLVED = "RESOLVED"
    CANCELLED = "CANCELLED"
    EXPIRED = "EXPIRED"

    @property
    def is_terminal(self) -> bool:
        return self in {
            IncidentState.RESOLVED,
            IncidentState.CANCELLED,
            IncidentState.EXPIRED,
        }


_TERMINAL = frozenset(
    {IncidentState.RESOLVED, IncidentState.CANCELLED, IncidentState.EXPIRED}
)

VALID_TRANSITIONS: Dict[IncidentState, FrozenSet[IncidentState]] = {
    IncidentState.TRIGGERED: frozenset(
        {
            IncidentState.LOCAL_DISPATCHING,
            IncidentState.CLOUD_PENDING,
            IncidentState.CLOUD_ACCEPTED,
            IncidentState.DEGRADED,
            IncidentState.RESOLVED,
            IncidentState.CANCELLED,
        }
    ),
    IncidentState.LOCAL_DISPATCHING: frozenset(
        {
            IncidentState.CLOUD_PENDING,
            IncidentState.CLOUD_ACCEPTED,
            IncidentState.CONTACTS_NOTIFIED,
            IncidentState.DEGRADED,
            IncidentState.ESCALATED_TO_EMERGENCY_SERVICES,
            IncidentState.RESOLVED,
            IncidentState.CANCELLED,
        }
    ),
    IncidentState.CLOUD_PENDING: frozenset(
        {
            IncidentState.CLOUD_ACCEPTED,
            IncidentState.CONTACTS_NOTIFIED,
            IncidentState.DEGRADED,
            IncidentState.RESOLVED,
            IncidentState.CANCELLED,
        }
    ),
    IncidentState.CLOUD_ACCEPTED: frozenset(
        {
            IncidentState.CONTACTS_NOTIFIED,
            IncidentState.COMMUNITY_OFFERED,
            IncidentState.RESPONDERS_ACCEPTED,
            IncidentState.DEGRADED,
            IncidentState.ESCALATED_TO_EMERGENCY_SERVICES,
        }
        | _TERMINAL
    ),
    IncidentState.CONTACTS_NOTIFIED: frozenset(
        {
            IncidentState.COMMUNITY_OFFERED,
            IncidentState.RESPONDERS_ACCEPTED,
            IncidentState.DEGRADED,
            IncidentState.ESCALATED_TO_EMERGENCY_SERVICES,
        }
        | _TERMINAL
    ),
    IncidentState.COMMUNITY_OFFERED: frozenset(
        {
            IncidentState.RESPONDERS_ACCEPTED,
            IncidentState.DEGRADED,
            IncidentState.ESCALATED_TO_EMERGENCY_SERVICES,
        }
        | _TERMINAL
    ),
    IncidentState.RESPONDERS_ACCEPTED: frozenset(
        {
            IncidentState.RESPONDERS_EN_ROUTE,
            IncidentState.DEGRADED,
            IncidentState.ESCALATED_TO_EMERGENCY_SERVICES,
        }
        | _TERMINAL
    ),
    IncidentState.RESPONDERS_EN_ROUTE: frozenset(
        {
            IncidentState.HELP_ARRIVED,
            IncidentState.DEGRADED,
            IncidentState.ESCALATED_TO_EMERGENCY_SERVICES,
        }
        | _TERMINAL
    ),
    IncidentState.HELP_ARRIVED: frozenset(
        {IncidentState.RESOLVED, IncidentState.CANCELLED}
    ),
    IncidentState.DEGRADED: frozenset(
        {
            IncidentState.CLOUD_PENDING,
            IncidentState.CLOUD_ACCEPTED,
            IncidentState.CONTACTS_NOTIFIED,
            IncidentState.COMMUNITY_OFFERED,
            IncidentState.RESPONDERS_ACCEPTED,
            IncidentState.RESPONDERS_EN_ROUTE,
            IncidentState.HELP_ARRIVED,
            IncidentState.ESCALATED_TO_EMERGENCY_SERVICES,
        }
        | _TERMINAL
    ),
    IncidentState.ESCALATED_TO_EMERGENCY_SERVICES: frozenset(
        {
            IncidentState.RESPONDERS_ACCEPTED,
            IncidentState.RESPONDERS_EN_ROUTE,
            IncidentState.HELP_ARRIVED,
            IncidentState.DEGRADED,
            IncidentState.RESOLVED,
            IncidentState.CANCELLED,
        }
    ),
    IncidentState.RESOLVED: frozenset(),
    IncidentState.CANCELLED: frozenset(),
    IncidentState.EXPIRED: frozenset(),
}


def can_transition(current_state: str, new_state: str) -> bool:
    """Return whether the requested transition is valid and non-regressive."""
    try:
        current = IncidentState(current_state)
        target = IncidentState(new_state)
    except ValueError:
        return False
    return current == target or target in VALID_TRANSITIONS[current]
