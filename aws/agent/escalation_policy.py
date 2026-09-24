"""
Guardian Emergency Response: Deterministic Progressive Escalation Policy
v3.0 - P1 Safety Architecture

Defines the progressive responder-radius escalation ladder, timeout rules,
candidate caps, quorum requirements, redispatch conditions, and multi-responder invariants.
"""

from dataclasses import dataclass
from typing import Dict, Any, List, Optional
import os


@dataclass(frozen=True)
class EscalationStage:
    stage_index: int
    radius_meters: float
    invitation_timeout_seconds: int
    max_candidates: int
    required_quorum: int
    description: str


# Centrally configurable escalation ladder
DEFAULT_ESCALATION_STAGES: List[EscalationStage] = [
    EscalationStage(
        stage_index=1,
        radius_meters=1000.0,
        invitation_timeout_seconds=60,
        max_candidates=3,
        required_quorum=1,
        description="Immediate vicinity (1 km) alert",
    ),
    EscalationStage(
        stage_index=2,
        radius_meters=2000.0,
        invitation_timeout_seconds=90,
        max_candidates=5,
        required_quorum=1,
        description="Local neighborhood (2 km) expansion",
    ),
    EscalationStage(
        stage_index=3,
        radius_meters=5000.0,
        invitation_timeout_seconds=120,
        max_candidates=8,
        required_quorum=1,
        description="District area (5 km) expansion",
    ),
    EscalationStage(
        stage_index=4,
        radius_meters=10000.0,
        invitation_timeout_seconds=180,
        max_candidates=10,
        required_quorum=1,
        description="Wide perimeter (10 km) final expansion",
    ),
]

# Invariant: Maximum simultaneously accepted responders per incident
MAX_ACCEPTED_RESPONDERS = int(os.environ.get("GUARDIAN_MAX_ACCEPTED_RESPONDERS", "2"))


def get_escalation_stage(stage_index: int) -> EscalationStage:
    """Return the escalation stage configuration for a given 1-based index."""
    if stage_index < 1:
        stage_index = 1
    if stage_index <= len(DEFAULT_ESCALATION_STAGES):
        return DEFAULT_ESCALATION_STAGES[stage_index - 1]
    
    # Beyond max stage: terminal max stage
    last = DEFAULT_ESCALATION_STAGES[-1]
    return EscalationStage(
        stage_index=stage_index,
        radius_meters=last.radius_meters,
        invitation_timeout_seconds=last.invitation_timeout_seconds,
        max_candidates=last.max_candidates,
        required_quorum=last.required_quorum,
        description="Maximum radius reached; awaiting emergency authorities",
    )


def is_max_stage(stage_index: int) -> bool:
    """Return True if stage is at or beyond the maximum radius stage."""
    return stage_index >= len(DEFAULT_ESCALATION_STAGES)


def get_stage_count() -> int:
    return len(DEFAULT_ESCALATION_STAGES)
