"""
AWS Lambda: Guardian Incident Ingestion & State Machine Handler
Handles:
  - POST /incidents (Ingests sensor anomaly/SOS with idempotency check)
  - GET  /incidents/{id} (Polls incident state & agent reasoning)
  - PUT  /incidents/{id}/status (Transitions state: I'm OK / Need Help / Ack)
  - GET  /incidents/{id}/timeline (Returns chronological audit trail)
"""

import json
import os
import uuid
import hashlib
import logging
import threading
import time
from datetime import datetime, timezone
from typing import Dict, Any, Optional

try:
    import boto3
    from botocore.exceptions import ClientError
    BOTO3_AVAILABLE = True
except ImportError:
    BOTO3_AVAILABLE = False

from aws.incident_handler.state_machine import IncidentState, can_transition
from aws.agent.risk_engine import assess_incident_risk

# Environment configuration
DYNAMODB_INCIDENTS_TABLE = os.environ.get("DYNAMODB_INCIDENTS_TABLE", "guardian-incidents")
DYNAMODB_EVENTS_TABLE = os.environ.get("DYNAMODB_EVENTS_TABLE", "guardian-incident-events")
DYNAMODB_ABUSE_COUNTERS_TABLE = os.environ.get(
    "DYNAMODB_ABUSE_COUNTERS_TABLE", "guardian-abuse-counters"
)
EVENTBUS_NAME = os.environ.get("EVENTBUS_NAME", "default")
AWS_REGION = os.environ.get("AWS_REGION", "us-east-1")

# In-memory store fallback for local simulation & testing
_LOCAL_INCIDENTS: Dict[str, Dict[str, Any]] = {}
_LOCAL_EVENTS: Dict[str, list] = {}
_LOCAL_IDEMPOTENCY: Dict[str, str] = {}
_LOCAL_STORE_LOCK = threading.RLock()
logger = logging.getLogger(__name__)


def _local_store_enabled() -> bool:
    return os.environ.get("GUARDIAN_DEV_MODE", "false").lower() == "true"


def _require_local_store() -> None:
    if not _local_store_enabled():
        raise RuntimeError("DynamoDB is unavailable and GUARDIAN_DEV_MODE is not enabled")


def get_dynamo_resource():
    if BOTO3_AVAILABLE and os.environ.get("AWS_EXECUTION_ENV"):
        return boto3.resource("dynamodb", region_name=AWS_REGION)
    return None


def get_eventbridge_client():
    if BOTO3_AVAILABLE and os.environ.get("AWS_EXECUTION_ENV"):
        return boto3.client("events", region_name=AWS_REGION)
    return None


def _set_orchestration_event_state(
    incident_id: str,
    state: str,
    *,
    error: Optional[str] = None,
) -> None:
    """Persist whether incident.created was accepted by EventBridge."""
    now_iso = datetime.now(timezone.utc).isoformat()
    dynamo = get_dynamo_resource()
    if dynamo:
        values = {":state": state, ":now": now_iso}
        expression = "SET orchestration_event_state = :state, updated_at = :now"
        if error:
            expression += ", orchestration_event_error = :error"
            values[":error"] = str(error)[:500]
        else:
            expression += " REMOVE orchestration_event_error"
        dynamo.Table(DYNAMODB_INCIDENTS_TABLE).update_item(
            Key={"incident_id": incident_id},
            UpdateExpression=expression,
            ExpressionAttributeValues=values,
        )
        return
    if _local_store_enabled():
        with _LOCAL_STORE_LOCK:
            inc = _LOCAL_INCIDENTS.get(incident_id)
            if inc:
                inc["orchestration_event_state"] = state
                inc["updated_at"] = now_iso
                if error:
                    inc["orchestration_event_error"] = str(error)[:500]
                else:
                    inc.pop("orchestration_event_error", None)


