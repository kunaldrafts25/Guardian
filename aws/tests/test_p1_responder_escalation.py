"""
Unit and Integration Tests for Guardian P1 Emergency Response Architecture
Validates:
- Responder heartbeat lifecycle & expiration invariant
- Geospatial multi-radius candidate discovery (1km, 2km, 5km, 10km) & Haversine filtering
- Deterministic progressive escalation ladder (1 -> 2 -> 5 -> 10 km)
- Duplicate responder prevention across stages
- Pause on acceptance, redispatch on withdrawal / expiry
- Terminal incident revocation (cancellation & resolution)
- Navigation grant secure renewal lifecycle across durations (>15m, 30m, 1h)
- Multi-responder capacity invariants
- Rate-aware fake-SOS abuse detection without dropping emergencies
"""

import os
os.environ["GUARDIAN_DEV_MODE"] = "true"

import pytest
import time
from datetime import datetime, timezone

from aws.agent import tools
from aws.agent.escalation_policy import (
    get_escalation_stage,
    is_max_stage,
    MAX_ACCEPTED_RESPONDERS,
)
from aws.incident_handler.handler import (
    create_incident,
    update_incident_status,
    get_incident,
    get_incident_timeline,
    IncidentState,
    _LOCAL_INCIDENTS,
)


def _seed_responder(responder_id: str, lat: float, lng: float, trust: int = 90, active: bool = True, expires_in: int = 300):
    now_epoch = int(datetime.now(timezone.utc).timestamp())
    record = {
        "responder_id": responder_id,
        "name": f"Responder {responder_id}",
        "latitude": lat,
        "longitude": lng,
        "trust_score": trust,
        "verification_status": "APPROVED",
        "is_active": active,
        "availability_expires_at": now_epoch + expires_in,
        "geohash": tools._encode_geohash(lat, lng, precision=5),
    }
    tools._LOCAL_RESPONDERS[responder_id] = record
    return record


class TestResponderHeartbeatAndGeospatial:
    def test_responder_heartbeat_lifecycle_and_expiry(self):
        # Register fresh heartbeat
        _seed_responder("h_resp_1", 19.0760, 72.8777, expires_in=300)
        
        inc = create_incident({
            "event_id": "evt_hb_1",
            "user_id": "usr_hb_1",
            "location": {"latitude": 19.0760, "longitude": 72.8777},
        })
        
        # Eligible when fresh
        responders = tools.find_nearby_responders(inc["incident_id"], radius_meters=1000.0)
        resp_ids = [r["responder_id"] for r in responders]
        assert "h_resp_1" in resp_ids

        # Immediately ineligible when deactivated
        tools._LOCAL_RESPONDERS["h_resp_1"]["is_active"] = False
        responders_inactive = tools.find_nearby_responders(inc["incident_id"], radius_meters=1000.0)
        assert "h_resp_1" not in [r["responder_id"] for r in responders_inactive]

        # Ineligible when expired (stale heartbeat)
        tools._LOCAL_RESPONDERS["h_resp_1"]["is_active"] = True
        tools._LOCAL_RESPONDERS["h_resp_1"]["availability_expires_at"] = int(time.time()) - 10
        responders_expired = tools.find_nearby_responders(inc["incident_id"], radius_meters=1000.0)
        assert "h_resp_1" not in [r["responder_id"] for r in responders_expired]

    def test_geospatial_radius_coverage_1km_2km_5km_10km(self):
        # Center: Mumbai BKC (19.0657, 72.8680)
        center_lat, center_lng = 19.0657, 72.8680
        inc = create_incident({
            "event_id": "evt_geo_multi",
            "user_id": "usr_geo_1",
            "location": {"latitude": center_lat, "longitude": center_lng},
        })

        # Coordinates placed at exact known distances:
        # ~800m north: lat + 0.0072
        _seed_responder("resp_800m", center_lat + 0.0072, center_lng)
        # ~1.8km east: lng + 0.017
        _seed_responder("resp_1800m", center_lat, center_lng + 0.017)
        # ~4.5km south: lat - 0.040
        _seed_responder("resp_4500m", center_lat - 0.040, center_lng)
        # ~9.2km west: lng - 0.087
        _seed_responder("resp_9200m", center_lat, center_lng - 0.087)
        # ~12.5km (outside 10km): lat + 0.112
        _seed_responder("resp_12500m", center_lat + 0.112, center_lng)

        # 1 km search
        r_1km = [r["responder_id"] for r in tools.find_nearby_responders(inc["incident_id"], radius_meters=1000.0)]
        assert "resp_800m" in r_1km
        assert "resp_1800m" not in r_1km
        assert "resp_4500m" not in r_1km
        assert "resp_9200m" not in r_1km

        # 2 km search
        r_2km = [r["responder_id"] for r in tools.find_nearby_responders(inc["incident_id"], radius_meters=2000.0)]
        assert "resp_800m" in r_2km
        assert "resp_1800m" in r_2km
        assert "resp_4500m" not in r_2km

        # 5 km search
        r_5km = [r["responder_id"] for r in tools.find_nearby_responders(inc["incident_id"], radius_meters=5000.0)]
        assert "resp_800m" in r_5km
        assert "resp_1800m" in r_5km
        assert "resp_4500m" in r_5km
        assert "resp_9200m" not in r_5km

        # 10 km search: MUST find resp_9200m (~9.2 km) and MUST EXCLUDE resp_12500m (~12.5 km)
        r_10km = [r["responder_id"] for r in tools.find_nearby_responders(inc["incident_id"], radius_meters=10000.0)]
        assert "resp_800m" in r_10km
        assert "resp_1800m" in r_10km
        assert "resp_4500m" in r_10km
        assert "resp_9200m" in r_10km
        assert "resp_12500m" not in r_10km


