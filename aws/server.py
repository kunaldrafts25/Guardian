"""
Guardian AWS Backend Server (FastAPI / Serverless Local Runner)
v3.0 — Full AWS-Only Stack: Cognito Auth + DynamoDB + SNS Push + Bedrock AI

Mirrors real AWS API Gateway + Lambda endpoints:
  POST   /auth/refresh               → Cognito: refresh access token
  POST   /auth/sign-out              → Cognito: global sign out

  GET    /users/{user_id}            → DynamoDB: get user profile
  PUT    /users/{user_id}            → DynamoDB: update user profile
  POST   /users/{user_id}/device     → SNS: register device for push notifications
  POST   /users/{user_id}/contacts   → DynamoDB: save emergency contacts

  POST   /incidents                  → Create incident + Bedrock AI evaluation
  GET    /incidents/{id}             → Get incident state
  PUT    /incidents/{id}/status      → Update incident state
  GET    /incidents/{id}/timeline    → Get audit trail
  GET    /incidents/{id}/nearby      → Get nearby verified responders
  POST   /incidents/{id}/accept      → Helper accepts rescue mission
  POST   /incidents/{id}/dispatch-community → Dispatch community SOS

  POST   /push/send                  → SNS: send push to user
  POST   /push/sms                   → SNS: send SMS to contact

  POST   /responders/heartbeat       → Update responder location
"""

import os
import sys
from pathlib import Path

# Ensure workspace root is in sys.path
BASE_DIR = Path(__file__).resolve().parent.parent
if str(BASE_DIR) not in sys.path:
    sys.path.insert(0, str(BASE_DIR))

# Load environment variables
try:
    from dotenv import load_dotenv
    env_path = Path(__file__).resolve().parent / ".env"
    if env_path.exists():
        load_dotenv(dotenv_path=env_path)
    else:
        root_env = BASE_DIR / ".env"
        if root_env.exists():
            load_dotenv(dotenv_path=root_env)
        else:
            load_dotenv()
except ImportError:
    pass

from fastapi import FastAPI, HTTPException, BackgroundTasks, Header, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, ConfigDict, Field
from typing import Dict, Any, Optional, List
from datetime import datetime, timezone
import uuid

from aws.incident_handler.handler import (
    create_incident,
    update_incident_status,
    update_incident_location,
    get_incident,
    get_incident_timeline,
    get_dynamo_resource,
    IncidentState,
    DYNAMODB_INCIDENTS_TABLE,
)
from aws.agent.guardian_agent import (
    execute_agent_reasoning,
    execute_authorized_tool,
    query_safety_companion,
)
from aws.agent.policy_authorization import issue_policy_authorizations
from aws.agent.safety_policy import evaluate_safety_policy

# AWS Services
from aws.cognito_service import (
    authenticate_with_google,
    refresh_tokens,
    sign_out,
    update_user_profile,
    get_user_profile,
)
from aws.session_service import (
    create_session,
    list_sessions,
    revoke_all_sessions,
    revoke_session,
    touch_session,
    validate_refresh_session,
)
from aws.sns_push_service import (
    register_device_endpoint,
    disable_all_device_endpoints,
    disable_device_endpoints_for_session,
    send_push_to_user,
    send_sms_alert,
)
from aws.auth_middleware import (
    AuthenticationMiddleware,
    authenticated_roles,
    authenticated_user_id,
    is_dev_mode,
)

app = FastAPI(
    title="Guardian AWS Agentic Backend",
    description="Full AWS-Only: Cognito Auth + DynamoDB + SNS Push + Amazon Bedrock AI",
    version="3.0.0",
)

_allowed_origins_env = os.environ.get("GUARDIAN_ALLOWED_ORIGINS")
_allowed_origins = [o.strip() for o in _allowed_origins_env.split(",") if o.strip()] if _allowed_origins_env else ["*"]

app.add_middleware(
    CORSMiddleware,
    allow_origins=_allowed_origins,
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)


def _error_payload(request: Request, code: str, message: str, retryable: bool):
    return {
        "error": {
            "code": code,
            "message": message,
            "retryable": retryable,
            "correlation_id": getattr(request.state, "correlation_id", "unknown"),
        }
    }


@app.middleware("http")
async def correlation_middleware(request: Request, call_next):
    supplied = request.headers.get("X-Correlation-ID", "")
    request.state.correlation_id = (
        supplied if 0 < len(supplied) <= 128 and supplied.isascii() else str(uuid.uuid4())
    )
    response = await call_next(request)
    response.headers["X-Correlation-ID"] = request.state.correlation_id
    return response


@app.exception_handler(HTTPException)
async def http_error_handler(request: Request, error: HTTPException):
    return JSONResponse(
        status_code=error.status_code,
        content=_error_payload(
            request,
            f"HTTP_{error.status_code}",
            str(error.detail),
            error.status_code >= 500 or error.status_code == 429,
        ),
        headers=error.headers,
    )