def _emit_incident_created(incident_record: Dict[str, Any]) -> bool:
    """Emit incident.created and record delivery state for retry/reconciliation."""
    eb = get_eventbridge_client()
    if not eb:
        return False
    incident_id = str(incident_record["incident_id"])
    response = eb.put_events(
        Entries=[
            {
                "Source": "guardian.incident",
                "DetailType": "incident.created",
                "Detail": json.dumps(incident_record),
                "EventBusName": EVENTBUS_NAME,
            }
        ]
    )
    if response.get("FailedEntryCount", 0) > 0:
        entry = (response.get("Entries") or [{}])[0]
        error_msg = entry.get("ErrorMessage", "Unknown EventBridge error")
        _set_orchestration_event_state(incident_id, "FAILED", error=error_msg)
        logger.error("Failed to emit incident %s to EventBridge: %s", incident_id, error_msg)
        raise RuntimeError(f"EventBridge delivery failed: {error_msg}")
    _set_orchestration_event_state(incident_id, "EMITTED")
    incident_record["orchestration_event_state"] = "EMITTED"
    incident_record.pop("orchestration_event_error", None)
    return True


def _captured_at_epoch_ms(location: Any) -> Optional[int]:
    if not isinstance(location, dict):
        return None
    captured = location.get("captured_at")
    if not captured:
        return None
    try:
        dt = datetime.fromisoformat(str(captured).replace("Z", "+00:00"))
        if dt.tzinfo is None:
            dt = dt.replace(tzinfo=timezone.utc)
        return int(dt.timestamp() * 1000)
    except Exception:
        return None


def _incident_frequency_advisory(user_id: str, now: datetime) -> Dict[str, Any]:
    """Return a non-blocking high-frequency advisory for responder safety.

    This signal must never suppress or reject an SOS. Production uses a small
    TTL-backed DynamoDB counter so behavior matches local tests.
    """
    count = 1
    dynamo = get_dynamo_resource()
    if dynamo:
        bucket = int(now.timestamp()) // 600
        counter_key = f"{user_id}:{bucket}"
        try:
            response = dynamo.Table(DYNAMODB_ABUSE_COUNTERS_TABLE).update_item(
                Key={"counter_key": counter_key},
                UpdateExpression="ADD incident_count :one SET expires_at = :ttl, updated_at = :now",
                ExpressionAttributeValues={
                    ":one": 1,
                    ":ttl": int(now.timestamp()) + 3600,
                    ":now": now.isoformat(),
                },
                ReturnValues="UPDATED_NEW",
            )
            count = int(response.get("Attributes", {}).get("incident_count", 1))
        except Exception as error:
            logger.warning(
                "Incident-frequency advisory unavailable: %s",
                type(error).__name__,
            )
            return {}
    elif _local_store_enabled():
        count = 1
        now_ts = now.timestamp()
        for existing in _LOCAL_INCIDENTS.values():
            if existing.get("user_id") != user_id:
                continue
            try:
                created = datetime.fromisoformat(str(existing.get("created_at", "")))
                if created.tzinfo is None:
                    created = created.replace(tzinfo=timezone.utc)
                if (now_ts - created.timestamp()) <= 600.0:
                    count += 1
            except Exception:
                continue
    else:
        return {}

    if count < 4:
        return {}
    return {
        "high_frequency_creation": True,
        "recent_incident_count_10m": count,
        "advisory_only": True,
    }


def _trigger_provenance(event_type: str, motion_data: Dict[str, Any]) -> Dict[str, str]:
    """Classify reported trigger provenance without pretending device attestation."""
    normalized = str(event_type or "").strip().upper()
    if normalized == "MANUAL_SOS":
        return {
            "origin": "USER_DECLARED",
            "trust_level": "DECLARED_DISTRESS",
            "attestation": "NOT_REQUIRED_FOR_HELP_REQUEST",
        }
    if bool((motion_data or {}).get("native_dispatch")):
        return {
            "origin": "DEVICE_NATIVE_REPORTED",
            "trust_level": "UNATTESTED_DEVICE",
            "attestation": "NOT_PRESENT",
        }
    if normalized in {
        "ANDROID_POWER_GESTURE",
        "ANDROID_SHAKE",
        "ANDROID_FALL",
        "ROUTE_DEVIATION",
        "ROUTE_DEVIATION_TIMEOUT",
        "CHECK_IN_EXPIRED",
        "VOICE_SOS",
        "MULTI_TAP",
    }:
        return {
            "origin": "DEVICE_REPORTED",
            "trust_level": "UNATTESTED_CLIENT",
            "attestation": "NOT_PRESENT",
        }
    return {
        "origin": "CLIENT_REPORTED",
        "trust_level": "UNATTESTED_CLIENT",
        "attestation": "NOT_PRESENT",
    }


