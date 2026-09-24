"""
Guardian Risk Assessment Engine (Python Serverless Core)
Ported from Guardian AIService deterministic scoring.
Calculates multidimensional risk score (0.0 - 1.0) and level: LOW, MEDIUM, HIGH, CRITICAL.
"""

from datetime import datetime
from typing import Dict, Any, List, Optional
import math


def calculate_time_risk(dt: Optional[datetime] = None, tz_offset_seconds: int = 0) -> float:
    """
    Time of day risk factor:
    - 20:00 - 05:00 (Night): 0.85
    - 05:00 - 07:00, 18:00 - 20:00 (Twilight/Evening): 0.50
    - Daytime: 0.20
    """
    if dt is None:
        return 0.40 # P1-09: unknown time -> neutral baseline
    
    from datetime import timedelta
    local_time = dt + timedelta(seconds=tz_offset_seconds)
    hour = local_time.hour
    if hour >= 20 or hour < 5:
        return 0.85
    if (5 <= hour < 7) or (18 <= hour < 20):
        return 0.50
    return 0.20


def calculate_movement_risk(event_type: str, motion_data: Optional[Dict[str, Any]] = None) -> float:
    """
    Movement anomaly risk factor:
    - fall_detected / crash_detected: 0.90
    - shake_detected / panic_gesture: 0.80
    - prolonged_inactivity: 0.70
    - normal_checkin: 0.15
    """
    motion = motion_data or {}
    e_type = (event_type or "").lower()

    if "power" in e_type or "hardware" in e_type or "triple" in e_type or "gesture" in e_type or "manual" in e_type or "tap" in e_type:
        return 0.99  # Explicit intentional distress signal
    if "fall" in e_type:
        # Prefer explicit g-force. Native Android emits peak_acceleration in
        # m/s², so derive an approximate g-force when that is the only signal.
        g_force = motion.get("g_force")
        if g_force is None:
            peak_acceleration = motion.get("peak_acceleration")
            if isinstance(peak_acceleration, (int, float)) and math.isfinite(float(peak_acceleration)):
                g_force = max(0.0, float(peak_acceleration) / 9.80665)
        try:
            g_value = max(0.0, float(g_force)) if g_force is not None else 1.0
        except (TypeError, ValueError):
            g_value = 1.0
        return min(0.95, 0.80 + (g_value / 20.0))
    if "crash" in e_type:
        return 0.95
    if "deviation" in e_type:
        return 0.85
    if "shake" in e_type or "panic" in e_type:
        return 0.80
    if "inactivity" in e_type or motion.get("stationary_seconds", 0) > 60:
        return 0.70
    if "checkin_timeout" in e_type or "check_in" in e_type:
        return 0.75
    return 0.25


def calculate_location_risk(location: Optional[Dict[str, Any]] = None, unsafe_zones: Optional[List[Dict[str, Any]]] = None) -> float:
    """
    Location-based risk factor based on safe zone proximity and historical incidents.
    """
    if not location or "latitude" not in location or "longitude" not in location:
        return 0.40  # Unknown location baseline

    lat = location.get("latitude", 0.0)
    lng = location.get("longitude", 0.0)
    
    # P1-10: Mark placeholder signals as UNAVAILABLE and use a neutral score (0.30)
    # The client doesn't send is_safe_zone, unsafe_zones, or is_isolated.
    # We remove the false references to unsafe zones.
    return 0.30


def assess_incident_risk(
    event_type: str,
    location: Optional[Dict[str, Any]] = None,
    motion_data: Optional[Dict[str, Any]] = None,
    timestamp: Optional[datetime] = None,
    unsafe_zones: Optional[List[Dict[str, Any]]] = None,
) -> Dict[str, Any]:
    """
    Unified multi-factor risk assessment.
    Returns composite score (0.0 - 1.0), risk level enum, and human/agent readable reasons.
    """
    tz_offset = location.get("timezone_offset", 0) if location else 0
    t_factor = calculate_time_risk(timestamp, tz_offset)
    m_factor = calculate_movement_risk(event_type, motion_data)
    l_factor = calculate_location_risk(location, unsafe_zones)

    # Weighted composition: Movement anomaly is primary (50%), Time (25%), Location (25%)
    composite_score = round((0.50 * m_factor) + (0.25 * t_factor) + (0.25 * l_factor), 2)

    reasons = []
    if m_factor >= 0.75:
        reasons.append(f"Severe movement anomaly detected ({event_type})")
    elif m_factor >= 0.60:
        reasons.append("Irregular movement or sudden stop")

    if t_factor >= 0.70:
        reasons.append("High-risk nighttime window")
    elif t_factor >= 0.50:
        reasons.append("Evening twilight window")

    if l_factor >= 0.70:
        reasons.append("Proximity to incident zone or isolated location")

    if "power" in event_type.lower() or "hardware" in event_type.lower() or "triple" in event_type.lower():
        reasons.append("Covert hardware power button 3-tap panic triggered (manual distress)")
        risk_level = "CRITICAL"
        composite_score = max(composite_score, 0.95)
    # A severe physical anomaly (fall/crash) should immediately elevate to HIGH/CRITICAL
    elif composite_score >= 0.75 or m_factor >= 0.85:
        risk_level = "CRITICAL" if composite_score >= 0.85 else "HIGH"
    elif composite_score >= 0.40:
        risk_level = "MEDIUM"
    else:
        risk_level = "LOW"

    return {
        "score": composite_score,
        "level": risk_level,
        "factors": {
            "movement": round(m_factor, 2),
            "time": round(t_factor, 2),
            "location": round(l_factor, 2),
        },
        "reasons": reasons,
        "recommended_action": (
            "IMMEDIATE_ESCALATION" if risk_level == "CRITICAL"
            else "USER_VERIFICATION" if risk_level in ("HIGH", "MEDIUM")
            else "LOG_AND_MONITOR"
        )
    }
