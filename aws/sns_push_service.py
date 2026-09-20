"""
Guardian AWS SNS Push Notification Service
Replaces Firebase Cloud Messaging (FCM) with AWS SNS + Pinpoint.

Architecture:
  - Each device registers an SNS Platform Endpoint (FCM/APNS token → SNS ARN)
  - Notifications are sent to individual endpoint ARNs or via SNS Topics
  - SMS fallback via SNS for when push fails (emergency contacts)
  - Emergency community alerts broadcast via SNS Topic fan-out

Supported platforms:
  - Android: FCM via SNS Platform Application
  - iOS: APNS via SNS Platform Application
  - SMS: Direct SNS SMS (emergency contacts who don't have the app)
"""

import os
import json
import logging
from typing import Optional, Dict, Any, List
from datetime import datetime, timezone

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
SNS_SOS_TOPIC_ARN = os.environ.get("SNS_SOS_TOPIC_ARN", "")         # Broadcast SOS topic
DYNAMODB_USERS_TABLE = os.environ.get("DYNAMODB_USERS_TABLE", "guardian-users")


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

def register_device_endpoint(
    user_id: str,
    device_token: str,
    platform: str = "android",  # "android" | "ios"
    user_data: Optional[str] = None,
) -> Dict[str, Any]:
    """
    Register a device push token with AWS SNS to get an endpoint ARN.
    This endpoint ARN is stored in DynamoDB and used for targeted push.
    
    Returns: { "endpoint_arn": str, "success": bool }
    """
    sns = _sns_client()
    if not sns:
        return {"endpoint_arn": "", "success": False, "error": "SNS client unavailable"}

    platform_arn = SNS_FCM_PLATFORM_ARN if platform == "android" else SNS_APNS_PLATFORM_ARN
    if not platform_arn:
        logger.warning(f"No SNS platform ARN configured for {platform}")
        return {"endpoint_arn": "", "success": False, "error": f"Platform ARN not configured for {platform}"}

    try:
        resp = sns.create_platform_endpoint(
            PlatformApplicationArn=platform_arn,
            Token=device_token,
            CustomUserData=user_data or user_id,
            Attributes={"Enabled": "true"},
        )
        endpoint_arn = resp["EndpointArn"]
        logger.info(f"SNS endpoint registered for {user_id}: {endpoint_arn}")

        # Persist endpoint ARN in DynamoDB
        _save_endpoint_arn(user_id, endpoint_arn, platform)

        return {"endpoint_arn": endpoint_arn, "success": True}
    except ClientError as ce:
        # Endpoint already exists — get existing ARN
        err_code = ce.response["Error"]["Code"]
        if err_code == "InvalidParameter" and "already exists" in str(ce):
            # Parse existing ARN from error message
            import re
            match = re.search(r"arn:aws:sns[^\s]+", str(ce))
            if match:
                endpoint_arn = match.group(0)
                _save_endpoint_arn(user_id, endpoint_arn, platform)
                return {"endpoint_arn": endpoint_arn, "success": True}
        logger.error(f"SNS endpoint registration failed: {ce}")
        return {"endpoint_arn": "", "success": False, "error": str(ce)}


def _save_endpoint_arn(user_id: str, endpoint_arn: str, platform: str):
    """Store the SNS endpoint ARN in the user's DynamoDB profile."""
    dynamo = _dynamo()
    if not dynamo:
        return
    try:
        table = dynamo.Table(DYNAMODB_USERS_TABLE)
        table.update_item(
            Key={"user_id": user_id},
            UpdateExpression=(
                "SET sns_endpoint_arn = :e, sns_platform = :p, updated_at = :u"
            ),
            ExpressionAttributeValues={
                ":e": endpoint_arn,
                ":p": platform,
                ":u": datetime.now(timezone.utc).isoformat(),
            },
        )
    except Exception as ex:
        logger.warning(f"Could not save SNS endpoint ARN: {ex}")


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
    """
    Send a targeted push notification to a specific user's device via SNS.
    Looks up the user's endpoint ARN from DynamoDB, then sends via SNS.
    """
    sns = _sns_client()
    dynamo = _dynamo()

    if not sns or not dynamo:
        return {"success": False, "error": "SNS or DynamoDB client unavailable"}

    # Get user's endpoint ARN
    try:
        table = dynamo.Table(DYNAMODB_USERS_TABLE)
        resp = table.get_item(Key={"user_id": user_id})
        user = resp.get("Item", {})
        endpoint_arn = user.get("sns_endpoint_arn", "")

        if not endpoint_arn:
            logger.warning(f"No SNS endpoint ARN found for user {user_id}")
            return {"success": False, "error": "No device registered for push"}

        platform = user.get("sns_platform", "android")
    except Exception as e:
        logger.error(f"Failed to get user endpoint: {e}")
        return {"success": False, "error": str(e)}

    # Build platform-specific message
    notification_data = {
        "type": notification_type,
        "user_id": user_id,
        **(data or {}),
    }

    if platform == "ios":
        message_payload = _build_apns_payload(title, body, notification_data)
    else:
        message_payload = _build_fcm_payload(title, body, notification_data)

    try:
        resp = sns.publish(
            TargetArn=endpoint_arn,
            Message=json.dumps(message_payload),
            MessageStructure="json",
            Subject=title,
        )
        logger.info(f"Push sent to {user_id}: MessageId={resp['MessageId']}")
        return {"success": True, "message_id": resp["MessageId"]}
    except ClientError as ce:
        logger.error(f"SNS push failed: {ce}")
        # Disable stale endpoint
        if "EndpointDisabled" in str(ce):
            _disable_endpoint(endpoint_arn, sns)
        return {"success": False, "error": str(ce)}