def create_incident(payload: Dict[str, Any]) -> Dict[str, Any]:
    """Ingest a new incident with idempotency guarantee."""
    event_id = payload.get("event_id") or str(uuid.uuid4())
    user_id = payload.get("user_id", "anonymous_user")
    event_type = payload.get("event_type", "fall_detected")
    location = payload.get("location", {})
    motion_data = payload.get("motion_data", {})
    
    # Idempotency check
    dynamo = get_dynamo_resource()
    if dynamo:
        table = dynamo.Table(DYNAMODB_INCIDENTS_TABLE)
        # Check if event_id already exists via GSI or scan/query
        # For atomic creation, we check our local/cache or conditional put
    else:
        _require_local_store()
        local_idempotency_key = f"{user_id}:{event_id}"
        if local_idempotency_key in _LOCAL_IDEMPOTENCY:
            existing_id = _LOCAL_IDEMPOTENCY[local_idempotency_key]
            return _LOCAL_INCIDENTS[existing_id]

    # A deterministic key makes retries idempotent even when the first
    # response is lost and separate Lambda containers process the requests.
    idempotency_key = f"{user_id}:{event_id}".encode("utf-8")
    incident_id = f"inc_{hashlib.sha256(idempotency_key).hexdigest()[:24]}"
    now_iso = datetime.now(timezone.utc).isoformat()

    # Calculate initial risk assessment via Risk Engine
    risk = assess_incident_risk(
        event_type=event_type,
        location=location,
        motion_data=motion_data,
    )
    abuse_signals = _incident_frequency_advisory(
        user_id,
        datetime.now(timezone.utc),
    )
    if abuse_signals:
        risk["abuse_signals"] = abuse_signals
        risk["responder_advisory"] = (
            "Caution: Multiple recent alerts were recorded from this account. "
            "This advisory never suppresses the SOS; responders should preserve "
            "buddy-safety procedures."
        )

    initial_state = IncidentState.CLOUD_ACCEPTED.value
    curr_location = dict(location) if isinstance(location, dict) else location
    if isinstance(curr_location, dict) and "captured_at" in curr_location and "freshness" not in curr_location:
        try:
            cap_dt = datetime.fromisoformat(str(curr_location["captured_at"]))
            if cap_dt.tzinfo is None:
                cap_dt = cap_dt.replace(tzinfo=timezone.utc)
            age = max(0.0, (datetime.now(timezone.utc) - cap_dt).total_seconds())
            curr_location["freshness"] = "FRESH" if age <= 30 else "STALE"
            curr_location["age_seconds"] = round(age, 1)
        except Exception:
            curr_location["freshness"] = "UNKNOWN"

    initial_location_epoch_ms = _captured_at_epoch_ms(curr_location)
    incident_record = {
        "incident_id": incident_id,
        "event_id": event_id,
        "user_id": user_id,
        "event_type": event_type,
        "state": initial_state,
        "location": location,
        "initial_sos_location": location,
        "current_emergency_location": curr_location,
        "current_location_captured_at_ms": initial_location_epoch_ms,
        "motion_data": motion_data,
        "trigger_source": (motion_data or {}).get("trigger_source") or event_type,
        "trigger_provenance": _trigger_provenance(event_type, motion_data or {}),
        "risk_assessment": risk,
        "created_at": now_iso,
        "updated_at": now_iso,
        "agent_decision": "PENDING_REASONING",
        "agent_execution_state": "PENDING",
        "orchestration_event_state": "PENDING",
        "agent_rationale": "Initial anomaly observed. Awaiting autonomous agent evaluation.",
    }
    if "contacts" in payload:
        incident_record["contacts"] = payload["contacts"]

    # Record first timeline event
    timeline_entry = {
        "incident_id": incident_id,
        "timestamp": now_iso,
        "event_type": event_type,
        "trigger_source": (motion_data or {}).get("trigger_source") or event_type,
        "state": initial_state,
        "actor": "SYSTEM",
        "details": f"Anomaly detected ({event_type}) with risk level {risk['level']} (score: {risk['score']})",
    }

    # Persist
    if dynamo:
        table = dynamo.Table(DYNAMODB_INCIDENTS_TABLE)
        try:
            table.put_item(
                Item=incident_record,
                ConditionExpression="attribute_not_exists(incident_id)",
            )
        except ClientError as error:
            if error.response.get("Error", {}).get("Code") != "ConditionalCheckFailedException":
                raise
            existing = table.get_item(
                Key={"incident_id": incident_id},
                ConsistentRead=True,
            ).get("Item")
            if existing:
                # If persistence succeeded previously but EventBridge delivery did
                # not, an idempotent mobile retry repairs orchestration instead of
                # silently returning a stranded incident.
                if existing.get("orchestration_event_state") != "EMITTED":
                    _emit_incident_created(existing)
                return existing
            raise

        events_table = dynamo.Table(DYNAMODB_EVENTS_TABLE)
        events_table.put_item(Item=timeline_entry)

        # Event emission is part of durable incident ingestion. A failed emit is
        # persisted as FAILED and retried on the next idempotent create request.
        _emit_incident_created(incident_record)
    else:
        _require_local_store()
        _LOCAL_INCIDENTS[incident_id] = incident_record
        _LOCAL_EVENTS[incident_id] = [timeline_entry]
        _LOCAL_IDEMPOTENCY[f"{user_id}:{event_id}"] = incident_id

    return incident_record


