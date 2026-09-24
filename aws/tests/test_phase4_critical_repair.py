"""Regression tests for Phase 4 critical emergency-orchestration repairs."""

from unittest.mock import patch

from aws.agent import tools
from aws.agent.guardian_agent import (
    _handle_verification_timeout,
    execute_agent_reasoning,
    execute_authorized_tool,
)
from aws.agent.policy_authorization import issue_policy_authorizations
from aws.agent.safety_policy import evaluate_safety_policy
from aws.incident_handler.handler import (
    acquire_agent_lease,
    create_incident,
    finish_agent_run,
    get_incident,
)


def _policy_token(incident_id: str, action: str) -> str:
    constraints = (
        {
            "max_responder_invitations": 6,
            "required_responder_quorum": 1,
            "location_precision_decimals": 2,
        }
        if action == "dispatch_community_alert"
        else {}
    )
    return issue_policy_authorizations(
        incident_id=incident_id,
        actions={action},
        decision="OWNER_REQUESTED_ESCALATION",
        correlation_id=f"repair:{incident_id}:{action}",
        actor="phase4-test",
        action_constraints={action: constraints},
    )[action]


def test_initial_agent_execution_lease_is_separate_from_business_decision():
    incident = create_incident(
        {
            "event_id": "phase4-lease-event",
            "user_id": "phase4-lease-user",
            "event_type": "fall_detected",
        }
    )
    incident_id = incident["incident_id"]
    assert incident["agent_decision"] == "PENDING_REASONING"
    assert incident["agent_execution_state"] == "PENDING"

    assert acquire_agent_lease(incident_id, "run-a") is True
    assert acquire_agent_lease(incident_id, "run-b") is False

    finish_agent_run(incident_id, "run-a", success=True)
    assert get_incident(incident_id)["agent_execution_state"] == "COMPLETED"
    assert acquire_agent_lease(incident_id, "run-c") is False


def test_inferred_sensor_events_require_verification_but_explicit_panic_is_immediate():
    for event_type in ("ANDROID_FALL", "ANDROID_SHAKE", "ROUTE_DEVIATION"):
        policy = evaluate_safety_policy(
            event_type=event_type,
            risk_level="HIGH",
            incident_state="CLOUD_ACCEPTED",
            is_isolated=False,
        )
        assert policy.decision == "REQUEST_USER_VERIFICATION"
        assert not policy.authorized_actions

    panic = evaluate_safety_policy(
        event_type="ANDROID_POWER_GESTURE",
        risk_level="LOW",
        incident_state="CLOUD_ACCEPTED",
        is_isolated=False,
    )
    assert panic.decision == "ESCALATE_IMMEDIATELY_WITH_COMMUNITY"
    assert panic.authorized_actions == {
        "notify_trusted_contact",
        "dispatch_community_alert",
    }

    for confirmed_route_event in (
        "ROUTE_DEVIATION_TIMEOUT",
        "ROUTE_DEVIATION_USER_SOS",
    ):
        confirmed = evaluate_safety_policy(
            event_type=confirmed_route_event,
            risk_level="LOW",
            incident_state="CLOUD_ACCEPTED",
            is_isolated=False,
        )
        assert confirmed.decision == "ESCALATE_IMMEDIATELY_WITH_COMMUNITY"


def test_dispatch_starts_stage_one_and_replay_does_not_restart_it():
    incident = create_incident(
        {
            "event_id": "phase4-stage1-event",
            "user_id": "phase4-stage1-user",
            "event_type": "hardware_power_panic",
            "location": {"latitude": 19.0760, "longitude": 72.8777},
        }
    )
    incident_id = incident["incident_id"]

    first = tools.dispatch_community_alert(
        incident_id,
        _policy_token(incident_id, "dispatch_community_alert"),
    )
    assert first["status"] == "INVITATIONS_CREATED"
    assert first["stage"] == 1
    assert first["radius_meters"] == 1000.0
    assert first["invite_count"] >= 1
    assert get_incident(incident_id)["current_escalation_stage"] == 1

    replay = tools.dispatch_community_alert(
        incident_id,
        _policy_token(incident_id, "dispatch_community_alert"),
    )
    assert replay["status"] == "ALREADY_DISPATCHED"
    assert get_incident(incident_id)["current_escalation_stage"] == 1


def test_redispatch_advances_to_next_stage_when_no_reachable_invitation_remains():
    tools._LOCAL_RESPONDERS.clear()
    center_lat, center_lng = 19.0760, 72.8777
    now_expiry = 2_000_000_000
    tools._LOCAL_RESPONDERS["stage1"] = {
        "responder_id": "stage1",
        "name": "Stage 1",
        "latitude": center_lat + 0.004,
        "longitude": center_lng,
        "trust_score": 90,
        "verification_status": "APPROVED",
        "is_active": True,
        "availability_expires_at": now_expiry,
        "geohash": tools._encode_geohash(center_lat + 0.004, center_lng, precision=5),
    }
    tools._LOCAL_RESPONDERS["stage2"] = {
        "responder_id": "stage2",
        "name": "Stage 2",
        "latitude": center_lat + 0.014,
        "longitude": center_lng,
        "trust_score": 90,
        "verification_status": "APPROVED",
        "is_active": True,
        "availability_expires_at": now_expiry,
        "geohash": tools._encode_geohash(center_lat + 0.014, center_lng, precision=5),
    }

    incident = create_incident(
        {
            "event_id": "phase4-redispatch-event",
            "user_id": "phase4-redispatch-user",
            "event_type": "hardware_power_panic",
            "location": {"latitude": center_lat, "longitude": center_lng},
        }
    )
    incident_id = incident["incident_id"]
    first = tools.dispatch_community_alert(
        incident_id,
        _policy_token(incident_id, "dispatch_community_alert"),
    )
    assert first["stage"] == 1

    # Dev transport is intentionally not delivered, so it is not a reachable
    # live invitation and the deterministic evaluator may widen immediately.
    second = tools.process_incident_redispatch_eval(incident_id)
    assert second["stage"] == 2
    assert get_incident(incident_id)["current_escalation_stage"] == 2


