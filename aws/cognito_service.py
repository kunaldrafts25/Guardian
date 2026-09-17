"""
Guardian AWS Cognito Authentication Service
Replaces Firebase Auth with real AWS Cognito User Pool.
Supports Phone OTP (SMS MFA), JWT token issuance, and user profile management in DynamoDB.
"""

import os
import hmac
import hashlib
import base64
import logging
from typing import Optional, Dict, Any
from datetime import datetime, timezone

try:
    import boto3
    from botocore.exceptions import ClientError, BotoCoreError
    BOTO3_AVAILABLE = True
except ImportError:
    BOTO3_AVAILABLE = False

logger = logging.getLogger("cognito_service")

# Env config
COGNITO_USER_POOL_ID = os.environ.get("COGNITO_USER_POOL_ID", "")
COGNITO_CLIENT_ID = os.environ.get("COGNITO_CLIENT_ID", "")
COGNITO_CLIENT_SECRET = os.environ.get("COGNITO_CLIENT_SECRET", "")
AWS_REGION = os.environ.get("AWS_DEFAULT_REGION", "ap-south-1")
DYNAMODB_USERS_TABLE = os.environ.get("DYNAMODB_USERS_TABLE", "guardian-users")


def _get_secret_hash(username: str) -> str:
    """HMAC-SHA256 hash required by Cognito app clients with secret."""
    if not COGNITO_CLIENT_SECRET:
        return ""
    msg = username + COGNITO_CLIENT_ID
    dig = hmac.new(COGNITO_CLIENT_SECRET.encode("utf-8"), msg.encode("utf-8"), hashlib.sha256).digest()
    return base64.b64encode(dig).decode()


def _cognito_client():
    if not BOTO3_AVAILABLE:
        return None
    try:
        return boto3.client("cognito-idp", region_name=AWS_REGION)
    except Exception as e:
        logger.error(f"Failed to create Cognito client: {e}")
        return None


def _dynamo_resource():
    if not BOTO3_AVAILABLE:
        return None
    return boto3.resource("dynamodb", region_name=AWS_REGION)


# ─────────────────────────────────────────────────────────────────────────────
# PHONE OTP FLOW
# ─────────────────────────────────────────────────────────────────────────────

def initiate_phone_auth(phone_number: str) -> Dict[str, Any]:
    """
    Step 1: Initiate phone number authentication.
    Cognito sends an SMS OTP to the phone number.
    If the user doesn't exist, they are auto-created.
    
    Returns: { "session": str, "user_exists": bool }
    """
    client = _cognito_client()
    if not client or not COGNITO_USER_POOL_ID or not COGNITO_CLIENT_ID:
        # Development fallback — return a mock session
        logger.warning("Cognito not configured. Using dev fallback OTP flow.")
        return {
            "session": f"dev_session_{phone_number}",
            "user_exists": True,
            "dev_mode": True,
            "message": "DEV MODE: Use OTP code 123456"
        }

    # Normalize phone number to E.164 format
    phone = phone_number.strip()
    if not phone.startswith("+"):
        phone = f"+91{phone}"  # Default to India prefix

    # Try to auto-register user if not exists
    try:
        client.admin_create_user(
            UserPoolId=COGNITO_USER_POOL_ID,
            Username=phone,
            UserAttributes=[{"Name": "phone_number", "Value": phone}],
            MessageAction="SUPPRESS",  # Don't send welcome email
            TemporaryPassword=_generate_temp_password(),
        )
        logger.info(f"New Cognito user created for {phone}")
    except ClientError as e:
        if e.response["Error"]["Code"] != "UsernameExistsException":
            logger.warning(f"User creation note: {e}")

    # Force set permanent password (to allow CUSTOM_AUTH flow)
    try:
        client.admin_set_user_password(
            UserPoolId=COGNITO_USER_POOL_ID,
            Username=phone,
            Password=_generate_temp_password(),
            Permanent=True,
        )
    except Exception as e:
        logger.warning(f"Set password: {e}")

    # Initiate Custom Auth / OTP flow
    try:
        auth_params = {
            "USERNAME": phone,
        }
        if COGNITO_CLIENT_SECRET:
            auth_params["SECRET_HASH"] = _get_secret_hash(phone)

        resp = client.initiate_auth(
            AuthFlow="CUSTOM_AUTH",
            AuthParameters=auth_params,
            ClientId=COGNITO_CLIENT_ID,
        )
        session = resp.get("Session", "")
        return {
            "session": session,
            "phone": phone,
            "user_exists": True,
            "message": f"OTP sent to {phone}"
        }
    except ClientError as ce:
        code = ce.response["Error"]["Code"]
        msg = ce.response["Error"]["Message"]
        logger.error(f"Initiate auth error: {code}: {msg}")
        raise ValueError(f"Authentication failed: {msg}")


