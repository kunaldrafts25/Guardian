"""
Guardian AWS Backend Server (FastAPI / Serverless Local Runner)
v3.0 — Full AWS-Only Stack: Cognito Auth + DynamoDB + SNS Push + Bedrock AI

Mirrors real AWS API Gateway + Lambda endpoints:
  POST   /auth/send-otp              → Cognito: send phone OTP
  POST   /auth/verify-otp            → Cognito: verify OTP, get JWT tokens
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
  POST   /push/sos-broadcast         → SNS: broadcast SOS to all community

  POST   /responders/heartbeat       → Update responder location
  POST   /simulate/{scenario}        → Demo mode: trigger test incident
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

from fastapi import FastAPI, HTTPException, BackgroundTasks, Header
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
from typing import Dict, Any, Optional, List
import uuid

from aws.incident_handler.handler import (
    create_incident,
    update_incident_status,
    get_incident,
    get_incident_timeline,
    IncidentState,
)
from aws.agent.guardian_agent import execute_agent_reasoning

# AWS Services
from aws.cognito_service import (
    initiate_phone_auth,
    verify_otp,
    refresh_tokens,
    sign_out,
    update_user_profile,
    get_user_profile,
    save_fcm_token,
)
from aws.sns_push_service import (
    register_device_endpoint,
    send_push_to_user,
    send_sms_alert,
    send_community_sos_broadcast,
    send_emergency_contact_alerts,
)

app = FastAPI(
    title="Guardian AWS Agentic Backend",
    description="Full AWS-Only: Cognito Auth + DynamoDB + SNS Push + Amazon Bedrock AI",
    version="3.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ─────────────────────────────────────────────────────────────────────────────
# HEALTH CHECK
# ─────────────────────────────────────────────────────────────────────────────

@app.get("/")
def health_check():
    import boto3
    aws_configured = bool(os.environ.get("AWS_ACCESS_KEY_ID") or os.environ.get("AWS_PROFILE"))
    cognito_configured = bool(os.environ.get("COGNITO_USER_POOL_ID"))
    sns_configured = bool(os.environ.get("SNS_SOS_TOPIC_ARN"))
    return {
        "status": "online",
        "service": "Guardian AWS Full-Stack API",
        "version": "3.0.0",
        "aws_region": os.environ.get("AWS_DEFAULT_REGION", "ap-south-1"),
        "services": {
            "auth": "AWS Cognito" if cognito_configured else "Dev Mode (Cognito not configured)",
            "database": "AWS DynamoDB" if aws_configured else "In-Memory (Dev)",
            "push": "AWS SNS" if sns_configured else "Dev Mode (SNS not configured)",
            "ai": "Amazon Bedrock Claude" if aws_configured else "Hybrid Fallback Engine",
        },
        "model": os.environ.get("BEDROCK_MODEL_ID", "anthropic.claude-3-haiku-20240307-v1:0"),
    }


# ─────────────────────────────────────────────────────────────────────────────
# AUTH ENDPOINTS (AWS Cognito)
# ─────────────────────────────────────────────────────────────────────────────

class SendOtpRequest(BaseModel):
    phone_number: str


class VerifyOtpRequest(BaseModel):
    phone_number: str
    otp_code: str
    session: str


class RefreshTokenRequest(BaseModel):
    refresh_token: str
    user_id: str


class SignOutRequest(BaseModel):
    access_token: str


@app.post("/auth/send-otp")
def api_send_otp(req: SendOtpRequest):
    """Initiate phone number authentication — sends SMS OTP via Cognito."""
    try:
        result = initiate_phone_auth(req.phone_number)
        return result
    except ValueError as ve:
        raise HTTPException(status_code=400, detail=str(ve))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"OTP dispatch failed: {str(e)}")


@app.post("/auth/verify-otp")
def api_verify_otp(req: VerifyOtpRequest):
    """Verify SMS OTP and return JWT tokens (access + id + refresh)."""
    try:
        result = verify_otp(req.phone_number, req.otp_code, req.session)
        return result
    except ValueError as ve:
        raise HTTPException(status_code=401, detail=str(ve))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"OTP verification failed: {str(e)}")


@app.post("/auth/refresh")
def api_refresh_token(req: RefreshTokenRequest):
    """Refresh expired JWT access/id tokens."""
    try:
        result = refresh_tokens(req.refresh_token, req.user_id)
        return result
    except ValueError as ve:
        raise HTTPException(status_code=401, detail=str(ve))


@app.post("/auth/sign-out")
def api_sign_out(req: SignOutRequest):
    """Revoke all tokens — global sign out from Cognito."""
    result = sign_out(req.access_token)
    return result


# ─────────────────────────────────────────────────────────────────────────────
# USER PROFILE ENDPOINTS (DynamoDB)
# ─────────────────────────────────────────────────────────────────────────────

class UpdateProfileRequest(BaseModel):
    display_name: Optional[str] = None
    photo_url: Optional[str] = None
    emergency_contacts: Optional[List[Dict[str, Any]]] = None
    safe_zones: Optional[List[Dict[str, Any]]] = None
    guardian_circle: Optional[List[str]] = None
    settings: Optional[Dict[str, Any]] = None


class RegisterDeviceRequest(BaseModel):
    device_token: str
    platform: str = "android"  # "android" | "ios"


class SaveContactsRequest(BaseModel):
    contacts: List[Dict[str, Any]]


@app.get("/users/{user_id}")
def api_get_user(user_id: str):
    """Fetch user profile from DynamoDB."""
    profile = get_user_profile(user_id)
    if not profile:
        raise HTTPException(status_code=404, detail="User not found")
    return profile


@app.put("/users/{user_id}")
def api_update_user(user_id: str, req: UpdateProfileRequest):
    """Update user profile fields in DynamoDB."""
    data = {k: v for k, v in req.model_dump().items() if v is not None}
    result = update_user_profile(user_id, data)
    return result


@app.post("/users/{user_id}/device")
def api_register_device(user_id: str, req: RegisterDeviceRequest):
    """Register device push token with AWS SNS — returns endpoint ARN."""
    result = register_device_endpoint(user_id, req.device_token, req.platform)
    # Also save token for reference
    save_fcm_token(user_id, req.device_token)
    return result


@app.post("/users/{user_id}/contacts")
def api_save_contacts(user_id: str, req: SaveContactsRequest):
    """Save emergency contacts to DynamoDB user profile."""
    result = update_user_profile(user_id, {"emergency_contacts": req.contacts})
    return result


# ─────────────────────────────────────────────────────────────────────────────
# PUSH NOTIFICATION ENDPOINTS (AWS SNS)
# ─────────────────────────────────────────────────────────────────────────────

class PushRequest(BaseModel):
    user_id: str
    title: str
    body: str
    data: Optional[Dict[str, str]] = None
    notification_type: str = "general"


class SmsRequest(BaseModel):
    phone_number: str
    message: str
    sender_id: str = "GUARDIAN"


class SosBroadcastRequest(BaseModel):
    incident_id: str
    latitude: float
    longitude: float
    message: Optional[str] = None


@app.post("/push/send")
def api_send_push(req: PushRequest):
    """Send targeted push notification to a user via SNS."""
    result = send_push_to_user(
        user_id=req.user_id,
        title=req.title,
        body=req.body,
        data=req.data,
        notification_type=req.notification_type,
    )
    return result


@app.post("/push/sms")
def api_send_sms(req: SmsRequest):
    """Send SMS to a phone number via AWS SNS."""
    result = send_sms_alert(req.phone_number, req.message, req.sender_id)
    return result


@app.post("/push/sos-broadcast")
def api_sos_broadcast(req: SosBroadcastRequest):
    """Broadcast SOS alert to all community members via SNS Topic."""
    result = send_community_sos_broadcast(
        incident_id=req.incident_id,
        victim_location={"latitude": req.latitude, "longitude": req.longitude},
        message=req.message or "⚡ Guardian SOS: Someone nearby needs urgent help!",
    )
    return result


# ─────────────────────────────────────────────────────────────────────────────
# INCIDENT MANAGEMENT (DynamoDB + Bedrock AI)
# ─────────────────────────────────────────────────────────────────────────────

class IncidentCreateRequest(BaseModel):
    event_id: Optional[str] = None
    user_id: Optional[str] = "guardian_user_1"
    event_type: str = "fall_detected"
    location: Optional[Dict[str, Any]] = None
    motion_data: Optional[Dict[str, Any]] = None


class IncidentStatusUpdateRequest(BaseModel):
    state: str
    actor: Optional[str] = "USER"
    note: Optional[str] = ""


@app.post("/incidents", status_code=201)
def api_create_incident(req: IncidentCreateRequest, background_tasks: BackgroundTasks):
    """Create incident and trigger Bedrock AI evaluation."""
    payload = req.model_dump()
    if not payload.get("event_id"):
        payload["event_id"] = str(uuid.uuid4())

    incident = create_incident(payload)
    iid = incident["incident_id"]

    # Trigger autonomous AI agent evaluation in background
    background_tasks.add_task(execute_agent_reasoning, iid)
    
    # Auto-alert emergency contacts for critical events
    if req.event_type in ("sos_button", "hardware_power_panic", "crash_detected"):
        background_tasks.add_task(
            send_emergency_contact_alerts,
            req.user_id,
            iid,
            req.location or {},
        )
    
    return incident


@app.get("/incidents/{incident_id}")
def api_get_incident(incident_id: str):
    inc = get_incident(incident_id)
    if not inc:
        raise HTTPException(status_code=404, detail="Incident not found")
    return inc


@app.put("/incidents/{incident_id}/status")
def api_update_incident_status(incident_id: str, req: IncidentStatusUpdateRequest):
    try:
        updated = update_incident_status(
            incident_id=incident_id,
            new_state=req.state,
            actor=req.actor or "USER",
            note=req.note or "",
        )
        return updated
    except ValueError as ve:
        raise HTTPException(status_code=400, detail=str(ve))


@app.get("/incidents/{incident_id}/timeline")
def api_get_incident_timeline(incident_id: str):
    timeline = get_incident_timeline(incident_id)
    return {"incident_id": incident_id, "timeline": timeline}


@app.get("/incidents/{incident_id}/nearby")
def api_get_nearby_responders(incident_id: str, radius_meters: float = 1200.0):
    from aws.agent.tools import find_nearby_responders
    responders = find_nearby_responders(incident_id, radius_meters=radius_meters)
    return {"incident_id": incident_id, "nearby_responders": responders}


@app.post("/incidents/{incident_id}/accept")
def api_accept_mission(incident_id: str, req: Dict[str, Any]):
    from aws.agent.tools import accept_rescue_mission
    responder_id = req.get("responder_id", "resp_01")
    try:
        result = accept_rescue_mission(incident_id, responder_id)
        
        # Notify victim that help is coming via push/SMS
        incident = get_incident(incident_id)
        if incident:
            background_push = send_push_to_user(
                user_id=incident.get("user_id", ""),
                title="✅ Help is on the way!",
                body="A verified Guardian helper has accepted your SOS and is navigating to you.",
                notification_type="rescue_accepted",
                data={"incident_id": incident_id, "responder_id": responder_id},
            )
        return result
    except PermissionError as pe:
        raise HTTPException(status_code=403, detail=str(pe))
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))


@app.post("/incidents/{incident_id}/dispatch-community")
def api_dispatch_community(incident_id: str, background_tasks: BackgroundTasks):
    from aws.agent.tools import dispatch_community_alert
    try:
        result = dispatch_community_alert(incident_id)
        
        # Also broadcast via SNS to community topic
        incident = get_incident(incident_id)
        if incident:
            location = incident.get("location", {})
            background_tasks.add_task(
                send_community_sos_broadcast,
                incident_id,
                location,
            )
        return result
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))


# ─────────────────────────────────────────────────────────────────────────────
# RESPONDER / AGENT
# ─────────────────────────────────────────────────────────────────────────────

class ResponderHeartbeatRequest(BaseModel):
    responder_id: str
    name: str = "Good Samaritan"
    latitude: float = 19.0760
    longitude: float = 72.8777
    trust_score: int = 80
    is_active: bool = True


@app.post("/responders/heartbeat")
def api_responder_heartbeat(req: ResponderHeartbeatRequest):
    from aws.agent.tools import register_responder_heartbeat
    res = register_responder_heartbeat(
        responder_id=req.responder_id,
        name=req.name,
        latitude=req.latitude,
        longitude=req.longitude,
        trust_score=req.trust_score,
        is_active=req.is_active,
    )
    return res


@app.post("/incidents/{incident_id}/agent-step")
def api_trigger_agent_step(incident_id: str):
    res = execute_agent_reasoning(incident_id)
    if "error" in res:
        raise HTTPException(status_code=404, detail=res["error"])
    return res


# ─────────────────────────────────────────────────────────────────────────────
# DEMO SIMULATOR
# ─────────────────────────────────────────────────────────────────────────────

@app.post("/simulate/{scenario}")
def api_simulate_scenario(scenario: str, background_tasks: BackgroundTasks):
    """
    Demo Simulator — triggers realistic test incidents.
    scenario: 'fall' | 'sos' | 'inactivity' | 'hardware_panic'
    """
    scenarios = {
        "fall": {
            "event_type": "fall_detected",
            "motion_data": {"g_force": 4.8, "stationary_seconds": 15},
            "location": {"latitude": 19.0760, "longitude": 72.8777, "is_isolated": True},
        },
        "sos": {
            "event_type": "sos_button",
            "motion_data": {"g_force": 1.2},
            "location": {"latitude": 19.0760, "longitude": 72.8777},
        },
        "inactivity": {
            "event_type": "prolonged_inactivity",
            "motion_data": {"stationary_seconds": 120},
            "location": {"latitude": 19.0760, "longitude": 72.8777, "is_isolated": True},
        },
        "hardware_panic": {
            "event_type": "hardware_power_panic",
            "motion_data": {"tap_count": 3, "interval_ms": 1850},
            "location": {"latitude": 19.0760, "longitude": 72.8777, "is_isolated": True},
        },
    }

    sc = scenarios.get(scenario.lower())
    if not sc:
        raise HTTPException(
            status_code=400,
            detail=f"Unknown scenario '{scenario}'. Available: {list(scenarios.keys())}"
        )

    payload = {
        "event_id": f"sim_{scenario}_{uuid.uuid4().hex[:6]}",
        "user_id": "demo_user",
        **sc,
    }

    incident = create_incident(payload)
    iid = incident["incident_id"]
    background_tasks.add_task(execute_agent_reasoning, iid)
    return {
        "scenario": scenario,
        "message": f"Simulated '{scenario}' incident initiated successfully.",
        "incident": incident,
    }


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("aws.server:app", host="0.0.0.0", port=8000, reload=True)
