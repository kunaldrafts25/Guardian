# Guardian Comprehensive Safety & Quality Test Plan (Post-P0/P1/P2/P3)

This test plan defines the formal verification suite and regression acceptance criteria for Guardian across mobile clients (Flutter & Android native) and cloud infrastructure (AWS API Gateway, Lambda, DynamoDB, Cognito, SNS, Bedrock).

---

## 1. Authentication, Sessions & Identity Governance

### 1.1 Amazon Cognito Phone Authentication
- [x] Verify phone number E.164 normalization and custom SMS challenge initiation (`POST /auth/send-otp`).
- [x] Test OTP verification and secure storage of access, ID, and refresh tokens in `FlutterSecureStorage`.
- [x] Verify token refresh flow with active `X-Guardian-Session-ID` (`POST /auth/refresh`).
- [x] Verify that an expired session or failed refresh clears all local credentials and redirects to login immediately.
- [x] Test rejection of dev/mock tokens in production release builds.

### 1.2 Session Management & Multi-Device Isolation
- [x] Verify that every authenticated request enforces valid `X-Guardian-Session-ID`.
- [x] Test listing active sessions with device labels and timestamps (`GET /auth/sessions`).
- [x] Test remote session revocation terminating unauthorized device access (`DELETE /auth/sessions/{id}`).
- [x] Verify global sign-out revoking all user sessions in DynamoDB and Cognito (`POST /auth/sign-out`).

---

## 2. Emergency Triggering & Durability

### 2.1 In-App Hold-to-Activate SOS
- [x] Test 3-second hold countdown with haptic feedback and explicit abort window.
- [x] Verify deterministic local incident generation with unique client UUID nonce.
- [x] Verify atomic persistence to local Drift SQLite database before attempting outbound network I/O.
- [x] Verify UI transition to live emergency tracking HUD.

### 2.2 Offline Durability & Outbox Synchronization
- [x] Test SOS activation in airplane mode / zero cellular connectivity.
- [x] Verify incident persistence in Drift `local_incidents` with status `PENDING_SYNC`.
- [x] Test `OfflineSyncService` automatic background queue processing when network returns.
- [x] Verify server-side idempotency ensuring replay or duplicate sync does not duplicate emergency alerts.

### 2.3 Android Native Hardware Panic & Background Resilience
- [x] Unit/code-path verification for rapid screen/power toggle triggering the native dispatcher.
- [x] Verify priority-aware native trigger arbitration so a lower-confidence event cannot suppress a later explicit panic.
- [x] Verify `NativeEmergencyStore` reads the encrypted, account-bound contact snapshot and attempts direct cellular SMS through `SmsManager`.
- [x] Verify pending native events use stable event IDs and remain independently tracked for Flutter replay and cloud synchronization.
- [x] Verify WorkManager cloud sync uses `POST /incidents`, Cognito access token, `X-Guardian-Session-ID`, and the same stable event ID.
- [x] Verify native access-token refresh uses Guardian's existing `POST /auth/refresh` session validation and encrypted refresh token.
- [x] Verify native emergency events cannot upload or replay under a different signed-in Guardian account.
- [ ] Physical-device verification under locked screen, Doze, process death, reboot, no-data/reconnect, and OEM task killing.

---

## 3. Location Freshness & Spatial Integrity

### 3.1 Dual-Coordinate Separation
- [x] Verify strict separation of `initial_location` (immutable origin) and `current_location` (streaming trajectory).
- [x] Verify that periodic tracking updates never overwrite or erase `initial_location`.

### 3.2 Location Freshness Quality Filtering
- [x] Verify classification of GPS fixes based on age and accuracy:
  - `FRESH`: Age $\le 15$s, accuracy $\le 50$m
  - `ACCEPTABLE`: Age $\le 60$s, accuracy $\le 100$m
  - `STALE`: Age $\le 120$s
  - `EXPIRED`: Age $> 120$s
- [x] Test suppression of stale/expired coordinates from remote streaming until fresh GPS lock acquired.
- [x] Verify backend freshness evaluation (`FRESH` $\le 30$s) for responder location grant endpoints.

---

## 4. Responder Discovery, Escalation & Mission Lifecycle

### 4.1 Responder Availability & Heartbeat
- [x] Verify responder heartbeat dispatch every 15 minutes while available, plus movement-triggered updates after 500m.
- [x] Verify DynamoDB geohash indexing and 30-minute availability expiration, leaving margin for the 15-minute heartbeat cadence.
- [x] Test immediate availability teardown and deactivation heartbeat upon toggling offline.

