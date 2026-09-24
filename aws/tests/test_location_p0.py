import os
os.environ["GUARDIAN_DEV_MODE"] = "true"

import pytest
from datetime import datetime, timezone, timedelta
from fastapi.testclient import TestClient
from aws.server import app
from aws.incident_handler.handler import create_incident, update_incident_location, get_incident, update_incident_status
from aws.incident_handler.state_machine import IncidentState
from aws.session_service import create_session
from aws.agent.tools import accept_rescue_mission

client = TestClient(app)


@pytest.fixture(autouse=True)
def setup_dev_env():
    os.environ["GUARDIAN_DEV_MODE"] = "true"
    yield


@pytest.fixture
def victim_headers():
    session = create_session("victim-01", "ref-victim-01", "Victim Phone", "android")
    return {
        "Authorization": "Bearer dev_access_token_victim-01",
        "X-Guardian-Session-ID": session["session_id"],
    }


@pytest.fixture
def other_headers():
    session = create_session("attacker-02", "ref-attacker-02", "Attacker Phone", "android")
    return {
        "Authorization": "Bearer dev_access_token_attacker-02",
        "X-Guardian-Session-ID": session["session_id"],
    }


@pytest.fixture
def responder_headers():
    session = create_session("resp_01", "ref-resp-01", "Responder Phone", "android")
    return {
        "Authorization": "Bearer dev_access_token_resp_01",
        "X-Guardian-Session-ID": session["session_id"],
    }


def test_create_incident_stores_canonical_emergency_location():
    now = datetime.now(timezone.utc)
    loc_payload = {
        "latitude": 19.0760,
        "longitude": 72.8777,
        "accuracy": 12.5,
        "captured_at": now.isoformat(),
        "source": "gps",
    }
    incident = create_incident({
        "user_id": "victim-01",
        "event_type": "sos_button",
        "location": loc_payload,
    })
    inc_id = incident["incident_id"]

    saved = get_incident(inc_id)
    assert saved is not None
    assert "initial_sos_location" in saved
    assert "current_emergency_location" in saved
    curr = saved["current_emergency_location"]
    assert curr["latitude"] == 19.0760
    assert curr["longitude"] == 72.8777
    assert curr["captured_at"] == now.isoformat()
    assert curr["freshness"] == "FRESH"


def test_monotonic_location_update_success(victim_headers):
    t0 = datetime.now(timezone.utc)
    t1 = t0 + timedelta(seconds=15)

    incident = create_incident({
        "user_id": "victim-01",
        "event_type": "sos_button",
        "location": {
            "latitude": 19.0760,
            "longitude": 72.8777,
            "accuracy": 10.0,
            "captured_at": t0.isoformat(),
        },
    })
    inc_id = incident["incident_id"]

    resp = client.post(
        f"/incidents/{inc_id}/location",
        headers=victim_headers,
        json={
            "latitude": 19.0780,
            "longitude": 72.8790,
            "accuracy": 8.0,
            "captured_at": t1.isoformat(),
            "source": "network",
        },
    )
    assert resp.status_code == 200
    data = resp.json()
    assert data["current_emergency_location"]["latitude"] == 19.0780
    assert data["current_emergency_location"]["captured_at"] == t1.isoformat()

    saved = get_incident(inc_id)
    # initial location must remain intact and auditable
    assert saved["initial_sos_location"]["latitude"] == 19.0760
    # current location is updated
    assert saved["current_emergency_location"]["latitude"] == 19.0780


def test_out_of_order_location_update_rejected(victim_headers):
    """Victim moves A -> B -> C. If C arrives then delayed B arrives, B must be rejected."""
    t0 = datetime.now(timezone.utc)
    t_b = t0 + timedelta(seconds=10)
    t_c = t0 + timedelta(seconds=20)

    incident = create_incident({
        "user_id": "victim-01",
        "event_type": "sos_button",
        "location": {
            "latitude": 19.0760,
            "longitude": 72.8777,
            "accuracy": 10.0,
            "captured_at": t0.isoformat(),
        },
    })
    inc_id = incident["incident_id"]

    # Position C arrives first
    resp_c = client.post(
        f"/incidents/{inc_id}/location",
        headers=victim_headers,
        json={
            "latitude": 19.0800,
            "longitude": 72.8800,
            "accuracy": 5.0,
            "captured_at": t_c.isoformat(),
        },
    )
    assert resp_c.status_code == 200

    # Delayed position B arrives later
    resp_b = client.post(
        f"/incidents/{inc_id}/location",
        headers=victim_headers,
        json={
            "latitude": 19.0770,
            "longitude": 72.8780,
            "accuracy": 6.0,
            "captured_at": t_b.isoformat(),
        },
    )
    # Must be rejected because t_b < t_c
    assert resp_b.status_code == 409
    error_msg = resp_b.json().get("error", {}).get("message", "")
    assert "out-of-order" in error_msg.lower()

    # Verify current location did NOT regress to B
    saved = get_incident(inc_id)
    assert saved["current_emergency_location"]["latitude"] == 19.0800


def test_non_owner_location_update_forbidden(other_headers):
    t0 = datetime.now(timezone.utc)
    incident = create_incident({
        "user_id": "victim-01",
        "event_type": "sos_button",
    })
    inc_id = incident["incident_id"]

    resp = client.post(
        f"/incidents/{inc_id}/location",
        headers=other_headers,
        json={
            "latitude": 19.0780,
            "longitude": 72.8790,
            "accuracy": 8.0,
            "captured_at": t0.isoformat(),
        },
    )
    assert resp.status_code == 403


def test_terminal_incident_location_update_rejected(victim_headers):
    incident = create_incident({
        "user_id": "victim-01",
        "event_type": "sos_button",
    })
    inc_id = incident["incident_id"]
    update_incident_status(inc_id, IncidentState.RESOLVED.value, actor="victim-01")

    now = datetime.now(timezone.utc)
    resp = client.post(
        f"/incidents/{inc_id}/location",
        headers=victim_headers,
        json={
            "latitude": 19.0780,
            "longitude": 72.8790,
            "accuracy": 8.0,
            "captured_at": now.isoformat(),
        },
    )
    assert resp.status_code == 409
    error_msg = resp.json().get("error", {}).get("message", "")
    assert "resolved" in error_msg.lower() or "terminal" in error_msg.lower()


def test_responder_authorized_location_and_freshness(responder_headers):
    # Victim creates incident with stale location (40s ago)
    t_stale = datetime.now(timezone.utc) - timedelta(seconds=40)
    incident = create_incident({
        "user_id": "victim-01",
        "event_type": "sos_button",
        "location": {
            "latitude": 19.0760,
            "longitude": 72.8777,
            "accuracy": 15.0,
            "captured_at": t_stale.isoformat(),
        },
    })
    inc_id = incident["incident_id"]

    # Responder accepts mission
    mission = accept_rescue_mission(inc_id, "resp_01")
    grant = mission["navigation_grant"]

    # Responder requests authorized precise location
    resp = client.post(
        f"/incidents/{inc_id}/authorized-location",
        headers=responder_headers,
        json={"navigation_grant": grant},
    )
    assert resp.status_code == 200
    data = resp.json()
    assert data["latitude"] == 19.0760
    assert data["longitude"] == 72.8777
    assert data["freshness"] == "STALE"
    assert data["age_seconds"] >= 35

    # Attacker with invalid grant is forbidden
    bad_resp = client.post(
        f"/incidents/{inc_id}/authorized-location",
        headers=responder_headers,
        json={"navigation_grant": "invalid_grant_token_that_does_not_match_hash_00000000000000000000"},
    )
    assert bad_resp.status_code == 403
