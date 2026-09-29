"""Versioned deterministic safety policy for incident and responder actions."""

from dataclasses import dataclass
from typing import FrozenSet, Tuple

from aws.agent.policy_authorization import POLICY_VERSION


TERMINAL_STATES = frozenset({"RESOLVED", "CANCELLED", "EXPIRED"})
AUTOMATIC_INFERRED_TRIGGER_TYPES = frozenset(
    {
        "android_fall",
        "fall_detected",
        "crash_detected",
        "android_shake",
        "shake_detected",
        "route_deviation",
    }
)
IMMEDIATE_TRIGGER_TYPES = frozenset(
    {
        "sos_button",
        "hardware_power_panic",
        "crash_detected",
        "check_in_expired",
        "android_power_gesture",
        "manual_sos",
        "voice_sos",
        "multi_tap",
        "route_deviation_timeout",
        "route_deviation_user_sos",
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
    verification_timed_out: bool = False,
    trigger_origin: str = "",
    trigger_trust_level: str = "",
) -> SafetyPolicyDecision:
    """Return the complete authority envelope without consulting an LLM."""
    normalized_event = event_type.strip().lower()
    normalized_risk = risk_level.strip().upper()
    normalized_state = incident_state.strip().upper()
    normalized_origin = trigger_origin.strip().upper()
    normalized_trust = trigger_trust_level.strip().upper()
    unattested_automatic = (
        normalized_event in AUTOMATIC_INFERRED_TRIGGER_TYPES
        and (
            normalized_trust.startswith("UNATTESTED")
            or normalized_origin in {"CLIENT_REPORTED", "DEVICE_REPORTED", "DEVICE_NATIVE_REPORTED"}
            or (not normalized_origin and not normalized_trust)
        )
    )

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
    if verification_timed_out:
        immediate_reasons.append("USER_VERIFICATION_TIMED_OUT")
    if owner_requested:
        immediate_reasons.append("OWNER_REQUESTED_ESCALATION")
    if normalized_event in IMMEDIATE_TRIGGER_TYPES and not unattested_automatic:
        immediate_reasons.append("MANDATORY_TRIGGER")
    if normalized_risk == "CRITICAL" and not unattested_automatic:
        immediate_reasons.append("CRITICAL_RISK")

    # Automatic sensor telemetry from a mobile client is useful evidence, but
    # without device attestation it cannot be the sole authority for exposing
    # an incident to community responders. Explicit distress and a missed
    # verification deadline remain immediate and never depend on attestation.
    if unattested_automatic and not owner_requested and not verification_timed_out:
        return SafetyPolicyDecision(
            version=POLICY_VERSION,
            decision="REQUEST_USER_VERIFICATION",
            authorized_actions=frozenset(),
            reason_codes=("UNATTESTED_AUTOMATIC_TRIGGER_REQUIRES_CONFIRMATION",),
            max_responder_invitations=0,
            required_responder_quorum=0,
            location_precision_decimals=2,
        )

    if immediate_reasons:
        decision = (
            "VERIFICATION_TIMEOUT_ESCALATION"
            if verification_timed_out
            else "OWNER_REQUESTED_ESCALATION"
            if owner_requested
            else "ESCALATE_IMMEDIATELY_WITH_COMMUNITY"
        )
        return SafetyPolicyDecision(
            version=POLICY_VERSION,
            decision=decision,
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
