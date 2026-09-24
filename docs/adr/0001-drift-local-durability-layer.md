# ADR 0001: Retention of Drift as Local Durability Layer

## Status
Accepted (P0/P1/P2/P3 Invariant)

## Context
Emergency situations often occur in locations with intermittent or zero cellular connectivity (subways, basements, elevators, remote areas). A safety app that depends on an immediate, synchronous HTTP response before recording an incident risks losing the event if the app crashes, the battery dies, or the device is destroyed.

## Decision
Retain Drift (SQLite) with transactional outbox semantics as the primary local persistence layer. Every SOS trigger (in-app hold, gesture, native panic) MUST write an append-only incident record to local SQLite before attempting any network communication.

## Consequences
- **Positive**: Complete offline survivability. Even if the device has zero signal, the emergency event is safely persisted with its initial timestamp, coordinates, and local SMS dispatch status.
- **Positive**: When connectivity is restored, `OfflineSyncService` drains the outbox and synchronizes the incident with AWS API Gateway using idempotent client nonces.
- **Negative**: Requires maintaining local schema migrations across app updates.
