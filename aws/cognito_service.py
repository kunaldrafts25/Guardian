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
import re
import uuid
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
GOOGLE_CLIENT_ID = os.environ.get("GOOGLE_CLIENT_ID", "")
AWS_REGION = os.environ.get("AWS_DEFAULT_REGION", "ap-south-1")
DYNAMODB_USERS_TABLE = os.environ.get("DYNAMODB_USERS_TABLE", "guardian-users")
DYNAMODB_AUTH_THROTTLE_TABLE = os.environ.get(
    "DYNAMODB_AUTH_THROTTLE_TABLE", "guardian-auth-throttle"
)
OTP_RESEND_COOLDOWN_SECONDS = int(os.environ.get("OTP_RESEND_COOLDOWN_SECONDS", "5"))
OTP_MAX_REQUESTS_PER_HOUR = int(os.environ.get("OTP_MAX_REQUESTS_PER_HOUR", "50"))


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
        raise ValueError("AWS Cognito is not configured; OTP authentication is unavailable")

    phone = _normalize_e164(phone_number)
    _enforce_otp_rate_limit(phone)

    # Try to auto-register user if not exists
    temp_pwd = _generate_temp_password()
    try:
        client.admin_create_user(
            UserPoolId=COGNITO_USER_POOL_ID,
            Username=phone,
            UserAttributes=[
                {"Name": "phone_number", "Value": phone},
                {"Name": "phone_number_verified", "Value": "true"},
            ],
            MessageAction="SUPPRESS",  # Don't send welcome email
            TemporaryPassword=temp_pwd,
        )
        logger.info("New Cognito user created")
    except ClientError as e:
        if e.response["Error"]["Code"] != "UsernameExistsException":
            logger.warning(f"User creation note: {e}")

    # Force set permanent password (to allow CUSTOM_AUTH flow)
    try:
        client.admin_set_user_password(
            UserPoolId=COGNITO_USER_POOL_ID,
            Username=phone,
            Password=temp_pwd,
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
            "message": "If the number can receive messages, a code has been sent."
        }
    except ClientError as ce:
        code = ce.response["Error"]["Code"]
        logger.error("Initiate auth error: %s", code)
        raise ValueError("Unable to start verification. Please try again later.")


def verify_otp(phone_number: str, otp_code: str, session: str) -> Dict[str, Any]:
    """
    Step 2: Verify the SMS OTP and return JWT tokens.
    Returns: { "access_token": str, "id_token": str, "refresh_token": str, "user_id": str }
    """
    client = _cognito_client()
    if not client or not COGNITO_USER_POOL_ID or not COGNITO_CLIENT_ID:
        raise ValueError("AWS Cognito is not configured; OTP authentication is unavailable")

    phone = _normalize_e164(phone_number)

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

        if not access_token:
            raise ValueError("The verification code is incorrect or expired.")

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
        code = ce.response.get("Error", {}).get("Code", "Unknown")
        msg = ce.response.get("Error", {}).get("Message", str(ce))
        logger.error(f"OTP verification rejected: code={code}, msg={msg}")
        raise ValueError(f"{msg}")


def refresh_tokens(refresh_token: str, user_id: Optional[str] = None) -> Dict[str, Any]:
    """Refresh expired access/id tokens using the refresh token."""
    is_dev = os.environ.get("GUARDIAN_DEV_MODE", "false").lower() == "true"
    if refresh_token.startswith("google_refresh_token_") or (user_id and user_id.startswith("google_")):
        if not is_dev:
            raise ValueError("Development tokens cannot be refreshed in production.")
        resolved_user = user_id or f"google_{uuid.uuid4().hex[:8]}"
        return {
            "access_token": f"dev_access_token_{resolved_user}",
            "id_token": f"dev_id_token_{resolved_user}",
        }

    client = _cognito_client()
    if not client:
        return {"error": "Cognito not available"}

    try:
        auth_params = {"REFRESH_TOKEN": refresh_token}
        if COGNITO_CLIENT_SECRET:
            raise ValueError("Mobile Cognito clients must not use a client secret")

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