@app.exception_handler(RequestValidationError)
async def validation_error_handler(request: Request, error: RequestValidationError):
    return JSONResponse(
        status_code=422,
        content=_error_payload(request, "VALIDATION_ERROR", "Request validation failed", False),
    )


def _require_role(request: Request, role: str) -> None:
    if is_dev_mode():
        return
    if role not in authenticated_roles(request):
        raise HTTPException(status_code=403, detail="This account is not authorized for responder operations.")
app.add_middleware(AuthenticationMiddleware)


# ─────────────────────────────────────────────────────────────────────────────
# HEALTH CHECK
# ─────────────────────────────────────────────────────────────────────────────

@app.get("/health")
def api_health():
    now_iso = datetime.now(timezone.utc).isoformat()
    db_status = "connected"
    if os.environ.get("AWS_EXECUTION_ENV"):
        try:
            import boto3
            dynamo = boto3.client("dynamodb", region_name=os.environ.get("AWS_REGION", "ap-south-1"))
            dynamo.describe_limits()
            db_status = "connected"
        except Exception as e:
            db_status = f"unreachable: {str(e)[:50]}"
    elif os.environ.get("GUARDIAN_DEV_MODE", "false").lower() == "true":
        db_status = "local_simulation"
    else:
        db_status = "unconfigured"

    is_healthy = db_status in ("connected", "local_simulation")
    return {
        "status": "healthy" if is_healthy else "degraded",
        "service": "Guardian AWS Full-Stack API",
        "version": "3.0.0",
        "timestamp": now_iso,
        "region": os.environ.get("AWS_DEFAULT_REGION", "ap-south-1"),
        "checks": {
            "database": db_status,
            "auth": "cognito_configured" if os.environ.get("COGNITO_USER_POOL_ID") else "dev_mock",
            "push": "sns_configured" if os.environ.get("SNS_FCM_PLATFORM_ARN") else "dev_mock",
        },
    }


@app.get("/")
def health_check():
    aws_configured = bool(
        os.environ.get("AWS_EXECUTION_ENV")
        or os.environ.get("AWS_ACCESS_KEY_ID")
        or os.environ.get("AWS_PROFILE")
    )
    cognito_configured = bool(os.environ.get("COGNITO_USER_POOL_ID"))
    sns_configured = bool(
        os.environ.get("SNS_FCM_PLATFORM_ARN")
        or os.environ.get("SNS_APNS_PLATFORM_ARN")
    )
    return {
        "status": "online",
        "service": "Guardian AWS Full-Stack API",
        "version": "3.0.0",
        "aws_region": os.environ.get("AWS_DEFAULT_REGION", "ap-south-1"),
        "services": {
            "auth": "AWS Cognito" if cognito_configured else "Unavailable",
            "database": "AWS DynamoDB" if aws_configured else "Unavailable",
            "push": "AWS SNS" if sns_configured else "Unavailable",
            "ai": "Amazon Bedrock advisory" if aws_configured else "Unavailable",
        },
        "model": os.environ.get("BEDROCK_MODEL_ID", "anthropic.claude-3-haiku-20240307-v1:0"),
    }


# ─────────────────────────────────────────────────────────────────────────────
# AUTH ENDPOINTS (AWS Cognito)
# ─────────────────────────────────────────────────────────────────────────────


class GoogleAuthRequest(BaseModel):
    id_token: str = Field(min_length=1)
    device_label: str = Field(default="Guardian mobile device", max_length=80)
    platform: str = Field(default="unknown", max_length=20)


@app.post("/auth/google")
def api_google_auth(req: GoogleAuthRequest):
    """Authenticate via Google ID token, link profile in DynamoDB, and issue session."""
    try:
        result = authenticate_with_google(req.id_token)
        guardian_session = create_session(
            result["user_id"],
            result["refresh_token"],
            req.device_label,
            req.platform,
        )
        result.update(guardian_session)
        return result
    except ValueError as ve:
        raise HTTPException(status_code=401, detail=str(ve))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Google authentication failed: {str(e)}")



class RefreshTokenRequest(BaseModel):
    refresh_token: str
    session_id: str = Field(min_length=1, max_length=64)


class AssistantRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    message: str = Field(min_length=1, max_length=4000)
    incident_id: Optional[str] = Field(default=None, min_length=1, max_length=128)



@app.post("/auth/refresh")
def api_refresh_token(req: RefreshTokenRequest):
    """Refresh expired JWT access/id tokens."""
    try:
        user_id = validate_refresh_session(req.session_id, req.refresh_token)
        result = refresh_tokens(req.refresh_token, user_id=user_id)
        touch_session(req.session_id, user_id)
        result["session_id"] = req.session_id
        return result
    except ValueError as ve:
        raise HTTPException(status_code=401, detail=str(ve))


