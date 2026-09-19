"""
Unit tests for AWS Lambda Incident Handler
"""

import json
import pytest
from aws.incident_handler.handler import lambda_handler, IncidentState


def test_create_incident_and_idempotency():
    event_id = "test_evt_101"
    payload = {
        "event_id": event_id,
        "user_id": "usr_99",
        "event_type": "fall_detected",
        "location": {"latitude": 19.076, "longitude": 72.877},
        "motion_data": {"g_force": 4.5},
    }

    # First POST
    req = {
        "httpMethod": "POST",
        "path": "/incidents",
        "body": json.dumps(payload),
    }
    resp = lambda_handler(req, None)
    assert resp["statusCode"] == 201
    data = json.loads(resp["body"])
    incident_id = data["incident_id"]
    assert data["state"] == IncidentState.CLOUD_ACCEPTED.value
    assert data["risk_assessment"]["level"] in ("HIGH", "CRITICAL")

    # Idempotent second POST with identical event_id
    resp2 = lambda_handler(req, None)
    assert resp2["statusCode"] == 201
    data2 = json.loads(resp2["body"])
    assert data2["incident_id"] == incident_id  # Returns the exact same incident!


def test_state_transitions_and_timeline():
    # 1. Create incident
    req = {
        "httpMethod": "POST",
        "path": "/incidents",
        "body": json.dumps({
            "event_id": "test_evt_202",
            "user_id": "usr_100",
            "event_type": "prolonged_inactivity",
        }),
    }
    resp = lambda_handler(req, None)
    incident_id = json.loads(resp["body"])["incident_id"]

    # 2. Transition CLOUD_ACCEPTED -> CONTACTS_NOTIFIED
    req_verify = {
        "httpMethod": "PUT",
        "path": f"/incidents/{incident_id}/status",
        "body": json.dumps({
            "state": IncidentState.CONTACTS_NOTIFIED.value,
            "actor": "AGENT",
            "note": "Agent prompted user for 15s confirmation.",
        }),
    }
    resp_v = lambda_handler(req_verify, None)
    assert resp_v["statusCode"] == 200
    assert json.loads(resp_v["body"])["state"] == "CONTACTS_NOTIFIED"

    # 3. User responds: CONTACTS_NOTIFIED -> RESOLVED
    req_resolve = {
        "httpMethod": "PUT",
        "path": f"/incidents/{incident_id}/status",
        "body": json.dumps({
            "state": IncidentState.RESOLVED.value,
            "actor": "USER",
            "note": "User tapped I'M OK",
        }),
    }
    resp_r = lambda_handler(req_resolve, None)
    assert resp_r["statusCode"] == 200
    assert json.loads(resp_r["body"])["state"] == "RESOLVED"

    # Replays are idempotent, but a terminal incident can never reopen.
    assert lambda_handler(req_resolve, None)["statusCode"] == 200
    stale = lambda_handler(
        {
            "httpMethod": "PUT",
            "path": f"/incidents/{incident_id}/status",
            "body": json.dumps({"state": IncidentState.CONTACTS_NOTIFIED.value}),
        },
        None,
    )
    assert stale["statusCode"] == 400

    # 4. Check timeline
    req_timeline = {
        "httpMethod": "GET",
        "path": f"/incidents/{incident_id}/timeline",
    }
    resp_t = lambda_handler(req_timeline, None)
    assert resp_t["statusCode"] == 200
    events = json.loads(resp_t["body"])["timeline"]
    assert len(events) == 3


def test_invalid_transition_returns_400():
    req = {
        "httpMethod": "POST",
        "path": "/incidents",
        "body": json.dumps({"event_id": "test_evt_303"}),
    }
    resp = lambda_handler(req, None)
    incident_id = json.loads(resp["body"])["incident_id"]

    # Try illegal transition directly to an impossible state or back from resolved
    req_bad = {
        "httpMethod": "PUT",
        "path": f"/incidents/{incident_id}/status",
        "body": json.dumps({"state": "INVALID_STATE"}),
    }
    resp_bad = lambda_handler(req_bad, None)
    assert resp_bad["statusCode"] == 400


def test_nearby_responders_and_accept_handler():
    # 1. Create incident
    req = {
        "httpMethod": "POST",
        "path": "/incidents",
        "body": json.dumps({"event_id": "test_evt_handler_comm", "event_type": "hardware_power_panic"}),
    }
    resp = lambda_handler(req, None)
    incident_id = json.loads(resp["body"])["incident_id"]

    # 2. GET /incidents/{id}/nearby
    req_nearby = {
        "httpMethod": "GET",
        "path": f"/incidents/{incident_id}/nearby",
    }
    resp_n = lambda_handler(req_nearby, None)
    assert resp_n["statusCode"] == 200
    responders = json.loads(resp_n["body"])["nearby_responders"]
    assert len(responders) >= 2

    # 3. POST /incidents/{id}/accept
    req_accept = {
        "httpMethod": "POST",
        "path": f"/incidents/{incident_id}/accept",
        "body": json.dumps({"responder_id": "resp_01"}),
    }
    resp_a = lambda_handler(req_accept, None)
    assert resp_a["statusCode"] == 200
    res_data = json.loads(resp_a["body"])
    assert res_data["mission"]["status"] == "ACCEPTED"
    assert "precision_coordinates" not in res_data
    assert "navigation_grant" in res_data

    # 4. POST /responders/heartbeat
    req_hb = {
        "httpMethod": "POST",
        "path": "/responders/heartbeat",
        "body": json.dumps({
            "responder_id": "resp_new_test",
            "name": "Local Helper",
            "latitude": 19.0765,
            "longitude": 72.8780,
            "trust_score": 88,
        }),
    }
    resp_hb = lambda_handler(req_hb, None)
    assert resp_hb["statusCode"] == 200
    hb_data = json.loads(resp_hb["body"])
    assert hb_data["responder_id"] == "resp_new_test"


if __name__ == "__main__":
    pytest.main([__file__])

