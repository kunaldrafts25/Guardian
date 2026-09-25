"""
Tests for P0-01 (Development Authentication Bypass) and P0-02 (Session Enforcement).
"""

import os
import pytest
from fastapi.testclient import TestClient
from starlette.requests import Request
from aws.server import app
from aws.auth_middleware import _gateway_identity
from aws.session_service import create_session, revoke_session


def test_dev_token_rejected_when_dev_mode_disabled(monkeypatch):
    """P0-01: In production (GUARDIAN_DEV_MODE=false), dev_access_token_* must be rejected."""
    monkeypatch.setenv("GUARDIAN_DEV_MODE", "false")
    monkeypatch.delenv("COGNITO_USER_POOL_ID", raising=False)

    client = TestClient(
        app,
        headers={
            "Authorization": "Bearer dev_access_token_test_user",
            "X-Guardian-Session-ID": "dev-session",
        },
    )
    response = client.get("/users/test_user")
    assert response.status_code == 401
    assert "invalid or expired" in response.json()["detail"].lower()


def test_google_prefix_token_rejected(monkeypatch):
    """P0-01: A raw token starting with google_* must never confer identity."""
    monkeypatch.setenv("GUARDIAN_DEV_MODE", "false")
    monkeypatch.delenv("COGNITO_USER_POOL_ID", raising=False)

    client = TestClient(
        app,
        headers={
            "Authorization": "Bearer google_fake_user_id",
            "X-Guardian-Session-ID": "dev-session",
        },
    )
    response = client.get("/users/google_fake_user_id")
    assert response.status_code == 401


def test_random_bearer_token_rejected(monkeypatch):
    """P0-01: Completely random token rejected."""
    monkeypatch.setenv("GUARDIAN_DEV_MODE", "false")

    client = TestClient(
        app,
        headers={
            "Authorization": "Bearer random_token_1234567890",
            "X-Guardian-Session-ID": "dev-session",
        },
    )
    response = client.get("/users/test_user")
    assert response.status_code == 401


def test_session_id_alone_does_not_confer_identity(monkeypatch):
    """P0-01: Session ID without valid token must not authenticate."""
    monkeypatch.setenv("GUARDIAN_DEV_MODE", "true")
    session = create_session(
        "session_owner",
        "refresh_token_xyz",
        "Test Device",
        "android",
    )
    # Now simulate production mode where bearer tokens must be authentic
    monkeypatch.setenv("GUARDIAN_DEV_MODE", "false")
    client = TestClient(
        app,
        headers={
            "Authorization": "Bearer totally_bogus_token",
            "X-Guardian-Session-ID": session["session_id"],
        },
    )
    response = client.get("/users/session_owner")
    assert response.status_code == 401


def test_protected_endpoint_rejects_missing_session_header(monkeypatch):
    """P0-02: Omitting X-Guardian-Session-ID on protected API must return 401."""
    monkeypatch.setenv("GUARDIAN_DEV_MODE", "true")

    client = TestClient(
        app,
        headers={
            "Authorization": "Bearer dev_access_token_test_user",
            # Notice X-Guardian-Session-ID is completely omitted!
        },
    )
    response = client.get("/users/test_user")
    assert response.status_code == 401
    assert "X-Guardian-Session-ID" in response.json()["detail"]


def test_protected_endpoint_rejects_revoked_session(monkeypatch):
    """P0-02: Revoked session must be rejected with 401."""
    monkeypatch.setenv("GUARDIAN_DEV_MODE", "true")

    session = create_session(
        "revoked_user",
        "refresh_token_rev",
        "Revoked Device",
        "android",
    )
    session_id = session["session_id"]
    revoke_session("revoked_user", session_id)

    client = TestClient(
        app,
        headers={
            "Authorization": "Bearer dev_access_token_revoked_user",
            "X-Guardian-Session-ID": session_id,
        },
    )
    response = client.get("/users/revoked_user")
    assert response.status_code == 401
    assert "invalid or revoked" in response.json()["detail"].lower()


def test_protected_endpoint_rejects_other_users_session(monkeypatch):
    """P0-02: Using User A's session with User B's token must return 401."""
    monkeypatch.setenv("GUARDIAN_DEV_MODE", "true")

    session_user_a = create_session(
        "user_a",
        "refresh_token_a",
        "User A Device",
        "android",
    )

    client = TestClient(
        app,
        headers={
            "Authorization": "Bearer dev_access_token_user_b",
            "X-Guardian-Session-ID": session_user_a["session_id"],
        },
    )
    response = client.get("/users/user_b")
    assert response.status_code == 401
    assert "invalid or revoked" in response.json()["detail"].lower()


def test_public_bootstrap_endpoints_allow_unauthenticated():
    """Google remains public while retired phone-OTP routes are absent."""
    unauthed = TestClient(app)
    assert unauthed.get("/").status_code == 200
    paths = app.openapi()["paths"]
    assert "/auth/google" in paths
    assert "/auth/refresh" in paths
    assert "/auth/send-otp" not in paths
    assert "/auth/verify-otp" not in paths


def _gateway_request(claims):
    return Request(
        {
            "type": "http",
            "method": "GET",
            "path": "/users/test",
            "headers": [],
            "query_string": b"",
            "server": ("testserver", 80),
            "client": ("testclient", 123),
            "scheme": "https",
            "aws.event": {
                "requestContext": {
                    "authorizer": {
                        "claims": claims,
                    }
                }
            },
        }
    )


def test_gateway_identity_rejects_cognito_id_token_claims():
    request = _gateway_request(
        {
            "sub": "user-sub",
            "token_use": "id",
            "cognito:groups": "responder",
        }
    )
    assert _gateway_identity(request) is None


def test_gateway_identity_accepts_cognito_access_token_claims():
    request = _gateway_request(
        {
            "sub": "user-sub",
            "token_use": "access",
            "cognito:groups": "responder",
        }
    )
    identity = _gateway_identity(request)
    assert identity is not None
    user_id, roles = identity
    assert user_id == "user-sub"
    assert "responder" in roles
