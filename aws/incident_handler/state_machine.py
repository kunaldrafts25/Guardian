"""
Guardian Incident State Machine
Enforces valid state transitions and conditional guarantees.
"""

from typing import Dict, Any, List, Optional
from enum import Enum


class IncidentState(str, Enum):
    SUSPECTED = "SUSPECTED"
    VERIFYING = "VERIFYING"
    RESPONDING = "RESPONDING"
    RESOLVED = "RESOLVED"


# Strict transition graph
VALID_TRANSITIONS: Dict[IncidentState, List[IncidentState]] = {
    IncidentState.SUSPECTED: [
        IncidentState.VERIFYING,
        IncidentState.RESPONDING,
        IncidentState.RESOLVED,
    ],
    IncidentState.VERIFYING: [
        IncidentState.RESPONDING,
        IncidentState.RESOLVED,
    ],
    IncidentState.RESPONDING: [
        IncidentState.RESOLVED,
    ],
    IncidentState.RESOLVED: [],  # Terminal state
}


def can_transition(current_state: str, new_state: str) -> bool:
    """Validate if a state transition is permitted."""
    try:
        curr = IncidentState(current_state)
        nxt = IncidentState(new_state)
        return nxt in VALID_TRANSITIONS.get(curr, [])
    except (ValueError, KeyError):
        return False