def _verify_google_payload(id_token_str: str) -> Dict[str, Any]:
    """Cryptographic verification via google.oauth2.id_token or Google tokeninfo endpoint."""
    try:
        from google.oauth2 import id_token
        from google.auth.transport import requests as google_requests

        req = google_requests.Request()
        audience = GOOGLE_CLIENT_ID if GOOGLE_CLIENT_ID else None
        return id_token.verify_oauth2_token(id_token_str, req, audience=audience)
    except Exception as library_err:
        logger.info(f"Local google-auth transport note: {library_err}. Using Google tokeninfo endpoint.")
        import urllib.request
        import json
        tokeninfo_url = f"https://oauth2.googleapis.com/tokeninfo?id_token={id_token_str}"
        req = urllib.request.Request(tokeninfo_url, headers={"User-Agent": "Guardian-Backend"})
        with urllib.request.urlopen(req, timeout=10) as resp:
            id_info = json.loads(resp.read().decode("utf-8"))
        if "error" in id_info:
            raise ValueError(id_info.get("error_description", id_info["error"]))
        return id_info


def authenticate_with_google(id_token_str: str) -> Dict[str, Any]:
    """
    Authenticate with Google ID Token.
    Validates cryptographic signature with Google or dev mock fallback.
    Upserts profile into DynamoDB and returns access + id + refresh tokens.
    """
    if not id_token_str or not id_token_str.strip():
        raise ValueError("Google ID token is required")

    sub: str = ""
    email: str = ""
    name: str = ""
    picture: str = ""

    # Check for dev token fallback
    is_dev = os.environ.get("GUARDIAN_DEV_MODE", "false").lower() == "true"
    if is_dev and (id_token_str.startswith("dev_google_") or id_token_str.startswith("mock_google_")):
        parts = id_token_str.split("_")
        user_suffix = parts[-1] if len(parts) > 2 else "user1"
        sub = f"dev_{user_suffix}"
        email = f"{user_suffix}@gmail.com"
        name = f"Guardian User ({user_suffix})"
        picture = "https://lh3.googleusercontent.com/a/default-user"
    else:
        try:
            id_info = _verify_google_payload(id_token_str)

            if id_info.get("iss") not in ["accounts.google.com", "https://accounts.google.com"]:
                raise ValueError("Invalid Google token issuer")

            sub = id_info.get("sub", "")
            email = id_info.get("email", "")
            if not sub or not email:
                raise ValueError("Google token is missing sub or verified email claim")
            name = id_info.get("name", "")
            picture = id_info.get("picture", "")
        except Exception as e:
            logger.error(f"Google token verification failed: {e}")
            raise ValueError(f"Invalid Google ID token: {str(e)}")

    user_id = f"google_{sub}"

    if is_dev:
        refresh_token = f"google_refresh_token_{uuid.uuid4().hex}"
        access_token = f"dev_access_token_{user_id}"
    else:
        client = _cognito_client()
        if not client or not COGNITO_USER_POOL_ID or not COGNITO_CLIENT_ID:
            raise ValueError("AWS Cognito is not configured; Google authentication is unavailable in production")
        temp_pwd = _generate_temp_password()
        try:
            client.admin_create_user(
                UserPoolId=COGNITO_USER_POOL_ID,
                Username=user_id,
                UserAttributes=[
                    {"Name": "email", "Value": email},
                    {"Name": "email_verified", "Value": "true"},
                ],
                MessageAction="SUPPRESS",
                TemporaryPassword=temp_pwd,
            )
        except ClientError as e:
            if e.response["Error"]["Code"] != "UsernameExistsException":
                logger.warning(f"Google Cognito user creation note: {e}")
        try:
            client.admin_set_user_password(
                UserPoolId=COGNITO_USER_POOL_ID,
                Username=user_id,
                Password=temp_pwd,
                Permanent=True,
            )
            auth_params = {"USERNAME": user_id, "PASSWORD": temp_pwd}
            if COGNITO_CLIENT_SECRET:
                auth_params["SECRET_HASH"] = _get_secret_hash(user_id)
            resp = client.admin_initiate_auth(
                UserPoolId=COGNITO_USER_POOL_ID,
                ClientId=COGNITO_CLIENT_ID,
                AuthFlow="ADMIN_USER_PASSWORD_AUTH",
                AuthParameters=auth_params,
            )
            auth_result = resp.get("AuthenticationResult", {})
            access_token = auth_result.get("AccessToken", "")
            refresh_token = auth_result.get("RefreshToken", "")
        except Exception as e:
            logger.error(f"Cognito token issuance for Google auth failed: {e}")
            raise ValueError("Unable to issue authenticated session for Google login.")

    # Upsert user profile in DynamoDB
    _upsert_user_profile(
        user_id=user_id,
        phone="",
        extra={
            "email": email,
            "display_name": name,
            "photo_url": picture,
            "auth_provider": "google",
        },
    )

    return {
        "access_token": access_token,
        "id_token": id_token_str,
        "refresh_token": refresh_token,
        "user_id": user_id,
        "email": email,
        "display_name": name,
        "photo_url": picture,
        "auth_provider": "google",
    }


