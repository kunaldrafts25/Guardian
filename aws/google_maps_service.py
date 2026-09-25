"""Google Maps Platform gateway used by authenticated Guardian APIs.

Mobile clients never receive the server-side Places/Routes credential. The
native Google Maps SDK uses separate Android/iOS application-restricted keys.
Guardian remains authoritative for emergency state, responder authorization,
and victim-location truth; Google only supplies place/routing data.
"""

from __future__ import annotations

import json
import logging
import os
from functools import lru_cache
from typing import Any, Dict, Optional

import boto3
import requests

logger = logging.getLogger("guardian_google_maps")

PLACES_AUTOCOMPLETE_URL = "https://places.googleapis.com/v1/places:autocomplete"
PLACES_DETAILS_URL = "https://places.googleapis.com/v1/places/{place_id}"
ROUTES_URL = "https://routes.googleapis.com/directions/v2:computeRoutes"

DEFAULT_TIMEOUT_SECONDS = 8


@lru_cache(maxsize=1)
def _api_key() -> str:
    """Resolve the server-only Google Maps Platform credential.

    Local development may provide GOOGLE_MAPS_SERVER_API_KEY directly. AWS
    deployments should provide GOOGLE_MAPS_SERVER_API_KEY_SECRET_ARN and grant
    only secretsmanager:GetSecretValue for that ARN.
    """
    direct = os.environ.get("GOOGLE_MAPS_SERVER_API_KEY", "").strip()
    if direct:
        if os.environ.get("AWS_EXECUTION_ENV"):
            logger.warning(
                "GOOGLE_MAPS_SERVER_API_KEY is set directly in an AWS runtime; "
                "prefer GOOGLE_MAPS_SERVER_API_KEY_SECRET_ARN."
            )
        return direct

    secret_arn = os.environ.get(
        "GOOGLE_MAPS_SERVER_API_KEY_SECRET_ARN",
        "",
    ).strip()
    if not secret_arn:
        raise RuntimeError("Google Maps server credential is not configured")

    client = boto3.client(
        "secretsmanager",
        region_name=os.environ.get("AWS_DEFAULT_REGION", "ap-south-1"),
    )
    response = client.get_secret_value(SecretId=secret_arn)
    raw = str(response.get("SecretString") or "").strip()
    if not raw:
        raise RuntimeError("Google Maps server credential secret is empty")

    # Support either a raw key or {"api_key": "..."} without logging either.
    if raw.startswith("{"):
        try:
            decoded = json.loads(raw)
            raw = str(decoded.get("api_key") or "").strip()
        except Exception as error:
            raise RuntimeError("Google Maps credential secret is invalid") from error
    if not raw:
        raise RuntimeError("Google Maps server credential secret has no api_key")
    return raw


def _response_json(response: requests.Response, *, service: str) -> Dict[str, Any]:
    try:
        payload = response.json()
    except Exception as error:
        raise RuntimeError(f"{service} returned a non-JSON response") from error

    if response.status_code >= 400:
        status = ""
        message = ""
        if isinstance(payload, dict):
            error = payload.get("error")
            if isinstance(error, dict):
                status = str(error.get("status") or "")
                message = str(error.get("message") or "")
        logger.warning(
            "%s request failed with HTTP %s%s",
            service,
            response.status_code,
            f" ({status})" if status else "",
        )
        # Do not reflect provider detail/API-key metadata to the mobile client.
        raise RuntimeError(
            f"{service} request failed"
            + (f" ({status})" if status else "")
        )
    if not isinstance(payload, dict):
        raise RuntimeError(f"{service} returned an invalid response")
    return payload