@app.post("/auth/sign-out")
def api_sign_out(request: Request):
    """Revoke all tokens, sessions, and user-bound push endpoints."""
    user_id = authenticated_user_id(request)
    disable_all_device_endpoints(user_id)
    result = sign_out(request.state.access_token)
    revoke_all_sessions(user_id)
    return result


@app.get("/auth/sessions")
def api_list_sessions(request: Request):
    try:
        sessions = list_sessions(authenticated_user_id(request))
        for session in sessions:
            session["current"] = session["session_id"] == request.state.session_id
        return {"sessions": sessions}
    except RuntimeError as error:
        raise HTTPException(status_code=503, detail=str(error))


@app.delete("/auth/sessions/{session_id}")
def api_revoke_session(session_id: str, request: Request):
    try:
        user_id = authenticated_user_id(request)
        disable_device_endpoints_for_session(user_id, session_id)
        revoke_session(user_id, session_id)
        return {"success": True}
    except ValueError as error:
        raise HTTPException(status_code=404, detail=str(error))


@app.post("/assistant/chat")
def api_assistant_chat(req: AssistantRequest, request: Request):
    """Generate a safety response using the configured Amazon Bedrock model."""
    try:
        authorized_context: Dict[str, str] = {}
        if req.incident_id:
            incident = _owned_incident(req.incident_id, request)
            authorized_context = {
                "incident_id": str(incident["incident_id"]),
                "state": str(incident.get("state", "unknown")),
                "event_type": str(incident.get("event_type", "unknown")),
                "risk_level": str(incident.get("risk_level", "unknown")),
            }
        return {"response": query_safety_companion(req.message, authorized_context)}
    except HTTPException:
        raise
    except Exception:
        raise HTTPException(status_code=503, detail="Safety assistant is temporarily unavailable")


# ─────────────────────────────────────────────────────────────────────────────
# USER PROFILE ENDPOINTS (DynamoDB)
# ─────────────────────────────────────────────────────────────────────────────

class UpdateProfileRequest(BaseModel):
    display_name: Optional[str] = None
    photo_url: Optional[str] = None
    safe_zones: Optional[List[Dict[str, Any]]] = None
    guardian_circle: Optional[List[str]] = None
    settings: Optional[Dict[str, Any]] = None


class RegisterDeviceRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    device_token: str = Field(min_length=16, max_length=4096)
    device_id: str = Field(min_length=8, max_length=128)
    platform: str = Field(default="android", pattern="^(android|ios)$")


class EmergencyContactRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    id: str = Field(min_length=1, max_length=128)
    name: str = Field(min_length=1, max_length=120)
    phone: str = Field(pattern=r"^\+[1-9][0-9]{7,14}$")
    relation: str = Field(default="", max_length=80)
    is_primary: bool = False


class SaveContactsRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    contacts: List[EmergencyContactRequest] = Field(max_length=5)


def _owned_incident(incident_id: str, request: Request) -> Dict[str, Any]:
    """Load an incident and enforce ownership for victim-facing operations."""
    incident = get_incident(incident_id)
    if not incident:
        raise HTTPException(status_code=404, detail="Incident not found")
    if incident.get("user_id") != authenticated_user_id(request):
        raise HTTPException(status_code=403, detail="Incident access denied")
    return incident


@app.get("/users/{user_id}")
def api_get_user(user_id: str, request: Request):
    """Fetch user profile from DynamoDB."""
    if user_id != authenticated_user_id(request):
        raise HTTPException(status_code=403, detail="User profile access denied")
    profile = get_user_profile(user_id)
    if not profile:
        raise HTTPException(status_code=404, detail="User not found")
    return profile


@app.put("/users/{user_id}")
def api_update_user(user_id: str, req: UpdateProfileRequest, request: Request):
    """Update user profile fields in DynamoDB."""
    if user_id != authenticated_user_id(request):
        raise HTTPException(status_code=403, detail="User profile access denied")
    data = {k: v for k, v in req.model_dump().items() if v is not None}
    result = update_user_profile(user_id, data)
    return result


@app.post("/users/{user_id}/device")
def api_register_device(user_id: str, req: RegisterDeviceRequest, request: Request):
    """Register device push token with AWS SNS — returns endpoint ARN."""
    if user_id != authenticated_user_id(request):
        raise HTTPException(status_code=403, detail="Device registration denied")
    result = register_device_endpoint(
        user_id=user_id,
        session_id=request.state.session_id,
        device_id=req.device_id,
        device_token=req.device_token,
        platform=req.platform,
    )
    return result


