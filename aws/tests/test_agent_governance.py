import pytest

from aws.agent import ledger, policy_authorization
from aws.agent.policy_authorization import (
    consume_policy_authorization,
    issue_policy_authorizations,
    read_policy_authorization,
)
from aws.agent.safety_policy import evaluate_safety_policy


@pytest.fixture(autouse=True)
def isolated_governance_state(monkeypatch):
    monkeypatch.setenv("GUARDIAN_DEV_MODE", "true")
    policy_authorization._CONSUMED_AUTHORIZATIONS.clear()
    ledger._LOCAL_LEDGER.clear()
    yield
    policy_authorization._CONSUMED_AUTHORIZATIONS.clear()
    ledger._LOCAL_LEDGER.clear()


def _tokens(incident_id="inc-a"):
    return issue_policy_authorizations(
        incident_id=incident_id,
        actions={"notify_trusted_contact", "dispatch_community_alert"},
        decision="ESCALATE_IMMEDIATELY_WITH_COMMUNITY",
        correlation_id="corr-1",
        actor="guardian_agent",
    )


def test_authorization_is_incident_and_action_scoped():
    token = _tokens()["notify_trusted_contact"]

    with pytest.raises(PermissionError):
        read_policy_authorization(
            token,
            expected_incident_id="inc-b",
            expected_action="notify_trusted_contact",
        )
    with pytest.raises(PermissionError):
        read_policy_authorization(
            token,
            expected_incident_id="inc-a",
            expected_action="dispatch_community_alert",
        )


def test_non_escalation_decision_cannot_mint_side_effect_authority():
    with pytest.raises(PermissionError):
        issue_policy_authorizations(
            incident_id="inc-a",
            actions={"notify_trusted_contact"},
            decision="MONITOR_NORMAL",
            correlation_id="corr-1",
            actor="guardian_agent",
        )


def test_authorization_rejects_tampering_and_replay():
    token = _tokens()["notify_trusted_contact"]
    tampered = f"{token[:-1]}{'A' if token[-1] != 'A' else 'B'}"
    with pytest.raises(PermissionError):
        consume_policy_authorization(
            tampered,
            expected_incident_id="inc-a",
            expected_action="notify_trusted_contact",
        )

    consume_policy_authorization(
        token,
        expected_incident_id="inc-a",
        expected_action="notify_trusted_contact",
    )
    with pytest.raises(PermissionError):
        consume_policy_authorization(
            token,
            expected_incident_id="inc-a",
            expected_action="notify_trusted_contact",
        )


def test_agent_ledger_redacts_sensitive_evidence():
    ledger.append_agent_event(
        incident_id="inc-a",
        correlation_id="corr-1",
        event_type="TOOL_COMPLETED",
        policy_version="guardian-safety-v1",
        evidence={
            "status": "COMPLETED",
            "latitude": 19.076,
            "longitude": 72.877,
            "navigation_grant": "secret",
            "message_id": "provider-123",
        },
    )

    event = ledger.list_agent_events("inc-a")[0]
    assert event["evidence"] == {
        "status": "COMPLETED",
        "message_id": "provider-123",
    }


def test_policy_binds_quorum_cap_and_coarse_precision():
    decision = evaluate_safety_policy(
        event_type="hardware_power_panic",
        risk_level="CRITICAL",
        incident_state="CLOUD_ACCEPTED",
        is_isolated=True,
    )

    assert decision.decision == "ESCALATE_IMMEDIATELY_WITH_COMMUNITY"
    assert decision.required_responder_quorum == 2
    assert decision.max_responder_invitations == 6
    assert decision.location_precision_decimals == 2
    assert decision.authorized_actions == {
        "notify_trusted_contact",
        "dispatch_community_alert",
    }


def test_terminal_incident_policy_cannot_authorize_side_effects():
    decision = evaluate_safety_policy(
        event_type="hardware_power_panic",
        risk_level="CRITICAL",
        incident_state="RESOLVED",
        is_isolated=False,
        owner_requested=True,
    )

    assert decision.decision == "NO_ACTION_TERMINAL"
    assert decision.authorized_actions == frozenset()