def test_verification_timeout_is_idempotent_and_escalates_without_flutter():
    incident = create_incident(
        {
            "event_id": "phase4-verification-event",
            "user_id": "phase4-verification-user",
            "event_type": "fall_detected",
            "location": {"latitude": 19.0760, "longitude": 72.8777},
            "motion_data": {"g_force": 4.2},
            "contacts": [
                {
                    "id": "phase4-contact",
                    "name": "Trusted",
                    "phone": "+919000000001",
                    "authorized": True,
                }
            ],
        }
    )
    incident_id = incident["incident_id"]
    initial = execute_agent_reasoning(incident_id, correlation_id="initial-run")
    assert initial["decision"] == "REQUEST_USER_VERIFICATION"
    assert get_incident(incident_id)["verification_status"] == "PENDING"

    timeout = _handle_verification_timeout(incident_id, "timeout-run")
    assert timeout["status"] == "VERIFICATION_TIMEOUT_ESCALATED"
    assert timeout["community_dispatch"]["status"] == "INVITATIONS_CREATED"

    duplicate = _handle_verification_timeout(incident_id, "timeout-run-duplicate")
    assert duplicate["status"].startswith("VERIFICATION_TIMEOUT_NOOP")


def test_contact_provider_failure_does_not_block_responder_dispatch():
    incident = create_incident(
        {
            "event_id": "phase4-independent-actions",
            "user_id": "phase4-independent-user",
            "event_type": "hardware_power_panic",
            "location": {"latitude": 19.0760, "longitude": 72.8777},
            "contacts": [
                {
                    "id": "phase4-contact-failure",
                    "name": "Trusted",
                    "phone": "+919000000002",
                    "authorized": True,
                }
            ],
        }
    )
    with patch(
        "aws.agent.guardian_agent.notify_trusted_contact",
        side_effect=RuntimeError("sms provider unavailable"),
    ):
        result = execute_agent_reasoning(
            incident["incident_id"],
            correlation_id="independent-actions-run",
        )

    assert result["action_result"]["contact_alert"]["status"] == "FAILED"
    assert result["action_result"]["community_dispatch"]["status"] == "INVITATIONS_CREATED"


def test_per_recipient_local_sms_acceptance_only_skips_that_contact():
    incident = create_incident(
        {
            "event_id": "phase4-per-recipient-sms",
            "user_id": "phase4-sms-user",
            "event_type": "hardware_power_panic",
            "location": {"latitude": 19.0760, "longitude": 72.8777},
            "motion_data": {
                "local_sms_delivery": [
                    {"contact_id": "local-ok", "state": "OS_ACCEPTED"},
                    {"contact_id": "needs-cloud", "state": "FAILED"},
                ]
            },
            "contacts": [
                {
                    "id": "local-ok",
                    "name": "Local Contact",
                    "phone": "+919000000003",
                    "authorized": True,
                },
                {
                    "id": "needs-cloud",
                    "name": "Cloud Contact",
                    "phone": "+919000000004",
                    "authorized": True,
                },
            ],
        }
    )
    result = tools.notify_trusted_contact(
        incident["incident_id"],
        _policy_token(incident["incident_id"], "notify_trusted_contact"),
    )
    assert result["contacts_skipped_native"] == ["Local Contact"]
    assert result["contacts_notified_cloud"] == ["Cloud Contact"]


def test_action_execution_lease_suppresses_concurrent_duplicate_side_effect():
    incident = create_incident(
        {
            "event_id": "phase4-action-lease",
            "user_id": "phase4-action-user",
            "event_type": "hardware_power_panic",
        }
    )
    incident_id = incident["incident_id"]
    calls = []

    def fake_tool(iid, token):
        calls.append((iid, token))
        return {"status": "PROVIDER_ACCEPTED"}

    first = execute_authorized_tool(
        incident_id=incident_id,
        correlation_id="action-run-a",
        action="notify_trusted_contact",
        token=_policy_token(incident_id, "notify_trusted_contact"),
        tool=fake_tool,
    )
    second = execute_authorized_tool(
        incident_id=incident_id,
        correlation_id="action-run-b",
        action="notify_trusted_contact",
        token=_policy_token(incident_id, "notify_trusted_contact"),
        tool=fake_tool,
    )

    assert first["status"] == "PROVIDER_ACCEPTED"
    assert second["status"] == "ALREADY_PROCESSED_OR_RUNNING"
    assert len(calls) == 1