class TestProgressiveEscalationAndRedispatch:
    def test_progressive_escalation_ladder_and_deduplication(self):
        tools._LOCAL_RESPONDERS.clear()
        tools._LOCAL_MISSIONS.clear()
        center_lat, center_lng = 19.0760, 72.8777
        inc = create_incident({
            "event_id": "evt_ladder_1",
            "user_id": "usr_ladder_1",
            "location": {"latitude": center_lat, "longitude": center_lng},
        })
        iid = inc["incident_id"]

        # Responders at different distance bands
        _seed_responder("stage1_resp", center_lat + 0.005, center_lng)       # ~550m
        _seed_responder("stage2_resp", center_lat + 0.015, center_lng)       # ~1.6km
        _seed_responder("stage3_resp", center_lat + 0.035, center_lng)       # ~3.9km
        _seed_responder("stage4_resp", center_lat + 0.075, center_lng)       # ~8.3km

        # Stage 1 (1 km)
        res1 = tools.advance_incident_escalation(iid)
        assert res1["stage"] == 1
        assert res1["radius_meters"] == 1000.0
        inc_s1 = get_incident(iid)
        assert "stage1_resp" in inc_s1["dispatched_responder_ids"]
        assert "stage2_resp" not in inc_s1["dispatched_responder_ids"]

        # Stage 2 (2 km) -> Deduplication: stage1_resp must NOT receive a duplicate invite!
        res2 = tools.advance_incident_escalation(iid)
        assert res2["stage"] == 2
        assert res2["radius_meters"] == 2000.0
        inc_s2 = get_incident(iid)
        assert "stage2_resp" in inc_s2["dispatched_responder_ids"]
        # Only 1 new invitation created in stage 2 (stage1_resp was not invited again)
        assert res2["new_invitations"] == 1

        # Stage 3 (5 km)
        res3 = tools.advance_incident_escalation(iid)
        assert res3["stage"] == 3
        inc_s3 = get_incident(iid)
        assert "stage3_resp" in inc_s3["dispatched_responder_ids"]

        # Stage 4 (10 km)
        res4 = tools.advance_incident_escalation(iid)
        assert res4["stage"] == 4
        inc_s4 = get_incident(iid)
        assert "stage4_resp" in inc_s4["dispatched_responder_ids"]

        # Beyond stage 4: max radius reached
        res5 = tools.advance_incident_escalation(iid)
        assert res5["status"] == "MAX_RADIUS_REACHED"

    def test_escalation_pauses_when_responder_accepts(self):
        inc = create_incident({
            "event_id": "evt_pause_accept",
            "user_id": "usr_pa_1",
            "location": {"latitude": 19.0760, "longitude": 72.8777},
        })
        iid = inc["incident_id"]
        _seed_responder("helper_1", 19.0765, 72.8777)

        # Stage 1 dispatch
        tools.advance_incident_escalation(iid)

        # Helper accepts
        accept_res = tools.accept_rescue_mission(iid, "helper_1")
        assert accept_res["navigation_grant"] is not None

        # Next escalation attempt should be PAUSED because help is already active
        escalate_res = tools.advance_incident_escalation(iid)
        assert escalate_res["status"] == "ESCALATION_PAUSED_ACCEPTED"

    def test_withdrawal_triggers_redispatch(self):
        tools._LOCAL_RESPONDERS.clear()
        tools._LOCAL_MISSIONS.clear()
        inc = create_incident({
            "event_id": "evt_withdraw_redispatch",
            "user_id": "usr_w_1",
            "location": {"latitude": 19.0760, "longitude": 72.8777},
        })
        iid = inc["incident_id"]
        _seed_responder("helper_w", 19.0765, 72.8777)
        _seed_responder("helper_backup", 19.0880, 72.8777) # ~1.3km (Stage 2)

        # Stage 1 dispatch & acceptance
        tools.advance_incident_escalation(iid)
        tools.accept_rescue_mission(iid, "helper_w")

        # Helper withdraws -> automatically evaluates and triggers redispatch to stage 2!
        mission_id = tools._mission_id(iid, "helper_w")
        tools.transition_rescue_mission(mission_id, "helper_w", "WITHDRAWN")

        inc_w = get_incident(iid)
        assert inc_w["current_escalation_stage"] == 4
        assert "helper_backup" in inc_w["dispatched_responder_ids"]

        # DEV_MODE_NOT_SENT is deliberately not treated as a reachable invitation.
        # With no provider-accepted delivery, the safety engine continues through
        # the remaining stages instead of falsely waiting for an unreachable helper.
        eval_res = tools.process_incident_redispatch_eval(iid)
        assert eval_res["status"] == "MAX_RADIUS_REACHED"