def update_incident_status(incident_id: str, new_state: str, actor: str = "USER", note: str = "") -> Dict[str, Any]:
    """Execute an idempotent, compare-and-set lifecycle transition."""
    dynamo = get_dynamo_resource()
    now_iso = datetime.now(timezone.utc).isoformat()
    try:
        target_state = IncidentState(str(new_state).upper()).value
    except ValueError as exc:
        raise ValueError(f"Unknown incident state: {new_state}") from exc
    actor = str(actor).upper()[:40]

    if dynamo:
        table = dynamo.Table(DYNAMODB_INCIDENTS_TABLE)
        incident = table.get_item(
            Key={"incident_id": incident_id}, ConsistentRead=True
        ).get("Item")
        if not incident:
            raise ValueError(f"Incident {incident_id} not found")
        current_state = incident["state"]
        if current_state == target_state:
            return incident
        if not can_transition(current_state, target_state):
            raise ValueError(
                f"Illegal transition from {current_state} to {target_state}"
            )
        try:
            response = table.update_item(
                Key={"incident_id": incident_id},
                UpdateExpression="SET #s = :target, updated_at = :updated, agent_rationale = :note",
                ConditionExpression="#s = :expected",
                ExpressionAttributeNames={"#s": "state"},
                ExpressionAttributeValues={
                    ":target": target_state,
                    ":expected": current_state,
                    ":updated": now_iso,
                    ":note": note or incident.get("agent_rationale", ""),
                },
                ReturnValues="ALL_NEW",
            )
            incident = response["Attributes"]
        except ClientError as error:
            if error.response.get("Error", {}).get("Code") != "ConditionalCheckFailedException":
                raise
            latest = table.get_item(
                Key={"incident_id": incident_id}, ConsistentRead=True
            ).get("Item")
            if latest and latest.get("state") == target_state:
                return latest
            latest_state = latest.get("state") if latest else "missing"
            raise ValueError(
                f"Stale transition from {current_state}; current state is {latest_state}"
            ) from error
    else:
        _require_local_store()
        with _LOCAL_STORE_LOCK:
            incident = _LOCAL_INCIDENTS.get(incident_id)
            if not incident:
                raise ValueError(f"Incident {incident_id} not found")
            current_state = incident["state"]
            if current_state == target_state:
                return incident
            if not can_transition(current_state, target_state):
                raise ValueError(
                    f"Illegal transition from {current_state} to {target_state}"
                )
            incident = {
                **incident,
                "state": target_state,
                "updated_at": now_iso,
                "agent_rationale": note or incident.get("agent_rationale", ""),
            }
            _LOCAL_INCIDENTS[incident_id] = incident

    timeline_entry = {
        "incident_id": incident_id,
        "timestamp": now_iso,
        "event_type": f"state_transition_to_{target_state}",
        "state": target_state,
        "actor": actor,
        "details": note or f"State transitioned from {current_state} to {target_state} by {actor}",
    }

    if dynamo:
        events_table = dynamo.Table(DYNAMODB_EVENTS_TABLE)
        events_table.put_item(Item=timeline_entry)
    else:
        _require_local_store()
        with _LOCAL_STORE_LOCK:
            _LOCAL_EVENTS.setdefault(incident_id, []).append(timeline_entry)

    return incident


