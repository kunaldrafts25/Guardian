"""Isolated development-store setup for backend tests."""

import pytest


@pytest.fixture(autouse=True)
def seed_development_responder_store():
    from aws.agent import tools
    from aws.agent import ledger, policy_authorization

    tools._LOCAL_RESPONDERS.clear()
    tools._LOCAL_MISSIONS.clear()
    ledger._LOCAL_LEDGER.clear()
    policy_authorization._CONSUMED_AUTHORIZATIONS.clear()
    for responder_id, latitude, longitude, trust_score in (
        ("resp_01", 19.0772, 72.8785, 92),
        ("resp_02", 19.0751, 72.8765, 84),
        ("resp_low_trust", 19.0762, 72.8770, 45),
        ("test_user", 19.0768, 72.8779, 90),
        ("resp_new_test", 19.0765, 72.8780, 85),
    ):
        tools._LOCAL_RESPONDERS[responder_id] = {
            "responder_id": responder_id,
            "name": f"Test responder {responder_id}",
            "latitude": latitude,
            "longitude": longitude,
            "trust_score": trust_score,
            "verification_status": "APPROVED",
            "is_active": True,
        }
    yield
    tools._LOCAL_RESPONDERS.clear()
    tools._LOCAL_MISSIONS.clear()
    ledger._LOCAL_LEDGER.clear()
    policy_authorization._CONSUMED_AUTHORIZATIONS.clear()
