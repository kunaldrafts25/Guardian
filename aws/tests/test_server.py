"""
Integration test for Guardian FastAPI server (mirrors API Gateway)
"""

import os
import pytest

os.environ["GUARDIAN_DEV_MODE"] = "true"
from fastapi.testclient import TestClient
from aws.server import app
from aws.session_service import create_session


client = TestClient(
    app,
    headers={
        "Authorization": "Bearer dev_access_token_test_user",
        "X-Guardian-Session-ID": "dev-session",
    },
)
unauthenticated_client = TestClient(app)
other_user_client = TestClient(
    app,
    headers={
        "Authorization": "Bearer dev_access_token_other_user",
        "X-Guardian-Session-ID": "dev-session",
    },
)


def test_protected_endpoints_require_bearer_token():
    response = unauthenticated_client.post("/simulate/fall")
    assert response.status_code == 401


def test_sign_out_requires_an_authenticated_bearer_session():
    response = unauthenticated_client.post(
        "/auth/sign-out",
        json={"access_token": "someone-elses-token"},
    )
    assert response.status_code == 401


def test_revoked_session_is_denied_on_the_next_api_request():
    session = create_session(
        "session_test_user",
        "refresh-token",
        "Guardian Android device",
        "android",
    )
    session_client = TestClient(
        app,
        headers={
            "Authorization": "Bearer dev_access_token_session_test_user",
            "X-Guardian-Session-ID": session["session_id"],
        },
    )

    listed = session_client.get("/auth/sessions")
    assert listed.status_code == 200
    assert listed.json()["sessions"][0]["current"] is True

    revoked = session_client.delete(f"/auth/sessions/{session['session_id']}")
    assert revoked.status_code == 200
    assert session_client.get("/auth/sessions").status_code == 401


def test_incident_is_not_readable_by_another_user():
    created = client.post("/simulate/fall")
    assert created.status_code == 200
    incident_id = created.json()["incident"]["incident_id"]

    response = other_user_client.get(f"/incidents/{incident_id}")
    assert response.status_code == 403


def test_push_contract_rejects_client_supplied_user_identity():
    response = client.post(
        "/push/send",
        json={
            "user_id": "another_user",
            "title": "test",
            "body": "test",
        },
    )
    assert response.status_code == 422


def test_incident_contract_rejects_client_supplied_user_identity():
    response = client.post(
        "/incidents",
        json={"user_id": "another_user", "event_type": "sos_button"},
    )
    assert response.status_code == 422


def test_assistant_rejects_client_authored_incident_context():
    response = client.post(
        "/assistant/chat",
        json={
            "message": "What should I do?",
            "context": {"incident_state": "help_arrived"},
        },
    )
    assert response.status_code == 422


def test_assistant_cannot_ground_on_another_users_incident():
    created = client.post("/simulate/fall")
    incident_id = created.json()["incident"]["incident_id"]

    response = other_user_client.post(
        "/assistant/chat",
        json={"message": "Summarize this", "incident_id": incident_id},
    )
    assert response.status_code == 403


def test_health_endpoint():
    response = client.get("/")
    assert response.status_code == 200
    assert response.json()["status"] == "online"


def test_e2e_fall_simulation_flow():
    # 1. Simulate Fall
    sim_resp = client.post("/simulate/fall")
    assert sim_resp.status_code == 200
    data = sim_resp.json()
    incident_id = data["incident"]["incident_id"]
    assert incident_id.startswith("inc_")

    # 2. Get incident details
    inc_resp = client.get(f"/incidents/{incident_id}")
    assert inc_resp.status_code == 200
    inc_data = inc_resp.json()
    assert inc_data["event_type"] == "fall_detected"

    # 3. Trigger Agent Step
    agent_resp = client.post(f"/incidents/{incident_id}/agent-step")
    assert agent_resp.status_code == 200
    agent_data = agent_resp.json()
    assert agent_data["decision"] in (
        "REQUEST_USER_VERIFICATION",
        "ESCALATE_IMMEDIATELY",
        "ESCALATE_IMMEDIATELY_WITH_COMMUNITY",
    )

    # 4. User confirms I'M OK
    ok_resp = client.put(
        f"/incidents/{incident_id}/status",
        json={"state": "RESOLVED", "note": "User clicked I'M OK"},
    )
    assert ok_resp.status_code == 200
    assert ok_resp.json()["state"] == "RESOLVED"

    # 5. Verify Timeline has audit steps
    t_resp = client.get(f"/incidents/{incident_id}/timeline")
    assert t_resp.status_code == 200
    timeline = t_resp.json()["timeline"]
    assert len(timeline) >= 2


if __name__ == "__main__":
    pytest.main([__file__])
