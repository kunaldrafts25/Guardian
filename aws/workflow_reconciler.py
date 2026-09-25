"""Guardian durable workflow reconciliation.

The queue/scheduler transport is not the source of truth. Incident deadlines and
orchestration state in DynamoDB are authoritative. This minute-level sweeper
re-enqueues overdue work and repairs failed incident.created publication without
ever blocking an SOS.
"""

import json
import logging
import os
from datetime import datetime, timezone
from typing import Any, Dict

import boto3

from aws.incident_handler.handler import (
    DYNAMODB_INCIDENTS_TABLE,
    AWS_REGION,
    _emit_incident_created,
)

logger = logging.getLogger("guardian_workflow_reconciler")

TERMINAL_STATES = {"RESOLVED", "CANCELLED", "EXPIRED"}


def _queue_url() -> str:
    return os.environ.get("WORKFLOW_QUEUE_URL", "").strip()


def _enqueue(
    sqs,
    *,
    incident_id: str,
    timeout_type: str,
    deadline_at: int,
    idempotency_key: str,
) -> None:
    now_epoch = int(datetime.now(timezone.utc).timestamp())
    sqs.send_message(
        QueueUrl=_queue_url(),
        MessageBody=json.dumps(
            {
                "detail": {
                    "incident_id": incident_id,
                    "timeout_type": timeout_type,
                    "deadline_at": int(deadline_at),
                    "idempotency_key": idempotency_key,
                    "reconciled": True,
                }
            }
        ),
        DelaySeconds=max(0, min(900, int(deadline_at) - now_epoch)),
    )


def handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    queue_url = _queue_url()
    if not queue_url:
        raise RuntimeError("WORKFLOW_QUEUE_URL is required")

    dynamo = boto3.resource("dynamodb", region_name=AWS_REGION)
    table = dynamo.Table(DYNAMODB_INCIDENTS_TABLE)
    sqs = boto3.client("sqs", region_name=AWS_REGION)
    now_epoch = int(datetime.now(timezone.utc).timestamp())

    scanned = 0
    queued = 0
    orchestration_repairs = 0
    request: Dict[str, Any] = {
        "ProjectionExpression": (
            "incident_id, #state, verification_status, verification_deadline_at, "
            "current_escalation_stage, escalation_deadline_at, "
            "orchestration_event_state, event_id, user_id, event_type, #loc, "
            "initial_sos_location, current_emergency_location, motion_data, "
            "risk_assessment, created_at, updated_at, agent_decision, "
            "agent_execution_state, agent_rationale"
        ),
        "ExpressionAttributeNames": {
            "#state": "state",
            "#loc": "location",
        },
    }

    while True:
        response = table.scan(**request)
        for incident in response.get("Items", []):
            scanned += 1
            incident_id = str(incident.get("incident_id") or "")
            if not incident_id:
                continue
            if str(incident.get("state") or "") in TERMINAL_STATES:
                continue

            if incident.get("orchestration_event_state") != "EMITTED":
                try:
                    _emit_incident_created(incident)
                    orchestration_repairs += 1
                except Exception as error:
                    logger.warning(
                        "Orchestration repair failed for %s: %s",
                        incident_id,
                        type(error).__name__,
                    )

            verification_deadline = int(
                incident.get("verification_deadline_at") or 0
            )
            if (
                incident.get("verification_status") == "PENDING"
                and verification_deadline
                and verification_deadline <= now_epoch
            ):
                _enqueue(
                    sqs,
                    incident_id=incident_id,
                    timeout_type="USER_VERIFICATION",
                    deadline_at=verification_deadline,
                    idempotency_key=f"verification:{verification_deadline}",
                )
                queued += 1

            escalation_deadline = int(
                incident.get("escalation_deadline_at") or 0
            )
            current_stage = int(incident.get("current_escalation_stage") or 0)
            if (
                current_stage > 0
                and escalation_deadline
                and escalation_deadline <= now_epoch
            ):
                _enqueue(
                    sqs,
                    incident_id=incident_id,
                    timeout_type="ESCALATION_CHECK",
                    deadline_at=escalation_deadline,
                    idempotency_key=(
                        f"escalation:{current_stage}:{escalation_deadline}"
                    ),
                )
                queued += 1

        last_key = response.get("LastEvaluatedKey")
        if not last_key:
            break
        request["ExclusiveStartKey"] = last_key

    return {
        "scanned": scanned,
        "queued": queued,
        "orchestration_repairs": orchestration_repairs,
    }
