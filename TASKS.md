# Guardian Hackathon MVP Tracker

Last updated: 2026-09-24  
This file tracks only the smallest safe, real, demonstrable MVP. The broader production backlog remains in `docs/PRODUCTION_IMPLEMENTATION_PLAN.md` and is frozen until this list is complete.

## MVP product promise

On Android, a protected user can trigger one durable emergency incident from the app or supported power/screen gesture. Guardian records real contact-delivery evidence, applies deterministic safety policy, optionally uses Amazon Bedrock for advisory reasoning, and invites a small closed cohort of approved nearby responders without exposing exact location before acceptance.

The MVP does not claim public responder onboarding, emergency-service dispatch, universal OEM power-button support, iOS side-button interception, or guaranteed message delivery.

## Scope rules

- Android-first hackathon build. iOS compilation and supported App Intent/widget work are post-MVP.
- Closed, manually approved responder cohort only. No public responder marketplace.
- One region, one language, and one responder capability for the demo.
- Manual SOS and supported Android panic gesture only. BLE relay, fall ML, and wearables are removed from product scope; safe-zone automation is excluded from the MVP.
- Trusted contacts and capped responder invitations are the only outbound emergency channels.
- Bedrock explains and recommends; deterministic policy authorizes every action.
- No runtime fixtures, invented responders, simulated acknowledgements, or fabricated delivery states.

## Completed foundation

- [x] Canonical incident state machine and append-only local emergency journal.
- [x] Account-scoped Drift contacts with E.164 validation and deletion tombstones.
- [x] Durable Android native panic event, encrypted native snapshot, local SMS queue, stable nonce, debounce, and reboot restoration.
- [x] Offline incident outbox, deterministic incident IDs, conditional creation, and terminal-state protection.
- [x] Cognito custom challenge infrastructure, secure token storage, refresh-once behavior, and protected API ownership checks.
- [x] Server-enforced application sessions with device listing and immediate revocation.
- [x] One FastAPI/Mangum backend surface with structured errors and correlation IDs.
- [x] Deterministic agent policy; Bedrock cannot downgrade hardware/manual panic.
- [x] Signed, expiring, incident/action-bound, atomically single-use tool authorization.
- [x] Append-only agent ledger containing proposals, policy decisions, tool attempts, redacted evidence, and final outcomes.
- [x] Policy-bound responder quorum, invitation cap, and coarse-location precision.
- [x] Runtime fake responders and fake acknowledgement/delivery claims removed.
- [x] BLE/offline-mesh runtime, dependency, permissions, UI, and stale local cache removed; schema v7 upgrade is covered by a migration test.
- [x] Durable DynamoDB mission acceptance and short-lived navigation grants exist.
- [x] Backend suite passes: 71 tests across authentication, sessions, incident state machine, risk engine, progressive escalation, and P0/P1/P2 remediation suites.
- [x] Flutter suite passes: 145 tests across units, widgets, database, and P2 state machine remediation.
- [x] P0 (Safety Critical), P1 (Emergency Pipeline), P2 (Lifecycle & Truthfulness), and P3 (Clean Architecture & Drift Elimination) remediation completed.
- [x] Static analysis has no errors or warnings (informational modernization lint remains).
- [x] Android release APK builds and verifies with explicit cryptographic signing: 69.7 MB after the UI foundation update.
- [x] GitHub Android CI is green with an explicit Android SDK setup action and API 36 packages.
- [x] Minimal semantic theme, simplified Home hierarchy, hold-to-SOS flow, truthful active-incident copy, and full-screen critical routes implemented.
- [x] macOS CI passes CocoaPods module generation and the unsigned iOS simulator build.
- [x] Staging/production AWS resources are isolated by an explicit environment name.
- [x] Final AWS, Firebase, Android, iOS, and public-release runbook completed locally.
- [x] Runtime incident simulator, legacy unauthenticated handler, and unused placeholder map service removed.

## Four remaining MVP deliverables

### M1 — Deliver responder invitations

Status: code complete; physical SNS/FCM/APNs delivery requires deployment credentials and two-device staging proof.

- [x] Send targeted push only to capped responder IDs selected by policy; the legacy general broadcast API/topic is removed.
- [x] Persist per-responder invitation transport evidence without claiming delivery.
- [x] Show a real authenticated responder invitation/mission inbox.
- [ ] Prove receipt on an approved physical responder device in staging.

Acceptance: an approved available responder receives one coarse invitation on a physical device; an unapproved, stale, or excess responder receives nothing.

### M2 — Finish the mission journey

Status: code complete; two-device field validation remains.

- [x] Complete conditional `INVITED → ACCEPTED → EN_ROUTE → ARRIVED → COMPLETED` and withdrawal/cancellation/expiry handling.
- [x] Bind Flutter mission/navigation to authenticated mission data and an encrypted device-held grant.
- [x] Revoke precise-location grants on arrival, terminal mission state, and terminal incident state.
- [ ] Prove the complete journey on two physical devices.

Acceptance: one approved responder can accept, navigate, arrive, and complete; replay, second acceptance, expired grants, and cancelled incidents fail safely.

### M3 — Make the demo understandable

Status: code complete; staging evidence remains.

- [x] Add readiness checks for contacts, permissions, protection service, battery optimization, push registration, and API reachability.
- [x] Add a confirmation-gated real contact SMS explicitly labelled as a non-emergency test.
- [x] Add an owner-safe persisted incident evidence timeline.

Acceptance: a judge can understand what happened, which parts were autonomous, and what was actually delivered without reading logs.

### M4 — Package and prove the Android MVP

Status: implementation complete; external staging and store credentials remain.

- [x] Replace notification `Navigator.pushNamed` handling with authenticated `go_router` routing for incident and invitation opens, including terminated-app messages.
- [ ] Run real staging Cognito, Bedrock, SNS/FCM, process-death, locked-device, no-network, and reboot tests.
- [x] Build the Android release APK with production application ID `com.company.guardian`.
- [x] Require explicit Android release credentials; CI uses an ephemeral verification certificate and labels its artifact non-distribution.
- [ ] Rebuild with the real staging API/Firebase dart-defines and distribution signing credentials.
- [ ] Run the macOS CI/Xcode iOS simulator build, then archive with the Apple team and APNs credentials.

Acceptance: the complete protected-user/responder flow works on two physical Android devices and every visible status is backed by persisted evidence.

## Explicitly deferred until after the hackathon

Public responder enrollment and identity review; moderation/report/appeal systems; scalable geospatial indexing and load testing; safe-zone background execution; generalized offline sync; iOS App Intents/widgets and Xcode release; multilingual UI; advanced accessibility pass; public app-store release controls; multi-region disaster recovery; WAF/KMS/retention operations; independent penetration and privacy review.

Removed from product scope rather than deferred: BLE/offline mesh relay, fall-detection ML, and wearable integrations.

## Remaining execution order

1. Deploy the AWS stack and inject the real Cognito, API, Bedrock, SNS/FCM, and APNs configuration.
2. Sign Android and iOS with the owner's distribution credentials.
3. Complete the two-device physical responder journey and failure-mode checklist.
4. Execute the production runbook, store pre-release tracks, and monitored gradual rollout.