def verify_otp(phone_number: str, otp_code: str, session: str) -> Dict[str, Any]:
    """
    Step 2: Verify the SMS OTP and return JWT tokens.
    Returns: { "access_token": str, "id_token": str, "refresh_token": str, "user_id": str }
    """
    client = _cognito_client()

    # Dev mode bypass
    if session.startswith("dev_session_"):
        if otp_code == "123456":
            user_id = f"dev_user_{phone_number.replace('+', '').replace(' ', '')}"
            return {
                "access_token": f"dev_access_token_{user_id}",
                "id_token": f"dev_id_token_{user_id}",
                "refresh_token": f"dev_refresh_{user_id}",
                "user_id": user_id,
                "phone": phone_number,
                "dev_mode": True,
            }
        raise ValueError("Invalid OTP code. Dev mode accepts: 123456")

    if not client:
        raise ValueError("AWS Cognito not available")

    phone = phone_number.strip()
    if not phone.startswith("+"):
        phone = f"+91{phone}"

    try:
        challenge_responses = {
            "USERNAME": phone,
            "ANSWER": otp_code,
        }
        if COGNITO_CLIENT_SECRET:
            challenge_responses["SECRET_HASH"] = _get_secret_hash(phone)

        resp = client.respond_to_auth_challenge(
            ClientId=COGNITO_CLIENT_ID,
            ChallengeName="CUSTOM_CHALLENGE",
            Session=session,
            ChallengeResponses=challenge_responses,
        )

        auth_result = resp.get("AuthenticationResult", {})
        access_token = auth_result.get("AccessToken", "")
        id_token = auth_result.get("IdToken", "")
        refresh_token = auth_result.get("RefreshToken", "")

        # Get user info
        user_info = client.get_user(AccessToken=access_token)
        user_id = user_info.get("Username", phone)

        # Upsert user profile in DynamoDB
        _upsert_user_profile(user_id=user_id, phone=phone)

        return {
            "access_token": access_token,
            "id_token": id_token,
            "refresh_token": refresh_token,
            "user_id": user_id,
            "phone": phone,
        }
    except ClientError as ce:
        code = ce.response["Error"]["Code"]
        msg = ce.response["Error"]["Message"]
        logger.error(f"OTP verification error: {code}: {msg}")
        raise ValueError(f"OTP verification failed: {msg}")


def refresh_tokens(refresh_token: str, user_id: str) -> Dict[str, Any]:
    """Refresh expired access/id tokens using the refresh token."""
    client = _cognito_client()
    if not client:
        return {"error": "Cognito not available"}

    try:
        auth_params = {"REFRESH_TOKEN": refresh_token}
        if COGNITO_CLIENT_SECRET:
            auth_params["SECRET_HASH"] = _get_secret_hash(user_id)

        resp = client.initiate_auth(
            AuthFlow="REFRESH_TOKEN_AUTH",
            AuthParameters=auth_params,
            ClientId=COGNITO_CLIENT_ID,
        )
        auth_result = resp.get("AuthenticationResult", {})
        return {
            "access_token": auth_result.get("AccessToken", ""),
            "id_token": auth_result.get("IdToken", ""),
        }
    except ClientError as ce:
        raise ValueError(f"Token refresh failed: {ce.response['Error']['Message']}")


def sign_out(access_token: str) -> Dict[str, Any]:
    """Revoke all tokens for the user (global sign out)."""
    client = _cognito_client()
    if not client:
        return {"success": True, "dev_mode": True}
    try:
        client.global_sign_out(AccessToken=access_token)
        return {"success": True}
    except ClientError as ce:
        logger.warning(f"Sign out error: {ce}")
        return {"success": False, "error": str(ce)}


