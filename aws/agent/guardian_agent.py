"""
Guardian Autonomous Agent (Amazon Bedrock / Claude Haiku + Strands Pattern)
Observes incoming incident telemetry, gathers context, assesses risk via Bedrock LLM / deterministic engine,
decides whether to verify with the user or immediately escalate, and dispatches trusted contact alerts.
"""

import os
import sys
import json
import logging
from typing import Dict, Any, Optional
from datetime import datetime, timezone
from pathlib import Path

# Load .env if present
try:
    from dotenv import load_dotenv
    env_path = Path(__file__).resolve().parent.parent / ".env"
    if env_path.exists():
        load_dotenv(dotenv_path=env_path)
    else:
        load_dotenv()
except ImportError:
    pass

from aws.agent.tools import (
    get_incident_context,
    assess_risk,
    ask_user_confirmation,
    notify_trusted_contact,
    dispatch_community_alert,
)
from aws.incident_handler.handler import (
    get_incident,
    update_incident_status,
    IncidentState,
    AWS_REGION,
)

logger = logging.getLogger("guardian_agent")

try:
    import boto3
    from botocore.exceptions import BotoCoreError, ClientError
    BOTO3_AVAILABLE = True
except ImportError:
    BOTO3_AVAILABLE = False

BEDROCK_MODEL_ID = os.environ.get("BEDROCK_MODEL_ID", "anthropic.claude-3-haiku-20240307-v1:0")

SYSTEM_PROMPT = """You are the Guardian Autonomous Emergency Response Agent.
Your responsibility is personal safety monitoring and rapid, accountable escalation.
When an incident is detected:
1. Review the gathered telemetry context (motion, location, time, sensor readings).
2. Evaluate the risk factors and composite threat level.
3. Determine the immediate appropriate action:
   - For CRITICAL risk, hardware panic (power button 3-tap), or direct SOS: ESCALATE_IMMEDIATELY_WITH_COMMUNITY.
   - For HIGH or elevated risk: REQUEST_USER_VERIFICATION with a 15-second countdown.
   - For LOW risk: MONITOR_NORMAL.

Output must be strict JSON matching this schema:
{
  "threat_level": "CRITICAL" | "HIGH" | "MEDIUM" | "LOW",
  "confidence_score": 0.0 to 1.0,
  "decision": "ESCALATE_IMMEDIATELY_WITH_COMMUNITY" | "REQUEST_USER_VERIFICATION" | "MONITOR_NORMAL",
  "rationale": "<concise 2-sentence rationale explaining the reasoning>"
}
"""


def _query_bedrock_llm(context: Dict[str, Any], risk_info: Dict[str, Any]) -> Optional[Dict[str, Any]]:
    """
    Invokes real Amazon Bedrock LLM via boto3 Bedrock Runtime Converse API.
    Returns parsed structured JSON decision or None if AWS is not configured.
    """
    if not BOTO3_AVAILABLE:
        return None

    # Check for credentials
    has_keys = bool(os.environ.get("AWS_ACCESS_KEY_ID") or os.environ.get("AWS_PROFILE"))
    if not has_keys and not os.environ.get("AWS_EXECUTION_ENV"):
        return None

    try:
        region = os.environ.get("AWS_DEFAULT_REGION") or os.environ.get("AWS_REGION") or "us-east-1"
        client = boto3.client("bedrock-runtime", region_name=region)

        user_message = (
            f"Analyze this incident telemetry:\n"
            f"Event Type: {context.get('event_type')}\n"
            f"Location: {json.dumps(context.get('location'))}\n"
            f"Motion Sensors: {json.dumps(context.get('motion_data'))}\n"
            f"Baseline Risk Assessment: Level={risk_info.get('level')}, Score={risk_info.get('score')}, Reasons={risk_info.get('reasons')}\n\n"
            f"Provide your autonomous reasoning and decision in strict JSON."
        )

        response = client.converse(
            modelId=BEDROCK_MODEL_ID,
            system=[{"text": SYSTEM_PROMPT}],
            messages=[
                {"role": "user", "content": [{"text": user_message}]}
            ],
            inferenceConfig={"temperature": 0.1, "maxTokens": 400},
        )

        output_text = response["output"]["message"]["content"][0]["text"].strip()
        
        # Extract JSON from output
        json_start = output_text.find("{")
        json_end = output_text.rfind("}")
        if json_start != -1 and json_end != -1:
            parsed = json.loads(output_text[json_start : json_end + 1])
            parsed["provider"] = f"Amazon Bedrock ({BEDROCK_MODEL_ID})"
            return parsed

    except Exception as e:
        logger.warning(f"Live Bedrock invocation failed or unconfigured, using hybrid fallback: {e}")

    return None


