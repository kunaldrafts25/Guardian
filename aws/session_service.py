"""Server-enforced Guardian application sessions.

Cognito validates token authenticity and expiry. This registry binds each
token use to an opaque Guardian session id so an individual signed-in device
can be revoked immediately, without waiting for its Cognito access token to
expire.
"""

import hashlib
import hmac
import os
import uuid
from datetime import datetime, timedelta, timezone
from typing import Any, Dict, List, Optional

try:
    import boto3
    from botocore.exceptions import ClientError
except ImportError:  # pragma: no cover - production package includes boto3
    boto3 = None
    ClientError = Exception


SESSIONS_TABLE = os.environ.get("DYNAMODB_SESSIONS_TABLE", "guardian-sessions")
SESSION_LIFETIME_DAYS = 30
_LOCAL_SESSIONS: Dict[str, Dict[str, Any]] = {}


def _dev_mode() -> bool:
    return os.environ.get("GUARDIAN_DEV_MODE", "false").lower() == "true"


def _table():
    if boto3 is None:
        return None
    return boto3.resource(
        "dynamodb",
        region_name=os.environ.get("AWS_DEFAULT_REGION", "ap-south-1"),
    ).Table(SESSIONS_TABLE)


def _refresh_hash(refresh_token: str) -> str:
    return hashlib.sha256(refresh_token.encode("utf-8")).hexdigest()


def _clean_device_label(value: str) -> str:
    label = " ".join(value.strip().split())[:80]
    return label or "Guardian mobile device"


def create_session(
    user_id: str,
    refresh_token: str,
    device_label: str,
    platform: str,
) -> Dict[str, Any]:
    if not user_id or not refresh_token:
        raise ValueError("A verified user and refresh token are required")
    now = datetime.now(timezone.utc)
    item = {
        "session_id": str(uuid.uuid4()),
        "user_id": user_id,
        "refresh_token_hash": _refresh_hash(refresh_token),
        "device_label": _clean_device_label(device_label),
        "platform": platform.strip().lower()[:20] or "unknown",
        "status": "active",
        "created_at": now.isoformat(),
        "last_seen_at": now.isoformat(),
        "expires_at": int((now + timedelta(days=SESSION_LIFETIME_DAYS)).timestamp()),
    }
    if _dev_mode():
        _LOCAL_SESSIONS[item["session_id"]] = item
    else:
        table = _table()
        if table is None:
            raise RuntimeError("Session storage is unavailable")
        table.put_item(Item=item, ConditionExpression="attribute_not_exists(session_id)")
    return {key: item[key] for key in ("session_id", "device_label", "platform", "created_at")}


def _get_session(session_id: str) -> Optional[Dict[str, Any]]:
    if not session_id or len(session_id) > 64:
        return None
    if _dev_mode():
        return _LOCAL_SESSIONS.get(session_id)
    table = _table()
    if table is None:
        raise RuntimeError("Session storage is unavailable")
    return table.get_item(Key={"session_id": session_id}, ConsistentRead=True).get("Item")


def validate_access_session(session_id: str, user_id: str) -> bool:
    if _dev_mode() and session_id == "dev-session":
        return True
    item = _get_session(session_id)
    if not item or item.get("user_id") != user_id or item.get("status") != "active":
        return False
    return int(item.get("expires_at", 0)) > int(datetime.now(timezone.utc).timestamp())


def validate_refresh_session(session_id: str, refresh_token: str) -> str:
    item = _get_session(session_id)
    if (
        not item
        or item.get("status") != "active"
        or int(item.get("expires_at", 0)) <= int(datetime.now(timezone.utc).timestamp())
        or not hmac.compare_digest(
            str(item.get("refresh_token_hash", "")), _refresh_hash(refresh_token)
        )
    ):
        raise ValueError("The session is invalid, expired, or revoked")
    return str(item["user_id"])


def touch_session(session_id: str, user_id: str) -> None:
    now = datetime.now(timezone.utc).isoformat()
    if _dev_mode():
        item = _LOCAL_SESSIONS.get(session_id)
        if item and item.get("user_id") == user_id:
            item["last_seen_at"] = now
        return
    table = _table()
    if table is None:
        raise RuntimeError("Session storage is unavailable")
    table.update_item(
        Key={"session_id": session_id},
        UpdateExpression="SET last_seen_at = :now",
        ConditionExpression="user_id = :user AND #status = :active",
        ExpressionAttributeNames={"#status": "status"},
        ExpressionAttributeValues={":now": now, ":user": user_id, ":active": "active"},
    )


def list_sessions(user_id: str) -> List[Dict[str, Any]]:
    if _dev_mode():
        items = [item for item in _LOCAL_SESSIONS.values() if item.get("user_id") == user_id]
    else:
        table = _table()
        if table is None:
            raise RuntimeError("Session storage is unavailable")
        items = []
        request = {
            "IndexName": "UserSessionsIndex",
            "KeyConditionExpression": "user_id = :user",
            "ExpressionAttributeValues": {":user": user_id},
            "ScanIndexForward": False,
        }
        while True:
            response = table.query(**request)
            items.extend(response.get("Items", []))
            last_key = response.get("LastEvaluatedKey")
            if not last_key:
                break
            request["ExclusiveStartKey"] = last_key
    return [
        {
            "session_id": item["session_id"],
            "device_label": item.get("device_label", "Guardian mobile device"),
            "platform": item.get("platform", "unknown"),
            "status": item.get("status", "revoked"),
            "created_at": item.get("created_at"),
            "last_seen_at": item.get("last_seen_at"),
        }
        for item in items
    ]


def revoke_session(user_id: str, session_id: str) -> None:
    if _dev_mode():
        item = _LOCAL_SESSIONS.get(session_id)
        if not item or item.get("user_id") != user_id:
            raise ValueError("Session not found")
        item["status"] = "revoked"
        item["revoked_at"] = datetime.now(timezone.utc).isoformat()
        return
    table = _table()
    if table is None:
        raise RuntimeError("Session storage is unavailable")
    try:
        table.update_item(
            Key={"session_id": session_id},
            UpdateExpression="SET #status = :revoked, revoked_at = :now",
            ConditionExpression="user_id = :user AND attribute_exists(session_id)",
            ExpressionAttributeNames={"#status": "status"},
            ExpressionAttributeValues={
                ":revoked": "revoked",
                ":now": datetime.now(timezone.utc).isoformat(),
                ":user": user_id,
            },
        )
    except ClientError as error:
        if error.response.get("Error", {}).get("Code") == "ConditionalCheckFailedException":
            raise ValueError("Session not found") from error
        raise


def revoke_all_sessions(user_id: str) -> None:
    for session in list_sessions(user_id):
        if session["status"] == "active":
            revoke_session(user_id, session["session_id"])