@app.post("/users/{user_id}/contacts")
def api_save_contacts(user_id: str, req: SaveContactsRequest, request: Request):
    """Save emergency contacts to DynamoDB user profile."""
    if user_id != authenticated_user_id(request):
        raise HTTPException(status_code=403, detail="Contact update denied")
    result = update_user_profile(
        user_id,
        {"emergency_contacts": [contact.model_dump() for contact in req.contacts]},
    )
    return result


# ─────────────────────────────────────────────────────────────────────────────
# PUSH NOTIFICATION ENDPOINTS (AWS SNS)
# ─────────────────────────────────────────────────────────────────────────────

class PushRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    title: str
    body: str
    data: Optional[Dict[str, str]] = None
    notification_type: str = "general"


class SmsRequest(BaseModel):
    phone_number: str
    message: str
    sender_id: str = "GUARDIAN"


class ContactNotificationRequest(BaseModel):
    notification_type: str
    minutes_overdue: Optional[int] = None
    zone_name: Optional[str] = None


class ContactTestRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    contact_id: Optional[str] = Field(default=None, max_length=128)


@app.post("/push/send")
def api_send_push(req: PushRequest, request: Request):
    """Send targeted push notification to a user via SNS."""
    user_id = authenticated_user_id(request)
    result = send_push_to_user(
        user_id=user_id,
        title=req.title,
        body=req.body,
        data=req.data,
        notification_type=req.notification_type,
    )
    return result


@app.post("/push/sms")
def api_send_sms(req: SmsRequest, request: Request):
    """Send SMS to a phone number via AWS SNS."""
    if not is_dev_mode():
        raise HTTPException(status_code=403, detail="Direct SMS dispatch is server-side only")
    result = send_sms_alert(req.phone_number, req.message, req.sender_id)
    return result


@app.post("/notifications/contacts")
def api_notify_contacts(req: ContactNotificationRequest, request: Request):
    """Send a server-authored safety update to the caller's trusted contacts."""
    user_id = authenticated_user_id(request)
    profile = get_user_profile(user_id)
    if not profile:
        raise HTTPException(status_code=404, detail="User profile not found")
    contacts = profile.get("emergency_contacts", [])
    display_name = profile.get("display_name") or profile.get("phone") or "Your Guardian contact"

    if req.notification_type == "safe_arrival":
        message = f"Guardian update: {display_name} has checked in safely."
    elif req.notification_type == "sos_resolved":
        message = f"Guardian update: {display_name} has marked their SOS as resolved."
    elif req.notification_type == "check_in_overdue":
        overdue = max(0, min(req.minutes_overdue or 0, 1440))
        message = f"Guardian alert: {display_name} is {overdue} minutes overdue for a safety check-in. Please contact them."
    elif req.notification_type == "safe_zone_exit":
        zone = (req.zone_name or "a safe zone").strip()[:80]
        message = f"Guardian alert: {display_name} has left {zone}. Please check on them."
    else:
        raise HTTPException(status_code=400, detail="Unsupported notification type")

    results = []
    for contact in contacts:
        phone = str(contact.get("phone", "")).strip()
        if not phone:
            continue
        result = send_sms_alert(phone, message)
        results.append({"contact_id": contact.get("id"), "success": bool(result.get("success"))})
    sent_count = sum(1 for result in results if result["success"])
    return {
        "success": bool(results) and sent_count == len(results),
        "sent_count": sent_count,
        "attempted_count": len(results),
        "results": results,
    }


@app.post("/notifications/contact-test")
def api_test_contact_notification(req: ContactTestRequest, request: Request):
    """Send one clearly labelled, non-emergency test to an owned contact."""
    user_id = authenticated_user_id(request)
    profile = get_user_profile(user_id)
    if not profile:
        raise HTTPException(status_code=404, detail="User profile not found")
    contacts = profile.get("emergency_contacts", [])
    selected = next(
        (
            contact
            for contact in contacts
            if req.contact_id and str(contact.get("id")) == req.contact_id
        ),
        None,
    )
    if selected is None and req.contact_id is None:
        selected = next(
            (contact for contact in contacts if contact.get("is_primary")),
            contacts[0] if contacts else None,
        )
    if selected is None or not str(selected.get("phone", "")).strip():
        raise HTTPException(status_code=404, detail="Configured contact not found")
    display_name = profile.get("display_name") or profile.get("phone") or "A Guardian user"
    result = send_sms_alert(
        str(selected["phone"]),
        f"Guardian TEST — no emergency. {display_name} is verifying their safety contact setup. No action is required.",
    )
    return {
        "contact_id": selected.get("id"),
        "provider_accepted": bool(result.get("success")),
        "message_id": result.get("message_id"),
        "status": "PROVIDER_ACCEPTED" if result.get("success") else "FAILED",
        "error": result.get("error"),
    }


