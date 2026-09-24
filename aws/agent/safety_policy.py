"""Versioned deterministic safety policy for incident and responder actions."""

from dataclasses import dataclass
from typing import FrozenSet, Tuple

from aws.agent.policy_authorization import POLICY_VERSION


TERMINAL_STATES = frozenset({"RESOLVED", "CANCELLED", "EXPIRED"})
IMMEDIATE_TRIGGER_TYPES = frozenset(
    {
        "sos_button",
        "hardware_power_panic",
        "crash_detected",
        "check_in_expired",
        "android_power_gesture",
        "android_shake",
        "android_fall",
        "manual_sos",
        "voice_sos",
        "route_deviation",
        "multi_tap",
    }
)


@dataclass(frozen=True)
class SafetyPolicyDecision:
    version: str
    decision: str
    authorized_actions: FrozenSet[str]
    reason_codes: Tuple[str, ...]
    max_responder_invitations: int
    required_responder_quorum: int
    location_precision_decimals: int

    def constraints_for(self, action: str):
        if action == "dispatch_community_alert":
            return {
                "max_responder_invitations": self.max_responder_invitations,
                "required_responder_quorum": self.required_responder_quorum,
                "location_precision_decimals": self.location_precision_decimals,
            }
        return {}


def evaluate_safety_policy(
    *,
    event_type: str,
    risk_level: str,
    incident_state: str,
    is_isolated: bool,
    owner_requested: bool = False,
) -> SafetyPolicyDecision:
    """Return the complete authority envelope without consulting an LLM."""
    normalized_event = event_type.strip().lower()
    normalized_risk = risk_level.strip().upper()
    normalized_state = incident_state.strip().upper()

    if normalized_state in TERMINAL_STATES:
        return SafetyPolicyDecision(
            version=POLICY_VERSION,
            decision="NO_ACTION_TERMINAL",
            authorized_actions=frozenset(),
            reason_codes=("INCIDENT_TERMINAL",),
            max_responder_invitations=0,
            required_responder_quorum=0,
            location_precision_decimals=2,
        )

    immediate_reasons = []
    if owner_requested:
        immediate_reasons.append("OWNER_REQUESTED_ESCALATION")
    if normalized_event in IMMEDIATE_TRIGGER_TYPES:
        immediate_reasons.append("MANDATORY_TRIGGER")
    if normalized_risk == "CRITICAL":
        immediate_reasons.append("CRITICAL_RISK")

    if immediate_reasons:
        return SafetyPolicyDecision(
            version=POLICY_VERSION,
            decision=(
                "OWNER_REQUESTED_ESCALATION"
                if owner_requested
                else "ESCALATE_IMMEDIATELY_WITH_COMMUNITY"
            ),
            authorized_actions=frozenset(
                {"notify_trusted_contact", "dispatch_community_alert"}
            ),
            reason_codes=tuple(immediate_reasons),
            max_responder_invitations=6,
            required_responder_quorum=2 if is_isolated else 1,
            location_precision_decimals=2,
        )

    if normalized_risk in {"HIGH", "MEDIUM"}:
        return SafetyPolicyDecision(
            version=POLICY_VERSION,
            decision="REQUEST_USER_VERIFICATION",
            authorized_actions=frozenset(),
            reason_codes=("ELEVATED_RISK_REQUIRES_CONFIRMATION",),
            max_responder_invitations=0,
            required_responder_quorum=0,
            location_precision_decimals=2,
        )

    return SafetyPolicyDecision(
        version=POLICY_VERSION,
        decision="MONITOR_NORMAL",
        authorized_actions=frozenset(),
        reason_codes=("NO_ESCALATION_THRESHOLD_MET",),
        max_responder_invitations=0,
        required_responder_quorum=0,
        location_precision_decimals=2,
    )
