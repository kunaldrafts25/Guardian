"""
Unit tests for Guardian Incident State Machine
"""

import pytest
from aws.incident_handler.state_machine import (
    IncidentState,
    can_transition,
    VALID_TRANSITIONS,
)


def test_valid_transitions():
    assert can_transition(IncidentState.TRIGGERED, IncidentState.CLOUD_PENDING)
    assert can_transition(IncidentState.CLOUD_PENDING, IncidentState.CLOUD_ACCEPTED)
    assert can_transition(IncidentState.CLOUD_ACCEPTED, IncidentState.CONTACTS_NOTIFIED)
    assert can_transition(IncidentState.CONTACTS_NOTIFIED, IncidentState.COMMUNITY_OFFERED)
    assert can_transition(IncidentState.COMMUNITY_OFFERED, IncidentState.RESPONDERS_ACCEPTED)
    assert can_transition(IncidentState.RESPONDERS_ACCEPTED, IncidentState.RESPONDERS_EN_ROUTE)
    assert can_transition(IncidentState.RESPONDERS_EN_ROUTE, IncidentState.HELP_ARRIVED)
    assert can_transition(IncidentState.HELP_ARRIVED, IncidentState.RESOLVED)


def test_invalid_transitions():
    # Cannot go backward
    assert not can_transition(IncidentState.CONTACTS_NOTIFIED, IncidentState.CLOUD_PENDING)
    assert not can_transition(IncidentState.RESOLVED, IncidentState.CLOUD_ACCEPTED)
    assert not can_transition(IncidentState.CANCELLED, IncidentState.RESPONDERS_ACCEPTED)

    # Invalid values
    assert not can_transition("UNKNOWN", IncidentState.CLOUD_ACCEPTED)
    assert not can_transition(IncidentState.TRIGGERED, "UNKNOWN")


if __name__ == "__main__":
    pytest.main([__file__])
