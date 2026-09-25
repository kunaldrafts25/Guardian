# Guardian Phase 5 — Pre-Production Hardening Report

## Scope

Phase 5 hardens the post-Phase-4 Guardian baseline across authentication, account isolation, offline recovery, location integrity, responder concurrency, notification ownership/evidence, durable workflows, abuse controls, privacy/retention, truthful product semantics, and production map/routing providers.

This report describes repository/code state. It does **not** claim that AWS production configuration, mobile-store approval, carrier delivery, or physical-device behavior has been validated merely because automated CI passes.

## Implemented hardening

### Authentication

- Phone OTP login, OTP screens, OTP API routes, custom Cognito challenge Lambdas, OTP throttling resources, and Cognito SMS-login dependency were removed.
- Production login uses Google federation through Cognito managed login with authorization-code + PKCE.
- No Google-user shadow password is manufactured in production.
- Google client configuration is mandatory for the production stack.
- Development direct-Google bootstrap remains explicitly dev-only.
- Protected APIs require a Cognito **access token** plus active Guardian device session.
- API Gateway verified claims are rejected if `token_use != access`.
- Per-device Guardian session listing/revocation remains available.
- Session revocation/global logout disables session-bound push endpoints.

### Offline/account integrity

- Drift outbox operations are bound to `owner_user_id`.
- Pending operations are selected only for the authenticated owner.
- Legacy rows are backfilled only where ownership can be proven from the local alert.
- Cross-account replay is rejected rather than reassigned.
- Android native emergency events and native cloud auth remain owner-bound.

### Offline-to-online incident recovery

- Successful outbox incident creation emits a `CloudIncidentBinding`.
- The active EmergencyNotifier binds the returned cloud incident ID.
- Polling starts immediately.
- The latest local victim location is immediately pushed to cloud after binding instead of waiting for a later GPS event.

### Victim location integrity

- Initial and current emergency locations remain distinct.
- Current-location writes use an atomic DynamoDB condition on captured-time epoch milliseconds.
- Concurrent stale/out-of-order writes cannot overwrite a newer cloud fix.
- Owner and terminal-state conditions are evaluated atomically with the write.
- Responder UI refreshes authorized victim location while an accepted/en-route mission is active and displays freshness, age, and accuracy.

### Responder concurrency and discovery

- Responder mission acceptance uses a DynamoDB transaction that:
  - requires a nonterminal incident,
  - enforces accepted-responder capacity,
  - requires an unexpired `INVITED` mission bound to the caller,
  - updates mission acceptance/grant and incident capacity atomically.
- Capacity is released on applicable mission-exit paths.
- Responder/session/mission query paths added in Phase 5 paginate DynamoDB result pages.
- Progressive responder widening remains backend-controlled at 1 -> 2 -> 5 -> 10 km.

### Push ownership

- Push registration uses a dedicated `DeviceEndpointsTable`.
- Endpoint records bind user, device, platform, token hash, Guardian session, and enabled state.
- Token reuse across accounts/sessions disables stale bindings.
- Delivery validates the bound Guardian session.
- Global logout and individual session revocation disable corresponding endpoints.
- Session IDs are not copied into SNS provider metadata.

### Android SMS evidence

- Native SMS creates per-part sent PendingIntents.
- `SmsSentReceiver` records asynchronous radio-send success/failure.
- Native evidence is correlated to contacts without duplicating full phone numbers into the emergency event journal.
- Cloud fallback does not treat simple API/OS submission acceptance as equivalent to successful radio send.
- Human/carrier handset **delivery** is still not claimed; there is no end-to-end delivery-receipt implementation.

### Durable workflow recovery

- Short safety deadlines use a durable SQS queue with DLQ rather than relying on EventBridge Scheduler precision.
- Deadline execution rechecks the authoritative incident deadline and state.
- Early messages are requeued until the deadline.
- Verification and responder-stage work use recoverable idempotency.
- A minute-level reconciler:
  - repairs overdue verification deadlines,
  - repairs overdue responder escalation checks,
  - retries failed/not-emitted `incident.created` orchestration.
