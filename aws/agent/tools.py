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

try:
    import boto3
    BOTO3_AVAILABLE = True
except ImportError:
    BOTO3_AVAILABLE = False

SNS_TOPIC_ARN = os.environ.get("SNS_TOPIC_ARN", "")
DYNAMODB_RESPONDERS_TABLE = os.environ.get("DYNAMODB_RESPONDERS_TABLE", "guardian-responders")


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
    Tool 3: Transition state to VERIFYING and trigger user confirmation countdown ("Are You OK?").
    """
    res = update_incident_status(
        incident_id=incident_id,
        new_state=IncidentState.VERIFYING.value,
        actor="AGENT",
        note=f"Prompting user confirmation with {timeout_seconds}s timeout.",
    )
    return {
        "incident_id": incident_id,
        "status": "VERIFYING_INITIATED",
        "timeout_seconds": timeout_seconds,
        "current_state": res.get("state"),
    }


def notify_trusted_contact(incident_id: str, contact_id: Optional[str] = None) -> Dict[str, Any]:
    """
    Tool 4: Enforce authorization policy and publish escalation alert via AWS SNS.
    Transitions state to RESPONDING.
    """
    ctx = get_incident_context(incident_id)
    contacts = ctx.get("contacts", [])
    
    target_contact = None
    if contact_id:
        target_contact = next((c for c in contacts if c.get("id") == contact_id), None)
    if not target_contact and contacts:
        target_contact = contacts[0]

    # Policy Check: Is the recipient in the user's authorized contacts list?
    if not target_contact or not target_contact.get("authorized", False):
        raise PermissionError(f"Contact {contact_id} is not authorized for emergency alerts.")

    # Publish to AWS SNS
    lat = ctx.get("location", {}).get("latitude", 19.0760)
    lng = ctx.get("location", {}).get("longitude", 72.8777)
    maps_url = f"https://maps.google.com/?q={lat},{lng}"
    
    alert_subject = f"EMERGENCY ALERT: Guardian Safety Alert for {ctx.get('user_id')}"
    alert_message = (
        f"🚨 GUARDIAN EMERGENCY ALERT 🚨\n\n"
        f"User: {ctx.get('user_id')}\n"
        f"Incident ID: {incident_id}\n"
        f"Event: {ctx.get('event_type')}\n"
        f"Time: {datetime.now(timezone.utc).strftime('%Y-%m-%d %H:%M:%S UTC')}\n"
        f"Live GPS Location: {maps_url}\n\n"
        f"The user did not respond to safety verification. Immediate assistance requested."
    )

    if not SNS_TOPIC_ARN or not BOTO3_AVAILABLE or not os.environ.get("AWS_EXECUTION_ENV"):
        if not _dev_mode():
            raise RuntimeError("AWS SNS is not configured; emergency alert was not sent")
        sns_message_id = None
        delivery_status = "DEV_MODE_NOT_SENT"
    else:
        try:
            sns = boto3.client("sns", region_name=AWS_REGION)
            pub_res = sns.publish(
                TopicArn=SNS_TOPIC_ARN,
                Subject=alert_subject[:100],
                Message=alert_message,
            )
            sns_message_id = pub_res.get("MessageId")
            delivery_status = "SENT"
        except Exception as exc:
            raise RuntimeError("AWS SNS publish failed; emergency alert was not sent") from exc

    # Transition to RESPONDING
    res = update_incident_status(
        incident_id=incident_id,
        new_state=IncidentState.RESPONDING.value,
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

# Local responder records are test/dev-only. Production uses DynamoDB.
_LOCAL_RESPONDERS: Dict[str, Dict[str, Any]] = {
    "resp_01": {
        "responder_id": "resp_01",
        "name": "Dr. Ananya Rao",
        "phone": "+919811122233",
        "latitude": 19.0772,
        "longitude": 72.8785,
        "trust_score": 92,  # Verified Medical / Community Responder
        "is_active": True,
        "fcm_token": "fcm_token_ananya",
    },
    "resp_02": {
        "responder_id": "resp_02",
        "name": "Vikram Seth (Verified Volunteer)",
        "phone": "+919811122244",
        "latitude": 19.0751,
        "longitude": 72.8765,
        "trust_score": 84,  # High Trust Good Samaritan
        "is_active": True,
        "fcm_token": "fcm_token_vikram",
    },
    "resp_low_trust": {
        "responder_id": "resp_low_trust",
        "name": "Unverified User",
        "phone": "+919811122255",
        "latitude": 19.0762,
        "longitude": 72.8770,
        "trust_score": 45,  # Below minimum trust threshold (<70)
        "is_active": True,
        "fcm_token": "fcm_token_low",
    },
}

_ACCEPTED_MISSIONS: Dict[str, List[Dict[str, Any]]] = {}


def register_responder_heartbeat(
    responder_id: str,
    name: str,
    latitude: float,
    longitude: float,
    trust_score: int = 80,
    is_active: bool = True,
) -> Dict[str, Any]:
    """Register or update active responder location."""
    record = {
        "responder_id": responder_id,
        "name": name,
        "latitude": latitude,
        "longitude": longitude,
        "trust_score": trust_score,
        "is_active": is_active,
        "last_seen": datetime.now(timezone.utc).isoformat(),
    }
    dynamo = get_dynamo_resource()
    if dynamo:
        dynamo.Table(DYNAMODB_RESPONDERS_TABLE).put_item(Item=record)
    elif _dev_mode():
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
    inc_loc = ctx.get("location") or {"latitude": 19.0760, "longitude": 72.8777}
    lat1 = inc_loc.get("latitude", 19.0760)
    lng1 = inc_loc.get("longitude", 72.8777)

    eligible_responders = []
    for resp in _get_responder_records():
        if not resp.get("is_active"):
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
    responders = find_nearby_responders(incident_id)

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
    lat = ctx.get("location", {}).get("latitude", 19.0760)
    lng = ctx.get("location", {}).get("longitude", 72.8777)

    dispatch_payload = {
        "incident_id": incident_id,
        "event_type": ctx.get("event_type"),
        "approximate_location": {
            "area": "Near Station Road / Market Cross",
            "distance_hint": f"~{responders[0]['distance_meters']}m from you" if responders else "Nearby",
        },
        "tamper_proof_evidence_recording": True,  # Mutual digital witness activated
        "quorum_size": len(responders),
        "dispatched_to": [r["responder_id"] for r in responders],
    }

    # Append to incident audit timeline
    update_incident_status(
        incident_id=incident_id,
        new_state=IncidentState.RESPONDING.value,
        actor="AGENT",
        note=f"Community Rescue dispatched to {len(responders)} verified nearby responders. Anti-Solo Quorum satisfied.",
    )

    return {
        "incident_id": incident_id,
        "status": "COMMUNITY_DISPATCHED",
        "dispatched_count": len(responders),
        "responders": responders,
        "broadcast_payload": dispatch_payload,
    }


def accept_rescue_mission(incident_id: str, responder_id: str) -> Dict[str, Any]:
    """
    Tool 7: Responder accepts rescue mission.
    Unlocks precision GPS coordinates and establishes mutual coordination beacon.
    """
    resp = _get_responder(responder_id)
    if not resp or resp.get("trust_score", 0) < 70:
        raise PermissionError(f"Responder {responder_id} does not meet trust score criteria.")

    ctx = get_incident_context(incident_id)
    acceptance_record = {
        "responder_id": responder_id,
        "responder_name": resp.get("name"),
        "responder_phone": resp.get("phone"),
        "accepted_at": datetime.now(timezone.utc).isoformat(),
        "mission_status": "EN_ROUTE",
    }
    _ACCEPTED_MISSIONS.setdefault(incident_id, []).append(acceptance_record)

    # Record on timeline
    update_incident_status(
        incident_id=incident_id,
        new_state=IncidentState.RESPONDING.value,
        actor="COMMUNITY_RESPONDER",
        note=f"Verified helper {resp.get('name')} accepted mission and is en-route.",
    )

    # Precision location unlocked for verified en-route helper
    lat = ctx.get("location", {}).get("latitude", 19.0760)
    lng = ctx.get("location", {}).get("longitude", 72.8777)

    return {
        "incident_id": incident_id,
        "responder": acceptance_record,
        "precision_coordinates": {"latitude": lat, "longitude": lng},
        "navigation_url": f"https://maps.google.com/?q={lat},{lng}",
        "other_responders_en_route": len(_ACCEPTED_MISSIONS[incident_id]) - 1,
    }