def get_incident(incident_id: str) -> Optional[Dict[str, Any]]:
    dynamo = get_dynamo_resource()
    if dynamo:
        table = dynamo.Table(DYNAMODB_INCIDENTS_TABLE)
        resp = table.get_item(Key={"incident_id": incident_id})
        return resp.get("Item")
    _require_local_store()
    return _LOCAL_INCIDENTS.get(incident_id)



def acquire_agent_lease(
    incident_id: str,
    correlation_id: str,
    *,
    lease_seconds: int = 90,
) -> bool:
    """Atomically acquire the initial-agent execution lease.

    Business decision state (agent_decision) is deliberately separate from the
    distributed execution lock. A crashed RUNNING lease may be reclaimed only
    after expiry; COMPLETED executions are never replayed.
    """
    now_epoch = int(time.time())
    lease_until = now_epoch + max(30, int(lease_seconds))
    dynamo = get_dynamo_resource()
    if not dynamo:
        _require_local_store()
        with _LOCAL_STORE_LOCK:
            inc = _LOCAL_INCIDENTS.get(incident_id)
            if not inc:
                return False
            raw_state = inc.get("agent_execution_state")
            if raw_state is None and inc.get("agent_decision") not in (
                None,
                "",
                "PENDING_REASONING",
            ):
                return False
            state = str(raw_state or "PENDING")
            expiry = int(inc.get("agent_lease_expires_at") or 0)
            if state == "COMPLETED":
                return False
            if state == "RUNNING" and expiry >= now_epoch:
                return False
            inc["agent_execution_state"] = "RUNNING"
            inc["agent_run_id"] = correlation_id
            inc["agent_lease_expires_at"] = lease_until
            return True

    table = dynamo.Table(DYNAMODB_INCIDENTS_TABLE)
    try:
        table.update_item(
            Key={"incident_id": incident_id},
            UpdateExpression=(
                "SET agent_execution_state = :running, "
                "agent_run_id = :run_id, agent_lease_expires_at = :lease_until"
            ),
            ConditionExpression=(
                "(attribute_not_exists(agent_execution_state) "
                "AND (attribute_not_exists(agent_decision) "
                "OR agent_decision = :pending_decision "
                "OR agent_decision = :empty)) "
                "OR agent_execution_state = :pending "
                "OR agent_execution_state = :failed "
                "OR (agent_execution_state = :running "
                "AND agent_lease_expires_at < :now)"
            ),
            ExpressionAttributeValues={
                ":running": "RUNNING",
                ":pending": "PENDING",
                ":failed": "FAILED",
                ":pending_decision": "PENDING_REASONING",
                ":empty": "",
                ":run_id": correlation_id,
                ":lease_until": lease_until,
                ":now": now_epoch,
            },
        )
        return True
    except ClientError as error:
        if error.response.get("Error", {}).get("Code") == "ConditionalCheckFailedException":
            return False
        raise


