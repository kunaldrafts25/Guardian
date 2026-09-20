"""
Integration test for Guardian FastAPI server (mirrors API Gateway)
"""

import os
from datetime import datetime, timezone
from urllib.parse import quote
from unittest.mock import patch
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


def create_real_incident(api_client=client, event_type="fall_detected"):
    response = api_client.post(
        "/incidents",
        json={
            "event_type": event_type,
            "location": {"latitude": 19.0760, "longitude": 72.8777},
            "motion_data": {"g_force": 4.8, "stationary_seconds": 15},
        },
    )
    assert response.status_code == 201
    return response.json()


def test_protected_endpoints_require_bearer_token():
    response = unauthenticated_client.post(
        "/incidents", json={"event_type": "sos_button"}
    )
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
    incident_id = create_real_incident()["incident_id"]

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


def test_general_community_broadcast_route_does_not_exist():
    response = client.post(
        "/push/sos-broadcast",
        json={"incident_id": "anything", "latitude": 1, "longitude": 1},
    )
    assert response.status_code == 404


def test_contact_test_is_owned_labelled_and_reports_provider_acceptance():
    profile = {
        "display_name": "Test User",
        "emergency_contacts": [
            {
                "id": "owned-contact",
                "name": "Trusted Person",
                "phone": "+919000000000",
                "is_primary": True,
            }
        ],
    }
    with patch("aws.server.get_user_profile", return_value=profile), patch(
        "aws.server.send_sms_alert",
        return_value={"success": True, "message_id": "provider-message"},
    ) as send:
        response = client.post(
            "/notifications/contact-test",
            json={"contact_id": "owned-contact"},
        )
    assert response.status_code == 200
    assert response.json()["status"] == "PROVIDER_ACCEPTED"
    assert "TEST" in send.call_args.args[1]
    assert "no emergency" in send.call_args.args[1]


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
    incident_id = create_real_incident()["incident_id"]

    response = other_user_client.post(
        "/assistant/chat",
        json={"message": "Summarize this", "incident_id": incident_id},
    )
    assert response.status_code == 403


def test_health_endpoint():
    response = client.get("/")
    assert response.status_code == 200
    assert response.json()["status"] == "online"


def test_e2e_real_incident_flow():
    # 1. Ingest a real authenticated incident payload
    incident_id = create_real_incident()["incident_id"]
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


def test_responder_inbox_and_mission_routes_are_identity_bound():
    from aws.agent import tools

    created = create_real_incident()
    incident_id = created["incident_id"]
    mission_id = f"{incident_id}#test_user"
    now = datetime.now(timezone.utc)
    tools._LOCAL_MISSIONS[mission_id] = {
        "mission_id": mission_id,
        "incident_id": incident_id,
        "responder_id": "test_user",
        "status": "INVITED",
        "invited_at": now.isoformat(),
        "invitation_expires_at": int(now.timestamp()) + 180,
        "expires_at": int(now.timestamp()) + 86400,
        "approximate_location": {"latitude": 19.08, "longitude": 72.88},
        "invitation_delivery_status": "PROVIDER_ACCEPTED",
    }

    inbox = client.get("/responders/invitations")
    assert inbox.status_code == 200
    assert inbox.json()["invitations"][0]["mission_id"] == mission_id

    accepted = client.post(f"/incidents/{incident_id}/accept")
    assert accepted.status_code == 200
    grant = accepted.json()["navigation_grant"]
    assert grant

    encoded_mission_id = quote(mission_id, safe="")
    en_route = client.put(
        f"/missions/{encoded_mission_id}/status", json={"status": "EN_ROUTE"}
    )
    assert en_route.status_code == 200
    assert en_route.json()["status"] == "EN_ROUTE"

    foreign = other_user_client.get(f"/missions/{encoded_mission_id}")
    assert foreign.status_code == 403

    resolved = client.put(
        f"/incidents/{incident_id}/status",
        json={"state": "RESOLVED", "note": "Owner confirmed safe"},
    )
    assert resolved.status_code == 200
    assert resolved.json()["cancelled_mission_count"] == 1
    mission = client.get(f"/missions/{encoded_mission_id}")
    assert mission.json()["status"] == "CANCELLED"


if __name__ == "__main__":
    pytest.main([__file__])
