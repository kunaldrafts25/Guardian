"""
Autonomous Agent Tools for Guardian (Bedrock / Strands SDK)
Defines 4 core tools:
  1. get_incident_context(incident_id)
  2. assess_risk(incident_id, context)
  3. ask_user_confirmation(incident_id)
  4. notify_trusted_contact(incident_id, contact_id)
"""

import os
import json
import hashlib
import hmac
import secrets
from typing import Dict, Any, List, Optional
from datetime import datetime, timezone

from aws.incident_handler.handler import (
    append_incident_event,
    get_incident,
    get_dynamo_resource,
    update_incident_status,
    IncidentState,
    DYNAMODB_INCIDENTS_TABLE,
    AWS_REGION,
)
from aws.cognito_service import get_user_profile
from aws.agent.risk_engine import assess_incident_risk
from aws.agent.policy_authorization import consume_policy_authorization
from aws.sns_push_service import send_push_to_user, send_sms_alert

try:
    import boto3
    BOTO3_AVAILABLE = True
except ImportError:
    BOTO3_AVAILABLE = False

DYNAMODB_RESPONDERS_TABLE = os.environ.get("DYNAMODB_RESPONDERS_TABLE", "guardian-responders")
DYNAMODB_MISSIONS_TABLE = os.environ.get("DYNAMODB_MISSIONS_TABLE", "guardian-missions")


def _dev_mode() -> bool:
    return os.environ.get("GUARDIAN_DEV_MODE", "false").lower() == "true"


def get_incident_context(incident_id: str) -> Dict[str, Any]:
    """
    Tool 1: Read incident context from DynamoDB/storage.
    Retrieves location, sensor motion readings, user ID, and current state.
    """
    incident = get_incident(incident_id)
    if not incident:
        return {"error": f"Incident {incident_id} not found"}

    contacts = incident.get("contacts")
    if contacts is None:
        profile = get_user_profile(incident.get("user_id"))
        contacts = (profile or {}).get("emergency_contacts", [])

    return {
        "incident_id": incident_id,
        "user_id": incident.get("user_id"),
        "state": incident.get("state"),
        "event_type": incident.get("event_type"),
        "location": incident.get("location"),
        "motion_data": incident.get("motion_data"),
        "contacts": contacts,
        "created_at": incident.get("created_at"),
    }