def autocomplete_places(
    query: str,
    *,
    latitude: Optional[float] = None,
    longitude: Optional[float] = None,
    radius_meters: float = 30000.0,
    region_code: str = "IN",
    session_token: Optional[str] = None,
) -> Dict[str, Any]:
    text = query.strip()
    if len(text) < 2:
        return {"predictions": []}

    body: Dict[str, Any] = {
        "input": text[:200],
        "regionCode": region_code[:2].upper(),
    }
    if latitude is not None and longitude is not None:
        body["locationBias"] = {
            "circle": {
                "center": {
                    "latitude": float(latitude),
                    "longitude": float(longitude),
                },
                "radius": max(100.0, min(float(radius_meters), 50000.0)),
            }
        }
    if session_token:
        body["sessionToken"] = session_token[:128]

    response = requests.post(
        PLACES_AUTOCOMPLETE_URL,
        headers={
            "Content-Type": "application/json",
            "X-Goog-Api-Key": _api_key(),
            "X-Goog-FieldMask": (
                "suggestions.placePrediction.placeId,"
                "suggestions.placePrediction.text.text,"
                "suggestions.placePrediction.structuredFormat.mainText.text,"
                "suggestions.placePrediction.structuredFormat.secondaryText.text,"
                "suggestions.placePrediction.distanceMeters"
            ),
        },
        json=body,
        timeout=DEFAULT_TIMEOUT_SECONDS,
    )
    payload = _response_json(response, service="Google Places Autocomplete")

    predictions = []
    for suggestion in payload.get("suggestions", []):
        if not isinstance(suggestion, dict):
            continue
        prediction = suggestion.get("placePrediction")
        if not isinstance(prediction, dict):
            continue
        structured = prediction.get("structuredFormat") or {}
        main = (structured.get("mainText") or {}).get("text")
        secondary = (structured.get("secondaryText") or {}).get("text")
        full_text = (prediction.get("text") or {}).get("text")
        place_id = str(prediction.get("placeId") or "").strip()
        if not place_id:
            continue
        predictions.append(
            {
                "place_id": place_id,
                "main_text": str(main or full_text or "Place"),
                "secondary_text": str(secondary or "") or None,
                "description": str(full_text or main or "Place"),
                "distance_meters": prediction.get("distanceMeters"),
            }
        )
    return {"predictions": predictions}


def place_details(
    place_id: str,
    *,
    session_token: Optional[str] = None,
) -> Dict[str, Any]:
    safe_place_id = place_id.strip()
    if not safe_place_id or "/" in safe_place_id or len(safe_place_id) > 256:
        raise ValueError("Invalid Google place ID")

    headers = {
        "X-Goog-Api-Key": _api_key(),
        "X-Goog-FieldMask": "id,displayName,formattedAddress,location",
    }
    # Places (New) accepts a session token through the query string for details
    # billing continuity when Autocomplete was session-based.
    params = {"sessionToken": session_token[:128]} if session_token else None
    response = requests.get(
        PLACES_DETAILS_URL.format(place_id=safe_place_id),
        headers=headers,
        params=params,
        timeout=DEFAULT_TIMEOUT_SECONDS,
    )
    payload = _response_json(response, service="Google Place Details")
    location = payload.get("location") or {}
    if "latitude" not in location or "longitude" not in location:
        raise RuntimeError("Google Place Details response has no location")
    return {
        "place_id": str(payload.get("id") or safe_place_id),
        "name": str((payload.get("displayName") or {}).get("text") or "Place"),
        "address": str(payload.get("formattedAddress") or ""),
        "latitude": float(location["latitude"]),
        "longitude": float(location["longitude"]),
    }


def compute_walking_route(
    *,
    origin_latitude: float,
    origin_longitude: float,
    destination_latitude: float,
    destination_longitude: float,
) -> Dict[str, Any]:
    body = {
        "origin": {
            "location": {
                "latLng": {
                    "latitude": float(origin_latitude),
                    "longitude": float(origin_longitude),
                }
            }
        },
        "destination": {
            "location": {
                "latLng": {
                    "latitude": float(destination_latitude),
                    "longitude": float(destination_longitude),
                }
            }
        },
        "travelMode": "WALK",
        "computeAlternativeRoutes": False,
        "polylineQuality": "HIGH_QUALITY",
        "polylineEncoding": "ENCODED_POLYLINE",
        "languageCode": "en",
        "units": "METRIC",
    }
    response = requests.post(
        ROUTES_URL,
        headers={
            "Content-Type": "application/json",
            "X-Goog-Api-Key": _api_key(),
            "X-Goog-FieldMask": (
                "routes.distanceMeters,"
                "routes.duration,"
                "routes.polyline.encodedPolyline"
            ),
        },
        json=body,
        timeout=10,
    )
    payload = _response_json(response, service="Google Routes")
    routes = payload.get("routes") or []
    if not routes:
        raise RuntimeError("Google Routes returned no walking route")
    route = routes[0]
    encoded = ((route.get("polyline") or {}).get("encodedPolyline") or "").strip()
    if not encoded:
        raise RuntimeError("Google Routes response has no route geometry")
    return {
        "provider": "google_routes",
        "geometry_type": "authoritative_route",
        "distance_meters": int(route.get("distanceMeters") or 0),
        "duration": str(route.get("duration") or ""),
        "encoded_polyline": encoded,
    }
