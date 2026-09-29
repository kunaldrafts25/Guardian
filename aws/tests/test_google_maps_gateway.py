import os
from unittest.mock import patch

from fastapi.testclient import TestClient

os.environ.setdefault("GUARDIAN_DEV_MODE", "true")
os.environ.setdefault("GOOGLE_MAPS_SERVER_API_KEY", "test-server-key")

from aws import google_maps_service as maps
from aws.server import app


class _Response:
    def __init__(self, payload, status_code=200):
        self._payload = payload
        self.status_code = status_code

    def json(self):
        return self._payload


def setup_function():
    maps._api_key.cache_clear()


def test_places_autocomplete_minimizes_and_normalizes_google_response():
    payload = {
        "suggestions": [
            {
                "placePrediction": {
                    "placeId": "place_123",
                    "text": {"text": "MIT ADT University, Pune"},
                    "structuredFormat": {
                        "mainText": {"text": "MIT ADT University"},
                        "secondaryText": {"text": "Pune, Maharashtra"},
                    },
                    "distanceMeters": 1200,
                }
            }
        ]
    }
    with patch("aws.google_maps_service.requests.post", return_value=_Response(payload)) as post:
        result = maps.autocomplete_places(
            "MIT ADT",
            latitude=18.52,
            longitude=73.85,
            session_token="session-token-123",
        )

    assert result["predictions"] == [
        {
            "place_id": "place_123",
            "main_text": "MIT ADT University",
            "secondary_text": "Pune, Maharashtra",
            "description": "MIT ADT University, Pune",
            "distance_meters": 1200,
        }
    ]
    headers = post.call_args.kwargs["headers"]
    assert headers["X-Goog-Api-Key"] == "test-server-key"
    assert headers["X-Goog-FieldMask"] != "*"
    assert post.call_args.kwargs["json"]["locationBias"]["circle"]["radius"] == 30000.0


def test_walking_route_requests_only_route_geometry_distance_and_duration():
    payload = {
        "routes": [
            {
                "distanceMeters": 850,
                "duration": "650s",
                "polyline": {"encodedPolyline": "_p~iF~ps|U_ulLnnqC"},
            }
        ]
    }
    with patch("aws.google_maps_service.requests.post", return_value=_Response(payload)) as post:
        route = maps.compute_walking_route(
            origin_latitude=18.52,
            origin_longitude=73.85,
            destination_latitude=18.53,
            destination_longitude=73.86,
        )

    assert route["provider"] == "google_routes"
    assert route["geometry_type"] == "authoritative_route"
    assert route["distance_meters"] == 850
    assert route["duration"] == "650s"
    assert route["encoded_polyline"] == "_p~iF~ps|U_ulLnnqC"
    assert (
        post.call_args.kwargs["headers"]["X-Goog-FieldMask"]
        == "routes.distanceMeters,routes.duration,routes.polyline.encodedPolyline"
    )
    assert post.call_args.kwargs["json"]["travelMode"] == "WALK"


def test_maps_endpoints_remain_guardian_session_protected():
    anonymous = TestClient(app)
    denied = anonymous.post(
        "/maps/routes/walking",
        json={
            "origin": {"latitude": 18.52, "longitude": 73.85},
            "destination": {"latitude": 18.53, "longitude": 73.86},
        },
    )
    assert denied.status_code == 401

    client = TestClient(
        app,
        headers={
            "Authorization": "Bearer dev_access_token_test_user",
            "X-Guardian-Session-ID": "dev-session",
        },
    )
    with patch(
        "aws.server.compute_walking_route",
        return_value={
            "provider": "google_routes",
            "geometry_type": "authoritative_route",
            "distance_meters": 100,
            "duration": "80s",
            "encoded_polyline": "abc",
        },
    ):
        allowed = client.post(
            "/maps/routes/walking",
            json={
                "origin": {"latitude": 18.52, "longitude": 73.85},
                "destination": {"latitude": 18.53, "longitude": 73.86},
            },
        )
    assert allowed.status_code == 200
    assert allowed.json()["provider"] == "google_routes"
