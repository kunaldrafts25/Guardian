"""
Guardian AWS SNS Push Notification Service
Replaces Firebase Cloud Messaging (FCM) with AWS SNS + Pinpoint.

Architecture:
  - Each device registers an SNS Platform Endpoint (FCM/APNS token → SNS ARN)
  - Notifications are sent to individual endpoint ARNs or via SNS Topics
  - SMS fallback via SNS for when push fails (emergency contacts)
  - Responder invitations target only policy-selected endpoint ARNs

Supported platforms:
  - Android: FCM via SNS Platform Application
  - iOS: APNS via SNS Platform Application
  - SMS: Direct SNS SMS (emergency contacts who don't have the app)
"""

import os
import json
import logging
import hashlib
from typing import Optional, Dict, Any, List
from datetime import datetime, timezone

from aws.session_service import validate_access_session

try:
    import boto3
    from botocore.exceptions import ClientError
    BOTO3_AVAILABLE = True
except ImportError:
    BOTO3_AVAILABLE = False

logger = logging.getLogger("sns_push_service")

AWS_REGION = os.environ.get("AWS_DEFAULT_REGION", "ap-south-1")
SNS_FCM_PLATFORM_ARN = os.environ.get("SNS_FCM_PLATFORM_ARN", "")   # Android GCM/FCM
SNS_APNS_PLATFORM_ARN = os.environ.get("SNS_APNS_PLATFORM_ARN", "") # iOS APNS
DYNAMODB_USERS_TABLE = os.environ.get("DYNAMODB_USERS_TABLE", "guardian-users")
DYNAMODB_DEVICE_ENDPOINTS_TABLE = os.environ.get(
    "DYNAMODB_DEVICE_ENDPOINTS_TABLE",
    "guardian-device-endpoints",
)


def _sns_client():
    if not BOTO3_AVAILABLE:
        return None
    return boto3.client("sns", region_name=AWS_REGION)


def _dynamo():
    if not BOTO3_AVAILABLE:
        return None
    return boto3.resource("dynamodb", region_name=AWS_REGION)


# ─────────────────────────────────────────────────────────────────────────────
# DEVICE REGISTRATION
# ─────────────────────────────────────────────────────────────────────────────

def _device_table(dynamo=None):
    resource = dynamo or _dynamo()
    return resource.Table(DYNAMODB_DEVICE_ENDPOINTS_TABLE) if resource else None


def _query_all(table, **kwargs) -> List[Dict[str, Any]]:
    items: List[Dict[str, Any]] = []
    request = dict(kwargs)
    while True:
        response = table.query(**request)
        items.extend(response.get("Items", []))
        last_key = response.get("LastEvaluatedKey")
        if not last_key:
            return items
        request["ExclusiveStartKey"] = last_key


def _token_hash(device_token: str) -> str:
    return hashlib.sha256(device_token.encode("utf-8")).hexdigest()


def _mark_endpoint_disabled(
    user_id: str,
    device_id: str,
    *,
    reason: str,
    dynamo=None,
) -> None:
    table = _device_table(dynamo)
    if not table:
        return
    try:
        table.update_item(
            Key={"user_id": user_id, "device_id": device_id},
            UpdateExpression=(
                "SET enabled = :disabled, disabled_at = :now, "
                "disable_reason = :reason, last_seen_at = :now"
            ),
            ExpressionAttributeValues={
                ":disabled": False,
                ":now": datetime.now(timezone.utc).isoformat(),
                ":reason": reason[:120],
            },
            ConditionExpression="attribute_exists(user_id)",
        )
    except Exception as error:
        logger.warning("Could not mark push endpoint disabled: %s", type(error).__name__)