def execute_agent_reasoning(incident_id: str) -> Dict[str, Any]:
    """
    Core agentic loop: Observe -> Gather Context -> Assess Risk -> Bedrock LLM Reasoning -> Act -> Document.
    """
    # 1. Gather Context
    context = get_incident_context(incident_id)
    if "error" in context:
        return {"error": context["error"]}

    # 2. Baseline Deterministic Risk Assessment
    risk_info = assess_risk(incident_id, context)["risk_assessment"]
    risk_level = risk_info.get("level", "MEDIUM")
    risk_score = risk_info.get("score", 0.5)
    reasons = risk_info.get("reasons", [])

    # 3. Live Amazon Bedrock LLM Reasoning (with resilient fallback)
    bedrock_result = _query_bedrock_llm(context, risk_info)

    provider_name = "Amazon Bedrock (Live)" if bedrock_result else "AWS Hybrid Resilient Engine"
    
    if bedrock_result and "decision" in bedrock_result:
        decision = bedrock_result["decision"]
        rationale = f"[Amazon Bedrock] {bedrock_result.get('rationale', '')}"
        risk_level = bedrock_result.get("threat_level", risk_level)
        risk_score = float(bedrock_result.get("confidence_score", risk_score))
    else:
        # Resilient deterministic reasoning
        if (
            risk_level == "CRITICAL"
            or "power" in str(context.get("event_type", "")).lower()
            or "hardware" in str(context.get("event_type", "")).lower()
            or context.get("event_type") in ("sos_button", "crash_detected")
        ):
            decision = "ESCALATE_IMMEDIATELY_WITH_COMMUNITY"
            rationale = (
                f"Observed critical emergency condition ({context.get('event_type')}) with risk score {risk_score}. "
                f"Escalated immediately. Alert sent to trusted contact and dispatched to nearby verified community responders."
            )
        elif risk_level in ("HIGH", "MEDIUM"):
            decision = "REQUEST_USER_VERIFICATION"
            rationale = (
                f"Observed elevated risk ({risk_level}, score: {risk_score}) due to: {', '.join(reasons)}. "
                f"Prompting user confirmation with a 15s timeout before notifying contacts and community."
            )
        else:
            decision = "MONITOR_NORMAL"
            rationale = f"Low risk score ({risk_score}). Telemetry within acceptable threshold. Continuing passive monitoring."

    # 4. Act according to decision
    action_result = {}
    if decision == "ESCALATE_IMMEDIATELY_WITH_COMMUNITY":
        contact_res = notify_trusted_contact(incident_id)
        community_res = dispatch_community_alert(incident_id)
        action_result = {
            "contact_alert": contact_res,
            "community_dispatch": community_res,
        }
    elif decision == "REQUEST_USER_VERIFICATION":
        action_result = ask_user_confirmation(incident_id, timeout_seconds=15)

    # 5. Document & Persist
    incident = get_incident(incident_id)
    if incident:
        incident["agent_decision"] = decision
        incident["agent_rationale"] = rationale
        incident["agent_provider"] = provider_name
        incident["risk_level"] = risk_level
        incident["risk_score"] = risk_score

        if BOTO3_AVAILABLE and os.environ.get("AWS_EXECUTION_ENV"):
            try:
                dynamo = boto3.resource("dynamodb", region_name=AWS_REGION)
                table = dynamo.Table(os.environ.get("DYNAMODB_INCIDENTS_TABLE", "guardian-incidents"))
                table.update_item(
                    Key={"incident_id": incident_id},
                    UpdateExpression="SET agent_decision = :d, agent_rationale = :r, agent_provider = :p",
                    ExpressionAttributeValues={":d": decision, ":r": rationale, ":p": provider_name},
                )
            except Exception as dyn_err:
                logger.warning(f"DynamoDB sync skipped: {dyn_err}")

    return {
        "incident_id": incident_id,
        "provider": provider_name,
        "risk_assessment": {
            **risk_info,
            "level": risk_level,
            "score": risk_score,
        },
        "decision": decision,
        "rationale": rationale,
        "action_result": action_result,
    }


def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    detail = event.get("detail", {})
    incident_id = detail.get("incident_id") or event.get("incident_id")
    if not incident_id:
        return {"statusCode": 400, "error": "incident_id missing in event"}

    result = execute_agent_reasoning(incident_id)
    return {
        "statusCode": 200,
        "body": result,
    }