# ─────────────────────────────────────────────────────────────────────────────
# USER PROFILE — DynamoDB
# ─────────────────────────────────────────────────────────────────────────────

def _upsert_user_profile(user_id: str, phone: str, extra: Optional[Dict] = None):
    """Create or update user profile in DynamoDB guardian-users table."""
    dynamo = _dynamo_resource()
    if not dynamo:
        return
    try:
        table = dynamo.Table(DYNAMODB_USERS_TABLE)
        item = {
            "user_id": user_id,
            "phone": phone,
            "updated_at": datetime.now(timezone.utc).isoformat(),
            "fcm_tokens": [],
        }
        if extra:
            item.update(extra)
        table.update_item(
            Key={"user_id": user_id},
            UpdateExpression=(
                "SET phone = :p, updated_at = :u"
            ),
            ExpressionAttributeValues={
                ":p": phone,
                ":u": item["updated_at"],
            },
        )
        logger.info(f"User profile upserted for {user_id}")
    except Exception as e:
        logger.warning(f"Could not upsert user profile: {e}")


def update_user_profile(user_id: str, profile_data: Dict[str, Any]) -> Dict[str, Any]:
    """Update arbitrary user profile fields in DynamoDB."""
    dynamo = _dynamo_resource()
    if not dynamo:
        return {"success": True, "dev_mode": True}

    try:
        table = dynamo.Table(DYNAMODB_USERS_TABLE)
        # Build dynamic update expression
        update_expr = "SET updated_at = :u"
        expr_values: Dict[str, Any] = {":u": datetime.now(timezone.utc).isoformat()}
        expr_names: Dict[str, str] = {}

        allowed_fields = [
            "display_name", "photo_url", "emergency_contacts",
            "safe_zones", "guardian_circle", "settings", "fcm_tokens",
        ]

        for field in allowed_fields:
            if field in profile_data:
                placeholder = f":v_{field}"
                name_placeholder = f"#f_{field}"
                update_expr += f", {name_placeholder} = {placeholder}"
                expr_values[placeholder] = profile_data[field]
                expr_names[name_placeholder] = field

        table.update_item(
            Key={"user_id": user_id},
            UpdateExpression=update_expr,
            ExpressionAttributeValues=expr_values,
            ExpressionAttributeNames=expr_names if expr_names else None,
        )
        return {"success": True, "updated_fields": list(profile_data.keys())}
    except Exception as e:
        logger.error(f"Profile update failed: {e}")
        return {"success": False, "error": str(e)}


def get_user_profile(user_id: str) -> Optional[Dict[str, Any]]:
    """Fetch user profile from DynamoDB."""
    dynamo = _dynamo_resource()
    if not dynamo:
        return {"user_id": user_id, "dev_mode": True}
    try:
        table = dynamo.Table(DYNAMODB_USERS_TABLE)
        resp = table.get_item(Key={"user_id": user_id})
        return resp.get("Item")
    except Exception as e:
        logger.error(f"Get user profile failed: {e}")
        return None


def save_fcm_token(user_id: str, fcm_token: str) -> Dict[str, Any]:
    """
    Add a device FCM/SNS token to the user's token list in DynamoDB.
    This enables targeted push notifications via AWS SNS.
    """
    dynamo = _dynamo_resource()
    if not dynamo:
        return {"success": True, "dev_mode": True}
    try:
        table = dynamo.Table(DYNAMODB_USERS_TABLE)
        table.update_item(
            Key={"user_id": user_id},
            UpdateExpression="ADD fcm_tokens :t SET updated_at = :u",
            ExpressionAttributeValues={
                ":t": {fcm_token},
                ":u": datetime.now(timezone.utc).isoformat(),
            },
        )
        return {"success": True}
    except Exception as e:
        logger.error(f"Save FCM token failed: {e}")
        return {"success": False, "error": str(e)}


# ─────────────────────────────────────────────────────────────────────────────
# HELPERS
# ─────────────────────────────────────────────────────────────────────────────

def _generate_temp_password() -> str:
    """Generate a consistent temporary password for Cognito user creation."""
    import secrets
    import string
    chars = string.ascii_letters + string.digits + "!@#$"
    pwd = "".join(secrets.choice(chars) for _ in range(16))
    # Ensure complexity requirements met
    return f"Grd!{pwd[:12]}"