# ─────────────────────────────────────────────────────────────────────────────
# INCIDENT MANAGEMENT (DynamoDB + Bedrock AI)
# ─────────────────────────────────────────────────────────────────────────────

class IncidentCreateRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    event_id: Optional[str] = None
    event_type: str = "fall_detected"
    location: Optional[Dict[str, Any]] = None
    motion_data: Optional[Dict[str, Any]] = None


class IncidentStatusUpdateRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    state: str
    note: Optional[str] = ""


@app.post("/incidents", status_code=201)
def api_create_incident(
    req: IncidentCreateRequest,
    background_tasks: BackgroundTasks,
    request: Request,
):
    """Create incident and trigger Bedrock AI evaluation."""
    payload = req.model_dump()
    owner_id = authenticated_user_id(request)
    payload["user_id"] = owner_id
    if not payload.get("event_id"):
        payload["event_id"] = str(uuid.uuid4())

    incident = create_incident(payload)
    iid = incident["incident_id"]

    # In AWS Lambda production, EventBridge asynchronously triggers GuardianAgentFunction
    # without freezing or racing against API Gateway responses. In local/dev, execute via background task.
    if not os.environ.get("AWS_EXECUTION_ENV"):
        background_tasks.add_task(execute_agent_reasoning, iid)
    
    return incident


@app.get("/incidents/{incident_id}")
def api_get_incident(incident_id: str, request: Request):
    return _owned_incident(incident_id, request)


@app.put("/incidents/{incident_id}/status")
def api_update_incident_status(
    incident_id: str,
    req: IncidentStatusUpdateRequest,
    request: Request,
):
    try:
        _owned_incident(incident_id, request)
        updated = update_incident_status(
            incident_id=incident_id,
            new_state=req.state,
            actor="USER",
            note=req.note or "",
        )
        if updated.get("state") in {"RESOLVED", "CANCELLED", "EXPIRED"}:
            from aws.agent.tools import cancel_incident_missions

            cancelled = cancel_incident_missions(
                incident_id,
                req.note or f"Incident became {updated['state']}",
            )
            return {**updated, "cancelled_mission_count": cancelled}
        return updated
    except ValueError as ve:
        raise HTTPException(status_code=400, detail=str(ve))


class IncidentLocationUpdateRequest(BaseModel):
    model_config = ConfigDict(extra="allow")

    location: Optional[Dict[str, Any]] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    accuracy: Optional[float] = None
    captured_at: Optional[str] = None
    source: Optional[str] = None


@app.post("/incidents/{incident_id}/location")
def api_update_incident_location(
    incident_id: str,
    req: IncidentLocationUpdateRequest,
    request: Request,
):
    try:
        user_id = authenticated_user_id(request)
        loc_payload = req.location or req.model_dump(exclude_none=True)
        return update_incident_location(
            incident_id=incident_id,
            location_payload=loc_payload,
            user_id=user_id,
        )
    except PermissionError as pe:
        raise HTTPException(status_code=403, detail=str(pe))
    except ValueError as ve:
        raise HTTPException(status_code=409, detail=str(ve))


@app.get("/incidents/{incident_id}/timeline")
def api_get_incident_timeline(incident_id: str, request: Request):
    _owned_incident(incident_id, request)
    timeline = get_incident_timeline(incident_id)
    return {"incident_id": incident_id, "timeline": timeline}


@app.get("/incidents/{incident_id}/nearby")
def api_get_nearby_responders(
    incident_id: str,
    request: Request,
    radius_meters: float = 1200.0,
):
    incident = _owned_incident(incident_id, request)
    from aws.agent.tools import find_nearby_responders
    responders = find_nearby_responders(incident_id, radius_meters=radius_meters)
    return {
        "incident_id": incident_id,
        "eligible_responder_count": len(responders),
        "search_stage": incident.get("current_escalation_stage", 1),
        "radius_meters": radius_meters,
    }


@app.post("/incidents/{incident_id}/accept")
def api_accept_mission(
    incident_id: str,
    request: Request,
):
    from aws.agent.tools import accept_rescue_mission
    _require_role(request, "responder")
    responder_id = authenticated_user_id(request)
    try:
        result = accept_rescue_mission(incident_id, responder_id)
        
        # Notify victim that help is coming via push/SMS
        incident = get_incident(incident_id)
        if incident:
            background_push = send_push_to_user(
                user_id=incident.get("user_id", ""),
                title="✅ Helper Accepted Alert",
                body="A verified Guardian helper accepted your request. Awaiting route departure.",
                notification_type="rescue_accepted",
                data={"incident_id": incident_id, "responder_id": responder_id},
            )
        return result
    except PermissionError as pe:
        raise HTTPException(status_code=403, detail=str(pe))
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))


class NavigationGrantRequest(BaseModel):
    navigation_grant: str = Field(min_length=32, max_length=256)