def assess_risk(incident_id: str, context: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
    """
    Tool 2: Execute deterministic risk assessment using multidimensional metrics.
    """
    ctx = context or get_incident_context(incident_id)
    assessment = assess_incident_risk(
        event_type=ctx.get("event_type", "unknown"),
        location=ctx.get("location"),
        motion_data=ctx.get("motion_data"),
    )
    return {
        "incident_id": incident_id,
        "risk_assessment": assessment,
    }


def ask_user_confirmation(incident_id: str, timeout_seconds: int = 15) -> Dict[str, Any]:
    """
    Tool 3: Request confirmation without inventing a separate incident state.
    """
    incident = get_incident_context(incident_id)
    return {
        "incident_id": incident_id,
        "status": "CONFIRMATION_REQUESTED",
        "timeout_seconds": timeout_seconds,
        "current_state": incident.get("state"),
    }


def notify_trusted_contact(
    incident_id: str,
    authorization_token: str,
    contact_id: Optional[str] = None,
) -> Dict[str, Any]:
    """
    Tool 4: Enforce authorization policy and publish escalation alert via AWS SNS.
    Transitions state to CONTACTS_NOTIFIED only after dispatch acceptance.
    """
    consume_policy_authorization(
        authorization_token,
        expected_incident_id=incident_id,
        expected_action="notify_trusted_contact",
    )
    ctx = get_incident_context(incident_id)
    if ctx.get("state") in {
        IncidentState.CONTACTS_NOTIFIED.value,
        IncidentState.COMMUNITY_OFFERED.value,
        IncidentState.RESPONDERS_ACCEPTED.value,
        IncidentState.RESPONDERS_EN_ROUTE.value,
        IncidentState.HELP_ARRIVED.value,
        IncidentState.ESCALATED_TO_EMERGENCY_SERVICES.value,
        IncidentState.RESOLVED.value,
        IncidentState.CANCELLED.value,
        IncidentState.EXPIRED.value,
    }:
        return {
            "incident_id": incident_id,
            "delivery_status": "ALREADY_PROCESSED",
            "state": ctx.get("state"),
        }
    contacts = ctx.get("contacts", [])
    local_accepted = int((ctx.get("motion_data") or {}).get("local_sms_accepted_count", 0))
    if local_accepted > 0:
        res = update_incident_status(
            incident_id=incident_id,
            new_state=IncidentState.CONTACTS_NOTIFIED.value,
            actor="DEVICE",
            note=(
                f"The user's device recorded {local_accepted} provider-accepted SMS "
                "dispatch attempt(s); cloud duplicate suppressed."
            ),
        )
        return {
            "incident_id": incident_id,
            "delivery_status": "LOCAL_PROVIDER_ACCEPTED",
            "accepted_count": local_accepted,
            "state": res.get("state"),
        }
    
    target_contact = None
    if contact_id:
        target_contact = next((c for c in contacts if c.get("id") == contact_id), None)
    if not target_contact and contacts:
        target_contact = contacts[0]

    # Policy Check: Is the recipient in the user's authorized contacts list?
    if not target_contact:
        raise PermissionError(f"Contact {contact_id} is not authorized for emergency alerts.")

    # Publish to AWS SNS
    location = ctx.get("location") or {}
    lat = location.get("latitude")
    lng = location.get("longitude")
    maps_line = (
        f"Live GPS Location: https://maps.google.com/?q={lat},{lng}\n\n"
        if isinstance(lat, (int, float)) and isinstance(lng, (int, float))
        else "Current location was unavailable.\n\n"
    )
    
    alert_message = (
        f"🚨 GUARDIAN EMERGENCY ALERT 🚨\n\n"
        f"User: {ctx.get('user_id')}\n"
        f"Incident ID: {incident_id}\n"
        f"Event: {ctx.get('event_type')}\n"
        f"Time: {datetime.now(timezone.utc).strftime('%Y-%m-%d %H:%M:%S UTC')}\n"
        f"{maps_line}"
        f"The user did not respond to safety verification. Immediate assistance requested."
    )

    if _dev_mode() and not os.environ.get("AWS_EXECUTION_ENV"):
        return {
            "incident_id": incident_id,
            "contact_notified": None,
            "sns_message_id": None,
            "delivery_status": "DEV_MODE_NOT_SENT",
            "state": ctx.get("state"),
        }
    else:
        dispatch = send_sms_alert(str(target_contact.get("phone", "")), alert_message)
        if not dispatch.get("success"):
            raise RuntimeError("AWS SNS SMS was not accepted; emergency alert was not sent")
        sns_message_id = dispatch.get("message_id")
        delivery_status = "PROVIDER_ACCEPTED"

    # Record the distinct contact-delivery lifecycle state.
    res = update_incident_status(
        incident_id=incident_id,
        new_state=IncidentState.CONTACTS_NOTIFIED.value,
        actor="AGENT",
        note=f"Escalated to trusted contact {target_contact.get('name')} ({target_contact.get('email', target_contact.get('phone'))}) via SNS.",
    )

    return {
        "incident_id": incident_id,
        "contact_notified": target_contact.get("name"),
        "sns_message_id": sns_message_id,
        "delivery_status": delivery_status,
        "state": res.get("state"),
    }


# ==============================================================================
# Nearby Community Responder Tools & Anti-Abuse Shield
# ==============================================================================

import math

_GEOHASH_BASE32 = "0123456789bcdefghjkmnpqrstuvwxyz"


def _encode_geohash(lat: float, lng: float, precision: int = 5) -> str:
    """Encode latitude and longitude into standard base32 Geohash."""
    lat_interval = [-90.0, 90.0]
    lng_interval = [-180.0, 180.0]
    geohash = []
    bits = [16, 8, 4, 2, 1]
    bit = 0
    ch = 0
    even = True

    while len(geohash) < precision:
        if even:
            mid = (lng_interval[0] + lng_interval[1]) / 2.0
            if lng > mid:
                ch |= bits[bit]
                lng_interval[0] = mid
            else:
                lng_interval[1] = mid
        else:
            mid = (lat_interval[0] + lat_interval[1]) / 2.0
            if lat > mid:
                ch |= bits[bit]
                lat_interval[0] = mid
            else:
                lat_interval[1] = mid

        even = not even
        if bit < 4:
            bit += 1
        else:
            geohash.append(_GEOHASH_BASE32[ch])
            bit = 0
            ch = 0

    return "".join(geohash)


def _decode_geohash_bbox(geohash: str):
    """Decode a geohash into bounding box latitude and longitude intervals."""
    lat_interval = [-90.0, 90.0]
    lng_interval = [-180.0, 180.0]
    even = True
    for c in geohash:
        cd = _GEOHASH_BASE32.index(c)
        for mask in [16, 8, 4, 2, 1]:
            if even:
                mid = (lng_interval[0] + lng_interval[1]) / 2.0
                if cd & mask:
                    lng_interval[0] = mid
                else:
                    lng_interval[1] = mid
            else:
                mid = (lat_interval[0] + lat_interval[1]) / 2.0
                if cd & mask:
                    lat_interval[0] = mid
                else:
                    lat_interval[1] = mid
            even = not even
    return lat_interval, lng_interval


def _geohash_neighbors(geohash: str) -> List[str]:
    """Compute 8 adjacent neighbor geohashes to cover boundary crossings."""
    lat_int, lng_int = _decode_geohash_bbox(geohash)
    lat_height = lat_int[1] - lat_int[0]
    lng_width = lng_int[1] - lng_int[0]
    center_lat = (lat_int[0] + lat_int[1]) / 2.0
    center_lng = (lng_int[0] + lng_int[1]) / 2.0
    precision = len(geohash)

    neighbors = []
    for d_lat in [-1.0, 0.0, 1.0]:
        for d_lng in [-1.0, 0.0, 1.0]:
            if d_lat == 0.0 and d_lng == 0.0:
                continue
            n_lat = center_lat + d_lat * lat_height
            n_lng = center_lng + d_lng * lng_width
            if n_lat > 90.0:
                n_lat = 90.0
            elif n_lat < -90.0:
                n_lat = -90.0
            if n_lng > 180.0:
                n_lng = n_lng - 360.0
            elif n_lng < -180.0:
                n_lng = n_lng + 360.0
            neighbors.append(_encode_geohash(n_lat, n_lng, precision))
    return list(set(neighbors))


def _haversine_meters(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Accurate great-circle distance between two GPS coordinates in meters."""
    r = 6371000.0
    phi1 = math.radians(lat1)
    phi2 = math.radians(lat2)
    delta_phi = math.radians(lat2 - lat1)
    delta_lambda = math.radians(lon2 - lon1)
    a = (
        math.sin(delta_phi / 2.0) ** 2
        + math.cos(phi1) * math.cos(phi2) * math.sin(delta_lambda / 2.0) ** 2
    )
    c = 2.0 * math.atan2(math.sqrt(a), math.sqrt(max(0.0, 1.0 - a)))
    return r * c

# Explicit development mode may use an in-process store, but it starts empty.
# Tests seed their own records; production never ships invented responders.
_LOCAL_RESPONDERS: Dict[str, Dict[str, Any]] = {}

_LOCAL_MISSIONS: Dict[str, Dict[str, Any]] = {}


def _mission_id(incident_id: str, responder_id: str) -> str:
    return f"{incident_id}#{responder_id}"


def _coarse_location(location: Dict[str, Any]) -> Dict[str, float]:
    return {
        "latitude": round(float(location.get("latitude", 0.0)), 2),
        "longitude": round(float(location.get("longitude", 0.0)), 2),
    }


def register_responder_heartbeat(
    responder_id: str,
    latitude: float,
    longitude: float,
    is_active: bool = True,
    *,
    name: Optional[str] = None,
    trust_score: Optional[int] = None,
) -> Dict[str, Any]:
    """Register or update active responder location."""
    record = {
        "responder_id": responder_id,
        "latitude": latitude,
        "longitude": longitude,
        "is_active": is_active,
        "last_seen": datetime.now(timezone.utc).isoformat(),
        "availability_expires_at": int(datetime.now(timezone.utc).timestamp()) + 300,
        "geohash": _encode_geohash(latitude, longitude, precision=5),
    }
    if name is not None:
        record["name"] = name
    if trust_score is not None:
        record["trust_score"] = trust_score
    dynamo = get_dynamo_resource()
    if dynamo:
        table = dynamo.Table(DYNAMODB_RESPONDERS_TABLE)
        existing = table.get_item(Key={"responder_id": responder_id}).get("Item")
        if not existing or existing.get("verification_status") != "APPROVED":
            raise PermissionError("Responder enrollment is not approved")
        table.update_item(
            Key={"responder_id": responder_id},
            UpdateExpression=(
                "SET latitude = :lat, longitude = :lng, is_active = :active, "
                "last_seen = :seen, availability_expires_at = :expiry, geohash = :gh"
            ),
            ExpressionAttributeValues={
                ":lat": latitude,
                ":lng": longitude,
                ":active": is_active,
                ":seen": record["last_seen"],
                ":expiry": record["availability_expires_at"],
                ":gh": record["geohash"],
            },
        )
        record = {**existing, **record}
    elif _dev_mode():
        existing = _LOCAL_RESPONDERS.get(responder_id)
        if not existing or existing.get("verification_status") != "APPROVED":
            raise PermissionError("Responder enrollment is not approved")
        record = {**existing, **record}
        _LOCAL_RESPONDERS[responder_id] = record
    else:
        raise RuntimeError("Responder registry is unavailable")
    return record


def _get_responder_records(geohash_filter: Optional[List[str]] = None) -> List[Dict[str, Any]]:
    dynamo = get_dynamo_resource()
    if dynamo:
        table = dynamo.Table(DYNAMODB_RESPONDERS_TABLE)
        if geohash_filter:
            items = []
            for gh in geohash_filter:
                try:
                    resp = table.query(
                        IndexName="GeohashIndex",
                        KeyConditionExpression="geohash = :gh",
                        ExpressionAttributeValues={":gh": gh},
                    )
                    items.extend(resp.get("Items", []))
                except Exception:
                    pass
            if items:
                return items
            try:
                fe = "geohash IN (" + ", ".join(f":gh{i}" for i in range(len(geohash_filter))) + ")"
                eav = {f":gh{i}": gh for i, gh in enumerate(geohash_filter)}
                return table.scan(FilterExpression=fe, ExpressionAttributeValues=eav).get("Items", [])
            except Exception:
                pass
        return table.scan().get("Items", [])
    if _dev_mode():
        records = list(_LOCAL_RESPONDERS.values())
        if geohash_filter:
            return [
                r for r in records
                if r.get("geohash") in geohash_filter
                or "geohash" not in r
                or not r.get("geohash")
            ]
        return records
    raise RuntimeError("Responder registry is unavailable")


def _get_responder(responder_id: str) -> Optional[Dict[str, Any]]:
    dynamo = get_dynamo_resource()
    if dynamo:
        return dynamo.Table(DYNAMODB_RESPONDERS_TABLE).get_item(
            Key={"responder_id": responder_id}
        ).get("Item")
    if _dev_mode():
        return _LOCAL_RESPONDERS.get(responder_id)
    raise RuntimeError("Responder registry is unavailable")


def find_nearby_responders(incident_id: str, radius_meters: float = 1200.0) -> List[Dict[str, Any]]:
    """
    Tool 5: Query high-trust nearby responders within radius.
    Anti-Abuse Gating: Filters out any user with trust_score < 70.
    """
    ctx = get_incident_context(incident_id)
    inc_loc = ctx.get("location") or {}
    lat1 = inc_loc.get("latitude")
    lng1 = inc_loc.get("longitude")
    if not isinstance(lat1, (int, float)) or not isinstance(lng1, (int, float)):
        return []

    eligible_responders = []
    now_epoch = int(datetime.now(timezone.utc).timestamp())
    center_geohash = _encode_geohash(float(lat1), float(lng1), precision=5)
    candidate_geohashes = [center_geohash] + _geohash_neighbors(center_geohash)
    responder_pool = _get_responder_records(geohash_filter=candidate_geohashes)

    for resp in responder_pool:
        if not resp.get("is_active"):
            continue

        if not _dev_mode() and (
            resp.get("verification_status") != "APPROVED"
            or int(resp.get("availability_expires_at", 0)) <= now_epoch
        ):
            continue

        # Anti-Abuse Check 1: Trust Score minimum threshold
        trust_score = resp.get("trust_score", 0)
        if trust_score < 70:
            continue

        lat2 = resp.get("latitude", 0.0)
        lng2 = resp.get("longitude", 0.0)

        # Distance calculation in meters
        d_lat = (lat1 - lat2) * 111320
        d_lng = (lng1 - lng2) * 111320 * math.cos(math.radians(lat1))
        distance = _haversine_meters(float(lat1), float(lng1), float(lat2), float(lng2))

        if distance <= radius_meters:
            eligible_responders.append({
                **resp,
                "distance_meters": round(distance, 1),
            })

    # Sort by distance ascending
    eligible_responders.sort(key=lambda r: r["distance_meters"])
    return eligible_responders


def dispatch_community_alert(
    incident_id: str,
    authorization_token: str,
) -> Dict[str, Any]:
    """
    Tool 6: Creates bounded invitations for nearby verified responders.
    Anti-Abuse Check 2: Anti-Solo Quorum Rule.
    If the incident is isolated/at night, alerts are dispatched to at least 2 responders in parallel.
    Anti-Abuse Check 3: Differential Geo-Obfuscation (General landmark given initially).
    """
    authorization = consume_policy_authorization(
        authorization_token,
        expected_incident_id=incident_id,
        expected_action="dispatch_community_alert",
    )
    constraints = authorization.get("constraints") or {}
    max_invitations = int(constraints.get("max_responder_invitations", 0))
    required_quorum = int(constraints.get("required_responder_quorum", 0))
    precision = int(constraints.get("location_precision_decimals", -1))
    if not 1 <= max_invitations <= 10 or not 1 <= required_quorum <= max_invitations:
        raise PermissionError("Policy authorization has invalid responder constraints")
    if precision not in {1, 2}:
        raise PermissionError("Policy authorization has invalid location precision")
    ctx = get_incident_context(incident_id)
    if ctx.get("state") in {
        IncidentState.COMMUNITY_OFFERED.value,
        IncidentState.RESPONDERS_ACCEPTED.value,
        IncidentState.RESPONDERS_EN_ROUTE.value,
        IncidentState.HELP_ARRIVED.value,
        IncidentState.RESOLVED.value,
        IncidentState.CANCELLED.value,
        IncidentState.EXPIRED.value,
    }:
        return {
            "incident_id": incident_id,
            "status": "ALREADY_DISPATCHED",
            "dispatched_count": 0,
        }
    responders = find_nearby_responders(incident_id)

    if not responders:
        return {
            "incident_id": incident_id,
            "status": "NO_ELIGIBLE_RESPONDERS",
            "dispatched_count": 0,
        }

    # Anti-Lure Defense: Quorum Check
    if len(responders) < required_quorum:
        # If alone in an isolated dark area, do NOT send a single responder alone.
        # Fall back to routing towards public landmark or police.
        return {
            "incident_id": incident_id,
            "status": "QUORUM_FALLBACK",
            "message": "The policy-required responder quorum is unavailable; no community invitation was created.",
            "dispatched_count": 0,
            "responders": [],
        }

    # Prepare coarse, responder-bound invitation records. Delivery through
    # targeted push is a separate transport step and is never implied here.
    now = datetime.now(timezone.utc)
    invitation_expiry = int(now.timestamp()) + 180
    dynamo = get_dynamo_resource()
    selected_responders = responders[:max_invitations]
    created_missions = []
    provider_accepted_count = 0
    failed_count = 0
    for responder in selected_responders:
        approximate_location = {
            "latitude": round(float(ctx["location"]["latitude"]), precision),
            "longitude": round(float(ctx["location"]["longitude"]), precision),
        }
        mission = {
            "mission_id": _mission_id(incident_id, responder["responder_id"]),
            "incident_id": incident_id,
            "responder_id": responder["responder_id"],
            "status": "INVITED",
            "invited_at": now.isoformat(),
            "invitation_expires_at": invitation_expiry,
            # DynamoDB TTL retains mission evidence for 30 days; invitation
            # validity is enforced separately and never extended implicitly.
            "expires_at": int(now.timestamp()) + 30 * 24 * 60 * 60,
            "updated_at": now.isoformat(),
            "approximate_location": approximate_location,
            "invitation_delivery_status": "PENDING",
        }
        created = False
        if dynamo:
            try:
                dynamo.Table(DYNAMODB_MISSIONS_TABLE).put_item(
                    Item=mission,
                    ConditionExpression="attribute_not_exists(mission_id)",
                )
                created = True
            except Exception as error:
                code = getattr(error, "response", {}).get("Error", {}).get("Code")
                if code != "ConditionalCheckFailedException":
                    raise
        elif _dev_mode():
            if mission["mission_id"] not in _LOCAL_MISSIONS:
                _LOCAL_MISSIONS[mission["mission_id"]] = mission
                created = True
        else:
            raise RuntimeError("Mission store is unavailable")

        # A replay must not produce a second transport attempt.
        if not created:
            continue
        created_missions.append(mission)

        if _dev_mode() and not os.environ.get("AWS_EXECUTION_ENV"):
            delivery = {"success": False, "status": "DEV_MODE_NOT_SENT"}
        else:
            delivery = send_push_to_user(
                responder["responder_id"],
                "Guardian safety request nearby",
                "Open Guardian to review a time-limited nearby assistance request.",
                data={
                    "incident_id": incident_id,
                    "mission_id": mission["mission_id"],
                    "expires_at": str(invitation_expiry),
                },
                notification_type="responder_invitation",
            )
            delivery["status"] = (
                "PROVIDER_ACCEPTED" if delivery.get("success") else "FAILED"
            )
        if delivery["status"] == "PROVIDER_ACCEPTED":
            provider_accepted_count += 1
        elif delivery["status"] == "FAILED":
            failed_count += 1
        _record_invitation_delivery(
            mission["mission_id"],
            delivery["status"],
            delivery.get("message_id"),
        )

    invitation_payload = {
        "incident_id": incident_id,
        "event_type": ctx.get("event_type"),
        "approximate_location": {
            "latitude": round(float(ctx["location"]["latitude"]), precision),
            "longitude": round(float(ctx["location"]["longitude"]), precision),
            "distance_hint": f"~{responders[0]['distance_meters']}m from you",
        },
        "eligible_count": len(responders),
        "invite_count": len(selected_responders),
        "required_quorum": required_quorum,
        "policy_version": authorization["policy_version"],
    }

    # Append to incident audit timeline
    update_incident_status(
        incident_id=incident_id,
        new_state=IncidentState.COMMUNITY_OFFERED.value,
        actor="AGENT",
        note=(
            f"Created {len(created_missions)} bounded invitations for verified "
            f"nearby responders; provider accepted {provider_accepted_count}."
        ),
    )

    return {
        "incident_id": incident_id,
        "status": "INVITATIONS_CREATED",
        "dispatched_count": provider_accepted_count,
        "invite_count": len(created_missions),
        "invitation_payload": invitation_payload,
        "provider_accepted_count": provider_accepted_count,
        "failed_count": failed_count,
    }


def _record_invitation_delivery(
    mission_id: str,
    status: str,
    message_id: Optional[str],
) -> None:
    now = datetime.now(timezone.utc).isoformat()
    dynamo = get_dynamo_resource()
    if dynamo:
        values = {":status": status, ":now": now}
        expression = "SET invitation_delivery_status = :status, delivery_attempted_at = :now"
        if message_id:
            expression += ", invitation_message_id = :message"
            values[":message"] = message_id
        dynamo.Table(DYNAMODB_MISSIONS_TABLE).update_item(
            Key={"mission_id": mission_id},
            UpdateExpression=expression,
            ConditionExpression="attribute_exists(mission_id)",
            ExpressionAttributeValues=values,
        )
    elif _dev_mode():
        mission = _LOCAL_MISSIONS.get(mission_id)
        if mission:
            mission["invitation_delivery_status"] = status
            mission["delivery_attempted_at"] = now
            if message_id:
                mission["invitation_message_id"] = message_id
    else:
        raise RuntimeError("Mission store is unavailable")


def _responder_missions(responder_id: str) -> List[Dict[str, Any]]:
    """Load missions by authenticated responder using the declared GSI."""
    now = int(datetime.now(timezone.utc).timestamp())
    dynamo = get_dynamo_resource()
    if dynamo:
        missions = dynamo.Table(DYNAMODB_MISSIONS_TABLE).query(
            IndexName="ResponderMissionsIndex",
            KeyConditionExpression="responder_id = :responder",
            ExpressionAttributeValues={":responder": responder_id},
            ScanIndexForward=False,
            Limit=50,
        ).get("Items", [])
    elif _dev_mode():
        missions = [
            mission
            for mission in _LOCAL_MISSIONS.values()
            if mission.get("responder_id") == responder_id
        ]
    else:
        raise RuntimeError("Mission store is unavailable")

    for mission in missions:
        if mission.get("status") == "INVITED" and int(
            mission.get("invitation_expires_at", mission.get("expires_at", 0))
        ) <= now:
            mission["status"] = "EXPIRED"
    return missions


def _public_mission(mission: Dict[str, Any]) -> Dict[str, Any]:
    return {
        key: value
        for key, value in mission.items()
        if key not in {"navigation_grant_hash", "invitation_message_id"}
    }


def list_responder_invitations(responder_id: str) -> List[Dict[str, Any]]:
    """Return live invitations for one authenticated responder, never exact location."""
    return [
        _public_mission(mission)
        for mission in _responder_missions(responder_id)
        if mission.get("status") == "INVITED"
    ]


def list_responder_missions(responder_id: str) -> List[Dict[str, Any]]:
    """Return the responder's missions without grant material or exact location."""
    return [_public_mission(mission) for mission in _responder_missions(responder_id)]


def accept_rescue_mission(incident_id: str, responder_id: str) -> Dict[str, Any]:
    """
    Tool 7: Responder accepts rescue mission.
    Conditionally accepts an invitation and issues a short-lived navigation grant.
    """
    resp = _get_responder(responder_id)
    if not resp or resp.get("trust_score", 0) < 70 or (
        not _dev_mode() and resp.get("verification_status") != "APPROVED"
    ):
        raise PermissionError(f"Responder {responder_id} does not meet trust score criteria.")

    ctx = get_incident_context(incident_id)
    now = datetime.now(timezone.utc)
    grant = secrets.token_urlsafe(32)
    acceptance_record = {
        "mission_id": _mission_id(incident_id, responder_id),
        "incident_id": incident_id,
        "responder_id": responder_id,
        "accepted_at": now.isoformat(),
        "updated_at": now.isoformat(),
        "status": "ACCEPTED",
        "navigation_grant_hash": hashlib.sha256(grant.encode("utf-8")).hexdigest(),
        "navigation_grant_expires_at": int(now.timestamp()) + 900,
    }
    mission_id = acceptance_record["mission_id"]
    dynamo = get_dynamo_resource()
    if dynamo:
        try:
            result = dynamo.Table(DYNAMODB_MISSIONS_TABLE).update_item(
                Key={"mission_id": mission_id},
                UpdateExpression=(
                    "SET #status = :accepted, accepted_at = :accepted_at, "
                    "updated_at = :updated_at, navigation_grant_hash = :grant, "
                    "navigation_grant_expires_at = :grant_expiry"
                ),
                ConditionExpression=(
                    "#status = :invited AND responder_id = :responder "
                    "AND invitation_expires_at > :now"
                ),
                ExpressionAttributeNames={"#status": "status"},
                ExpressionAttributeValues={
                    ":accepted": "ACCEPTED",
                    ":invited": "INVITED",
                    ":responder": responder_id,
                    ":now": int(now.timestamp()),
                    ":accepted_at": now.isoformat(),
                    ":updated_at": now.isoformat(),
                    ":grant": acceptance_record["navigation_grant_hash"],
                    ":grant_expiry": acceptance_record["navigation_grant_expires_at"],
                },
                ReturnValues="ALL_NEW",
            )
            acceptance_record = result["Attributes"]
        except Exception as error:
            code = getattr(error, "response", {}).get("Error", {}).get("Code")
            if code == "ConditionalCheckFailedException":
                raise PermissionError("Mission invitation is unavailable or expired") from error
            raise
    elif _dev_mode():
        existing = _LOCAL_MISSIONS.get(mission_id)
        if existing is None:
            # Direct tool tests create incidents without running dispatch first.
            existing = {
                "status": "INVITED",
                "invitation_expires_at": int(now.timestamp()) + 180,
                "expires_at": int(now.timestamp()) + 30 * 24 * 60 * 60,
            }
        if existing.get("status") == "ACCEPTED":
            return {
                "incident_id": incident_id,
                "mission": existing,
                "approximate_location": _coarse_location(ctx.get("location") or {}),
                "navigation_grant": None,
            }
        if existing.get("status") != "INVITED" or existing.get(
            "invitation_expires_at", existing.get("expires_at", 0)
        ) <= int(now.timestamp()):
            raise PermissionError("Mission invitation is unavailable or expired")
        _LOCAL_MISSIONS[mission_id] = {**existing, **acceptance_record}
    else:
        raise RuntimeError("Mission store is unavailable")

    # Record on timeline
    update_incident_status(
        incident_id=incident_id,
        new_state=IncidentState.RESPONDERS_ACCEPTED.value,
        actor="COMMUNITY_RESPONDER",
        note=f"Verified helper {resp.get('name')} accepted mission and is en-route.",
    )

    return {
        "incident_id": incident_id,
        "mission": {
            key: value
            for key, value in acceptance_record.items()
            if key not in {"navigation_grant_hash"}
        },
        "approximate_location": _coarse_location(ctx.get("location") or {}),
        "navigation_grant": grant,
    }


def get_authorized_incident_location(
    incident_id: str, responder_id: str, navigation_grant: str
) -> Dict[str, Any]:
    """Return exact coordinates only for a live, bound mission grant."""
    responder = _get_responder(responder_id)
    if not responder or responder.get("trust_score", 0) < 70 or (
        not _dev_mode() and responder.get("verification_status") != "APPROVED"
    ):
        raise PermissionError("Responder approval is no longer active")
    mission_id = _mission_id(incident_id, responder_id)
    dynamo = get_dynamo_resource()
    if dynamo:
        mission = dynamo.Table(DYNAMODB_MISSIONS_TABLE).get_item(
            Key={"mission_id": mission_id}, ConsistentRead=True
        ).get("Item")
    elif _dev_mode():
        mission = _LOCAL_MISSIONS.get(mission_id)
    else:
        raise RuntimeError("Mission store is unavailable")
    now = int(datetime.now(timezone.utc).timestamp())
    supplied_hash = hashlib.sha256(navigation_grant.encode("utf-8")).hexdigest()
    if not mission or mission.get("status") not in {"ACCEPTED", "EN_ROUTE"}:
        raise PermissionError("No active mission grant")
    if int(mission.get("navigation_grant_expires_at", 0)) <= now or not hmac.compare_digest(
        mission.get("navigation_grant_hash", ""), supplied_hash
    ):
        raise PermissionError("Navigation grant is invalid or expired")
    incident = get_incident_context(incident_id)
    if incident.get("state") in {
        IncidentState.RESOLVED.value,
        IncidentState.CANCELLED.value,
        IncidentState.EXPIRED.value,
    }:
        raise PermissionError("The incident is closed")
    location = incident.get("location")
    if not location:
        raise ValueError("Incident location is unavailable")
    return {
        "incident_id": incident_id,
        "latitude": location["latitude"],
        "longitude": location["longitude"],
        "accuracy": location.get("accuracy"),
        "grant_expires_at": mission["navigation_grant_expires_at"],
    }


_MISSION_TRANSITIONS = {
    "ACCEPTED": {"EN_ROUTE", "WITHDRAWN"},
    "EN_ROUTE": {"ARRIVED", "WITHDRAWN"},
    "ARRIVED": {"COMPLETED", "WITHDRAWN"},
}


def get_responder_mission(mission_id: str, responder_id: str) -> Dict[str, Any]:
    dynamo = get_dynamo_resource()
    if dynamo:
        mission = dynamo.Table(DYNAMODB_MISSIONS_TABLE).get_item(
            Key={"mission_id": mission_id}, ConsistentRead=True
        ).get("Item")
    elif _dev_mode():
        mission = _LOCAL_MISSIONS.get(mission_id)
    else:
        raise RuntimeError("Mission store is unavailable")
    if not mission or mission.get("responder_id") != responder_id:
        raise PermissionError("Mission is unavailable to this responder")
    return _public_mission(mission)


def transition_rescue_mission(
    mission_id: str,
    responder_id: str,
    new_status: str,
) -> Dict[str, Any]:
    """Conditionally advance one responder-owned mission."""
    responder = _get_responder(responder_id)
    if not responder or responder.get("trust_score", 0) < 70 or (
        not _dev_mode() and responder.get("verification_status") != "APPROVED"
    ):
        raise PermissionError("Responder approval is no longer active")
    target = str(new_status).upper()
    dynamo = get_dynamo_resource()
    if dynamo:
        table = dynamo.Table(DYNAMODB_MISSIONS_TABLE)
        existing = table.get_item(
            Key={"mission_id": mission_id}, ConsistentRead=True
        ).get("Item")
    elif _dev_mode():
        table = None
        existing = _LOCAL_MISSIONS.get(mission_id)
    else:
        raise RuntimeError("Mission store is unavailable")
    if not existing or existing.get("responder_id") != responder_id:
        raise PermissionError("Mission is unavailable to this responder")
    current = str(existing.get("status", ""))
    if target == current:
        return _public_mission(existing)
    if target not in _MISSION_TRANSITIONS.get(current, set()):
        raise ValueError(f"Illegal mission transition from {current} to {target}")

    now = datetime.now(timezone.utc).isoformat()
    terminal = target in {"COMPLETED", "WITHDRAWN", "CANCELLED", "EXPIRED"}
    if table:
        update_expression = "SET #status = :target, updated_at = :updated"
        if terminal:
            update_expression += " REMOVE navigation_grant_hash, navigation_grant_expires_at"
        try:
            result = table.update_item(
                Key={"mission_id": mission_id},
                UpdateExpression=update_expression,
                ConditionExpression="#status = :current AND responder_id = :responder",
                ExpressionAttributeNames={"#status": "status"},
                ExpressionAttributeValues={
                    ":target": target,
                    ":current": current,
                    ":responder": responder_id,
                    ":updated": now,
                },
                ReturnValues="ALL_NEW",
            )
            updated = result["Attributes"]
        except Exception as error:
            code = getattr(error, "response", {}).get("Error", {}).get("Code")
            if code == "ConditionalCheckFailedException":
                raise ValueError("Mission changed; refresh before trying again") from error
            raise
    else:
        updated = {**existing, "status": target, "updated_at": now}
        if terminal:
            updated.pop("navigation_grant_hash", None)
            updated.pop("navigation_grant_expires_at", None)
        _LOCAL_MISSIONS[mission_id] = updated

    incident_id = str(existing["incident_id"])
    if target == "EN_ROUTE":
        update_incident_status(
            incident_id,
            IncidentState.RESPONDERS_EN_ROUTE.value,
            actor="COMMUNITY_RESPONDER",
            note="An approved responder started navigating to the incident.",
        )
    elif target == "ARRIVED":
        update_incident_status(
            incident_id,
            IncidentState.HELP_ARRIVED.value,
            actor="COMMUNITY_RESPONDER",
            note="An approved responder reported arrival.",
        )
    else:
        append_incident_event(
            incident_id,
            f"mission_{target.lower()}",
            "COMMUNITY_RESPONDER",
            f"Responder mission {mission_id} changed from {current} to {target}.",
        )
    return _public_mission(updated)


def cancel_incident_missions(incident_id: str, reason: str) -> int:
    """Revoke active mission grants when an incident becomes terminal."""
    dynamo = get_dynamo_resource()
    if dynamo:
        missions = dynamo.Table(DYNAMODB_MISSIONS_TABLE).query(
            IndexName="IncidentMissionsIndex",
            KeyConditionExpression="incident_id = :incident",
            ExpressionAttributeValues={":incident": incident_id},
        ).get("Items", [])
    elif _dev_mode():
        missions = [
            mission
            for mission in _LOCAL_MISSIONS.values()
            if mission.get("incident_id") == incident_id
        ]
    else:
        raise RuntimeError("Mission store is unavailable")
    cancelled = 0
    for mission in missions:
        if mission.get("status") not in {"INVITED", "ACCEPTED", "EN_ROUTE", "ARRIVED"}:
            continue
        mission_id = mission["mission_id"]
        if dynamo:
            dynamo.Table(DYNAMODB_MISSIONS_TABLE).update_item(
                Key={"mission_id": mission_id},
                UpdateExpression=(
                    "SET #status = :cancelled, updated_at = :updated, "
                    "cancellation_reason = :reason "
                    "REMOVE navigation_grant_hash, navigation_grant_expires_at"
                ),
                ConditionExpression="#status = :expected",
                ExpressionAttributeNames={"#status": "status"},
                ExpressionAttributeValues={
                    ":cancelled": "CANCELLED",
                    ":expected": mission["status"],
                    ":updated": datetime.now(timezone.utc).isoformat(),
                    ":reason": reason[:200],
                },
            )
        else:
            mission.update(
                status="CANCELLED",
                updated_at=datetime.now(timezone.utc).isoformat(),
                cancellation_reason=reason[:200],
            )
            mission.pop("navigation_grant_hash", None)
            mission.pop("navigation_grant_expires_at", None)
        cancelled += 1
    return cancelled

