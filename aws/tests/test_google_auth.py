"""
Unit & Integration tests for Google Authentication in Guardian Backend
"""

import os
import pytest
from unittest.mock import patch
from fastapi.testclient import TestClient

os.environ["GUARDIAN_DEV_MODE"] = "true"
from aws.server import app
from aws.session_service import validate_access_session

client = TestClient(app)


def test_google_auth_empty_token_rejected():
    response = client.post(
        "/auth/google",
        json={"id_token": "", "device_label": "Pixel 8", "platform": "android"},
    )
    # Validation error for min_length=1
    assert response.status_code == 422


def test_google_auth_dev_token_success():
    response = client.post(
        "/auth/google",
        json={
            "id_token": "dev_google_token_priya",
            "device_label": "Priya's Galaxy S24",
            "platform": "android",
        },
    )
    assert response.status_code == 200
    data = response.json()
    assert data["user_id"] == "google_dev_priya"
    assert data["email"] == "priya@gmail.com"
    assert data["auth_provider"] == "google"
    assert "access_token" in data
    assert "refresh_token" in data
    assert "session_id" in data
    assert data["device_label"] == "Priya's Galaxy S24"

    # Verify session is registered and active
    is_valid = validate_access_session(data["session_id"], data["user_id"])
    assert is_valid is True


def test_google_auth_mocked_verified_token_success():
    mock_payload = {
        "iss": "https://accounts.google.com",
        "sub": "109876543210987654321",
        "email": "kunal.guardian@gmail.com",
        "email_verified": True,
        "name": "Kunal Singh",
        "picture": "https://lh3.googleusercontent.com/a/custom-avatar",
    }

    with patch("aws.cognito_service._verify_google_payload", return_value=mock_payload):
        response = client.post(
            "/auth/google",
            json={
                "id_token": "valid_signed_google_jwt_token_from_client",
                "device_label": "iPhone 15 Pro",
                "platform": "ios",
            },
        )
        assert response.status_code == 200
        data = response.json()
        assert data["user_id"] == "google_109876543210987654321"
        assert data["email"] == "kunal.guardian@gmail.com"
        assert data["display_name"] == "Kunal Singh"
        assert data["photo_url"] == "https://lh3.googleusercontent.com/a/custom-avatar"
        assert data["auth_provider"] == "google"
        assert data["platform"] == "ios"


def test_google_auth_invalid_token_rejected():
    with patch("aws.cognito_service._verify_google_payload", side_effect=ValueError("Token expired")):
        response = client.post(
            "/auth/google",
            json={
                "id_token": "expired_jwt_token",
                "device_label": "Test Device",
                "platform": "android",
            },
        )
        assert response.status_code == 401
        assert "Invalid Google ID token" in response.text
