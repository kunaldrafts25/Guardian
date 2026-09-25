# ADR 0002: Dedicated Android Native Safety Foreground Service

## Status
Accepted (P0/P1/P2/P3 Invariant)

## Context
Mobile operating systems aggressively terminate background Flutter processes to conserve memory and battery. A user in danger cannot be expected to unlock their phone, navigate to Guardian, and wait for the Flutter engine to cold-boot. Furthermore, the power/screen toggle hardware panic must operate reliably even when the device is locked and the UI is suspended.

## Decision
Maintain a dedicated native Kotlin `SafetyForegroundService` running as an Android foreground service with a persistent notification. The native layer maintains encrypted, account-bound emergency configuration and cloud-auth records in `NativeEmergencyStore`, plus a durable native event journal. This allows direct `SmsManager` submission and WorkManager-backed cloud ingestion without requiring a running Flutter engine. Contact/configuration data and cloud credentials are stored separately so one update cannot overwrite the other.

## Consequences
- **Positive**: Hardware panic gesture (rapid screen/power button toggles) functions when Flutter is asleep, suspended, or terminated.
- **Positive**: Direct SMS submission can be attempted immediately without waiting for Dart VM initialization.
- **Boundary**: A successful `SmsManager` call is recorded as OS acceptance/submission evidence, not proof of handset delivery. Carrier delivery receipts are not currently persisted end to end.
- **Negative**: Redundant location and sensor listening logic between Android native Kotlin and Flutter. This redundancy is intentional and essential for safety resilience.
