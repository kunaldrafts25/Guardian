"""Guardian authentication and user-profile service.

Google identity is the only production login bootstrap. Guardian APIs use
Cognito-issued access tokens plus Guardian device sessions.
"""

import os
import logging
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
GOOGLE_CLIENT_ID = os.environ.get("GOOGLE_CLIENT_ID", "")
AWS_REGION = os.environ.get("AWS_DEFAULT_REGION", "ap-south-1")
DYNAMODB_USERS_TABLE = os.environ.get("DYNAMODB_USERS_TABLE", "guardian-users")


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
# TOKEN REFRESH
# ─────────────────────────────────────────────────────────────────────────────

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
    """Verify a Google ID token cryptographically and for Guardian's audience."""
    if not GOOGLE_CLIENT_ID:
        raise ValueError("GOOGLE_CLIENT_ID is required for Google authentication")
    try:
        from google.oauth2 import id_token
        from google.auth.transport import requests as google_requests

        payload = id_token.verify_oauth2_token(
            id_token_str,
            google_requests.Request(),
            audience=GOOGLE_CLIENT_ID,
        )
    except Exception as error:
        raise ValueError("Google token verification failed") from error

    if payload.get("iss") not in {
        "accounts.google.com",
        "https://accounts.google.com",
    }:
        raise ValueError("Invalid Google token issuer")
    if payload.get("aud") != GOOGLE_CLIENT_ID:
        raise ValueError("Invalid Google token audience")
    if not payload.get("sub"):
        raise ValueError("Google token is missing subject")
    if not payload.get("email") or payload.get("email_verified") is not True:
        raise ValueError("Google account email must be verified")
    return payload

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

            if not GOOGLE_CLIENT_ID or id_info.get("aud") != GOOGLE_CLIENT_ID:
                raise ValueError("Invalid Google token audience")
            if id_info.get("email_verified") is not True:
                raise ValueError("Google account email must be verified")
            sub = id_info.get("sub", "")
            email = id_info.get("email", "")
            if not sub or not email:
                raise ValueError("Google token is missing required identity claims")
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


