# Guardian Safety & Quality Test Plan — Phase 5

This plan reflects the current Google/Cognito, Google Maps, durable-SOS, responder, and agentic architecture.

## 1. Authentication and account isolation

Automated:
- Google/Cognito configuration rejects missing or wrong Google audience in the development verification helper.
- Retired phone OTP routes are absent.
- Protected Gateway identity rejects Cognito ID-token claims and accepts access-token claims.
- Protected endpoints require `X-Guardian-Session-ID`.
- Revoked or other-user Guardian sessions are rejected.
- Refresh is bound to the stored session/refresh-token hash.
- Session listings are paginated.
- Device endpoints are bound to account + session + stable device ID.

Staging:
- Google hosted login PKCE callback on Android/iOS.
- App process death during OAuth callback and subsequent resume.
- Token refresh and remote session revocation.
- Account A -> logout -> Account B on the same push token/device.

## 2. Offline SOS and local durability

Automated:
- Drift outbox operations are account-scoped.
- Legacy outbox rows are backfilled only when ownership can be proven.
- Another account cannot replay a queued incident.
- Offline cloud creation publishes a local/cloud binding event.
- Active emergency binds the cloud incident and force-pushes the latest location.
- Terminal local incidents are not recreated later.

Physical/device:
- Offline SOS, app background/kill, reconnect.
- Native Android panic while Flutter is unavailable.
- Reboot with pending emergency/check-in.
- Account switch while User A has pending native/Flutter evidence.

## 3. Location integrity

Automated:
- Native cached capture time remains original.
- Stale/out-of-order coordinates are rejected.
- DynamoDB update uses a captured-time condition to prevent concurrent rollback.
- Terminal incidents reject location updates.
- Precise responder location requires a valid live grant.

Staging:
- Concurrent location writes with reversed completion order.
- Victim movement while responder is `ACCEPTED` / `EN_ROUTE`.
- Fresh -> aging -> stale responder UI behavior.

## 4. Automatic triggers

Validate:
- manual explicit SOS,
- Android native power/screen panic,
- Android shake,
- Android fall heuristic,
- check-in expiry,
- route-deviation confirmation.

One physical/logical trigger must become one canonical incident. Explicit distress must outrank lower-confidence automatic signals. Unattested automatic telemetry must not gain direct-dispatch authority merely from its event-type string.

Voice SOS and UI multi-tap are not active product triggers.

## 5. SMS and push truth

Automated/code:
- Native Android SMS has per-part sent callbacks.
- Submission acceptance and radio-send result are distinct.
- Cloud fallback is not suppressed solely by OS API acceptance.
- Push `DEV_MODE_NOT_SENT` is not provider acceptance.
- Push endpoint delivery validates the bound Guardian session.
- Token rebinding disables prior account/session binding.

Physical/staging:
- radio off/no service after submission,
- multipart SMS partial failure,
- real FCM/APNs acceptance and disabled endpoint,
- same token switching accounts.

Do not mark carrier handset delivery unless an actual delivery receipt is implemented.

## 6. Responders

Automated:
- eligibility requires active/approved/trusted responder and nonexpired availability.
- geohash/fallback queries paginate.
- exact haversine distance filters candidates.
- one backend progression engine widens 1 -> 2 -> 5 -> 10 km.
- zero reachable invitations widen immediately.
- acceptance is a DynamoDB transaction enforcing incident nonterminal + capacity + live invitation.
- capacity is released on withdrawal/completion/cancellation paths.
- grants are responder/mission/incident-bound and time-limited.
- terminal incident revokes future exact-location access.

Staging:
- simultaneous acceptance by more responders than capacity,
- cancellation racing acceptance,
- withdrawal after sole acceptance,
- all invitations decline/expire,
- max-radius exhaustion.

## 7. Agentic safety and workflow recovery

Automated:
- Bedrock output is validated advisory input.
- deterministic policy owns actions.
- capabilities are action/incident/version bound and single-use.
- duplicate initial agent execution is leased/idempotent.
- external actions use independent claims.
- contact provider failure does not block responder action.
- verification and escalation deadlines have recoverable idempotency.
- early SQS messages are requeued until deadline.
- reconciler repairs overdue deadlines and failed incident-created orchestration.
- terminal incidents turn stale workflow messages into no-ops.

Staging:
- duplicate EventBridge delivery,
- SQS retry/DLQ behavior,
- reconciler after intentionally failed queue send,
- Bedrock outage.

## 8. Abuse and moderation

Automated:
- production-path TTL-backed incident frequency advisory exists.
- advisory never blocks explicit SOS.
- trigger provenance/trust classification is persisted.
- incident reports require owner or associated responder.
- moderation records are separate and TTL-backed.

Red team:
- modified client fabricates `ANDROID_FALL` / `ANDROID_POWER_GESTURE`.
- repeated fake incidents.
- responder-luring attempts.
- prompt injection in telemetry and free text.

## 9. Maps and route deviation

Automated:
- authenticated Google Places autocomplete/details proxy.
- authenticated Google walking-route proxy.
- mobile place search uses Guardian backend rather than public Nominatim.
- walking geometry uses Google Routes rather than public OSRM.
- map rendering uses Google Maps SDK.
- missing/provider-failed route geometry cannot be treated as authoritative for route-deviation SOS.
- no "verified safe" route claims.

Deployment:
- Android key package/signing restrictions.
- iOS key bundle restrictions.
- server Places/Routes key only in Secrets Manager.
- quotas/budgets/monitoring.

## 10. Privacy and retention

Verify:
- no OTP flow/logging remains.
- logs avoid full contact phone, token, session, navigation grant, and precise GPS unless explicitly required.
- cloud incident/timeline/agent evidence carries retention TTL.
- local pruning never deletes active/pending safety evidence.
- Drift/SQLite protection boundary is documented truthfully; it is not described as SQLCipher-encrypted.

## 11. CI gate

The same final SHA must pass:
- backend pytest,
- SAM `validate --lint`,
- SAM build,
- Drift generated-code check,
- Dart format,
- Flutter analyze,
- Flutter test suite,
- Android release APK build,
- iOS simulator build.

## 12. Production acceptance not proven by CI

Before real-user rollout execute real AWS staging and physical-device tests for Cognito federation, DynamoDB concurrency, EventBridge/SQS, SNS push/SMS, Android sensor/background behavior, iOS callbacks/location, and Google Maps Platform credentials/quota behavior.
