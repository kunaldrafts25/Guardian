# Guardian Production Implementation Plan

Last audited: 2026-09-25  
Scope: Phase 5 pre-production hardening baseline.

## 1. Product boundary

Guardian is an offline-tolerant personal-safety application. It is not an emergency-service replacement and must not claim police, ambulance, carrier delivery, responder arrival, or "safe route" outcomes that have not actually occurred.

The production architecture is designed around these invariants:

1. One emergency event has one stable identity across native Android, Flutter, local storage, retries, and AWS.
2. Explicit distress is never suppressed by lower-confidence automatic telemetry.
3. Local safety actions and independent cloud channels degrade independently.
4. Precise victim location is owner-controlled and only disclosed to an approved responder through a short-lived mission-bound grant.
5. Amazon Bedrock is advisory; deterministic policy and scoped capabilities authorize side effects.
6. Account/session ownership is enforced on local outbox replay, native cloud sync, push endpoints, and API access.
7. Durable deadlines and responder widening recover from process or transport failures.

## 2. Current production architecture

### Identity and sessions

Production login uses Google federation through Amazon Cognito managed login:

```text
Google
  -> Cognito Hosted/Managed Login
  -> Authorization Code + PKCE
  -> Cognito access/id/refresh tokens
  -> POST /auth/session
  -> Guardian device session
  -> Bearer access token + X-Guardian-Session-ID on protected APIs
```

Phone OTP authentication has been retired. Phone numbers are emergency-contact data, not account identity.

Protected APIs accept Cognito **access tokens**, not ID tokens. Guardian sessions provide per-device revocation. Production direct Google-token brokerage is disabled; the remaining `/auth/google` helper is development-only.

### Local durability and automatic SOS

Flutter uses Drift/SQLite for the local incident journal, delivery evidence, check-ins, and account-bound outbox. Android adds an encrypted native emergency journal, account-bound cloud-auth record, direct SMS submission, radio-send callbacks, WorkManager upload, boot recovery, check-in AlarmManager, shake/fall heuristics, route-deviation handling, and the supported native power/screen panic gesture.

The Drift file is ordinary SQLite under OS application/data protection, not SQLCipher. See ADR 0009.

### Cloud incident and workflow

```text
POST /incidents
  -> deterministic incident identity
  -> DynamoDB conditional create
  -> EventBridge incident.created
  -> Guardian agent
  -> deterministic risk + policy
  -> optional Bedrock advisory
  -> scoped single-use capability
  -> independent contact/responder actions
```

Short verification and responder deadlines are represented in DynamoDB and delivered through a durable SQS queue. A minute-level reconciler repairs missed/failed deadline work and failed incident-created orchestration.

### Responders

Responder enrollment is a closed, manual-review workflow. Discovery requires an approved responder, trust threshold, active availability TTL, geospatial filtering, and exact haversine distance.

Responder escalation uses one backend-controlled ladder:

```text
1 km -> 2 km -> 5 km -> 10 km
```

Zero reachable invitations widen immediately. Provider-accepted invitations wait for their deadline. Acceptance capacity is enforced transactionally in DynamoDB. Precise location requires a valid mission-bound navigation grant.

### Location

Initial SOS location and current emergency location are distinct. Victim updates use an atomic captured-time condition so a stale concurrent write cannot overwrite a newer coordinate. Offline cloud creation publishes a local/cloud binding event so the active emergency immediately resumes current-location uploads when connectivity returns.

The responder mission screen refreshes the authorized current victim location while a mission is active and displays freshness/age/accuracy. External turn-by-turn navigation is a hand-off; it is not the authority for victim location.

### Push and SMS

Push tokens are stored as account-, device-, and Guardian-session-bound endpoint records. A token rebound to another account/session disables the old binding.

Android direct SMS records:
- submission request/OS acceptance,
- asynchronous radio-send result per message part,
- failure evidence.

