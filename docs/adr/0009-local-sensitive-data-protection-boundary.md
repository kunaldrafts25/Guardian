# ADR 0009: Local Sensitive Data Protection Boundary

## Status
Accepted — Phase 5

## Context

Guardian persists emergency contacts, SOS state, check-ins, delivery evidence, and
recent location evidence through Drift/SQLite so an emergency can survive network
loss and process restarts. The current Drift database is an ordinary SQLite file;
it is **not** protected by SQLCipher and must not be described as application-level
encrypted storage.

Guardian separately stores authentication secrets and the Android native emergency
snapshot/auth records in platform-protected secure storage.

## Decision

For the current controlled MVP:

- Drift remains the local durability database because emergency write/replay
  reliability is already built around it.
- The application relies on the operating-system app sandbox and device-at-rest
  encryption for the Drift file.
- Android backup is disabled for the application.
- Cognito tokens, refresh tokens, Guardian session material, and native Android
  emergency credentials remain outside Drift in secure/encrypted platform storage.
- Cloud incident/timeline/agent evidence uses explicit TTL-backed retention.
- Unsynced or unresolved local emergency evidence must not be silently purged merely
  to satisfy a storage-retention target.
- Logs must not contain tokens, OTPs, full contact phone numbers, or precise GPS.

## Threat-model boundary

This does **not** defend the Drift file against an attacker who has obtained
privileged/root access to an unlocked or compromised device filesystem. A deployment
whose threat model includes forensic extraction from a compromised device must add
SQLCipher or audited field-level encryption before that deployment.

Adding encryption later must preserve transactional outbox behavior, crash recovery,
schema migration safety, and the ability to perform native/Flutter reconciliation.
A rushed cryptographic wrapper is not acceptable in a safety-critical path.

## Consequences

- Documentation is truthful about the present protection level.
- Emergency durability is not weakened by a late storage-engine swap.
- Stronger application-level database encryption remains a deliberate hardening
  requirement for higher-risk/public deployments rather than an implied capability.
