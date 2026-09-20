"""Authentication boundary for the Guardian API.

Production requests must carry a Cognito access token. The local development
fallback is deliberately opt-in so a missing AWS configuration cannot silently
turn a deployed API into an unauthenticated demo server.
"""

import os
from typing import FrozenSet, Optional, Tuple

from fastapi import Request
from fastapi.responses import JSONResponse
from starlette.middleware.base import BaseHTTPMiddleware

from aws.session_service import validate_access_session


def _dev_mode_enabled() -> bool:
    return os.environ.get("GUARDIAN_DEV_MODE", "false").lower() == "true"


def is_dev_mode() -> bool:
    """Expose the explicit local-development switch to route policy code."""
    return _dev_mode_enabled()


def _gateway_identity(request: Request) -> Optional[Tuple[str, FrozenSet[str]]]:
    """Read claims already verified by the API Gateway Cognito authorizer."""
    event = request.scope.get("aws.event") or {}
    claims = (
        event.get("requestContext", {})
        .get("authorizer", {})
        .get("claims", {})
    )
    user_id = claims.get("sub") or claims.get("username") or claims.get("cognito:username")
    if not user_id:
        return None
    raw_groups = claims.get("cognito:groups", "")
    groups = raw_groups if isinstance(raw_groups, list) else str(raw_groups).split(",")
    return str(user_id), frozenset(group.strip() for group in groups if group.strip())


def _cognito_identity(access_token: str) -> Optional[Tuple[str, FrozenSet[str]]]:
    if _dev_mode_enabled() and access_token.startswith("dev_access_token_"):
        user_id = access_token.removeprefix("dev_access_token_") or None
        return (user_id, frozenset()) if user_id else None

    pool_id = os.environ.get("COGNITO_USER_POOL_ID", "")
    if not pool_id:
        return None

    try:
        import boto3

        client = boto3.client(
            "cognito-idp",
            region_name=os.environ.get("AWS_DEFAULT_REGION", "ap-south-1"),
        )
        result = client.get_user(AccessToken=access_token)
        user_id = result.get("Username")
        group_result = client.admin_list_groups_for_user(
            Username=user_id,
            UserPoolId=pool_id,
            Limit=20,
        )
        groups = frozenset(
            str(group.get("GroupName", "")).strip()
            for group in group_result.get("Groups", [])
            if str(group.get("GroupName", "")).strip()
        )
        return (user_id, groups) if user_id else None
    except Exception:
        return None


class AuthenticationMiddleware(BaseHTTPMiddleware):
    """Require authentication for all non-public API routes."""

    _public_paths = {
        "/",
        "/auth/send-otp",
        "/auth/verify-otp",
        "/auth/refresh",
        "/docs",
        "/docs/oauth2-redirect",
        "/openapi.json",
        "/redoc",
    }

    async def dispatch(self, request: Request, call_next):
        if request.method == "OPTIONS" or request.url.path in self._public_paths:
            return await call_next(request)

        header = request.headers.get("Authorization", "")
        scheme, _, token = header.partition(" ")
        if scheme.lower() != "bearer" or not token:
            return JSONResponse(
                status_code=401,
                content={"detail": "A valid bearer token is required."},
                headers={"WWW-Authenticate": "Bearer"},
            )

        identity = _gateway_identity(request) or _cognito_identity(token)
        if not identity:
            return JSONResponse(
                status_code=401,
                content={"detail": "The bearer token is invalid or expired."},
                headers={"WWW-Authenticate": "Bearer"},
            )

        request.state.user_id, request.state.roles = identity
        request.state.access_token = token
        session_id = request.headers.get("X-Guardian-Session-ID", "")
        try:
            session_is_valid = validate_access_session(session_id, request.state.user_id)
        except Exception:
            return JSONResponse(
                status_code=503,
                content={"detail": "Session validation is temporarily unavailable."},
            )
        if not session_is_valid:
            return JSONResponse(
                status_code=401,
                content={"detail": "The application session is invalid or revoked."},
                headers={"WWW-Authenticate": "Bearer"},
            )
        request.state.session_id = session_id
        return await call_next(request)


def authenticated_user_id(request: Request) -> str:
    """Return the identity established by AuthenticationMiddleware."""
    user_id = getattr(request.state, "user_id", None)
    if not user_id:
        raise RuntimeError("Authentication middleware did not establish an identity")
    return user_id


def authenticated_roles(request: Request) -> FrozenSet[str]:
    return getattr(request.state, "roles", frozenset())