Carrier handset delivery is **not** claimed unless a future delivery receipt implementation proves it. Cloud SMS failure cannot block independent responder dispatch.

### Maps

Production map/search/route architecture uses:
- Google Maps Flutter SDK for rendering,
- platform-restricted mobile SDK keys,
- Guardian-authenticated backend proxies for Google Places and Google Routes,
- a server key held in AWS Secrets Manager.

Google provides mapping/routing data only. Guardian remains authoritative for emergency state, live victim location, responder authorization, and safety policy. Routes are not described as "verified safe."

## 3. Phase 5 security controls

- Cognito Google federation with PKCE.
- Cognito access-token-only protected API boundary.
- Mandatory Guardian session header on protected APIs.
- Account-bound Flutter and Android offline queues.
- Session-bound multi-device push registration.
- Transactional responder acceptance cap.
- Atomic monotonic current-location writes.
- Participant-only abuse reporting.
- TTL-backed abuse advisories that never block explicit SOS.
- Trigger-provenance classification; unattested automatic telemetry cannot directly gain explicit-panic authority.
- Sensitive-log minimization.
- TTL-backed incident/timeline/agent evidence retention.
- Durable SQS deadline processing + reconciliation.
- Bedrock advisory isolation behind deterministic policy/capabilities.

## 4. Known platform/product limitations

These are intentional truths, not hidden defects:

- Physical Android behavior still requires representative-device qualification for Doze, reboot, OEM task killing, sensors, cellular SMS, and lock-screen flows.
- iOS cannot provide Android-equivalent arbitrary power-button interception, direct background SMS, or no-Flutter native sensor SOS.
- Voice SOS and UI multi-tap are not active product triggers.
- Responder identity review is manual; this repository does not implement a full external KYC vendor.
- Local Drift storage relies on OS protection rather than application-level SQLCipher.
- Embedded Google Navigation SDK turn-by-turn is not implemented; Guardian uses its own mission/live-location UI plus external navigation hand-off.
- AWS SMS production access and country-specific messaging registration are deployment/account prerequisites, not code guarantees.
- Sign in with Apple must be assessed/added before App Store distribution if Apple review rules require it for the final login configuration.

## 5. Required staging validation

Before real-user distribution, deploy an isolated staging stack and execute tests against real AWS services:

- Cognito Google login, refresh, session revoke and account switch.
- DynamoDB concurrent victim-location writes.
- Concurrent responder acceptance at and above capacity.
- EventBridge duplicate/failure behavior.
- SQS delayed workflow, retries, DLQ, and reconciliation.
- SNS FCM/APNs endpoint registration/rebinding and delivery failures.
- Android local SMS radio failure after submission.
- Offline SOS -> account switch -> reconnect.
- Offline SOS -> cloud bind -> current-location resume.
- 1 -> 2 -> 5 -> 10 km responder progression.
- Victim resolution racing responder acceptance/deadline processing.
- Bedrock unavailable.
- Google Places/Routes quota/provider failures.

## 6. Physical-device validation

At minimum qualify multiple Android manufacturers for:

- foreground/background/locked-screen SOS,
- Flutter killed,
- reboot,
- Doze/battery saver,
- offline then reconnect,
- stale/disabled/low-accuracy GPS,
- notification and SMS permission denial,
- controlled shake/fall false-positive scenarios,
- check-in deadline race,
- route-deviation confirmation,
- account switch with pending native event.

iOS must separately validate Google/Cognito callback restoration, background location behavior, push delivery, and supported in-app emergency flows.

## 7. Release gate

A repository commit can be considered code-complete for this phase only when the same SHA passes:

- backend pytest,
- SAM validate --lint,
- SAM build,
- generated Drift-code check,
- Dart format check,
- Flutter analyze,
- Flutter tests,
- Android release APK build,
- iOS simulator build.

Passing CI is necessary but does not replace staging or physical-device validation.