@app.post("/incidents/{incident_id}/authorized-location")
def api_authorized_incident_location(
    incident_id: str,
    req: NavigationGrantRequest,
    request: Request,
):
    from aws.agent.tools import get_authorized_incident_location

    _require_role(request, "responder")
    try:
        return get_authorized_incident_location(
            incident_id,
            authenticated_user_id(request),
            req.navigation_grant,
        )
    except PermissionError as error:
        raise HTTPException(status_code=403, detail=str(error))


class AbuseReportRequest(BaseModel):
    reason: str = Field(min_length=2)
    description: str = Field(min_length=5)

@app.post("/incidents/{incident_id}/report")
def api_report_incident(
    incident_id: str,
    req: AbuseReportRequest,
    request: Request,
):
    """Record a moderation report only from a participant in the incident."""
    from aws.incident_handler.handler import get_dynamo_resource
    from aws.agent.tools import _incident_missions, _dev_mode

    reporter_id = authenticated_user_id(request)
    incident = get_incident(incident_id)
    if not incident:
        raise HTTPException(status_code=404, detail="Incident not found")

    reporter_role = None
    if incident.get("user_id") == reporter_id:
        reporter_role = "OWNER"
    else:
        missions = _incident_missions(incident_id)
        if any(m.get("responder_id") == reporter_id for m in missions):
            reporter_role = "RESPONDER"
    if reporter_role is None:
        raise HTTPException(
            status_code=403,
            detail="Only the incident owner or an associated responder can report it.",
        )

    report_id = f"report_{uuid.uuid4().hex}"
    now = datetime.now(timezone.utc)
    report = {
        "report_id": report_id,
        "incident_id": incident_id,
        "reporter_user_id": reporter_id,
        "reporter_role": reporter_role,
        "reason": req.reason[:120],
        "description": req.description[:1000],
        "review_status": "PENDING",
        "created_at": now.isoformat(),
        "expires_at": int(now.timestamp()) + (180 * 24 * 60 * 60),
    }

    dynamo = get_dynamo_resource()
    if dynamo:
        try:
            dynamo.Table(
                os.environ.get(
                    "DYNAMODB_ABUSE_REPORTS_TABLE",
                    "guardian-abuse-reports",
                )
            ).put_item(
                Item=report,
                ConditionExpression="attribute_not_exists(report_id)",
            )
            dynamo.Table(DYNAMODB_INCIDENTS_TABLE).update_item(
                Key={"incident_id": incident_id},
                UpdateExpression=(
                    "SET moderation_status = :flagged, "
                    "last_reported_at = :reported_at"
                ),
                ConditionExpression="attribute_exists(incident_id)",
                ExpressionAttributeValues={
                    ":flagged": "NEEDS_REVIEW",
                    ":reported_at": now.isoformat(),
                },
            )
        except Exception as error:
            raise HTTPException(
                status_code=500,
                detail=f"Could not record moderation report: {type(error).__name__}",
            )
    elif not _dev_mode():
        raise HTTPException(status_code=500, detail="Database unavailable")

    return {
        "status": "REPORT_RECEIVED",
        "report_id": report_id,
    }

@app.post("/incidents/{incident_id}/dispatch-community")
def api_dispatch_community(
    incident_id: str,
    background_tasks: BackgroundTasks,
    request: Request,
):
    from aws.agent.tools import dispatch_community_alert
    try:
        incident = _owned_incident(incident_id, request)
        correlation_id = request.state.correlation_id
        policy = evaluate_safety_policy(
            event_type=str(incident.get("event_type", "")),
            risk_level=str((incident.get("risk_assessment") or {}).get("level", "MEDIUM")),
            incident_state=str(incident.get("state", "")),
            is_isolated=bool((incident.get("location") or {}).get("is_isolated", False)),
            owner_requested=True,
        )
        token = issue_policy_authorizations(
            incident_id=incident_id,
            actions={"dispatch_community_alert"},
            decision=policy.decision,
            correlation_id=correlation_id,
            actor=f"user:{authenticated_user_id(request)}",
            action_constraints={
                "dispatch_community_alert": policy.constraints_for(
                    "dispatch_community_alert"
                )
            },
        )["dispatch_community_alert"]
        result = execute_authorized_tool(
            incident_id=incident_id,
            correlation_id=correlation_id,
            action="dispatch_community_alert",
            token=token,
            tool=dispatch_community_alert,
        )
        return result
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))


# ─────────────────────────────────────────────────────────────────────────────
# RESPONDER / AGENT
# ─────────────────────────────────────────────────────────────────────────────


class ResponderEnrollmentRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")
    id_document_hash: str = Field(min_length=10)
    selfie_hash: str = Field(min_length=10)
    real_name: str = Field(min_length=2)

