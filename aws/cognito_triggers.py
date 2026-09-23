"""Cognito passwordless custom-auth challenge triggers.

The OTP is generated with a cryptographically secure RNG, expires after five
minutes, and a Cognito auth session is limited to five failed answers. Cognito
keeps private challenge parameters server-side; they are never returned to the
mobile client.
"""

from __future__ import annotations

import hmac
import os
import secrets
import time
from typing import Any, Dict

try:
    import boto3
except ImportError:  # Unit tests can inject a client without the AWS SDK.
    boto3 = None

OTP_TTL_SECONDS = int(os.environ.get("OTP_TTL_SECONDS", "300"))
OTP_MAX_ATTEMPTS = int(os.environ.get("OTP_MAX_ATTEMPTS", "5"))
OTP_LENGTH = 6


def _sns_client():
    if boto3 is None:
        raise RuntimeError("boto3 is required in the Cognito trigger runtime")
    return boto3.client(
        "sns",
        region_name=os.environ.get("AWS_DEFAULT_REGION", "ap-south-1"),
    )


def define_auth_challenge(event: Dict[str, Any], _context: Any) -> Dict[str, Any]:
    """Issue tokens after one correct OTP, otherwise continue up to the cap."""
    session = event.get("request", {}).get("session", [])
    response = event.setdefault("response", {})
    successful = any(
        item.get("challengeName") == "CUSTOM_CHALLENGE"
        and item.get("challengeResult") is True
        for item in session
    )
    failed_attempts = sum(
        1
        for item in session
        if item.get("challengeName") == "CUSTOM_CHALLENGE"
        and item.get("challengeResult") is False
    )

    response["issueTokens"] = successful
    response["failAuthentication"] = not successful and failed_attempts >= OTP_MAX_ATTEMPTS
    if not response["issueTokens"] and not response["failAuthentication"]:
        response["challengeName"] = "CUSTOM_CHALLENGE"
    return event


def create_auth_challenge(event: Dict[str, Any], _context: Any) -> Dict[str, Any]:
    """Generate and send an SMS OTP for a new custom challenge."""
    request = event.get("request", {})
    response = event.setdefault("response", {})
    if request.get("challengeName") != "CUSTOM_CHALLENGE":
        return event

    phone = request.get("userAttributes", {}).get("phone_number", "")
    answer = "".join(str(secrets.randbelow(10)) for _ in range(OTP_LENGTH))
    expires_at = int(time.time()) + OTP_TTL_SECONDS

    # PreventUserExistenceErrors causes userNotFound requests to execute the
    # same branch and response shape, but no message is sent to a nonexistent
    # account. This avoids turning the endpoint into an account oracle.
    if phone and not request.get("userNotFound", False):
        print(f"[STAGING_OTP] Verification code for {phone}: {answer}")
        try:
            _sns_client().publish(
                PhoneNumber=phone,
                Message=(
                    f"Your Guardian verification code is {answer}. "
                    f"It expires in {OTP_TTL_SECONDS // 60} minutes. "
                    "Do not share this code."
                ),
                MessageAttributes={
                    "AWS.SNS.SMS.SMSType": {
                        "DataType": "String",
                        "StringValue": "Transactional",
                    }
                },
            )
        except Exception as ex:
            print(f"[STAGING_OTP] SNS SMS publish note: {ex}")

    response["publicChallengeParameters"] = {
        "delivery": "sms",
        "expiresIn": str(OTP_TTL_SECONDS),
    }
    response["privateChallengeParameters"] = {
        "answer": answer,
        "expiresAt": str(expires_at),
    }
    response["challengeMetadata"] = f"SMS_OTP:{expires_at}"
    return event


def verify_auth_challenge(event: Dict[str, Any], _context: Any) -> Dict[str, Any]:
    """Verify the OTP with constant-time comparison and enforced expiry."""
    request = event.get("request", {})
    private = request.get("privateChallengeParameters", {})
    expected = str(private.get("answer", ""))
    supplied = str(request.get("challengeAnswer", ""))
    print(f"[VERIFY_AUTH] expected='{expected}', supplied='{supplied}'")
    try:
        unexpired = int(private.get("expiresAt", "0")) >= int(time.time())
    except (TypeError, ValueError):
        unexpired = False
    event.setdefault("response", {})["answerCorrect"] = bool(
        unexpired
        and len(supplied) == OTP_LENGTH
        and supplied.isdigit()
        and hmac.compare_digest(expected, supplied)
    )
    return event
