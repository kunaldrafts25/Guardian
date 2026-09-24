import os
import pytest
from datetime import datetime, timezone, timedelta
from fastapi.testclient import TestClient
from aws.server import app
from aws.incident_handler.handler import create_incident, get_incident, get_incident_timeline
from aws.agent import tools

client = TestClient(app)


def test_health_endpoint_real_metrics():
    """Verify GET /health returns structured service health checks rather than dummy configs."""
    response = client.get("/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] in ("healthy", "degraded")
    assert data["service"] == "Guardian AWS Full-Stack API"
    assert "timestamp" in data
    assert "checks" in data
    assert "database" in data["checks"]
    assert "auth" in data["checks"]
    assert "push" in data["checks"]


def test_mission_invitation_expiry_persistence():
    """Verify expired missions become durably EXPIRED and cannot be resurrected or transitioned."""
    now = datetime.now(timezone.utc)
    t_past = now - timedelta(seconds=200)

    # Create an incident
    incident = create_incident({
        "user_id": "victim-p2",
        "event_type": "sos_button",
        "location": {"latitude": 19.0760, "longitude": 72.8777, "captured_at": now.isoformat()},
    })
    iid = incident["incident_id"]
    mid = tools._mission_id(iid, "resp_expired_test")

    # Seed an invited mission with expiry in the past
    tools._LOCAL_MISSIONS[mid] = {
        "mission_id": mid,
        "incident_id": iid,
        "responder_id": "resp_expired_test",
        "status": "INVITED",
        "invitation_expires_at": int(t_past.timestamp()),
        "expires_at": int(t_past.timestamp()) + 3600,
        "created_at": t_past.isoformat(),
        "updated_at": t_past.isoformat(),
    }

    # Reading responder missions should detect expiry and durably mutate the mission
    missions = tools._responder_missions("resp_expired_test")
    matched = [m for m in missions if m["mission_id"] == mid]
    assert len(matched) == 1
    assert matched[0]["status"] == "EXPIRED"

    # Verify durability in storage
    assert tools._LOCAL_MISSIONS[mid]["status"] == "EXPIRED"

    # Set trust score for responder so it passes responder check
    tools._LOCAL_RESPONDERS["resp_expired_test"] = {
        "responder_id": "resp_expired_test",
        "name": "Test Responder",
        "trust_score": 95,
        "verification_status": "APPROVED",
    }

    # Accepting an expired mission must fail with PermissionError
    with pytest.raises(PermissionError, match="unavailable or expired"):
        tools.accept_rescue_mission(iid, "resp_expired_test")

    # Advancing an expired mission via transition_rescue_mission must fail
    with pytest.raises(ValueError, match="Illegal mission transition"):
        tools.transition_rescue_mission(mid, "resp_expired_test", "ACCEPTED")


def test_authorized_location_freshness_metadata():
    """Verify authorized location response exposes received_at, source, age_seconds, and freshness."""
    now = datetime.now(timezone.utc)
    t_cap = now - timedelta(seconds=15)
    incident = create_incident({
        "user_id": "victim-loc-meta",
        "event_type": "sos_button",
        "location": {
            "latitude": 19.0760,
            "longitude": 72.8777,
            "accuracy": 8.5,
            "captured_at": t_cap.isoformat(),
            "source": "gps_stream",
        },
    })
    iid = incident["incident_id"]

    tools._LOCAL_RESPONDERS["resp_loc_test"] = {
        "responder_id": "resp_loc_test",
        "name": "Loc Test Responder",
        "trust_score": 90,
        "verification_status": "APPROVED",
    }
    mission = tools.accept_rescue_mission(iid, "resp_loc_test")
    grant = mission["navigation_grant"]

    loc_data = tools.get_authorized_incident_location(iid, "resp_loc_test", grant)
    assert loc_data["latitude"] == 19.0760
    assert loc_data["longitude"] == 72.8777
    assert loc_data["accuracy"] == 8.5
    assert loc_data["source"] == "gps_stream"
    assert "received_at" in loc_data
    assert loc_data["freshness"] == "FRESH"
    assert loc_data["age_seconds"] is not None
    assert loc_data["age_seconds"] >= 10.0


def test_event_provenance_preservation():
    """Verify trigger source survives from input payload through incident record and timeline."""
    now = datetime.now(timezone.utc)
    incident = create_incident({
        "user_id": "victim-provenance",
        "event_type": "fall_detected",
        "motion_data": {
            "trigger_source": "fall_sensor_hardware",
            "acceleration_g": 3.8,
        },
        "location": {"latitude": 19.0760, "longitude": 72.8777, "captured_at": now.isoformat()},
    })
    iid = incident["incident_id"]

    saved_incident = get_incident(iid)
    assert saved_incident["trigger_source"] == "fall_sensor_hardware"
    assert saved_incident["motion_data"]["trigger_source"] == "fall_sensor_hardware"

    timeline = get_incident_timeline(iid)
    assert len(timeline) >= 1
    assert timeline[0]["trigger_source"] == "fall_sensor_hardware"
