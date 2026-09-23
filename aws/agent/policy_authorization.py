"""Short-lived authorization capabilities for safety-critical agent tools."""

import base64
import hashlib
import hmac
import json
import os
import secrets
import threading
import time
import uuid
from functools import lru_cache
from typing import Any, Dict, Iterable

try:
    import boto3
except ImportError:  # pragma: no cover - production package includes boto3
    boto3 = None


POLICY_VERSION = "guardian-safety-v1"
MAX_TOKEN_LIFETIME_SECONDS = 90
DECISION_ACTIONS = {
    "ESCALATE_IMMEDIATELY_WITH_COMMUNITY": frozenset(
        {"notify_trusted_contact", "dispatch_community_alert"}
    ),
    "OWNER_REQUESTED_ESCALATION": frozenset(
        {"notify_trusted_contact", "dispatch_community_alert"}
    ),
}
_DEV_KEY = secrets.token_bytes(32)
_REPLAY_LOCK = threading.RLock()
_CONSUMED_AUTHORIZATIONS: Dict[str, int] = {}
AGENT_AUTHORIZATIONS_TABLE = os.environ.get(
    "DYNAMODB_AGENT_AUTHORIZATIONS_TABLE", "guardian-agent-authorizations"
)


def _dev_mode() -> bool:
    return os.environ.get("GUARDIAN_DEV_MODE", "false").lower() == "true"


def _b64encode(value: bytes) -> str:
    return base64.urlsafe_b64encode(value).rstrip(b"=").decode("ascii")


def _b64decode(value: str) -> bytes:
    return base64.urlsafe_b64decode(value + "=" * (-len(value) % 4))


@lru_cache(maxsize=1)
def _signing_key() -> bytes:
    if _dev_mode():
        dev_env_key = os.environ.get("GUARDIAN_DEV_SIGNING_KEY")
        if dev_env_key:
            return dev_env_key.encode("utf-8")
        return _DEV_KEY
    secret_arn = os.environ.get("AGENT_POLICY_SECRET_ARN", "")
    if not secret_arn or boto3 is None:
        raise RuntimeError("Agent policy signing secret is unavailable")
    response = boto3.client(
        "secretsmanager",
        region_name=os.environ.get("AWS_DEFAULT_REGION", "ap-south-1"),
    ).get_secret_value(SecretId=secret_arn)
    secret = response.get("SecretString")
    if not secret or len(secret) < 32:
        raise RuntimeError("Agent policy signing secret is invalid")
    return secret.encode("utf-8")


def issue_policy_authorizations(
    *,
    incident_id: str,
    actions: Iterable[str],
    decision: str,
    correlation_id: str,
    actor: str,
    action_constraints: Dict[str, Dict[str, Any]] | None = None,
    lifetime_seconds: int = 60,
) -> Dict[str, str]:
    """Mint one single-use capability per policy-approved action."""
    if not incident_id or not correlation_id or not decision:
        raise ValueError("Policy authorization context is incomplete")
    if not 1 <= lifetime_seconds <= MAX_TOKEN_LIFETIME_SECONDS:
        raise ValueError("Policy authorization lifetime is outside the allowed range")
    now = int(time.time())
    requested_actions = set(actions)
    allowed_actions = DECISION_ACTIONS.get(decision, frozenset())
    if not requested_actions or not requested_actions.issubset(allowed_actions):
        raise PermissionError("The policy decision does not authorize the requested actions")
    result: Dict[str, str] = {}
    for action in sorted(requested_actions):
        if action not in {"notify_trusted_contact", "dispatch_community_alert"}:
            raise ValueError(f"Unknown policy action: {action}")
        payload = {
            "authorization_id": str(uuid.uuid4()),
            "incident_id": incident_id,
            "action": action,
            "decision": decision,
            "actor": actor,
            "correlation_id": correlation_id,
            "policy_version": POLICY_VERSION,
            "issued_at": now,
            "expires_at": now + lifetime_seconds,
            "constraints": (action_constraints or {}).get(action, {}),
        }
        encoded = _b64encode(
            json.dumps(payload, sort_keys=True, separators=(",", ":")).encode("utf-8")
        )
        signature = _b64encode(
            hmac.new(_signing_key(), encoded.encode("ascii"), hashlib.sha256).digest()
        )
        result[action] = f"{encoded}.{signature}"
    return result


def consume_policy_authorization(
    token: str,
    *,
    expected_incident_id: str,
    expected_action: str,
) -> Dict[str, Any]:
    """Validate and consume a capability, rejecting replay and scope changes."""
    payload = read_policy_authorization(
        token,
        expected_incident_id=expected_incident_id,
        expected_action=expected_action,
    )
    now = int(time.time())
    authorization_id = str(payload["authorization_id"])
    expires_at = int(payload["expires_at"])
    if _dev_mode():
        with _REPLAY_LOCK:
            expired = [key for key, expiry in _CONSUMED_AUTHORIZATIONS.items() if expiry <= now]
            for key in expired:
                del _CONSUMED_AUTHORIZATIONS[key]
            if authorization_id in _CONSUMED_AUTHORIZATIONS:
                raise PermissionError("Policy authorization has already been consumed")
            _CONSUMED_AUTHORIZATIONS[authorization_id] = expires_at
    else:
        if boto3 is None:
            raise RuntimeError("Policy authorization store is unavailable")
        table = boto3.resource(
            "dynamodb",
            region_name=os.environ.get("AWS_DEFAULT_REGION", "ap-south-1"),
        ).Table(AGENT_AUTHORIZATIONS_TABLE)
        try:
            table.put_item(
                Item={
                    "authorization_id": authorization_id,
                    "incident_id": expected_incident_id,
                    "action": expected_action,
                    "consumed_at": now,
                    "expires_at": expires_at,
                },
                ConditionExpression="attribute_not_exists(authorization_id)",
            )
        except Exception as error:
            code = getattr(error, "response", {}).get("Error", {}).get("Code")
            if code == "ConditionalCheckFailedException":
                raise PermissionError("Policy authorization has already been consumed") from error
            raise RuntimeError("Policy authorization store is unavailable") from error
    return payload


def read_policy_authorization(
    token: str,
    *,
    expected_incident_id: str,
    expected_action: str,
) -> Dict[str, Any]:
    """Validate capability scope and expiry without consuming it."""
    try:
        encoded, supplied_signature = token.split(".", 1)
        expected_signature = _b64encode(
            hmac.new(_signing_key(), encoded.encode("ascii"), hashlib.sha256).digest()
        )
        if not hmac.compare_digest(supplied_signature, expected_signature):
            raise PermissionError("Policy authorization signature is invalid")
        payload = json.loads(_b64decode(encoded))
    except PermissionError:
        raise
    except Exception as error:
        raise PermissionError("Policy authorization is malformed") from error

    now = int(time.time())
    if payload.get("policy_version") != POLICY_VERSION:
        raise PermissionError("Policy authorization version is unsupported")
    if payload.get("incident_id") != expected_incident_id:
        raise PermissionError("Policy authorization is bound to another incident")
    if payload.get("action") != expected_action:
        raise PermissionError("Policy authorization does not allow this action")
    issued_at = int(payload.get("issued_at", 0))
    expires_at = int(payload.get("expires_at", 0))
    if issued_at > now + 5 or expires_at <= now or expires_at - issued_at > MAX_TOKEN_LIFETIME_SECONDS:
        raise PermissionError("Policy authorization is expired or invalid")

    if not str(payload.get("authorization_id", "")):
        raise PermissionError("Policy authorization has no identity")
    return payload
