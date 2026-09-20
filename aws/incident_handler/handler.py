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
import threading
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
EVENTBUS_NAME = os.environ.get("EVENTBUS_NAME", "default")
AWS_REGION = os.environ.get("AWS_REGION", "us-east-1")

# In-memory store fallback for local simulation & testing
_LOCAL_INCIDENTS: Dict[str, Dict[str, Any]] = {}
_LOCAL_EVENTS: Dict[str, list] = {}
_LOCAL_IDEMPOTENCY: Dict[str, str] = {}
_LOCAL_STORE_LOCK = threading.RLock()


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

    initial_state = IncidentState.CLOUD_ACCEPTED.value

    incident_record = {
        "incident_id": incident_id,
        "event_id": event_id,
        "user_id": user_id,
        "event_type": event_type,
        "state": initial_state,
        "location": location,
        "motion_data": motion_data,
        "risk_assessment": risk,
        "created_at": now_iso,
        "updated_at": now_iso,
        "agent_decision": "PENDING_REASONING",
        "agent_rationale": "Initial anomaly observed. Awaiting autonomous agent evaluation.",
    }
    if "contacts" in payload:
        incident_record["contacts"] = payload["contacts"]

    # Record first timeline event
    timeline_entry = {
        "incident_id": incident_id,
        "timestamp": now_iso,
        "event_type": event_type,
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
                return existing
            raise
        
        events_table = dynamo.Table(DYNAMODB_EVENTS_TABLE)
        events_table.put_item(Item=timeline_entry)

        # Emit to EventBridge
        eb = get_eventbridge_client()
        if eb:
            eb.put_events(
                Entries=[
                    {
                        "Source": "guardian.incident",
                        "DetailType": "incident.created",
                        "Detail": json.dumps(incident_record),
                        "EventBusName": EVENTBUS_NAME,
                    }
                ]
            )
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


def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Standard AWS API Gateway / EventBridge Lambda handler
    """
    http_method = event.get("httpMethod") or event.get("requestContext", {}).get("http", {}).get("method", "GET")
    path = event.get("path") or event.get("rawPath", "/")

    allowed_origin = os.environ.get("GUARDIAN_ALLOWED_ORIGIN", "")
    headers = {
        "Content-Type": "application/json",
        "Access-Control-Allow-Methods": "GET, POST, PUT, OPTIONS",
        "Access-Control-Allow-Headers": "Content-Type, Authorization, X-Amz-Date, X-Api-Key",
    }
    if allowed_origin:
        headers["Access-Control-Allow-Origin"] = allowed_origin

    if http_method == "OPTIONS":
        return {"statusCode": 200, "headers": headers, "body": ""}

    try:
        body = {}
        if event.get("body"):
            body = json.loads(event["body"]) if isinstance(event["body"], str) else event["body"]

        # POST /incidents
        if http_method == "POST" and path.endswith("/incidents"):
            res = create_incident(body)
            return {"statusCode": 201, "headers": headers, "body": json.dumps(res)}

        # PUT /incidents/{id}/status
        if http_method == "PUT" and "/incidents/" in path and path.endswith("/status"):
            parts = path.strip("/").split("/")
            incident_id = parts[parts.index("incidents") + 1]
            new_state = body.get("state")
            actor = body.get("actor", "USER")
            note = body.get("note", "")
            res = update_incident_status(incident_id, new_state, actor, note)
            return {"statusCode": 200, "headers": headers, "body": json.dumps(res)}

        # GET /incidents/{id}/timeline
        if http_method == "GET" and "/incidents/" in path and path.endswith("/timeline"):
            parts = path.strip("/").split("/")
            incident_id = parts[parts.index("incidents") + 1]
            timeline = get_incident_timeline(incident_id)
            return {"statusCode": 200, "headers": headers, "body": json.dumps({"incident_id": incident_id, "timeline": timeline})}

        # GET /incidents/{id}
        if http_method == "GET" and "/incidents/" in path:
            parts = path.strip("/").split("/")
            incident_id = parts[parts.index("incidents") + 1]
            res = get_incident(incident_id)
            if not res:
                return {"statusCode": 404, "headers": headers, "body": json.dumps({"error": "Incident not found"})}
        # GET /incidents/{id}/nearby
        if http_method == "GET" and "/incidents/" in path and path.endswith("/nearby"):
            parts = path.strip("/").split("/")
            incident_id = parts[parts.index("incidents") + 1]
            from aws.agent.tools import find_nearby_responders
            responders = find_nearby_responders(incident_id)
            return {"statusCode": 200, "headers": headers, "body": json.dumps({"incident_id": incident_id, "nearby_responders": responders})}

        # POST /incidents/{id}/accept
        if http_method == "POST" and "/incidents/" in path and path.endswith("/accept"):
            parts = path.strip("/").split("/")
            incident_id = parts[parts.index("incidents") + 1]
            responder_id = body.get("responder_id", "resp_01")
            from aws.agent.tools import accept_rescue_mission
            result = accept_rescue_mission(incident_id, responder_id)
            return {"statusCode": 200, "headers": headers, "body": json.dumps(result)}

        # POST /responders/heartbeat
        if http_method == "POST" and path.endswith("/responders/heartbeat"):
            from aws.agent.tools import register_responder_heartbeat
            res = register_responder_heartbeat(
                responder_id=body.get("responder_id", "resp_new"),
                name=body.get("name", "Good Samaritan"),
                latitude=body.get("latitude", 19.0760),
                longitude=body.get("longitude", 72.8777),
                trust_score=body.get("trust_score", 85),
            )
            return {"statusCode": 200, "headers": headers, "body": json.dumps(res)}

        return {"statusCode": 404, "headers": headers, "body": json.dumps({"error": f"Path not found: {path}"})}

    except ValueError as ve:
        return {"statusCode": 400, "headers": headers, "body": json.dumps({"error": str(ve)})}
    except Exception as e:
        return {"statusCode": 500, "headers": headers, "body": json.dumps({"error": str(e)})}
