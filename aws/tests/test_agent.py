"""
Unit tests for Guardian Autonomous Agent and Tools
"""

import pytest
from unittest.mock import patch
from aws.incident_handler.handler import create_incident, IncidentState
from aws.agent.tools import (
    get_incident_context,
    assess_risk,
    ask_user_confirmation,
    notify_trusted_contact,
)
from aws.agent.guardian_agent import execute_agent_reasoning
from aws.agent.policy_authorization import issue_policy_authorizations
from aws.agent.ledger import list_agent_events


def _tool_token(incident_id: str, action: str) -> str:
    constraints = (
        {
            "max_responder_invitations": 6,
            "required_responder_quorum": 1,
            "location_precision_decimals": 2,
        }
        if action == "dispatch_community_alert"
        else {}
    )
    return issue_policy_authorizations(
        incident_id=incident_id,
        actions={action},
        decision="OWNER_REQUESTED_ESCALATION",
        correlation_id=f"test:{incident_id}:{action}",
        actor="test_policy",
        action_constraints={action: constraints},
    )[action]


def test_agent_tools_execution():
    # 1. Create a suspected incident
    rec = create_incident({
        "event_id": "test_agent_evt_1",
        "user_id": "test_user",
        "event_type": "fall_detected",
        "location": {"latitude": 19.0760, "longitude": 72.8777},
        "motion_data": {"g_force": 4.5},
        "contacts": [{"id": "contact_1", "name": "Test Contact", "phone": "+10000000000", "authorized": True}],
    })
    incident_id = rec["incident_id"]

    # 2. Tool 1: Context
    ctx = get_incident_context(incident_id)
    assert ctx["incident_id"] == incident_id
    assert len(ctx["contacts"]) >= 1

    # 3. Tool 2: Assess Risk
    r = assess_risk(incident_id, ctx)
    assert r["risk_assessment"]["level"] in ("HIGH", "CRITICAL")

    # 4. Tool 3: Ask User
    u_res = ask_user_confirmation(incident_id, timeout_seconds=15)
    assert u_res["status"] == "CONFIRMATION_REQUESTED"
    assert u_res["current_state"] == "CLOUD_ACCEPTED"

    # 5. Tool 4: Notify Contact (Policy check + SNS)
    n_res = notify_trusted_contact(
        incident_id,
        _tool_token(incident_id, "notify_trusted_contact"),
    )
    assert n_res["state"] == "CLOUD_ACCEPTED"
    assert n_res["delivery_status"] == "DEV_MODE_NOT_SENT"
    assert n_res["contact_notified"] is None


def test_agent_autonomous_reasoning_flow():
    # Test Fall -> Agent asks user verification
    fall_rec = create_incident({
        "event_id": "test_agent_evt_2",
        "user_id": "test_user_2",
        "event_type": "fall_detected",
        "motion_data": {"g_force": 3.8},
    })
    iid = fall_rec["incident_id"]

    res = execute_agent_reasoning(iid)
    assert res["decision"] == "REQUEST_USER_VERIFICATION"
    assert "reasons" in res["risk_assessment"]
    assert len(res["rationale"]) > 10


def test_agent_critical_immediate_escalation():
    # Test Direct SOS -> Immediate escalation
    sos_rec = create_incident({
        "event_id": "test_agent_evt_3",
        "user_id": "test_user_3",
        "event_type": "sos_button",
        "contacts": [{"id": "contact_1", "name": "Test Contact", "phone": "+10000000000", "authorized": True}],
    })
    iid = sos_rec["incident_id"]

    res = execute_agent_reasoning(iid)
    assert "ESCALATE_IMMEDIATELY" in res["decision"]
    assert res["action_result"]["contact_alert"]["delivery_status"] == "DEV_MODE_NOT_SENT"
    assert res["action_result"]["contact_alert"]["state"] == "CLOUD_ACCEPTED"


def test_bedrock_advice_cannot_downgrade_deterministic_panic_policy():
    panic = create_incident({
        "event_id": "test_agent_policy_guard",
        "user_id": "policy_user",
        "event_type": "hardware_power_panic",
        "contacts": [{"id": "c1", "name": "Test", "phone": "+10000000000", "authorized": True}],
    })
    advisory = {
        "threat_level": "LOW",
        "confidence_score": 0.99,
        "decision": "MONITOR_NORMAL",
        "rationale": "No action recommended.",
    }
    with patch("aws.agent.guardian_agent._query_bedrock_llm", return_value=advisory):
        result = execute_agent_reasoning(panic["incident_id"])
    assert result["decision"] == "ESCALATE_IMMEDIATELY_WITH_COMMUNITY"
    assert result["provider"] == "Deterministic policy v1 + Amazon Bedrock advisory"


