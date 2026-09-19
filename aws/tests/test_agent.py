"""
Unit tests for Guardian Autonomous Agent and Tools
"""

import pytest
from aws.incident_handler.handler import create_incident, IncidentState
from aws.agent.tools import (
    get_incident_context,
    assess_risk,
    ask_user_confirmation,
    notify_trusted_contact,
)
from aws.agent.guardian_agent import execute_agent_reasoning


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
    n_res = notify_trusted_contact(incident_id)
    assert n_res["state"] == "CONTACTS_NOTIFIED"
    assert n_res["contact_notified"] is not None


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
    assert res["action_result"]["contact_alert"]["state"] == "CONTACTS_NOTIFIED"


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
    assert res["action_result"]["community_dispatch"]["status"] == "COMMUNITY_DISPATCHED"



def test_community_responder_trust_gating_and_anti_solo_quorum():
    from aws.agent.tools import find_nearby_responders, dispatch_community_alert, accept_rescue_mission

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
    dispatch_res = dispatch_community_alert(iid)
    assert dispatch_res["status"] == "COMMUNITY_DISPATCHED"
    assert dispatch_res["dispatched_count"] >= 2
    assert "broadcast_payload" in dispatch_res

    # 4. Accept rescue mission: Unlocks precision coordinates
    accept_res = accept_rescue_mission(iid, responder_id="resp_01")
    assert accept_res["responder"]["mission_status"] == "EN_ROUTE"
    assert "precision_coordinates" in accept_res
    assert accept_res["precision_coordinates"]["latitude"] == 19.0760

    # 5. Low trust responder cannot accept mission
    with pytest.raises(PermissionError):
        accept_rescue_mission(iid, responder_id="resp_low_trust")


if __name__ == "__main__":
    pytest.main([__file__])

