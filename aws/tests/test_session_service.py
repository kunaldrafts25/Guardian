from datetime import datetime, timezone

import pytest

from aws import session_service


@pytest.fixture(autouse=True)
def isolated_sessions(monkeypatch):
    monkeypatch.setenv("GUARDIAN_DEV_MODE", "true")
    session_service._LOCAL_SESSIONS.clear()
    yield
    session_service._LOCAL_SESSIONS.clear()


def test_session_is_bound_to_user_and_refresh_token():
    session = session_service.create_session(
        "user-a", "refresh-a", "Guardian Android device", "android"
    )

    assert session_service.validate_access_session(session["session_id"], "user-a")
    assert not session_service.validate_access_session(session["session_id"], "user-b")
    assert (
        session_service.validate_refresh_session(session["session_id"], "refresh-a")
        == "user-a"
    )
    with pytest.raises(ValueError):
        session_service.validate_refresh_session(session["session_id"], "refresh-b")


def test_revoked_session_immediately_loses_access():
    session = session_service.create_session(
        "user-a", "refresh-a", "Guardian iOS device", "ios"
    )
    session_service.revoke_session("user-a", session["session_id"])

    assert not session_service.validate_access_session(session["session_id"], "user-a")
    with pytest.raises(ValueError):
        session_service.validate_refresh_session(session["session_id"], "refresh-a")


def test_user_cannot_revoke_another_users_session():
    session = session_service.create_session(
        "user-a", "refresh-a", "Guardian Android device", "android"
    )

    with pytest.raises(ValueError):
        session_service.revoke_session("user-b", session["session_id"])
    assert session_service.validate_access_session(session["session_id"], "user-a")


def test_expired_session_is_rejected():
    session = session_service.create_session(
        "user-a", "refresh-a", "Guardian Android device", "android"
    )
    session_service._LOCAL_SESSIONS[session["session_id"]]["expires_at"] = int(
        datetime.now(timezone.utc).timestamp()
    ) - 1

    assert not session_service.validate_access_session(session["session_id"], "user-a")