def send_community_sos_broadcast(
    incident_id: str,
    victim_location: Dict[str, float],
    message: str = "⚡ Guardian SOS: Someone nearby needs urgent help!",
) -> Dict[str, Any]:
    """
    Broadcast SOS alert to all nearby Guardian community members via SNS Topic.
    All subscribers within the topic receive this alert.
    """
    sns = _sns_client()
    if not sns:
        return {"success": False, "error": "SNS client unavailable"}

    if not SNS_SOS_TOPIC_ARN:
        logger.warning("SNS_SOS_TOPIC_ARN not configured - skipping community broadcast")
        return {"success": False, "error": "SOS topic ARN not configured"}

    try:
        resp = sns.publish(
            TopicArn=SNS_SOS_TOPIC_ARN,
            Message=json.dumps({
                "default": message,
                "GCM": json.dumps({
                    "notification": {
                        "title": "⚡ Guardian Community Alert",
                        "body": message,
                        "sound": "emergency_alert",
                    },
                    "data": {
                        "type": "community_sos",
                        "incident_id": incident_id,
                        "lat": str(victim_location.get("latitude", 0)),
                        "lng": str(victim_location.get("longitude", 0)),
                    },
                    "priority": "high",
                }),
            }),
            MessageStructure="json",
            Subject="Guardian Emergency SOS Alert",
            MessageAttributes={
                "incident_type": {
                    "DataType": "String",
                    "StringValue": "community_sos",
                },
            },
        )
        logger.info(f"SOS broadcast sent: MessageId={resp['MessageId']}")
        return {"success": True, "message_id": resp["MessageId"]}
    except ClientError as ce:
        logger.error(f"SOS broadcast failed: {ce}")
        return {"success": False, "error": str(ce)}


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
        logger.info(f"SMS sent to {phone}: MessageId={resp['MessageId']}")
        return {"success": True, "message_id": resp["MessageId"]}
    except ClientError as ce:
        logger.error(f"SNS SMS failed: {ce}")
        return {"success": False, "error": str(ce)}


def send_emergency_contact_alerts(
    user_id: str,
    incident_id: str,
    location: Dict[str, float],
    message_template: Optional[str] = None,
) -> Dict[str, Any]:
    """
    Notify ALL trusted emergency contacts for a user via:
    1. Push notification (if they have the app)
    2. SMS fallback (always sent for critical events)
    """
    dynamo = _dynamo()
    results = []

    # Get user's emergency contacts from DynamoDB
    contacts = []
    if dynamo:
        try:
            table = dynamo.Table(DYNAMODB_USERS_TABLE)
            resp = table.get_item(Key={"user_id": user_id})
            user = resp.get("Item", {})
            contacts = user.get("emergency_contacts", [])
        except Exception as e:
            logger.error(f"Failed to get emergency contacts: {e}")

    if not contacts:
        logger.warning(f"No emergency contacts found for user {user_id}")
        return {"success": False, "error": "No emergency contacts configured", "results": []}

    lat = location.get("latitude", 0)
    lng = location.get("longitude", 0)
    maps_link = f"https://www.google.com/maps?q={lat},{lng}"

    for contact in contacts:
        phone = contact.get("phone", "")
        name = contact.get("name", "Someone")

        if not phone:
            continue

        msg = message_template or (
            f"🆘 GUARDIAN SOS ALERT\n"
            f"{name}, your trusted contact needs help!\n"
            f"Incident: {incident_id}\n"
            f"Location: {maps_link}\n"
            f"Time: {datetime.now(timezone.utc).strftime('%H:%M UTC')}\n"
            f"Please call them immediately or contact emergency services."
        )

        # Send SMS (always)
        sms_result = send_sms_alert(phone, msg)
        results.append({
            "contact": name,
            "phone": phone,
            "sms": sms_result,
        })

    return {
        "success": True,
        "contacts_alerted": len(results),
        "results": results,
        "incident_id": incident_id,
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
            "data": {k: str(v) for k, v in data.items()},
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
        logger.info(f"Disabled stale endpoint: {endpoint_arn}")
    except Exception as e:
        logger.warning(f"Could not disable endpoint: {e}")
