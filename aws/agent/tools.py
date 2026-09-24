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
import logging
import secrets
import uuid
from typing import Dict, Any, List, Optional
from datetime import datetime, timezone, timedelta

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
logger = logging.getLogger(__name__)


def _dev_mode() -> bool:
    return os.environ.get("GUARDIAN_DEV_MODE", "false").lower() == "true"


def _schedule_agent_timeout(
    incident_id: str,
    timeout_type: str,
    delay_seconds: int,
    *,
    idempotency_key: str,
) -> Dict[str, Any]:
    """Create an idempotent one-shot EventBridge Scheduler invocation."""
    if not (
        BOTO3_AVAILABLE
        and os.environ.get("AWS_EXECUTION_ENV")
        and os.environ.get("SCHEDULER_ROLE_ARN")
    ):
        return {"scheduled": False, "reason": "scheduler_unavailable"}

    scheduler = boto3.client("scheduler", region_name=AWS_REGION)
    sts = boto3.client("sts", region_name=AWS_REGION)
    account_id = sts.get_caller_identity()["Account"]
    lambda_name = os.environ.get("AWS_LAMBDA_FUNCTION_NAME")
    if not lambda_name:
        return {"scheduled": False, "reason": "lambda_name_unavailable"}

    delay = max(1, int(delay_seconds))
    target_time = datetime.now(timezone.utc) + timedelta(seconds=delay)
    schedule_expr = f"at({target_time.strftime('%Y-%m-%dT%H:%M:%S')})"
    digest = hashlib.sha256(
        f"{incident_id}:{timeout_type}:{idempotency_key}".encode("utf-8")
    ).hexdigest()[:24]
    schedule_name = f"guardian-{timeout_type.lower().replace('_', '-')}-{digest}"[:64]
    payload = {
        "detail": {
            "incident_id": incident_id,
            "timeout_type": timeout_type,
            "idempotency_key": idempotency_key,
        }
    }
    try:
        scheduler.create_schedule(
            Name=schedule_name,
            ClientToken=digest,
            ScheduleExpression=schedule_expr,
            ScheduleExpressionTimezone="UTC",
            FlexibleTimeWindow={"Mode": "OFF"},
            ActionAfterCompletion="DELETE",
            Target={
                "Arn": f"arn:aws:lambda:{AWS_REGION}:{account_id}:function:{lambda_name}",
                "RoleArn": os.environ["SCHEDULER_ROLE_ARN"],
                "Input": json.dumps(payload),
                "RetryPolicy": {
                    "MaximumEventAgeInSeconds": 3600,
                    "MaximumRetryAttempts": 3,
                },
            },
        )
        return {
            "scheduled": True,
            "schedule_name": schedule_name,
            "deadline_at": int(target_time.timestamp()),
        }
    except Exception as error:
        code = getattr(error, "response", {}).get("Error", {}).get("Code")
        if code in {"ConflictException", "ResourceConflictException"}:
            return {
                "scheduled": True,
                "schedule_name": schedule_name,
                "deadline_at": int(target_time.timestamp()),
                "existing": True,
            }
        logger.error(
            "Failed to schedule %s for incident %s: %s",
            timeout_type,
            incident_id,
            type(error).__name__,
        )
        return {
            "scheduled": False,
            "reason": type(error).__name__,
        }


def _persist_verification_request(
    incident_id: str,
    timeout_seconds: int,
    schedule_result: Dict[str, Any],
) -> None:
    requested_at = datetime.now(timezone.utc)
    deadline = requested_at + timedelta(seconds=max(1, timeout_seconds))
    dynamo = get_dynamo_resource()
    values = {
        ":requested": requested_at.isoformat(),
        ":deadline": int(deadline.timestamp()),
        ":status": "PENDING",
    }
    if dynamo:
        dynamo.Table(DYNAMODB_INCIDENTS_TABLE).update_item(
            Key={"incident_id": incident_id},
            UpdateExpression=(
                "SET verification_requested_at = :requested, "
                "verification_deadline_at = :deadline, verification_status = :status"
            ),
            ExpressionAttributeValues=values,
        )
    elif _dev_mode():
        from aws.incident_handler.handler import _LOCAL_INCIDENTS
        inc = _LOCAL_INCIDENTS.get(incident_id)
        if inc:
            inc["verification_requested_at"] = values[":requested"]
            inc["verification_deadline_at"] = values[":deadline"]
            inc["verification_status"] = values[":status"]


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

    res = {**incident}
    if contacts is not None:
        res["contacts"] = contacts
    return res


