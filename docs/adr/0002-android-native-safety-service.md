# ADR 0002: Dedicated Android Native Safety Foreground Service

## Status
Accepted (P0/P1/P2/P3 Invariant)

## Context
Mobile operating systems aggressively terminate background Flutter processes to conserve memory and battery. A user in danger cannot be expected to unlock their phone, navigate to Guardian, and wait for the Flutter engine to cold-boot. Furthermore, the power/screen toggle hardware panic must operate reliably even when the device is locked and the UI is suspended.

## Decision
Maintain a dedicated native Kotlin `SafetyForegroundService` running as an Android foreground service with a persistent notification. The native layer maintains an encrypted master snapshot (`NativeEmergencyStore`) containing the user's primary emergency contacts and cached GPS fix, allowing direct `SmsManager` cellular dispatch without Flutter engine involvement.

## Consequences
- **Positive**: Hardware panic gesture (rapid screen/power button toggles) functions when Flutter is asleep, suspended, or terminated.
- **Positive**: Direct SMS is delivered instantly without waiting for Dart VM initialization.
- **Negative**: Redundant location and sensor listening logic between Android native Kotlin and Flutter. This redundancy is intentional and essential for safety resilience.