@app.post("/responders/enroll")
def api_responder_enroll(req: ResponderEnrollmentRequest, request: Request):
    """P0-01: Submit KYC documents for responder enrollment."""
    user_id = authenticated_user_id(request)
    from aws.incident_handler.handler import get_dynamo_resource
    from aws.agent.tools import DYNAMODB_RESPONDERS_TABLE, _dev_mode, _LOCAL_RESPONDERS
    
    record = {
        "responder_id": user_id,
        "name": req.real_name,
        "verification_status": "PENDING_MANUAL_REVIEW",
        "trust_score": 0,
        # These are references/evidence digests only; raw identity documents are
        # intentionally not accepted by this API.
        "id_document_hash": req.id_document_hash,
        "selfie_hash": req.selfie_hash,
        "enrolled_at": datetime.now(timezone.utc).isoformat(),
    }
    
    dynamo = get_dynamo_resource()
    if dynamo:
        table = dynamo.Table(DYNAMODB_RESPONDERS_TABLE)
        table.put_item(Item=record)
    elif _dev_mode():
        _LOCAL_RESPONDERS[user_id] = record
    else:
        raise HTTPException(status_code=500, detail="Database unavailable")
        
    return {"status": "ENROLLMENT_PENDING", "responder_id": user_id}

class ResponderHeartbeatRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    latitude: float = Field(ge=-90, le=90)
    longitude: float = Field(ge=-180, le=180)
    is_active: bool = True


@app.post("/responders/heartbeat")
def api_responder_heartbeat(req: ResponderHeartbeatRequest, request: Request):
    from aws.agent.tools import register_responder_heartbeat
    _require_role(request, "responder")
    responder_id = authenticated_user_id(request)
    res = register_responder_heartbeat(
        responder_id=responder_id,
        latitude=req.latitude,
        longitude=req.longitude,
        is_active=req.is_active,
    )
    return res


@app.get("/responders/invitations")
def api_responder_invitations(request: Request):
    from aws.agent.tools import list_responder_invitations

    _require_role(request, "responder")
    responder_id = authenticated_user_id(request)
    return {"invitations": list_responder_invitations(responder_id)}


@app.get("/responders/missions")
def api_responder_missions(request: Request):
    from aws.agent.tools import list_responder_missions

    _require_role(request, "responder")
    responder_id = authenticated_user_id(request)
    return {"missions": list_responder_missions(responder_id)}


@app.get("/missions/{mission_id}")
def api_get_responder_mission(mission_id: str, request: Request):
    from aws.agent.tools import get_responder_mission

    _require_role(request, "responder")
    try:
        return get_responder_mission(mission_id, authenticated_user_id(request))
    except PermissionError as error:
        raise HTTPException(status_code=403, detail=str(error))


class MissionStatusRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    status: str = Field(min_length=6, max_length=20)


@app.put("/missions/{mission_id}/status")
def api_transition_responder_mission(
    mission_id: str,
    req: MissionStatusRequest,
    request: Request,
):
    from aws.agent.tools import transition_rescue_mission

    _require_role(request, "responder")
    try:
        updated = transition_rescue_mission(
            mission_id,
            authenticated_user_id(request),
            req.status,
        )
        incident_id = str(updated.get("incident_id", ""))
        incident = get_incident(incident_id) if incident_id else None
        if incident and incident.get("user_id"):
            victim_user_id = incident["user_id"]
            if req.status == "EN_ROUTE":
                send_push_to_user(
                    user_id=victim_user_id,
                    title="🚗 Helper En Route",
                    body="A verified Guardian helper is now navigating to your location.",
                    notification_type="rescue_en_route",
                    data={"incident_id": incident_id, "mission_id": mission_id},
                )
            elif req.status == "ARRIVED":
                send_push_to_user(
                    user_id=victim_user_id,
                    title="📍 Helper Arrived",
                    body="A verified Guardian helper has reported arrival at your location.",
                    notification_type="rescue_arrived",
                    data={"incident_id": incident_id, "mission_id": mission_id},
                )
        return updated
    except PermissionError as error:
        raise HTTPException(status_code=403, detail=str(error))
    except ValueError as error:
        raise HTTPException(status_code=409, detail=str(error))


@app.post("/missions/{mission_id}/renew-grant")
def api_renew_mission_grant(mission_id: str, request: Request):
    from aws.agent.tools import renew_mission_navigation_grant

    _require_role(request, "responder")
    responder_id = authenticated_user_id(request)
    try:
        return renew_mission_navigation_grant(mission_id, responder_id)
    except PermissionError as error:
        raise HTTPException(status_code=403, detail=str(error))
    except ValueError as error:
        raise HTTPException(status_code=400, detail=str(error))


