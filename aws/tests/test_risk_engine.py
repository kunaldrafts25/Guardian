"""
Unit tests for Guardian Risk Assessment Engine
"""

from datetime import datetime
import pytest
from aws.agent.risk_engine import (
    calculate_time_risk,
    calculate_movement_risk,
    calculate_location_risk,
    assess_incident_risk,
)


def test_nighttime_risk():
    night_dt = datetime(2026, 9, 17, 23, 30)
    score = calculate_time_risk(night_dt)
    assert score == 0.85

    day_dt = datetime(2026, 9, 17, 14, 0)
    score_day = calculate_time_risk(day_dt)
    assert score_day == 0.20


def test_fall_movement_risk():
    fall_risk = calculate_movement_risk("fall_detected", {"g_force": 4.5})
    assert fall_risk >= 0.90

    peak_risk = calculate_movement_risk(
        "ANDROID_FALL", {"peak_acceleration": 39.2266}
    )
    assert peak_risk >= 0.90

    normal_risk = calculate_movement_risk("normal_checkin")
    assert normal_risk <= 0.30


def test_incident_composite_assessment():
    night_dt = datetime(2026, 9, 17, 23, 15)
    result = assess_incident_risk(
        event_type="fall_detected",
        location={"latitude": 19.0760, "longitude": 72.8777, "is_isolated": True},
        motion_data={"g_force": 4.2},
        timestamp=night_dt,
    )
    assert result["level"] in ("HIGH", "CRITICAL")
    # Location safety labels are intentionally unavailable/neutral unless backed by real data.
    assert result["score"] >= 0.75
    assert result["recommended_action"] in ("USER_VERIFICATION", "IMMEDIATE_ESCALATION")
    assert len(result["reasons"]) >= 2


if __name__ == "__main__":
    pytest.main([__file__])