def test_hardware_panic_immediate_critical_and_community_dispatch():
    # Test Hardware 3-Tap Panic -> Critical score 0.98, immediate escalation
    panic_rec = create_incident({
        "event_id": "test_agent_panic_1",
        "user_id": "test_panic_user",
        "event_type": "hardware_power_panic",
        "location": {"latitude": 19.0760, "longitude": 72.8777, "is_isolated": False},
        "contacts": [{"id": "contact_1", "name": "Test Contact", "phone": "+10000000000", "authorized": True}],
    })
    iid = panic_rec["incident_id"]
    assert panic_rec["risk_assessment"]["score"] >= 0.95
    assert panic_rec["risk_assessment"]["level"] == "CRITICAL"

    # Agent must escalate immediately without 15s verification delay
    res = execute_agent_reasoning(iid)
    assert res["decision"] == "ESCALATE_IMMEDIATELY_WITH_COMMUNITY"
    assert "community_dispatch" in res["action_result"]
    assert res["action_result"]["community_dispatch"]["status"] == "INVITATIONS_CREATED"
    event_types = {
        event["event_type"] for event in list_agent_events(iid)
    }
    assert {
        "CONTEXT_ASSESSED",
        "ACTION_PROPOSED",
        "POLICY_DECIDED",
        "ACTION_AUTHORIZED",
        "TOOL_REQUESTED",
        "TOOL_COMPLETED",
        "AGENT_RUN_COMPLETED",
    }.issubset(event_types)



def test_community_responder_trust_gating_and_anti_solo_quorum():
    from aws.agent.tools import (
        accept_rescue_mission,
        dispatch_community_alert,
        find_nearby_responders,
        get_authorized_incident_location,
        list_responder_invitations,
        transition_rescue_mission,
    )

    # 1. Create incident in non-isolated zone
    rec = create_incident({
        "event_id": "test_comm_1",
        "user_id": "test_user_comm",
        "event_type": "hardware_power_panic",
        "location": {"latitude": 19.0760, "longitude": 72.8777, "is_isolated": False},
    })
    iid = rec["incident_id"]

    # 2. Find nearby responders: Trust Gating Check (score >= 70)
    responders = find_nearby_responders(iid, radius_meters=1500)
    assert len(responders) >= 2
    # resp_low_trust (score 45) must NOT be in eligible list
    assert all(r["trust_score"] >= 70 for r in responders)
    assert all(r["responder_id"] != "resp_low_trust" for r in responders)

    # 3. Dispatch community alert: Anti-Solo Quorum check passes with >=2 helpers
    dispatch_res = dispatch_community_alert(
        iid,
        _tool_token(iid, "dispatch_community_alert"),
    )
    assert dispatch_res["status"] == "INVITATIONS_CREATED"
    assert dispatch_res["invite_count"] >= 2
    assert dispatch_res["dispatched_count"] == 0
    assert "invitation_payload" in dispatch_res
    invitations = list_responder_invitations("resp_01")
    assert len(invitations) == 1
    assert invitations[0]["approximate_location"] == {
        "latitude": 19.08,
        "longitude": 72.88,
    }
    assert "navigation_grant_hash" not in invitations[0]

    # A replay is idempotent and cannot send/create a second invitation.
    replay = dispatch_community_alert(
        iid,
        _tool_token(iid, "dispatch_community_alert"),
    )
    assert replay["status"] == "ALREADY_DISPATCHED"

    # 4. Acceptance reveals only a coarse area and a bound short-lived grant.
    accept_res = accept_rescue_mission(iid, responder_id="resp_01")
    assert accept_res["mission"]["status"] == "ACCEPTED"
    assert "precision_coordinates" not in accept_res
    assert accept_res["approximate_location"]["latitude"] == 19.08
    authorized = get_authorized_incident_location(
        iid, "resp_01", accept_res["navigation_grant"]
    )
    assert authorized["latitude"] == 19.0760
    with pytest.raises(PermissionError):
        get_authorized_incident_location(iid, "resp_01", "invalid-grant")

    from aws.agent import tools as agent_tools

    agent_tools._LOCAL_RESPONDERS["resp_01"]["trust_score"] = 0
    with pytest.raises(PermissionError):
        get_authorized_incident_location(
            iid, "resp_01", accept_res["navigation_grant"]
        )
    agent_tools._LOCAL_RESPONDERS["resp_01"]["trust_score"] = 92

    mission_id = accept_res["mission"]["mission_id"]
    en_route = transition_rescue_mission(mission_id, "resp_01", "EN_ROUTE")
    assert en_route["status"] == "EN_ROUTE"
    arrived = transition_rescue_mission(mission_id, "resp_01", "ARRIVED")
    assert arrived["status"] == "ARRIVED"
    with pytest.raises(PermissionError):
        get_authorized_incident_location(
            iid, "resp_01", accept_res["navigation_grant"]
        )
    completed = transition_rescue_mission(mission_id, "resp_01", "COMPLETED")
    assert completed["status"] == "COMPLETED"
    assert "navigation_grant_hash" not in completed
    with pytest.raises(ValueError):
        transition_rescue_mission(mission_id, "resp_01", "EN_ROUTE")

    # 5. Low trust responder cannot accept mission
    with pytest.raises(PermissionError):
        accept_rescue_mission(iid, responder_id="resp_low_trust")


if __name__ == "__main__":
    pytest.main([__file__])