def register_device_endpoint(
    user_id: str,
    session_id: str,
    device_id: str,
    device_token: str,
    platform: str = "android",
) -> Dict[str, Any]:
    """Bind one SNS platform endpoint to one Guardian account/device session."""
    if platform not in {"android", "ios"}:
        return {"endpoint_arn": "", "success": False, "error": "Unsupported platform"}
    if not user_id or not session_id or not device_id or not device_token:
        return {"endpoint_arn": "", "success": False, "error": "Missing device identity"}

    sns = _sns_client()
    dynamo = _dynamo()
    table = _device_table(dynamo)
    if not sns or not dynamo or not table:
        return {
            "endpoint_arn": "",
            "success": False,
            "error": "SNS or device endpoint store unavailable",
        }

    platform_arn = (
        SNS_FCM_PLATFORM_ARN if platform == "android" else SNS_APNS_PLATFORM_ARN
    )
    if not platform_arn:
        return {
            "endpoint_arn": "",
            "success": False,
            "error": f"Platform ARN not configured for {platform}",
        }

    token_hash = _token_hash(device_token)
    endpoint_arn = ""
    custom_user_data = f"{user_id}:{device_id}"[:2048]
    try:
        response = sns.create_platform_endpoint(
            PlatformApplicationArn=platform_arn,
            Token=device_token,
            CustomUserData=custom_user_data,
            Attributes={"Enabled": "true"},
        )
        endpoint_arn = response["EndpointArn"]
    except ClientError as error:
        if (
            error.response.get("Error", {}).get("Code") == "InvalidParameter"
            and "already exists" in str(error)
        ):
            import re

            match = re.search(r"arn:aws:sns[^\s]+", str(error))
            if match:
                endpoint_arn = match.group(0)
            else:
                return {
                    "endpoint_arn": "",
                    "success": False,
                    "error": "Existing SNS endpoint could not be resolved",
                }
        else:
            logger.error(
                "SNS endpoint registration failed: %s",
                error.response.get("Error", {}).get("Code", type(error).__name__),
            )
            return {
                "endpoint_arn": "",
                "success": False,
                "error": "SNS endpoint registration failed",
            }

    try:
        sns.set_endpoint_attributes(
            EndpointArn=endpoint_arn,
            Attributes={
                "Token": device_token,
                "Enabled": "true",
                "CustomUserData": custom_user_data,
            },
        )
    except Exception as error:
        logger.warning("Could not refresh SNS endpoint attributes: %s", type(error).__name__)

    # A push token may move between Guardian accounts on the same device.
    # Disable previous account bindings without disabling the SNS endpoint that
    # the new owner is about to use.
    try:
        previous = _query_all(
            table,
            IndexName="TokenHashIndex",
            KeyConditionExpression="token_hash = :token",
            ExpressionAttributeValues={":token": token_hash},
        )
        for item in previous:
            if (
                item.get("user_id") != user_id
                or item.get("device_id") != device_id
                or item.get("session_id") != session_id
            ):
                _mark_endpoint_disabled(
                    str(item["user_id"]),
                    str(item["device_id"]),
                    reason="token_rebound_to_another_session",
                    dynamo=dynamo,
                )
    except Exception as error:
        logger.warning("Push-token ownership reconciliation failed: %s", type(error).__name__)

    now = datetime.now(timezone.utc).isoformat()
    table.put_item(
        Item={
            "user_id": user_id,
            "device_id": device_id,
            "session_id": session_id,
            "platform": platform,
            "token_hash": token_hash,
            "sns_endpoint_arn": endpoint_arn,
            "enabled": True,
            "created_at": now,
            "last_seen_at": now,
        }
    )
    logger.info("SNS endpoint bound to authenticated Guardian device")
    return {
        "endpoint_arn": endpoint_arn,
        "device_id": device_id,
        "success": True,
    }


def disable_device_endpoints_for_session(user_id: str, session_id: str) -> int:
    """Disable every push endpoint bound to a revoked Guardian session."""
    table = _device_table()
    if not table:
        return 0
    disabled = 0
    for item in _query_all(
        table,
        KeyConditionExpression="user_id = :user",
        ExpressionAttributeValues={":user": user_id},
    ):
        if item.get("session_id") != session_id or not item.get("enabled", False):
            continue
        _mark_endpoint_disabled(
            user_id,
            str(item["device_id"]),
            reason="guardian_session_revoked",
        )
        disabled += 1
    return disabled


def disable_all_device_endpoints(user_id: str) -> int:
    table = _device_table()
    if not table:
        return 0
    disabled = 0
    for item in _query_all(
        table,
        KeyConditionExpression="user_id = :user",
        ExpressionAttributeValues={":user": user_id},
    ):
        if not item.get("enabled", False):
            continue
        _mark_endpoint_disabled(
            user_id,
            str(item["device_id"]),
            reason="guardian_global_sign_out",
        )
        disabled += 1
    return disabled


# ─────────────────────────────────────────────────────────────────────────────
# TARGETED PUSH NOTIFICATIONS
# ─────────────────────────────────────────────────────────────────────────────