def finish_agent_run(
    incident_id: str,
    correlation_id: str,
    *,
    success: bool,
) -> None:
    """Release the matching lease as COMPLETED or FAILED."""
    final_state = "COMPLETED" if success else "FAILED"
    now_iso = datetime.now(timezone.utc).isoformat()
    dynamo = get_dynamo_resource()
    if not dynamo:
        _require_local_store()
        with _LOCAL_STORE_LOCK:
            inc = _LOCAL_INCIDENTS.get(incident_id)
            if inc and inc.get("agent_run_id") == correlation_id:
                inc["agent_execution_state"] = final_state
                inc["agent_completed_at"] = now_iso
                inc.pop("agent_lease_expires_at", None)
        return

    try:
        dynamo.Table(DYNAMODB_INCIDENTS_TABLE).update_item(
            Key={"incident_id": incident_id},
            UpdateExpression=(
                "SET agent_execution_state = :state, agent_completed_at = :now "
                "REMOVE agent_lease_expires_at"
            ),
            ConditionExpression="agent_run_id = :run_id",
            ExpressionAttributeValues={
                ":state": final_state,
                ":now": now_iso,
                ":run_id": correlation_id,
            },
        )
    except ClientError as error:
        if error.response.get("Error", {}).get("Code") == "ConditionalCheckFailedException":
            logger.warning(
                "Agent lease completion ignored for stale run %s on %s",
                correlation_id,
                incident_id,
            )
            return
        raise


def get_incident_timeline(incident_id: str) -> list:
    dynamo = get_dynamo_resource()
    if dynamo:
        events_table = dynamo.Table(DYNAMODB_EVENTS_TABLE)
        resp = events_table.query(
            KeyConditionExpression="incident_id = :iid",
            ExpressionAttributeValues={":iid": incident_id},
            ScanIndexForward=True,
        )
        return resp.get("Items", [])
    _require_local_store()
    return _LOCAL_EVENTS.get(incident_id, [])


def append_incident_event(
    incident_id: str,
    event_type: str,
    actor: str,
    details: str,
    *,
    state: Optional[str] = None,
) -> Dict[str, Any]:
    """Append audit evidence without changing the incident lifecycle state."""
    incident = get_incident(incident_id)
    if not incident:
        raise ValueError(f"Incident {incident_id} not found")
    entry = {
        "incident_id": incident_id,
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "event_type": str(event_type)[:80],
        "state": state or incident["state"],
        "actor": str(actor).upper()[:40],
        "details": str(details)[:500],
    }
    dynamo = get_dynamo_resource()
    if dynamo:
        dynamo.Table(DYNAMODB_EVENTS_TABLE).put_item(Item=entry)
    else:
        _require_local_store()
        with _LOCAL_STORE_LOCK:
            _LOCAL_EVENTS.setdefault(incident_id, []).append(entry)
    return entry