- Terminal incidents remain no-ops for stale workflow messages.

### Abuse and trigger provenance

- Production has TTL-backed high-frequency incident advisory counters.
- Abuse signals are advisory and never suppress explicit SOS.
- Trigger provenance/trust is stored explicitly.
- Unattested automatic telemetry is not allowed to acquire the same deterministic authority as explicit user distress merely by supplying a trusted-looking event-type string.
- Incident abuse reports are separate TTL-backed records and require the reporter to be the incident owner or an associated responder.

### Privacy and retention

- Retired OTP logging/code was removed with the OTP subsystem.
- Precise-coordinate mobile logging was reduced.
- Native emergency journals no longer duplicate trusted-contact phone numbers merely to identify SMS outcome records.
- Incident, timeline, and agent evidence use configurable TTL retention.
- Local retained safety history is pruned without removing active/pending evidence.
- The local Drift database protection boundary is documented truthfully: ordinary SQLite in OS-protected application storage, not SQLCipher.

### Product truthfulness

- The UI describes the phone action as opening the emergency dialer, not as proof an emergency call completed.
- Trusted-contact emergency wording is derived from actual incident provenance/state.
- Voice SOS and UI multi-tap code were removed as inactive product claims.
- Android native screen/power panic remains the implemented covert hardware gesture.

### Maps and routing

- Public OSM tile/Nominatim/OSRM runtime dependencies were removed from the production mobile path.
- Flutter map rendering uses Google Maps SDK.
- Place search uses Guardian-authenticated Google Places proxy endpoints.
- Walking route geometry uses Guardian-authenticated Google Routes proxy endpoints.
- The server Places/Routes credential remains in AWS Secrets Manager.
- Mobile Maps SDK keys are platform/application restricted configuration.
- Google route data is not described as "verified safe."
- Guardian remains authoritative for victim location, emergency state, responder eligibility, and location grants.

## Current trigger support

| Trigger | Product status |
| --- | --- |
| Manual in-app SOS | Implemented |
| Android native power/screen panic | Implemented; physical OEM qualification still required |
| Android native shake | Implemented heuristic |
| Android native fall | Implemented heuristic |
| Check-in expiry | Implemented with Android native backup |
| Route deviation | Implemented only with authoritative route geometry and confirmation policy |
| Voice SOS | Not an active product trigger |
| UI multi-tap | Not an active product trigger |

## CI completion gate

The final Phase 5 SHA must pass all of these together:

- backend pytest,
- SAM `validate --lint`,
- SAM build,
- generated Drift-code verification,
- Dart format,
- Flutter analyze,
- Flutter tests,
- Android release APK build,
- iOS simulator build.

The PR/workflow result is the source of truth for the final SHA; this document intentionally does not hard-code a test count that can become stale after a new regression test is added.

## External validation still required

Phase 5 code completion does not remove these deployment gates:

1. Real Cognito Google federation in an isolated AWS staging stack.
2. Real DynamoDB concurrency tests for responder acceptance and victim-location ordering.
3. Real EventBridge/SQS/DLQ/reconciler failure injection.
4. FCM/APNs endpoint registration, token rebinding, disabled-endpoint and account-switch tests.
5. AWS/cloud SMS approval and country-specific messaging requirements where cloud SMS is enabled.
6. Representative physical Android testing for locked screen, Doze, reboot, OEM task killing, native sensors, SMS radio failures, check-in timing and route deviation.
7. Physical iOS testing for Cognito callback restoration, supported background location, push and in-app SOS.
8. Restricted Google Maps Platform key/quota/budget validation.
9. Apple App Store login-policy review; add Sign in with Apple before iOS distribution if required by the final App Store configuration.
10. Privacy/terms/account-deletion/support/abuse-review operational processes before unrestricted public release.

## Production-readiness interpretation

Phase 5 is a **pre-production code hardening** milestone. A green final CI run means the repository passes its automated code/build gates. Production safety readiness additionally requires the staging and physical-device validation listed above.
