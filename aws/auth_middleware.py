"""Authentication boundary for the Guardian API.

Production requests must carry a Cognito access token. The local development
fallback is deliberately opt-in so a missing AWS configuration cannot silently
turn a deployed API into an unauthenticated demo server.
"""

import os
from typing import Optional

from fastapi import Request
from fastapi.responses import JSONResponse
from starlette.middleware.base import BaseHTTPMiddleware


def _dev_mode_enabled() -> bool:
    return os.environ.get("GUARDIAN_DEV_MODE", "false").lower() == "true"


def is_dev_mode() -> bool:
    """Expose the explicit local-development switch to route policy code."""
    return _dev_mode_enabled()


def _cognito_user_id(access_token: str) -> Optional[str]:
    if _dev_mode_enabled() and access_token.startswith("dev_access_token_"):
        return access_token.removeprefix("dev_access_token_") or None

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
        return result.get("Username")
    except Exception:
        return None


class AuthenticationMiddleware(BaseHTTPMiddleware):
    """Require authentication for all non-public API routes."""

    _public_paths = {
        "/",
        "/docs",
        "/docs/oauth2-redirect",
        "/openapi.json",
        "/redoc",
    }

    async def dispatch(self, request: Request, call_next):
        if request.method == "OPTIONS" or request.url.path in self._public_paths:
            return await call_next(request)

        if request.url.path.startswith("/auth/"):
            return await call_next(request)

        header = request.headers.get("Authorization", "")
        scheme, _, token = header.partition(" ")
        if scheme.lower() != "bearer" or not token:
            return JSONResponse(
                status_code=401,
                content={"detail": "A valid bearer token is required."},
                headers={"WWW-Authenticate": "Bearer"},
            )

        user_id = _cognito_user_id(token)
        if not user_id:
            return JSONResponse(
                status_code=401,
                content={"detail": "The bearer token is invalid or expired."},
                headers={"WWW-Authenticate": "Bearer"},
            )

        request.state.user_id = user_id
        return await call_next(request)


def authenticated_user_id(request: Request) -> str:
    """Return the identity established by AuthenticationMiddleware."""
    user_id = getattr(request.state, "user_id", None)
    if not user_id:
        raise RuntimeError("Authentication middleware did not establish an identity")
    return user_id