@app.post("/incidents/{incident_id}/escalate-dispatch")
def api_escalate_dispatch(incident_id: str, request: Request):
    """Progressively advance escalation stage or evaluate redispatch."""
    _owned_incident(incident_id, request)
    from aws.agent.tools import advance_incident_escalation
    try:
        return advance_incident_escalation(incident_id)
    except Exception as error:
        raise HTTPException(status_code=400, detail=str(error))


@app.get("/incidents/{incident_id}/escalation-status")
def api_get_escalation_status(incident_id: str, request: Request):
    incident = _owned_incident(incident_id, request)
    from aws.agent.tools import _incident_missions
    missions = _incident_missions(incident_id)
    accepted = [m for m in missions if m.get("status") in {"ACCEPTED", "EN_ROUTE", "ARRIVED"}]
    return {
        "incident_id": incident_id,
        "current_stage": incident.get("current_escalation_stage", 1),
        "current_radius_meters": incident.get("current_radius_meters", 1000.0),
        "dispatched_count": len(incident.get("dispatched_responder_ids") or []),
        "accepted_count": len(accepted),
        "escalation_deadline_at": incident.get("escalation_deadline_at"),
    }


@app.post("/incidents/{incident_id}/agent-step")
def api_trigger_agent_step(incident_id: str, request: Request):
    incident = _owned_incident(incident_id, request)
    res = execute_agent_reasoning(
        incident_id,
        correlation_id=request.state.correlation_id,
    )
    if "error" in res:
        raise HTTPException(status_code=404, detail=res["error"])
    return res


@app.post("/incidents/{incident_id}/escalate")
def api_escalate_incident(incident_id: str, request: Request):
    """Owner-requested escalation through independent idempotent policy tools."""
    incident = _owned_incident(incident_id, request)
    from aws.agent.tools import dispatch_community_alert, notify_trusted_contact

    correlation_id = request.state.correlation_id
    policy = evaluate_safety_policy(
        event_type=str(incident.get("event_type", "")),
        risk_level=str((incident.get("risk_assessment") or {}).get("level", "MEDIUM")),
        incident_state=str(incident.get("state", "")),
        is_isolated=bool((incident.get("location") or {}).get("is_isolated", False)),
        owner_requested=True,
    )
    try:
        tokens = issue_policy_authorizations(
            incident_id=incident_id,
            actions=policy.authorized_actions,
            decision=policy.decision,
            correlation_id=correlation_id,
            actor=f"user:{authenticated_user_id(request)}",
            action_constraints={
                action: policy.constraints_for(action)
                for action in policy.authorized_actions
            },
        )
    except PermissionError as error:
        raise HTTPException(status_code=403, detail=str(error))
    except ValueError as error:
        raise HTTPException(status_code=409, detail=str(error))

    # A deliberate "Need help" response resolves any pending verification so
    # the backend timeout cannot perform the same escalation a second time.
    if incident.get("verification_status") == "PENDING":
        now_iso = datetime.now(timezone.utc).isoformat()
        dynamo = get_dynamo_resource()
        if dynamo:
            try:
                dynamo.Table(DYNAMODB_INCIDENTS_TABLE).update_item(
                    Key={"incident_id": incident_id},
                    UpdateExpression=(
                        "SET verification_status = :status, "
                        "verification_completed_at = :now"
                    ),
                    ConditionExpression="verification_status = :pending",
                    ExpressionAttributeValues={
                        ":status": "RESPONDED_HELP",
                        ":pending": "PENDING",
                        ":now": now_iso,
                    },
                )
            except Exception as error:
                code = getattr(error, "response", {}).get("Error", {}).get("Code")
                if code != "ConditionalCheckFailedException":
                    raise
        else:
            incident["verification_status"] = "RESPONDED_HELP"
            incident["verification_completed_at"] = now_iso

    contact_result: Dict[str, Any] = {"status": "NOT_ATTEMPTED"}
    community_result: Dict[str, Any] = {"status": "NOT_ATTEMPTED"}

    try:
        contact_result = execute_authorized_tool(
            incident_id=incident_id,
            correlation_id=correlation_id,
            action="notify_trusted_contact",
            token=tokens["notify_trusted_contact"],
            tool=notify_trusted_contact,
        )
    except Exception as error:
        contact_result = {
            "status": "FAILED",
            "error_type": type(error).__name__,
        }

    try:
        community_result = execute_authorized_tool(
            incident_id=incident_id,
            correlation_id=correlation_id,
            action="dispatch_community_alert",
            token=tokens["dispatch_community_alert"],
            tool=dispatch_community_alert,
        )
    except Exception as error:
        community_result = {
            "status": "FAILED",
            "error_type": type(error).__name__,
        }

    return {
        "incident_id": incident_id,
        "contact_alert": contact_result,
        "community_dispatch": community_result,
    }


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("aws.server:app", host="0.0.0.0", port=8000, reload=True)