def update_incident_location(
    incident_id: str,
    location_payload: Dict[str, Any],
    user_id: str,
) -> Dict[str, Any]:
    """
    Monotonically update active incident location.
    Requires caller ownership and active incident state.
    Rejects out-of-order or stale capture timestamps.
    """
    incident = get_incident(incident_id)
    if not incident:
        raise ValueError(f"Incident {incident_id} not found")
    if incident.get("user_id") != user_id:
        raise PermissionError("Only the incident owner can update emergency location")

    current_state = incident.get("state")
    if current_state in {
        IncidentState.RESOLVED.value,
        IncidentState.CANCELLED.value,
        IncidentState.EXPIRED.value,
    }:
        raise ValueError(f"Cannot update location for {current_state} incident")

    # Validate coordinate bounds
    try:
        lat = float(location_payload["latitude"])
        lng = float(location_payload["longitude"])
    except (KeyError, TypeError, ValueError) as err:
        raise ValueError(f"Invalid latitude/longitude: {err}")
    if not (-90.0 <= lat <= 90.0 and -180.0 <= lng <= 180.0):
        raise ValueError("Latitude/longitude out of valid range")

    now = datetime.now(timezone.utc)
    now_iso = now.isoformat()

    # Monotonic timestamp check
    incoming_cap_str = location_payload.get("captured_at")
    if incoming_cap_str:
        try:
            incoming_cap = datetime.fromisoformat(incoming_cap_str.replace("Z", "+00:00"))
        except Exception as e:
            raise ValueError(f"Invalid captured_at ISO timestamp: {e}")
        # Reject future timestamps beyond 5 minutes
        if (incoming_cap - now).total_seconds() > 300:
            raise ValueError("Captured timestamp cannot be in the future")
    else:
        incoming_cap = now
        location_payload["captured_at"] = now_iso

    current_loc = incident.get("current_emergency_location") or incident.get("location") or {}
    existing_cap_str = current_loc.get("captured_at")
    if existing_cap_str:
        try:
            existing_cap = datetime.fromisoformat(existing_cap_str.replace("Z", "+00:00"))
            if incoming_cap <= existing_cap:
                raise ValueError("Out-of-order or stale location update rejected")
        except ValueError:
            raise
        except Exception:
            pass

    location_payload["received_at"] = now_iso
    incoming_epoch_ms = int(incoming_cap.timestamp() * 1000)
    initial_loc = incident.get("initial_sos_location") or incident.get("location") or location_payload

    dynamo = get_dynamo_resource()
    if dynamo:
        table = dynamo.Table(DYNAMODB_INCIDENTS_TABLE)
        try:
            response = table.update_item(
                Key={"incident_id": incident_id},
                UpdateExpression=(
                    "SET current_emergency_location = :curr, #loc = :curr, "
                    "initial_sos_location = :init, current_location_captured_at_ms = :captured, "
                    "updated_at = :now"
                ),
                ConditionExpression=(
                    "#owner = :owner AND "
                    "#state <> :resolved AND #state <> :cancelled AND #state <> :expired AND "
                    "(attribute_not_exists(current_location_captured_at_ms) OR "
                    "current_location_captured_at_ms < :captured)"
                ),
                ExpressionAttributeNames={
                    "#loc": "location",
                    "#owner": "user_id",
                    "#state": "state",
                },
                ExpressionAttributeValues={
                    ":curr": location_payload,
                    ":init": initial_loc,
                    ":captured": incoming_epoch_ms,
                    ":now": now_iso,
                    ":owner": user_id,
                    ":resolved": IncidentState.RESOLVED.value,
                    ":cancelled": IncidentState.CANCELLED.value,
                    ":expired": IncidentState.EXPIRED.value,
                },
                ReturnValues="ALL_NEW",
            )
            incident = response["Attributes"]
        except ClientError as error:
            if error.response.get("Error", {}).get("Code") != "ConditionalCheckFailedException":
                raise
            latest = table.get_item(
                Key={"incident_id": incident_id},
                ConsistentRead=True,
            ).get("Item")
            if not latest:
                raise ValueError(f"Incident {incident_id} not found") from error
            if latest.get("user_id") != user_id:
                raise PermissionError("Only the incident owner can update emergency location") from error
            if latest.get("state") in {
                IncidentState.RESOLVED.value,
                IncidentState.CANCELLED.value,
                IncidentState.EXPIRED.value,
            }:
                raise ValueError(
                    f"Cannot update location for {latest.get('state')} incident"
                ) from error
            raise ValueError("Out-of-order or stale location update rejected") from error
    else:
        _require_local_store()
        with _LOCAL_STORE_LOCK:
            latest = _LOCAL_INCIDENTS.get(incident_id)
            if not latest:
                raise ValueError(f"Incident {incident_id} not found")
            if latest.get("user_id") != user_id:
                raise PermissionError("Only the incident owner can update emergency location")
            if latest.get("state") in {
                IncidentState.RESOLVED.value,
                IncidentState.CANCELLED.value,
                IncidentState.EXPIRED.value,
            }:
                raise ValueError(f"Cannot update location for {latest.get('state')} incident")
            existing_epoch = latest.get("current_location_captured_at_ms")
            if existing_epoch is not None and int(existing_epoch) >= incoming_epoch_ms:
                raise ValueError("Out-of-order or stale location update rejected")
            latest["current_emergency_location"] = location_payload
            latest["location"] = location_payload
            latest["initial_sos_location"] = initial_loc
            latest["current_location_captured_at_ms"] = incoming_epoch_ms
            latest["updated_at"] = now_iso
            _LOCAL_INCIDENTS[incident_id] = latest
            incident = latest

    append_incident_event(
        incident_id=incident_id,
        event_type="victim_location_updated",
        actor="VICTIM_DEVICE",
        details="Victim location updated with a newer authenticated device fix.",
        state=current_state,
    )

    return incident