def sign_out(access_token: str) -> Dict[str, Any]:
    """Revoke all tokens for the user (global sign out)."""
    client = _cognito_client()
    if not client or not COGNITO_USER_POOL_ID:
        raise ValueError("AWS Cognito is not configured; sign-out is unavailable")
    try:
        client.global_sign_out(AccessToken=access_token)
        return {"success": True}
    except ClientError as ce:
        logger.warning(f"Sign out error: {ce}")
        return {"success": False, "error": str(ce)}


# ─────────────────────────────────────────────────────────────────────────────
# USER PROFILE — DynamoDB
# ─────────────────────────────────────────────────────────────────────────────

def _upsert_user_profile(user_id: str, phone: str = "", extra: Optional[Dict] = None):
    """Create or update user profile in DynamoDB guardian-users table."""
    dynamo = _dynamo_resource()
    if not dynamo:
        return
    try:
        table = dynamo.Table(DYNAMODB_USERS_TABLE)
        updated_at = datetime.now(timezone.utc).isoformat()
        update_expr = "SET updated_at = :u"
        expr_values: Dict[str, Any] = {":u": updated_at}
        expr_names: Dict[str, str] = {}
        if phone:
            update_expr += ", phone = :p"
            expr_values[":p"] = phone
        if extra:
            for k, v in extra.items():
                field_name = f"#{k}"
                field_val = f":v_{k}"
                update_expr += f", {field_name} = {field_val}"
                expr_names[field_name] = k
                expr_values[field_val] = v
        table.update_item(
            Key={"user_id": user_id},
            UpdateExpression=update_expr,
            ExpressionAttributeValues=expr_values,
            ExpressionAttributeNames=expr_names if expr_names else None,
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
    return f"Grd1!A{pwd[:12]}"


def _normalize_e164(phone_number: str) -> str:
    phone = re.sub(r"[\s().-]", "", phone_number.strip())
    if not re.fullmatch(r"\+[1-9]\d{7,14}", phone):
        raise ValueError("Enter a valid phone number including country code.")
    return phone


def _enforce_otp_rate_limit(phone: str) -> None:
    """Atomically enforce resend cooldown and a per-number hourly quota."""
    dynamo = _dynamo_resource()
    if not dynamo:
        if os.environ.get("GUARDIAN_DEV_MODE", "false").lower() == "true":
            return
        raise ValueError("Verification is temporarily unavailable.")
    now = int(datetime.now(timezone.utc).timestamp())
    phone_hash = hashlib.sha256(phone.encode("utf-8")).hexdigest()
    hour_bucket = now // 3600
    try:
        dynamo.Table(DYNAMODB_AUTH_THROTTLE_TABLE).update_item(
            Key={"throttle_key": f"{phone_hash}:{hour_bucket}"},
            UpdateExpression=(
                "SET last_sent_at = :now, expires_at = :ttl ADD request_count :one"
            ),
            ConditionExpression=(
                "(attribute_not_exists(request_count) OR request_count < :max) "
                "AND (attribute_not_exists(last_sent_at) OR last_sent_at <= :cooldown)"
            ),
            ExpressionAttributeValues={
                ":now": now,
                ":ttl": now + 7200,
                ":one": 1,
                ":max": OTP_MAX_REQUESTS_PER_HOUR,
                ":cooldown": now - OTP_RESEND_COOLDOWN_SECONDS,
            },
        )
    except ClientError as error:
        if error.response.get("Error", {}).get("Code") == "ConditionalCheckFailedException":
            raise ValueError("Please wait before requesting another code.") from error
        logger.exception("OTP rate-limit storage failed")
        raise ValueError("Verification is temporarily unavailable.") from error