class TestNavigationGrantLifecycle:
    def test_grant_renewal_across_durations(self):
        inc = create_incident({
            "event_id": "evt_grant_renew",
            "user_id": "usr_gr_1",
            "location": {"latitude": 19.0760, "longitude": 72.8777},
        })
        iid = inc["incident_id"]
        _seed_responder("renew_helper", 19.0762, 72.8777)

        tools.advance_incident_escalation(iid)
        acc = tools.accept_rescue_mission(iid, "renew_helper")
        grant_v1 = acc["navigation_grant"]
        m_id = tools._mission_id(iid, "renew_helper")

        # Initial grant is valid
        loc = tools.get_authorized_incident_location(iid, "renew_helper", grant_v1)
        assert loc["latitude"] == 19.0760

        # Simulate 15 minutes passing (grant expires)
        tools._LOCAL_MISSIONS[m_id]["navigation_grant_expires_at"] = int(time.time()) - 10
        with pytest.raises(PermissionError, match="Navigation grant is invalid or expired"):
            tools.get_authorized_incident_location(iid, "renew_helper", grant_v1)

        # Legit helper renews grant (Simulating mission after 15 min / 30 min)
        renew_res = tools.renew_mission_navigation_grant(m_id, "renew_helper")
        grant_v2 = renew_res["navigation_grant"]
        assert grant_v2 != grant_v1
        assert renew_res["grant_renewal_count"] == 1

        # Fresh grant works immediately
        loc_renewed = tools.get_authorized_incident_location(iid, "renew_helper", grant_v2)
        assert loc_renewed["latitude"] == 19.0760

        # Old grant is revoked and cannot be used
        with pytest.raises(PermissionError, match="Navigation grant is invalid or expired"):
            tools.get_authorized_incident_location(iid, "renew_helper", grant_v1)

        # Renewing again (e.g. 45 min, 1 hour)
        renew_res_2 = tools.renew_mission_navigation_grant(m_id, "renew_helper")
        assert renew_res_2["grant_renewal_count"] == 2

    def test_unauthorized_responder_renewal_denied(self):
        inc = create_incident({
            "event_id": "evt_grant_unauth",
            "user_id": "usr_gr_2",
            "location": {"latitude": 19.0760, "longitude": 72.8777},
        })
        iid = inc["incident_id"]
        _seed_responder("real_helper", 19.0762, 72.8777)
        _seed_responder("intruder", 19.0763, 72.8777)

        tools.advance_incident_escalation(iid)
        tools.accept_rescue_mission(iid, "real_helper")
        m_id = tools._mission_id(iid, "real_helper")

        # Intruder attempts to renew real_helper's mission grant
        with pytest.raises(PermissionError, match="Mission does not belong to caller"):
            tools.renew_mission_navigation_grant(m_id, "intruder")

    def test_renewal_rejected_after_cancellation(self):
        inc = create_incident({
            "event_id": "evt_grant_cancel",
            "user_id": "usr_gr_3",
            "location": {"latitude": 19.0760, "longitude": 72.8777},
        })
        iid = inc["incident_id"]
        _seed_responder("cancel_helper", 19.0762, 72.8777)

        tools.advance_incident_escalation(iid)
        tools.accept_rescue_mission(iid, "cancel_helper")
        m_id = tools._mission_id(iid, "cancel_helper")

        # Victim cancels incident
        update_incident_status(iid, IncidentState.CANCELLED.value, actor="USER", note="False alarm")
        tools.cancel_incident_missions(iid, "Victim cancelled incident")

        # Renewal must be denied because incident is closed
        with pytest.raises(PermissionError, match="Incident is closed"):
            tools.renew_mission_navigation_grant(m_id, "cancel_helper")


