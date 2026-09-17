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
    assert can_transition(IncidentState.SUSPECTED, IncidentState.VERIFYING)
    assert can_transition(IncidentState.SUSPECTED, IncidentState.RESPONDING)
    assert can_transition(IncidentState.SUSPECTED, IncidentState.RESOLVED)
    assert can_transition(IncidentState.VERIFYING, IncidentState.RESPONDING)
    assert can_transition(IncidentState.VERIFYING, IncidentState.RESOLVED)
    assert can_transition(IncidentState.RESPONDING, IncidentState.RESOLVED)


def test_invalid_transitions():
    # Cannot go backward
    assert not can_transition(IncidentState.RESPONDING, IncidentState.VERIFYING)
    assert not can_transition(IncidentState.VERIFYING, IncidentState.SUSPECTED)
    assert not can_transition(IncidentState.RESOLVED, IncidentState.SUSPECTED)
    assert not can_transition(IncidentState.RESOLVED, IncidentState.RESPONDING)

    # Invalid values
    assert not can_transition("UNKNOWN", IncidentState.VERIFYING)
    assert not can_transition(IncidentState.SUSPECTED, "UNKNOWN")


if __name__ == "__main__":
    pytest.main([__file__])