def assess_risk(incident_id: str, context: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
    """Execute deterministic risk assessment with victim-event time when available."""
    ctx = context or get_incident_context(incident_id)
    motion = ctx.get("motion_data") or {}
    event_time = None
    raw_event_time = motion.get("event_occurred_at")
    if raw_event_time:
        try:
            event_time = datetime.fromisoformat(
                str(raw_event_time).replace("Z", "+00:00")
            )
            if event_time.tzinfo is None:
                event_time = event_time.replace(tzinfo=timezone.utc)
        except (TypeError, ValueError):
            event_time = None

    assessment = assess_incident_risk(
        event_type=ctx.get("event_type", "unknown"),
        location=ctx.get("location"),
        motion_data=motion,
        timestamp=event_time,
    )
    return {
        "incident_id": incident_id,
        "risk_assessment": assessment,
    }


def ask_user_confirmation(incident_id: str, timeout_seconds: int = 15) -> Dict[str, Any]:
    """Request user verification and durably own the timeout in the backend."""
    incident = get_incident_context(incident_id)
    if "error" in incident:
        return incident
    if incident.get("state") in {
        IncidentState.RESOLVED.value,
        IncidentState.CANCELLED.value,
        IncidentState.EXPIRED.value,
    }:
        return {"incident_id": incident_id, "status": "INCIDENT_CLOSED"}

    schedule = _schedule_agent_timeout(
        incident_id,
        "USER_VERIFICATION",
        timeout_seconds,
        idempotency_key="verification-v1",
    )
    _persist_verification_request(incident_id, timeout_seconds, schedule)
    append_incident_event(
        incident_id,
        "verification_requested",
        "AGENT",
        f"User verification requested with {timeout_seconds}s deadline; "
        f"backend_timer_scheduled={schedule.get('scheduled', False)}.",
    )
    return {
        "incident_id": incident_id,
        "status": "CONFIRMATION_REQUESTED",
        "timeout_seconds": timeout_seconds,
        "current_state": incident.get("state"),
        "backend_timer_scheduled": bool(schedule.get("scheduled")),
        "verification_deadline_at": schedule.get("deadline_at"),
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
    
    targets = [c for c in contacts if c.get("id") == contact_id] if contact_id else contacts
    if not targets:
        raise PermissionError(f"No authorized contacts found for dispatch.")

    location = ctx.get("location") or {}
    lat = location.get("latitude")
    lng = location.get("longitude")
    captured_at = location.get("captured_at")
    maps_line = (
        (
            f"Latest recorded location"
            f"{f' at {captured_at}' if captured_at else ''}: "
            f"https://maps.google.com/?q={lat},{lng}\n\n"
        )
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

    notified = []
    skipped = []
    failed = []

    local_delivery = {}
    for item in (ctx.get("motion_data") or {}).get("local_sms_delivery") or []:
        if not isinstance(item, dict):
            continue
        contact_key = str(item.get("contact_id") or "").strip()
        state = str(item.get("state") or "").upper()
        if contact_key:
            local_delivery[contact_key] = state

    for c in targets:
        # Per-recipient truth: suppress cloud fallback only for the exact contact
        # whose local Android dispatch was accepted by the OS.
        contact_key = str(c.get("id") or "").strip()
        local_state = local_delivery.get(
            contact_key,
            str(c.get("delivery_state") or "").upper(),
        )
        if local_state == "OS_ACCEPTED":
            skipped.append(c.get("name", "Unknown"))
            continue

        if _dev_mode() and not os.environ.get("AWS_EXECUTION_ENV"):
            notified.append(c.get("name", "Unknown"))
        else:
            dispatch = send_sms_alert(str(c.get("phone", "")), alert_message)
            if dispatch.get("success"):
                notified.append(c.get("name", "Unknown"))
            else:
                failed.append(c.get("name", "Unknown"))

    if not notified and not skipped:
        raise RuntimeError(f"AWS SNS SMS failed for all {len(failed)} targets.")

    res = update_incident_status(
        incident_id=incident_id,
        new_state=IncidentState.CONTACTS_NOTIFIED.value,
        actor="AGENT",
        note=f"Escalated via SNS to {len(notified)} contacts ({len(skipped)} already notified natively).",
    )

    return {
        "incident_id": incident_id,
        "contacts_notified_cloud": notified,
        "contacts_skipped_native": skipped,
        "contacts_failed": failed,
        "delivery_status": "PROVIDER_ACCEPTED" if notified else "LOCAL_PROVIDER_ACCEPTED",
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


def _geohash_cells_for_radius(
    center_lat: float, center_lng: float, radius_meters: float, precision: int = 5
) -> List[str]:
    """Compute all geohash cells covering the circle of given radius across all cardinal and diagonal directions."""
    center_gh = _encode_geohash(center_lat, center_lng, precision=precision)
    lat_int, lng_int = _decode_geohash_bbox(center_gh)
    lat_height = max(1e-6, lat_int[1] - lat_int[0])
    lng_width = max(1e-6, lng_int[1] - lng_int[0])

    meters_per_lat = 111320.0
    lat_cos = math.cos(math.radians(center_lat))
    meters_per_lng = max(1000.0, 111320.0 * abs(lat_cos))

    lat_radius_deg = (radius_meters / meters_per_lat) * 1.05
    lng_radius_deg = (radius_meters / meters_per_lng) * 1.05

    step_lat = max(1, math.ceil(lat_radius_deg / lat_height))
    step_lng = max(1, math.ceil(lng_radius_deg / lng_width))

    cells = set()
    for d_lat in range(-step_lat, step_lat + 1):
        for d_lng in range(-step_lng, step_lng + 1):
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
            cells.add(_encode_geohash(n_lat, n_lng, precision))
    return list(cells)


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
        "availability_expires_at": int(datetime.now(timezone.utc).timestamp()) + 1800, # P2-01: 30 min expiry
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
    now_epoch = int(datetime.now(timezone.utc).timestamp())
    if dynamo:
        table = dynamo.Table(DYNAMODB_RESPONDERS_TABLE)
        if geohash_filter:
            items = []
            for gh in geohash_filter:
                try:
                    resp = table.query(
                        IndexName="GeohashIndex",
                        KeyConditionExpression="geohash = :gh AND availability_expires_at > :now",
                        ExpressionAttributeValues={":gh": gh, ":now": now_epoch},
                    )
                    items.extend(resp.get("Items", []))
                except Exception:
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
    candidate_geohashes = _geohash_cells_for_radius(
        float(lat1), float(lng1), radius_meters=radius_meters, precision=5
    )
    responder_pool = _get_responder_records(geohash_filter=candidate_geohashes)

    for resp in responder_pool:
        if not resp.get("is_active"):
            continue

        if resp.get("verification_status") != "APPROVED":
            continue

        expiry = resp.get("availability_expires_at")
        if expiry is not None and int(expiry) <= now_epoch:
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


def _persist_escalation_policy(
    incident_id: str,
    constraints: Dict[str, Any],
    policy_version: str,
) -> None:
    """Store the responder envelope so later scheduler stages use the same policy."""
    max_per_stage = int(constraints.get("max_responder_invitations", 0))
    quorum = int(constraints.get("required_responder_quorum", 0))
    precision = int(constraints.get("location_precision_decimals", -1))
    if not 1 <= max_per_stage <= 10 or not 1 <= quorum <= max_per_stage:
        raise PermissionError("Policy authorization has invalid responder constraints")
    if precision not in {1, 2}:
        raise PermissionError("Policy authorization has invalid location precision")

    dynamo = get_dynamo_resource()
    if dynamo:
        dynamo.Table(DYNAMODB_INCIDENTS_TABLE).update_item(
            Key={"incident_id": incident_id},
            UpdateExpression=(
                "SET responder_max_invitations_per_stage = :max, "
                "responder_required_quorum = :quorum, "
                "responder_location_precision = :precision, "
                "responder_policy_version = :policy"
            ),
            ExpressionAttributeValues={
                ":max": max_per_stage,
                ":quorum": quorum,
                ":precision": precision,
                ":policy": policy_version,
            },
        )
    elif _dev_mode():
        from aws.incident_handler.handler import _LOCAL_INCIDENTS
        inc = _LOCAL_INCIDENTS.get(incident_id)
        if inc:
            inc["responder_max_invitations_per_stage"] = max_per_stage
            inc["responder_required_quorum"] = quorum
            inc["responder_location_precision"] = precision
            inc["responder_policy_version"] = policy_version


def dispatch_community_alert(
    incident_id: str,
    authorization_token: str,
) -> Dict[str, Any]:
    """Start the single deterministic 1→2→5→10 km responder engine."""
    authorization = consume_policy_authorization(
        authorization_token,
        expected_incident_id=incident_id,
        expected_action="dispatch_community_alert",
    )
    ctx = get_incident_context(incident_id)
    if ctx.get("state") in {
        IncidentState.COMMUNITY_OFFERED.value,
        IncidentState.RESPONDERS_ACCEPTED.value,
        IncidentState.RESPONDERS_EN_ROUTE.value,
        IncidentState.HELP_ARRIVED.value,
        IncidentState.RESOLVED.value,
        IncidentState.CANCELLED.value,
        IncidentState.EXPIRED.value,
    } or int(ctx.get("current_escalation_stage") or 0) > 0:
        return {
            "incident_id": incident_id,
            "status": "ALREADY_DISPATCHED",
            "dispatched_count": 0,
            "invite_count": 0,
        }

    constraints = authorization.get("constraints") or {}
    _persist_escalation_policy(
        incident_id,
        constraints,
        str(authorization.get("policy_version") or "unknown"),
    )
    return advance_incident_escalation(
        incident_id,
        target_stage=1,
        policy_constraints=constraints,
    )


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


def _persist_mission_expired(mission: Dict[str, Any]) -> None:
    """Durably transition an expired INVITED mission to EXPIRED."""
    mission_id = mission.get("mission_id")
    if not mission_id:
        return
    now_iso = datetime.now(timezone.utc).isoformat()
    now_ts = int(datetime.now(timezone.utc).timestamp())
    dynamo = get_dynamo_resource()
    if dynamo:
        try:
            dynamo.Table(DYNAMODB_MISSIONS_TABLE).update_item(
                Key={"mission_id": mission_id},
                UpdateExpression="SET #status = :expired, updated_at = :now REMOVE navigation_grant_hash, navigation_grant_expires_at",
                ConditionExpression="#status = :invited AND (invitation_expires_at <= :now_ts OR expires_at <= :now_ts)",
                ExpressionAttributeNames={"#status": "status"},
                ExpressionAttributeValues={
                    ":expired": "EXPIRED",
                    ":invited": "INVITED",
                    ":now": now_iso,
                    ":now_ts": now_ts,
                },
            )
        except Exception:
            pass
    if mission_id in _LOCAL_MISSIONS:
        _LOCAL_MISSIONS[mission_id]["status"] = "EXPIRED"
        _LOCAL_MISSIONS[mission_id]["updated_at"] = now_iso
    mission["status"] = "EXPIRED"
    mission["updated_at"] = now_iso


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
            _persist_mission_expired(mission)
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

    from aws.agent.escalation_policy import MAX_ACCEPTED_RESPONDERS
    active_accepted = [
        m for m in _incident_missions(incident_id)
        if m.get("status") in {"ACCEPTED", "EN_ROUTE", "ARRIVED"}
        and m.get("responder_id") != responder_id
    ]
    if len(active_accepted) >= MAX_ACCEPTED_RESPONDERS:
        raise PermissionError(
            f"The maximum responder capacity ({MAX_ACCEPTED_RESPONDERS}) for this incident has been reached."
        )

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
            if existing.get("status") == "INVITED":
                _persist_mission_expired(existing)
            raise PermissionError("Mission invitation is unavailable or expired")
        _LOCAL_MISSIONS[mission_id] = {**existing, **acceptance_record}
    else:
        raise RuntimeError("Mission store is unavailable")

    # Record on timeline
    update_incident_status(
        incident_id=incident_id,
        new_state=IncidentState.RESPONDERS_ACCEPTED.value,
        actor="COMMUNITY_RESPONDER",
        note=f"Verified helper {resp.get('name')} accepted the responder mission.",
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
    location = incident.get("current_emergency_location") or incident.get("location")
    if not location:
        raise ValueError("Incident location is unavailable")
    freshness = location.get("freshness", "UNKNOWN")
    age_seconds = location.get("age_seconds")
    if location.get("captured_at"):
        try:
            cap_dt = datetime.fromisoformat(str(location["captured_at"]))
            if cap_dt.tzinfo is None:
                cap_dt = cap_dt.replace(tzinfo=timezone.utc)
            computed_age = max(0.0, (datetime.now(timezone.utc) - cap_dt).total_seconds())
            age_seconds = round(computed_age, 1)
            freshness = "FRESH" if computed_age <= 30.0 else "STALE"
        except Exception:
            freshness = "UNKNOWN"

    return {
        "incident_id": incident_id,
        "latitude": location["latitude"],
        "longitude": location["longitude"],
        "accuracy": location.get("accuracy"),
        "captured_at": location.get("captured_at"),
        "received_at": location.get("received_at") or incident.get("updated_at"),
        "source": location.get("source") or "DEVICE_GPS",
        "freshness": freshness,
        "age_seconds": age_seconds,
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
    now = int(datetime.now(timezone.utc).timestamp())
    if mission.get("status") == "INVITED" and int(
        mission.get("invitation_expires_at", mission.get("expires_at", 0))
    ) <= now:
        _persist_mission_expired(mission)
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
    if target in {"WITHDRAWN", "DECLINED"}:
        remaining = [
            m for m in _incident_missions(incident_id)
            if m.get("status") in {"ACCEPTED", "EN_ROUTE", "ARRIVED"}
            and m.get("mission_id") != mission_id
        ]
        if not remaining:
            process_incident_redispatch_eval(incident_id)
    return _public_mission(updated)


def _incident_missions(incident_id: str) -> List[Dict[str, Any]]:
    """Load missions for an incident using declared IncidentMissionsIndex or local store."""
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

    now = int(datetime.now(timezone.utc).timestamp())
    for mission in missions:
        if mission.get("status") == "INVITED" and int(
            mission.get("invitation_expires_at", mission.get("expires_at", 0))
        ) <= now:
            _persist_mission_expired(mission)
    return missions


def cancel_incident_missions(incident_id: str, reason: str) -> int:
    """Revoke active mission grants when an incident becomes terminal."""
    missions = _incident_missions(incident_id)
    cancelled = 0
    dynamo = get_dynamo_resource()
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


def renew_mission_navigation_grant(
    mission_id: str,
    responder_id: str,
) -> Dict[str, Any]:
    """
    Secure renewal model for active rescue mission navigation grants.
    Validates responder authorization, active mission state, and active incident state.
    Issues a fresh short-lived HMAC grant (+900s cap) and audits the issuance.
    """
    responder = _get_responder(responder_id)
    if not responder or responder.get("trust_score", 0) < 70 or (
        not _dev_mode() and responder.get("verification_status") != "APPROVED"
    ):
        raise PermissionError("Responder is not approved or does not meet trust requirements")

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
        raise PermissionError("Mission does not belong to caller")

    incident_id = str(mission["incident_id"])
    incident = get_incident_context(incident_id)
    if incident.get("state") in {
        IncidentState.RESOLVED.value,
        IncidentState.CANCELLED.value,
        IncidentState.EXPIRED.value,
    }:
        raise PermissionError("Incident is closed; navigation grant cannot be renewed")

    current_status = mission.get("status")
    if current_status not in {"ACCEPTED", "EN_ROUTE"}:
        raise PermissionError(f"Cannot renew grant for mission in state {current_status}")

    now = datetime.now(timezone.utc)
    new_grant = secrets.token_urlsafe(32)
    new_grant_hash = hashlib.sha256(new_grant.encode("utf-8")).hexdigest()
    new_expiry = int(now.timestamp()) + 900  # Cap at +15 minutes per renewal
    renewal_count = int(mission.get("grant_renewal_count", 0)) + 1

    if dynamo:
        dynamo.Table(DYNAMODB_MISSIONS_TABLE).update_item(
            Key={"mission_id": mission_id},
            UpdateExpression=(
                "SET navigation_grant_hash = :gh, "
                "navigation_grant_expires_at = :exp, "
                "grant_renewal_count = :rc, "
                "updated_at = :updated"
            ),
            ConditionExpression="responder_id = :responder AND #s IN (:acc, :enr)",
            ExpressionAttributeNames={"#s": "status"},
            ExpressionAttributeValues={
                ":gh": new_grant_hash,
                ":exp": new_expiry,
                ":rc": renewal_count,
                ":updated": now.isoformat(),
                ":responder": responder_id,
                ":acc": "ACCEPTED",
                ":enr": "EN_ROUTE",
            },
        )
    elif _dev_mode():
        mission["navigation_grant_hash"] = new_grant_hash
        mission["navigation_grant_expires_at"] = new_expiry
        mission["grant_renewal_count"] = renewal_count
        mission["updated_at"] = now.isoformat()

    # Timeline audit
    append_incident_event(
        incident_id,
        "navigation_grant_renewed",
        "COMMUNITY_RESPONDER",
        f"Navigation grant renewed for responder {responder_id} (renewal #{renewal_count}).",
    )

    return {
        "mission_id": mission_id,
        "incident_id": incident_id,
        "navigation_grant": new_grant,
        "grant_expires_at": new_expiry,
        "grant_renewal_count": renewal_count,
    }


def _dispatch_escalation_stage(
    incident_id: str,
    stage_index: int,
    *,
    policy_constraints: Optional[Dict[str, Any]] = None,
) -> Dict[str, Any]:
    """Dispatch one responder stage and schedule its durable deadline."""
    from aws.agent.escalation_policy import get_escalation_stage

    ctx = get_incident_context(incident_id)
    stage = get_escalation_stage(stage_index)
    stored_max = int(ctx.get("responder_max_invitations_per_stage") or 10)
    stored_quorum = int(ctx.get("responder_required_quorum") or 1)
    stored_precision = int(ctx.get("responder_location_precision") or 2)
    if policy_constraints:
        stored_max = min(
            stored_max,
            int(policy_constraints.get("max_responder_invitations", stored_max)),
        )
        stored_quorum = int(
            policy_constraints.get("required_responder_quorum", stored_quorum)
        )
        stored_precision = int(
            policy_constraints.get("location_precision_decimals", stored_precision)
        )

    max_candidates = min(stage.max_candidates, max(1, stored_max))
    required_quorum = max(1, min(stored_quorum, max_candidates))
    precision = stored_precision if stored_precision in {1, 2} else 2
    radius_meters = stage.radius_meters

    all_candidates = find_nearby_responders(
        incident_id,
        radius_meters=radius_meters,
    )
    dispatched_history = set(ctx.get("dispatched_responder_ids") or [])
    new_candidates = [
        responder
        for responder in all_candidates
        if responder["responder_id"] not in dispatched_history
    ]
    selected = new_candidates[:max_candidates]

    if len(selected) < required_quorum:
        append_incident_event(
            incident_id,
            "escalation_stage_empty",
            "SYSTEM",
            f"Stage {stage.stage_index} ({int(radius_meters/1000)} km) had "
            f"{len(selected)} eligible new responders, below quorum {required_quorum}.",
        )
        return {
            "incident_id": incident_id,
            "stage": stage.stage_index,
            "radius_meters": radius_meters,
            "status": "NO_QUORUM",
            "new_invitations": 0,
        }

    now = datetime.now(timezone.utc)
    invitation_expiry = int(now.timestamp()) + stage.invitation_timeout_seconds
    dynamo = get_dynamo_resource()
    location = ctx.get("current_emergency_location") or ctx.get("location") or {}
    created_missions: List[Dict[str, Any]] = []
    provider_accepted_count = 0
    failed_count = 0

    for responder in selected:
        responder_id = responder["responder_id"]
        mission_id = _mission_id(incident_id, responder_id)
        mission = {
            "mission_id": mission_id,
            "incident_id": incident_id,
            "responder_id": responder_id,
            "status": "INVITED",
            "invited_at": now.isoformat(),
            "invitation_expires_at": invitation_expiry,
            "expires_at": int(now.timestamp()) + 30 * 24 * 60 * 60,
            "updated_at": now.isoformat(),
            "approximate_location": {
                "latitude": round(float(location.get("latitude", 0.0)), precision),
                "longitude": round(float(location.get("longitude", 0.0)), precision),
            },
            "invitation_delivery_status": "PENDING",
            "escalation_stage": stage.stage_index,
            "radius_meters": radius_meters,
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
            if mission_id not in _LOCAL_MISSIONS:
                _LOCAL_MISSIONS[mission_id] = mission
                created = True
        else:
            raise RuntimeError("Mission store is unavailable")

        if not created:
            continue

        created_missions.append(mission)
        dispatched_history.add(responder_id)
        if _dev_mode() and not os.environ.get("AWS_EXECUTION_ENV"):
            delivery = {"success": False, "status": "DEV_MODE_NOT_SENT"}
        else:
            delivery = send_push_to_user(
                responder_id,
                "Guardian safety request nearby",
                f"Assistance requested within {int(radius_meters/1000)} km. "
                "Open Guardian to review.",
                data={
                    "incident_id": incident_id,
                    "mission_id": mission_id,
                    "invitation_expires_at": str(invitation_expiry),
                    "stage": str(stage.stage_index),
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
            mission_id,
            delivery["status"],
            delivery.get("message_id"),
        )

    new_dispatched_list = sorted(dispatched_history)
    update_values = {
        ":stage": stage.stage_index,
        ":radius": radius_meters,
        ":dispatched": new_dispatched_list,
        ":deadline": invitation_expiry,
        ":now": now.isoformat(),
    }
    if dynamo:
        dynamo.Table(DYNAMODB_INCIDENTS_TABLE).update_item(
            Key={"incident_id": incident_id},
            UpdateExpression=(
                "SET current_escalation_stage = :stage, "
                "current_radius_meters = :radius, "
                "dispatched_responder_ids = :dispatched, "
                "escalation_deadline_at = :deadline, updated_at = :now"
            ),
            ExpressionAttributeValues=update_values,
        )
    elif _dev_mode():
        from aws.incident_handler.handler import _LOCAL_INCIDENTS
        inc = _LOCAL_INCIDENTS.get(incident_id)
        if inc:
            inc["current_escalation_stage"] = stage.stage_index
            inc["current_radius_meters"] = radius_meters
            inc["dispatched_responder_ids"] = new_dispatched_list
            inc["escalation_deadline_at"] = invitation_expiry
            inc["updated_at"] = now.isoformat()

    if created_missions and ctx.get("state") in {
        IncidentState.CLOUD_ACCEPTED.value,
        IncidentState.CONTACTS_NOTIFIED.value,
    }:
        try:
            update_incident_status(
                incident_id,
                IncidentState.COMMUNITY_OFFERED.value,
                actor="SYSTEM",
                note=f"Responder escalation stage {stage.stage_index} opened.",
            )
        except ValueError:
            pass

    append_incident_event(
        incident_id,
        "escalation_dispatched",
        "SYSTEM",
        f"Stage {stage.stage_index} ({int(radius_meters/1000)} km): "
        f"{len(created_missions)} missions created; "
        f"{provider_accepted_count} push requests accepted by provider.",
    )

    invitation_payload = {
        "incident_id": incident_id,
        "event_type": ctx.get("event_type"),
        "approximate_location": {
            "latitude": round(float(location.get("latitude", 0.0)), precision),
            "longitude": round(float(location.get("longitude", 0.0)), precision),
        },
        "eligible_count": len(all_candidates),
        "invite_count": len(created_missions),
        "required_quorum": required_quorum,
        "policy_version": ctx.get("responder_policy_version"),
        "stage": stage.stage_index,
        "radius_meters": radius_meters,
    }

    # In local test mode the transport is deliberately not sent, but creation of
    # real mission records is still the behavior under test. In production, a
    # stage with zero provider-accepted pushes widens immediately.
    local_simulation = _dev_mode() and not os.environ.get("AWS_EXECUTION_ENV")
    waiting_for_response = provider_accepted_count > 0 or (
        local_simulation and bool(created_missions)
    )
    if waiting_for_response:
        schedule = _schedule_agent_timeout(
            incident_id,
            "ESCALATION_CHECK",
            stage.invitation_timeout_seconds,
            idempotency_key=f"stage-{stage.stage_index}",
        )
        return {
            "incident_id": incident_id,
            "stage": stage.stage_index,
            "radius_meters": radius_meters,
            "new_invitations": len(created_missions),
            "invite_count": len(created_missions),
            "dispatched_count": provider_accepted_count,
            "provider_accepted_count": provider_accepted_count,
            "failed_count": failed_count,
            "status": "INVITATIONS_CREATED",
            "invitation_expires_at": invitation_expiry,
            "invitation_payload": invitation_payload,
            "backend_timer_scheduled": bool(schedule.get("scheduled")),
        }

    return {
        "incident_id": incident_id,
        "stage": stage.stage_index,
        "radius_meters": radius_meters,
        "new_invitations": len(created_missions),
        "invite_count": len(created_missions),
        "dispatched_count": 0,
        "provider_accepted_count": 0,
        "failed_count": failed_count,
        "status": "NO_REACHABLE_RESPONDERS",
        "invitation_expires_at": invitation_expiry,
        "invitation_payload": invitation_payload,
        "backend_timer_scheduled": False,
    }


def advance_incident_escalation(
    incident_id: str,
    target_stage: Optional[int] = None,
    *,
    policy_constraints: Optional[Dict[str, Any]] = None,
) -> Dict[str, Any]:
    """Progressively widen responder search through the configured stages."""
    from aws.agent.escalation_policy import get_stage_count

    ctx = get_incident_context(incident_id)
    state = str(ctx.get("state", ""))
    if state in {
        IncidentState.RESOLVED.value,
        IncidentState.CANCELLED.value,
        IncidentState.EXPIRED.value,
    }:
        return {"incident_id": incident_id, "status": "INCIDENT_CLOSED"}

    accepted = [
        mission
        for mission in _incident_missions(incident_id)
        if mission.get("status") in {"ACCEPTED", "EN_ROUTE", "ARRIVED"}
    ]
    if accepted:
        return {
            "incident_id": incident_id,
            "status": "ESCALATION_PAUSED_ACCEPTED",
            "accepted_count": len(accepted),
            "current_stage": int(ctx.get("current_escalation_stage") or 0),
        }

    current_stage = int(ctx.get("current_escalation_stage") or 0)
    stage_index = target_stage if target_stage is not None else current_stage + 1
    stage_count = get_stage_count()

    while stage_index <= stage_count:
        result = _dispatch_escalation_stage(
            incident_id,
            stage_index,
            policy_constraints=policy_constraints,
        )
        if result["status"] == "INVITATIONS_CREATED":
            return result
        # Zero candidates, insufficient quorum, or total transport failure: widen
        # immediately rather than waiting on a timer that cannot produce acceptance.
        stage_index += 1
        policy_constraints = None

    now_iso = datetime.now(timezone.utc).isoformat()
    dynamo = get_dynamo_resource()
    if dynamo:
        dynamo.Table(DYNAMODB_INCIDENTS_TABLE).update_item(
            Key={"incident_id": incident_id},
            UpdateExpression=(
                "SET current_escalation_stage = :stage, "
                "current_radius_meters = :radius, updated_at = :now"
            ),
            ExpressionAttributeValues={
                ":stage": stage_count,
                ":radius": 10000.0,
                ":now": now_iso,
            },
        )
    elif _dev_mode():
        from aws.incident_handler.handler import _LOCAL_INCIDENTS
        inc = _LOCAL_INCIDENTS.get(incident_id)
        if inc:
            inc["current_escalation_stage"] = stage_count
            inc["current_radius_meters"] = 10000.0
            inc["updated_at"] = now_iso
    append_incident_event(
        incident_id,
        "max_radius_reached",
        "SYSTEM",
        "Maximum community responder radius (10 km) reached with no active acceptance.",
    )
    return {
        "incident_id": incident_id,
        "status": "MAX_RADIUS_REACHED",
        "current_stage": stage_count,
        "dispatched_count": len(ctx.get("dispatched_responder_ids") or []),
    }


def process_incident_redispatch_eval(incident_id: str) -> Dict[str, Any]:
    """Advance when no accepted responder and no reachable live invitation remains."""
    ctx = get_incident_context(incident_id)
    state = str(ctx.get("state", ""))
    if state in {
        IncidentState.RESOLVED.value,
        IncidentState.CANCELLED.value,
        IncidentState.EXPIRED.value,
    }:
        return {"incident_id": incident_id, "status": "INCIDENT_CLOSED"}

    missions = _incident_missions(incident_id)
    accepted = [
        mission
        for mission in missions
        if mission.get("status") in {"ACCEPTED", "EN_ROUTE", "ARRIVED"}
    ]
    if accepted:
        return {
            "incident_id": incident_id,
            "status": "ACCEPTED_ACTIVE",
            "accepted_count": len(accepted),
        }

    now = int(datetime.now(timezone.utc).timestamp())
    pending_live = [
        mission
        for mission in missions
        if mission.get("status") == "INVITED"
        and int(mission.get("invitation_expires_at", 0)) > now
        and mission.get("invitation_delivery_status") == "PROVIDER_ACCEPTED"
    ]
    if pending_live:
        return {
            "incident_id": incident_id,
            "status": "WAITING_RESPONSE",
            "pending_count": len(pending_live),
        }

    return advance_incident_escalation(incident_id)

