# ADR 0003: Distinct Initial SOS Location and Current Emergency Location

## Status
Accepted (P0/P1/P2/P3 Invariant)

## Context
When an emergency occurs, the initial point of distress (e.g. where an abduction, assault, or accident started) is of critical evidentiary and forensic importance. If continuous tracking simply overwrites the single `location` field, the origin point is permanently erased as the victim moves or is transported. Conversely, if only the initial location is kept, responders cannot locate a moving victim.

## Decision
Strictly separate `initial_location` and `current_location` across database tables, backend schemas, and Flutter models:
1. `initial_location`: Captured at $T_0$ when SOS is activated. Immutable and permanently archived for audit and forensic response.
2. `current_location`: Continuously updated via `POST /incidents/{id}/location` during active tracking, annotated with capture timestamps, freshness quality, and horizontal accuracy.

## Consequences
- **Positive**: Responders receive real-time updates of the victim's current position without destroying the historical origin coordinate.
- **Positive**: Prevents catastrophic loss of origin evidence in vehicular transport scenarios.