class TestMultiResponderPolicyAndAbuse:
    def test_multi_responder_capacity_invariant(self):
        inc = create_incident({
            "event_id": "evt_multi_resp",
            "user_id": "usr_mr_1",
            "location": {"latitude": 19.0760, "longitude": 72.8777},
        })
        iid = inc["incident_id"]
        _seed_responder("mr_1", 19.0761, 72.8777)
        _seed_responder("mr_2", 19.0762, 72.8777)
        _seed_responder("mr_3", 19.0763, 72.8777)

        tools.advance_incident_escalation(iid)

        # Primary accepts
        acc1 = tools.accept_rescue_mission(iid, "mr_1")
        assert acc1["mission"]["status"] == "ACCEPTED"

        # Backup accepts (capacity is 2)
        acc2 = tools.accept_rescue_mission(iid, "mr_2")
        assert acc2["mission"]["status"] == "ACCEPTED"

        # Third responder tries to accept when capacity (2) is already full
        with pytest.raises(PermissionError, match="maximum responder capacity"):
            tools.accept_rescue_mission(iid, "mr_3")

    def test_fake_sos_abuse_signal_without_dropping_emergency(self):
        user_id = "frequent_caller_99"
        loc = {"latitude": 19.0760, "longitude": 72.8777}

        # Create 3 incidents in rapid succession
        create_incident({"event_id": "rapid_1", "user_id": user_id, "location": loc})
        create_incident({"event_id": "rapid_2", "user_id": user_id, "location": loc})
        create_incident({"event_id": "rapid_3", "user_id": user_id, "location": loc})

        # 4th incident: Must NOT be discarded, but MUST flag abuse warning and responder advisory!
        inc4 = create_incident({"event_id": "rapid_4", "user_id": user_id, "location": loc})
        assert inc4["state"] == IncidentState.CLOUD_ACCEPTED.value  # Emergency accepted, NOT dropped!
        
        risk = inc4["risk_assessment"]
        assert "abuse_signals" in risk
        assert risk["abuse_signals"]["high_frequency_creation"] is True
        assert "responder_advisory" in risk
        assert "Caution" in risk["responder_advisory"]
