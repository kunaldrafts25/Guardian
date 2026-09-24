# ADR 0005: Responder Precise Location Explicit Temporary Grants

## Status
Accepted (P0/P1/P2/P3 Invariant)

## Context
Broadcasting a victim's exact GPS coordinates to all candidate responders within a radius creates serious stalker, surveillance, and physical assault risks. A malicious or compromised responder account could harvest real-time locations of vulnerable individuals without ever intending to provide assistance.

## Decision
Enforce a two-tier spatial authorization model:
1. **Pre-Acceptance (Coarse Only)**: Candidate responders receive only coarse neighborhood or distance approximations (e.g. "Emergency ~450m away in Bandra West").
2. **Post-Acceptance (Single-Use Grant)**: Upon formal mission acceptance (`POST /missions/{id}/accept`), the backend issues an ephemeral `navigation_grant` token with short TTL (10 minutes).
3. **Automatic Revocation**: The grant is invalidated immediately upon mission completion, responder arrival (`ARRIVED`), responder withdrawal, or incident resolution.

## Consequences
- **Positive**: Strict data minimization. Only vetted responders actively en route hold access to real coordinates.
- **Negative**: Responders must formally commit to a mission before viewing the exact destination address.
