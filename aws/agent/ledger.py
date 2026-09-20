"""Append-only evidence ledger for Guardian agent decisions and tool execution."""

import os
import uuid
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional

try:
    import boto3
except ImportError:  # pragma: no cover
    boto3 = None


AGENT_LEDGER_TABLE = os.environ.get("DYNAMODB_AGENT_LEDGER_TABLE", "guardian-agent-ledger")
_LOCAL_LEDGER: Dict[str, List[Dict[str, Any]]] = {}


def _dev_mode() -> bool:
    return os.environ.get("GUARDIAN_DEV_MODE", "false").lower() == "true"


def _table():
    if boto3 is None:
        return None
    return boto3.resource(
        "dynamodb",
        region_name=os.environ.get("AWS_DEFAULT_REGION", "ap-south-1"),
    ).Table(AGENT_LEDGER_TABLE)


def append_agent_event(
    *,
    incident_id: str,
    correlation_id: str,
    event_type: str,
    policy_version: str,
    decision: Optional[str] = None,
    action: Optional[str] = None,
    authorization_id: Optional[str] = None,
    outcome: Optional[str] = None,
    evidence: Optional[Dict[str, Any]] = None,
) -> Dict[str, Any]:
    """Append one immutable, location-safe event to the agent ledger."""
    if not incident_id or not correlation_id or not event_type:
        raise ValueError("Agent ledger event context is incomplete")
    now = datetime.now(timezone.utc)
    item = {
        "incident_id": incident_id,
        "event_id": f"{now.isoformat()}#{uuid.uuid4()}",
        "correlation_id": correlation_id,
        "event_type": event_type,
        "policy_version": policy_version,
        "recorded_at": now.isoformat(),
    }
    optional = {
        "decision": decision,
        "action": action,
        "authorization_id": authorization_id,
        "outcome": outcome,
        "evidence": _safe_evidence(evidence or {}),
    }
    item.update({key: value for key, value in optional.items() if value not in (None, {}, "")})

    if _dev_mode():
        _LOCAL_LEDGER.setdefault(incident_id, []).append(item)
    else:
        table = _table()
        if table is None:
            raise RuntimeError("Agent ledger is unavailable")
        table.put_item(
            Item=item,
            ConditionExpression="attribute_not_exists(incident_id) AND attribute_not_exists(event_id)",
        )
    return item


def list_agent_events(incident_id: str) -> List[Dict[str, Any]]:
    if _dev_mode():
        return list(_LOCAL_LEDGER.get(incident_id, []))
    table = _table()
    if table is None:
        raise RuntimeError("Agent ledger is unavailable")
    return table.query(
        KeyConditionExpression="incident_id = :incident",
        ExpressionAttributeValues={":incident": incident_id},
        ScanIndexForward=True,
    ).get("Items", [])


def _safe_evidence(value: Dict[str, Any]) -> Dict[str, Any]:
    """Allow operational evidence while excluding coordinates, messages, and tokens."""
    allowed = {
        "risk_level",
        "risk_score",
        "provider",
        "delivery_status",
        "message_id",
        "state",
        "status",
        "dispatched_count",
        "invite_count",
        "retryable",
        "error_type",
        "policy_reasons",
    }
    return {
        key: value
        for key, value in value.items()
        if key in allowed and isinstance(value, (str, int, float, bool))
    }
