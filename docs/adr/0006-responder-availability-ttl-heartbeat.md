# ADR 0006 — Responder Availability TTL and Heartbeat

Status: Accepted (Phase 5 update)

## Context

Responder discovery must avoid inviting devices that have not recently declared availability, while avoiding a high-frequency background location loop that unnecessarily drains battery.

Availability is not the same as exact responder navigation. The heartbeat exists only to maintain coarse responder eligibility for discovery.

## Decision

Guardian uses:

- an approximately **15-minute periodic mobile heartbeat** while responder availability is enabled;
- an additional heartbeat after substantial movement (currently approximately 500 m);
- a server-side `availability_expires_at` approximately **30 minutes** after the accepted heartbeat;
- explicit `is_active=false` deactivation when the responder turns availability off where the client can reach the server.

Discovery requires all of:

```text
verification_status == APPROVED
trust_score >= policy threshold
is_active == true
availability_expires_at > now
distance <= current responder radius
```

The responder table stores geohash plus exact responder coordinates for server-side eligibility calculations. Victims and unaccepted responders do not receive another responder's exact coordinates.

DynamoDB TTL may eventually delete stale records, but application logic never relies on TTL deletion timing; eligibility checks the stored expiry directly.

## Rationale

A 60-second heartbeat was unnecessarily aggressive for the current community-responder MVP and created an avoidable battery/background-execution cost. The 15-minute / 30-minute model preserves a bounded availability window while allowing movement-triggered refreshes.

This is a product trade-off, not a guarantee that a responder has remained stationary or is reachable. Push-provider acceptance and mission acceptance remain separate evidence.

## Consequences

- A responder can remain discoverable for some time after losing connectivity; the UI and invitation state must not imply the responder has accepted.
- Higher-frequency responder movement tracking is only appropriate after a mission is accepted and must use the mission/location authorization model, not the availability heartbeat.
- Any future change to heartbeat cadence must keep the client interval comfortably below the server expiry.
