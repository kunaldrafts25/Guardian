"""
Guardian Risk Assessment Engine (Python Serverless Core)
Ported from Guardian AIService deterministic scoring.
Calculates multidimensional risk score (0.0 - 1.0) and level: LOW, MEDIUM, HIGH, CRITICAL.
"""

from datetime import datetime
from typing import Dict, Any, List, Optional
import math


def calculate_time_risk(dt: Optional[datetime] = None) -> float:
    """
    Time of day risk factor:
    - 20:00 - 05:00 (Night): 0.85
    - 05:00 - 07:00, 18:00 - 20:00 (Twilight/Evening): 0.50
    - Daytime: 0.20
    """
    now = dt or datetime.now()
    hour = now.hour
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

    if "power" in e_type or "hardware" in e_type or "triple" in e_type:
        return 0.99  # Explicit intentional hardware distress signal
    if "fall" in e_type:
        # Check acceleration magnitude spike if available
        g_force = motion.get("g_force", 3.0)
        return min(0.95, 0.80 + (g_force / 20.0))
    if "crash" in e_type:
        return 0.95
    if "shake" in e_type or "panic" in e_type:
        return 0.80
    if "inactivity" in e_type or motion.get("stationary_seconds", 0) > 60:
        return 0.70
    if "checkin_timeout" in e_type:
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
    
    # If explicitly in a designated safe zone
    if location.get("is_safe_zone") is True:
        return 0.10

    # Distance check against unsafe / incident hotspots if provided
    if unsafe_zones:
        for zone in unsafe_zones:
            z_lat = zone.get("latitude", 0.0)
            z_lng = zone.get("longitude", 0.0)
            radius = zone.get("radius_meters", 300)
            
            # Simple Euclidean approx for localized distance in meters
            d_lat = (lat - z_lat) * 111320
            d_lng = (lng - z_lng) * 111320 * math.cos(math.radians(lat))
            dist = math.sqrt(d_lat**2 + d_lng**2)
            if dist <= radius:
                return 0.90

    # High isolation indicator
    if location.get("is_isolated") is True:
        return 0.75

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
    t_factor = calculate_time_risk(timestamp)
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