def send_push_to_user(
    user_id: str,
    title: str,
    body: str,
    data: Optional[Dict[str, str]] = None,
    notification_type: str = "general",
) -> Dict[str, Any]:
    """Send a push to every enabled device currently bound to a user."""
    sns = _sns_client()
    dynamo = _dynamo()
    table = _device_table(dynamo)
    if not sns or not dynamo or not table:
        return {"success": False, "error": "SNS or device endpoint store unavailable"}

    try:
        endpoints = [
            item
            for item in _query_all(
                table,
                KeyConditionExpression="user_id = :user",
                ExpressionAttributeValues={":user": user_id},
            )
            if item.get("enabled") is True and item.get("sns_endpoint_arn")
        ]
    except Exception as error:
        logger.error("Push endpoint lookup failed: %s", type(error).__name__)
        return {"success": False, "error": "Push endpoint lookup failed"}

    if not endpoints:
        return {"success": False, "error": "No enabled device registered for push"}

    notification_data = {
        "type": notification_type,
        "user_id": user_id,
        **(data or {}),
    }
    accepted_ids: List[str] = []
    failures: List[Dict[str, str]] = []

    for endpoint in endpoints:
        session_id = str(endpoint.get("session_id") or "")
        if not session_id or not validate_access_session(session_id, user_id):
            _mark_endpoint_disabled(
                user_id,
                str(endpoint.get("device_id") or ""),
                reason="guardian_session_inactive",
                dynamo=dynamo,
            )
            continue

        platform = str(endpoint.get("platform") or "android")
        endpoint_arn = str(endpoint["sns_endpoint_arn"])
        payload = (
            _build_apns_payload(title, body, notification_data)
            if platform == "ios"
            else _build_fcm_payload(title, body, notification_data)
        )
        try:
            response = sns.publish(
                TargetArn=endpoint_arn,
                Message=json.dumps(payload),
                MessageStructure="json",
                Subject=title,
            )
            accepted_ids.append(str(response["MessageId"]))
        except ClientError as error:
            error_code = error.response.get("Error", {}).get("Code", "SNS_ERROR")
            failures.append(
                {
                    "device_id": str(endpoint.get("device_id") or ""),
                    "error_code": error_code,
                }
            )
            if error_code == "EndpointDisabled" or "EndpointDisabled" in str(error):
                _disable_endpoint(endpoint_arn, sns)
                _mark_endpoint_disabled(
                    user_id,
                    str(endpoint.get("device_id") or ""),
                    reason="sns_endpoint_disabled",
                    dynamo=dynamo,
                )

    return {
        "success": bool(accepted_ids),
        "message_id": accepted_ids[0] if accepted_ids else None,
        "message_ids": accepted_ids,
        "provider_accepted_count": len(accepted_ids),
        "failed_count": len(failures),
        "failures": failures,
    }


def send_sms_alert(
    phone_number: str,
    message: str,
    sender_id: str = "GUARDIAN",
) -> Dict[str, Any]:
    """
    Send SMS directly to a trusted contact via AWS SNS SMS.
    Used as fallback when push notifications fail, or for contacts without the app.
    """
    sns = _sns_client()
    if not sns:
        return {"success": False, "error": "SNS client unavailable"}

    phone = phone_number.strip()
    if not phone.startswith("+") or not phone[1:].isdigit() or not 8 <= len(phone[1:]) <= 15:
        return {"success": False, "error": "Phone number must use E.164 format"}

    try:
        resp = sns.publish(
            PhoneNumber=phone,
            Message=message,
            MessageAttributes={
                "AWS.SNS.SMS.SenderID": {
                    "DataType": "String",
                    "StringValue": sender_id,
                },
                "AWS.SNS.SMS.SMSType": {
                    "DataType": "String",
                    "StringValue": "Transactional",  # Highest delivery priority
                },
            },
        )
        logger.info("SNS accepted transactional SMS request")
        return {
            "success": True,
            "message_id": resp["MessageId"],
            "delivery_state": "PROVIDER_ACCEPTED",
        }
    except ClientError as ce:
        error_code = ce.response.get("Error", {}).get("Code", "SNS_ERROR")
        logger.error("SNS SMS request failed: %s", error_code)
        return {
            "success": False,
            "error": "SMS provider request failed",
            "error_code": error_code,
        }




# ─────────────────────────────────────────────────────────────────────────────
# HELPERS
# ─────────────────────────────────────────────────────────────────────────────

def _build_fcm_payload(title: str, body: str, data: Dict) -> Dict:
    """Build FCM (Android) notification payload for SNS MessageStructure=json."""
    return {
        "GCM": json.dumps({
            "notification": {
                "title": title,
                "body": body,
                "sound": "default",
                "android_channel_id": "guardian_sos",
            },
            "data": {
                "title": title,
                "body": body,
                "click_action": "FLUTTER_NOTIFICATION_CLICK",
                **{k: str(v) for k, v in data.items()},
            },
            "time_to_live": 180,
            "priority": "high",
            "android": {"priority": "high"},
        }),
        "default": f"{title}: {body}",
    }


def _build_apns_payload(title: str, body: str, data: Dict) -> Dict:
    """Build APNS (iOS) notification payload for SNS MessageStructure=json."""
    return {
        "APNS": json.dumps({
            "aps": {
                "alert": {"title": title, "body": body},
                "sound": "default",
                "badge": 1,
                "content-available": 1,
                "category": "GUARDIAN_SOS",
            },
            "data": data,
        }),
        "APNS_SANDBOX": json.dumps({
            "aps": {
                "alert": {"title": title, "body": body},
                "sound": "default",
            },
            "data": data,
        }),
        "default": f"{title}: {body}",
    }


def _disable_endpoint(endpoint_arn: str, sns_client):
    """Disable a stale/inactive SNS endpoint."""
    try:
        sns_client.set_endpoint_attributes(
            EndpointArn=endpoint_arn,
            Attributes={"Enabled": "false"},
        )
        logger.info("Disabled stale push endpoint")
    except Exception as e:
        logger.warning(f"Could not disable endpoint: {e}")
