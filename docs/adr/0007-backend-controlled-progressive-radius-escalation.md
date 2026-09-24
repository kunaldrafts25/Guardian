# ADR 0007: Backend-Controlled Progressive Radius Escalation

## Status
Accepted (P0/P1/P2/P3 Invariant)

## Context
If an emergency dispatch immediately alerts all responders within a 10km radius, it risks triggering alert fatigue, overwhelming the victim with chaotic arrivals, or exposing coordinates unnecessarily. Conversely, limiting the search to a narrow 500m radius can result in total failure to find help if no one is in the immediate vicinity.

## Decision
Implement a deterministic, 4-stage progressive escalation ladder orchestrated exclusively by the backend (`aws/agent/escalation_policy.py`):
- **Stage 1 (Immediate Vicinity)**: 1,000m radius, 60s timeout, max 3 candidates.
- **Stage 2 (Local Neighborhood)**: 2,000m radius, 90s timeout, max 5 candidates.
- **Stage 3 (District Area)**: 5,000m radius, 120s timeout, max 8 candidates.
- **Stage 4 (Wide Perimeter)**: 10,000m radius, 180s timeout, max 10 candidates.

The backend controls escalation timers and evaluates quorum (minimum 1 accepted responder). If an invitation expires or a candidate declines, the backend automatically expands to the next stage or triggers redispatch.

## Consequences
- **Positive**: Balances rapid local response with progressive expansion guarantees.
- **Positive**: Client devices cannot arbitrarily expand search radii or spam wide geographic cohorts.