### 4.2 Progressive Radial Escalation
- [x] Verify 4-stage progressive expansion ladder:
  - Stage 1: 1,000m radius, 60s timeout, max 3 candidates
  - Stage 2: 2,000m radius, 90s timeout, max 5 candidates
  - Stage 3: 5,000m radius, 120s timeout, max 8 candidates
  - Stage 4: 10,000m radius, 180s timeout, max 10 candidates
- [x] Test automatic escalation stage advancement upon timeout without quorum.
- [x] Test automatic candidate redispatch upon responder decline or withdrawal.

### 4.3 Mission Lifecycle & Precise Location Authorization
- [x] Verify candidate invitation delivery with coarse location only (approximate neighborhood/distance).
- [x] Test mission acceptance (`POST /missions/{id}/accept`) issuing single-use `navigation_grant`.
- [x] Verify maximum accepted responder limit (`MAX_ACCEPTED_RESPONDERS = 2`) rejecting excess acceptances with `409 Conflict`.
- [x] Test exchanging valid grant for precise coordinates (`POST /incidents/{id}/authorized-location`).
- [x] Verify immediate revocation of navigation grant upon:
  - Responder arrival (`ARRIVED`)
  - Mission completion (`COMPLETED`)
  - Responder withdrawal (`WITHDRAWN`)
  - Incident resolution or cancellation (`RESOLVED`, `CANCELLED`)

---

## 5. SMS Evidence & Truth-in-Advertising

### 5.1 Telephony State Semantics
- [x] Verify the modeled states remain distinct: `NOT_ATTEMPTED`, `COMPOSER_OPENED`, `SUBMISSION_REQUESTED`, `OS_ACCEPTED`, `PROVIDER_ACCEPTED`, `SENT`, `DELIVERED`, `FAILED`, and `UNKNOWN`.
- [x] Verify iOS composer launch never suppresses cloud fallback.
- [x] Verify Android native replay reconstructs per-recipient `OS_ACCEPTED` / `FAILED` evidence and cloud fallback skips only the exact locally accepted contact.
- [x] Verify UI/backend wording treats current Android `SmsManager` success as OS submission acceptance, not handset delivery.
- [ ] Persist and surface real carrier sent/delivery callbacks before treating `SENT` or `DELIVERED` as states produced by the Android transport.

---

## 6. Safety Policy Governance & Amazon Bedrock Advisory

### 6.1 Deterministic Policy Invariants
- [x] Verify that safety-critical actions require signed, single-use capability tokens from deterministic policy.
- [x] Verify atomic capability token consumption preventing replay attacks.
- [x] Verify that Amazon Bedrock advisory advice cannot downgrade, cancel, or suppress explicit panic events.
- [x] Verify Bedrock alone cannot elevate a low deterministic anomaly directly into unrestricted CRITICAL dispatch.
- [x] Verify contact-provider failure cannot prevent independently authorized responder dispatch.
- [x] Verify initial agent execution uses an atomic recoverable lease and duplicate EventBridge delivery cannot execute a concurrent second run.
- [x] Verify user-verification timeout is backend-owned and idempotent rather than Flutter-timer dependent.
- [x] Verify agent-ledger write failure is treated as an observability degradation rather than an authorization bypass or mandatory-action blocker.

---

## 7. Mapping, Routing & External Navigation

### 7.1 OpenStreetMap & OSRM Foot Routing
- [x] Verify in-app map rendering using `flutter_map` with OpenStreetMap tile servers.
- [x] Test walking route fetching from OSRM foot router (`https://router.project-osrm.org`).
- [x] Verify safe zone geofencing and proximity calculation.

### 7.2 External Navigation Handoff
- [x] Test launching external GPS turn-by-turn navigation via `geo:lat,lng` intent on Android.
- [x] Test fallback to Apple Maps URL on iOS and Google Maps web intent on web.

---

## 8. Automated Test Execution Baseline

All automated regression suites must be 100% green before staging promotion:

```powershell
# 1. Backend Pytest Suite
python -m pytest aws/tests --quiet

# 2. Flutter formatting, static analysis, and tests
dart format --output=none --set-exit-if-changed lib test
flutter analyze --no-fatal-infos
flutter test

# 3. AWS infrastructure validation
sam validate --lint --template-file aws/template.yaml
sam build --template-file aws/template.yaml

# 4. Release-compilation gates exercised by CI
flutter build apk --release
flutter build ios --simulator --no-codesign
```
