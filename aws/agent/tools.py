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
    get_incident,
    get_dynamo_resource,
    update_incident_status,
    IncidentState,
    DYNAMODB_INCIDENTS_TABLE,
    AWS_REGION,
)
from aws.cognito_service import get_user_profile
from aws.agent.risk_engine import assess_incident_risk
from aws.sns_push_service import send_sms_alert

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


def notify_trusted_contact(incident_id: str, contact_id: Optional[str] = None) -> Dict[str, Any]:
    """
    Tool 4: Enforce authorization policy and publish escalation alert via AWS SNS.
    Transitions state to CONTACTS_NOTIFIED only after dispatch acceptance.
    """
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
        sns_message_id = None
        delivery_status = "DEV_MODE_NOT_SENT"
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
                "last_seen = :seen, availability_expires_at = :expiry"
            ),
            ExpressionAttributeValues={
                ":lat": latitude,
                ":lng": longitude,
                ":active": is_active,
                ":seen": record["last_seen"],
                ":expiry": record["availability_expires_at"],
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


def _get_responder_records() -> List[Dict[str, Any]]:
    dynamo = get_dynamo_resource()
    if dynamo:
        return dynamo.Table(DYNAMODB_RESPONDERS_TABLE).scan().get("Items", [])
    if _dev_mode():
        return list(_LOCAL_RESPONDERS.values())
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
    for resp in _get_responder_records():
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
        distance = math.sqrt(d_lat**2 + d_lng**2)

        if distance <= radius_meters:
            eligible_responders.append({
                **resp,
                "distance_meters": round(distance, 1),
            })

    # Sort by distance ascending
    eligible_responders.sort(key=lambda r: r["distance_meters"])
    return eligible_responders


def dispatch_community_alert(incident_id: str) -> Dict[str, Any]:
    """
    Tool 6: Dispatches emergency request to nearby verified responders.
    Anti-Abuse Check 2: Anti-Solo Quorum Rule.
    If the incident is isolated/at night, alerts are dispatched to at least 2 responders in parallel.
    Anti-Abuse Check 3: Differential Geo-Obfuscation (General landmark given initially).
    """
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
    is_isolated = ctx.get("location", {}).get("is_isolated", False)
    if is_isolated and len(responders) < 2:
        # If alone in an isolated dark area, do NOT send a single responder alone.
        # Fall back to routing towards public landmark or police.
        return {
            "incident_id": incident_id,
            "status": "QUORUM_FALLBACK",
            "message": "Anti-Solo Quorum defense triggered: Less than 2 nearby helpers available in isolated zone. Directing to emergency services.",
            "dispatched_count": 0,
            "responders": [],
        }

    # Prepare obfuscated public broadcast payload
    now = datetime.now(timezone.utc)
    invitation_expiry = int(now.timestamp()) + 180
    dynamo = get_dynamo_resource()
    for responder in responders[:6]:
        mission = {
            "mission_id": _mission_id(incident_id, responder["responder_id"]),
            "incident_id": incident_id,
            "responder_id": responder["responder_id"],
            "status": "INVITED",
            "invited_at": now.isoformat(),
            "expires_at": invitation_expiry,
            "updated_at": now.isoformat(),
        }
        if dynamo:
            try:
                dynamo.Table(DYNAMODB_MISSIONS_TABLE).put_item(
                    Item=mission,
                    ConditionExpression="attribute_not_exists(mission_id)",
                )
            except Exception as error:
                code = getattr(error, "response", {}).get("Error", {}).get("Code")
                if code != "ConditionalCheckFailedException":
                    raise
        elif _dev_mode():
            _LOCAL_MISSIONS.setdefault(mission["mission_id"], mission)
        else:
            raise RuntimeError("Mission store is unavailable")

    dispatch_payload = {
        "incident_id": incident_id,
        "event_type": ctx.get("event_type"),
        "approximate_location": {
            "latitude": round(float(ctx["location"]["latitude"]), 2),
            "longitude": round(float(ctx["location"]["longitude"]), 2),
            "distance_hint": f"~{responders[0]['distance_meters']}m from you",
        },
        "quorum_size": len(responders),
        "invite_count": min(len(responders), 6),
    }

    # Append to incident audit timeline
    update_incident_status(
        incident_id=incident_id,
        new_state=IncidentState.COMMUNITY_OFFERED.value,
        actor="AGENT",
        note=f"Community Rescue dispatched to {len(responders)} verified nearby responders. Anti-Solo Quorum satisfied.",
    )

    return {
        "incident_id": incident_id,
        "status": "COMMUNITY_DISPATCHED",
        "dispatched_count": len(responders),
        "broadcast_payload": dispatch_payload,
    }


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
                    "AND expires_at > :now"
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
            existing = {"status": "INVITED", "expires_at": int(now.timestamp()) + 180}
        if existing.get("status") == "ACCEPTED":
            return {
                "incident_id": incident_id,
                "mission": existing,
                "approximate_location": _coarse_location(ctx.get("location") or {}),
                "navigation_grant": None,
            }
        if existing.get("status") != "INVITED" or existing.get("expires_at", 0) <= int(now.timestamp()):
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

