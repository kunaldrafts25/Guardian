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


def validate_refresh_token_owner(
    refresh_token: str,
    expected_user_id: str,
) -> None:
    """Prove the refresh token belongs to the same Cognito subject as access_token.

    Guardian sessions bind both token families. Without this check a caller
    could accidentally pair an access token from one account with a refresh
    token from another, creating a session that fails unpredictably at refresh.
    """
    if not refresh_token or not expected_user_id:
        raise ValueError("Refresh token and expected user are required")

    is_dev = os.environ.get("GUARDIAN_DEV_MODE", "false").lower() == "true"
    if is_dev:
        if refresh_token.startswith("google_refresh_token_"):
            return
        raise ValueError("Invalid development refresh token")

    client = _cognito_client()
    if not client or not COGNITO_CLIENT_ID:
        raise RuntimeError("AWS Cognito is temporarily unavailable")

    try:
        refreshed = client.initiate_auth(
            AuthFlow="REFRESH_TOKEN_AUTH",
            AuthParameters={"REFRESH_TOKEN": refresh_token},
            ClientId=COGNITO_CLIENT_ID,
        )
        refreshed_access = (
            refreshed.get("AuthenticationResult", {}).get("AccessToken", "")
        )
        if not refreshed_access:
            raise ValueError("Cognito refresh token could not be validated")
        result = client.get_user(AccessToken=refreshed_access)
    except ClientError as error:
        raise ValueError("Cognito refresh token is invalid or expired") from error

    attributes = {
        str(item.get("Name")): str(item.get("Value") or "")
        for item in result.get("UserAttributes", [])
        if item.get("Name")
    }
    refresh_user_id = attributes.get("sub", "").strip()
    if not refresh_user_id or refresh_user_id != expected_user_id:
        raise ValueError("Refresh token does not belong to the authenticated user")


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
    """Development-only direct Google bootstrap.

    Production mobile clients authenticate through Cognito's Google IdP using
    authorization-code + PKCE. Keeping this helper in explicit dev mode makes
    local tests deterministic without retaining a password-minting production
    backdoor.
    """
    is_dev = os.environ.get("GUARDIAN_DEV_MODE", "false").lower() == "true"
    if not is_dev:
        raise ValueError(
            "Direct Google token bootstrap is disabled in production; "
            "use Cognito managed login."
        )
    if not id_token_str or not id_token_str.strip():
        raise ValueError("Google ID token is required")

    if id_token_str.startswith("dev_google_") or id_token_str.startswith("mock_google_"):
        parts = id_token_str.split("_")
        suffix = parts[-1] if len(parts) > 2 else "user1"
        user_id = f"google_dev_{suffix}"
        email = f"{suffix}@gmail.com"
        name = f"Guardian User ({suffix})"
        picture = ""
    else:
        try:
            id_info = _verify_google_payload(id_token_str)
        except ValueError as error:
            raise ValueError("Invalid Google ID token") from error

        if id_info.get("iss") not in {
            "accounts.google.com",
            "https://accounts.google.com",
        }:
            raise ValueError("Invalid Google token issuer")
        if id_info.get("aud") != GOOGLE_CLIENT_ID:
            raise ValueError("Invalid Google token audience")
        if id_info.get("email_verified") is not True:
            raise ValueError("Google account email must be verified")

        sub = str(id_info.get("sub") or "").strip()
        email = str(id_info.get("email") or "").strip()
        if not sub or not email:
            raise ValueError("Google token is missing required identity claims")
        user_id = f"google_{sub}"
        name = str(id_info.get("name") or "")
        picture = str(id_info.get("picture") or "")

    refresh_token = f"google_refresh_token_{uuid.uuid4().hex}"
    access_token = f"dev_access_token_{user_id}"
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


def bootstrap_cognito_identity(access_token: str) -> Dict[str, Any]:
    """Resolve a Cognito-authenticated identity to Guardian's immutable user id."""
    if not access_token:
        raise ValueError("Cognito access token is required")

    is_dev = os.environ.get("GUARDIAN_DEV_MODE", "false").lower() == "true"
    if is_dev and access_token.startswith("dev_access_token_"):
        user_id = access_token.removeprefix("dev_access_token_")
        if not user_id:
            raise ValueError("Invalid development access token")
        profile = get_user_profile(user_id) or {}
        return {
            "user_id": user_id,
            "email": profile.get("email", ""),
            "display_name": profile.get("display_name", ""),
            "photo_url": profile.get("photo_url", ""),
            "auth_provider": profile.get("auth_provider", "google"),
        }

    client = _cognito_client()
    if not client or not COGNITO_USER_POOL_ID:
        raise ValueError("AWS Cognito is not configured")
    try:
        result = client.get_user(AccessToken=access_token)
    except ClientError as error:
        raise ValueError("Cognito access token is invalid or expired") from error

    attributes = {
        str(item.get("Name")): str(item.get("Value") or "")
        for item in result.get("UserAttributes", [])
        if item.get("Name")
    }
    user_id = attributes.get("sub", "").strip()
    if not user_id:
        raise ValueError("Cognito token is missing immutable subject identity")
    email = attributes.get("email", "").strip()
    display_name = attributes.get("name", "").strip()
    photo_url = attributes.get("picture", "").strip()
    _upsert_user_profile(
        user_id=user_id,
        phone="",
        extra={
            "email": email,
            "display_name": display_name,
            "photo_url": photo_url,
            "auth_provider": "google",
            "cognito_username": str(result.get("Username") or ""),
        },
    )
    return {
        "user_id": user_id,
        "email": email,
        "display_name": display_name,
        "photo_url": photo_url,
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
