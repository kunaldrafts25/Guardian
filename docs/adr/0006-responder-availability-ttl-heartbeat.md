# ADR 0006: Responder Availability TTL & Periodic Heartbeat

## Status
Accepted (P0/P1/P2/P3 Invariant)

## Context
Responders move throughout the day, turn off devices, enter dead zones, or become unavailable without remembering to open the app and toggle an "offline" switch. Dispatching emergency alerts to ghost or phantom responders who are asleep or kilometers away results in delayed rescues and false belief by the victim that assistance is approaching.

## Decision
Require active responders to publish periodic heartbeats (`POST /responders/heartbeat`) every 60 seconds. 
- In DynamoDB, each heartbeat updates the responder's geohash coordinate and sets an `availability_expires_at` TTL timestamp of exactly $T + 300\text{ seconds}$ (5 minutes).
- Discovery queries automatically filter out any responder whose heartbeat is older than 300 seconds.
- DynamoDB TTL natively purges stale availability records.

## Consequences
- **Positive**: Guarantees that only physically active, reachable, and recent responders are considered for discovery and dispatch.
- **Positive**: Eliminates zombie responders without requiring a permanent background socket connection.
- **Negative**: Adds battery and data overhead for active responders while on duty (minimized by a 60-second tick interval).
