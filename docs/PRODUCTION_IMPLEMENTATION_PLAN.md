# Guardian Production Implementation Plan

Last audited: 2026-09-20  
Scope: code, mobile platform integration, backend contracts, security, testing, and release readiness. AWS production provisioning and store publication remain deployment activities, but the code must be ready for them.

## 1. Product outcome

Guardian is an offline-tolerant personal-safety application with four primary promises:

1. A person can trigger help quickly, including through a covert hardware gesture where the operating system permits it.
2. Trusted contacts receive a real alert with the best available location even when cloud connectivity is poor.
3. Qualified nearby Guardian responders can provide safe, non-confrontational support without exposing the victim to stalking, ambush, or uncontrolled crowds.
4. Every safety-critical action is durable, auditable, idempotent, and understandable. AI can assist; it cannot invent facts or bypass safety policy.

The app must never claim that help was sent, a responder is coming, a message was delivered, or a location is live unless the relevant transport or participant has acknowledged it.

## 2. Reality check: current system

### Working foundations

- Flutter application with Riverpod state management and `go_router` authentication guards.
- Cognito custom-challenge infrastructure, secure token storage, refresh-once behavior, API authorization, and owner-scoped Guardian session revocation.
- Android foreground service, boot receiver, encrypted native emergency journal, native contact/config snapshot, native SMS queue, location cache, notification action, and screen on/off sequence detection.
- Manual, shake, voice, and hardware-trigger entry points feeding the SOS provider while Flutter is alive.
- Native Android SMS dispatch with per-recipient acceptance/failure evidence represented in application state.
- Drift tables for account-scoped contacts, alerts, incident events, delivery attempts, outbox operations, safe zones, check-ins, location history, and local incidents.
- Local SOS persistence before cloud ingestion and retry of pending alerts.
- Deterministic incident identifiers and conditional DynamoDB creation for idempotency.
- One FastAPI/Mangum backend surface for authenticated profile, contact notification, incident, assistant, push, responder, and mission operations.
- Versioned deterministic incident policy plus schema-validated Amazon Bedrock advisory reasoning. Bedrock cannot downgrade a hardware panic or directly authorize side effects.
- Conditional incident transitions, timeline events, DynamoDB-backed mission acceptance, coarse responder invitations, and short-lived navigation grants.
- OSM map display, OSRM walking routes, GPS location, and persisted safe-zone CRUD.
- Android release APK currently builds; Flutter and backend unit tests currently pass.

### Partial or unsafe to describe as production-ready

| Capability | Current truth | Production gap |
|---|---|---|
| Power-button panic | Foreground service journals a nonce-bound trigger and dispatches through a native queue without requiring Flutter | Readiness checks, configurable sensitivity/cancel behavior, OEM qualification, and physical locked/Doze/reboot tests remain |
| iOS covert hardware trigger | No equivalent implementation | Third-party apps cannot generally intercept arbitrary side-button sequences; must use supported Shortcuts, widgets, Action Button, Apple Watch, and notification actions |
| Community help | Production uses responder and mission tables, rejects unapproved responders, hides exact location until a scoped grant, and has no runtime responder fixtures | Enrollment/training UI, scalable geospatial query, complete mission lifecycle, abuse reporting, quorum/rendezvous policy, and field validation remain |
| Agentic response | Deterministic policy owns decisions; Bedrock receives coarse untrusted telemetry, returns validated advisory JSON, and cannot weaken hardware panic escalation | Durable tool/action ledger, policy authorization tokens, mission/disclosure policy, timeout tuning, grounded companion context, and red-team evaluations remain |
| Cognito OTP and sessions | Define/Create/Verify triggers, SAM wiring, expiry/attempt/cooldown limits, token refresh, and immediately enforced app-session revocation exist | Real staging challenge/session tests and step-up authentication for sensitive operations remain |
| Contacts | Account-scoped Drift is the on-device source and synchronizes canonical E.164 contacts with the profile endpoint | Server version/ETag conflict semantics and contact consent/channel verification remain |
| Check-ins | One Drift-backed provider restores deadlines and Android alarms after restart/reboot and escalates through the idempotent SOS path | Immutable event/delivery evidence and physical closed-app/reboot validation remain |
| Safe zones | CRUD is persisted | No continuous/background evaluation, hysteresis, dwell rules, or durable exit event |
| Notifications | SNS/FCM/APNs plumbing exists | Notification routes use an incompatible Navigator API; production credentials and end-to-end delivery evidence are absent |
| Backend | FastAPI on Lambda via Mangum is the production API; the older incident module remains only as an internal domain implementation | Rename the internal module, finish report APIs, typed OpenAPI client generation, and normalize remaining adapter errors |
| Navigation | Main shell and basic routes exist | No incident inbox/history, responder inbox, mission state routes, typed deep links, or emergency-safe route restoration |
| Tests | Unit suites exist | Integration tests contain placeholder assertions and do not verify real user journeys or process-death behavior |

### Misleading claims to remove until proven

The README currently presents several intended capabilities as completed. Documentation and UI must not claim any of the following until their acceptance tests pass on real devices:

- panic delivery with no app launch under all Android states;
- verified responders or a meaningful trust score;
- cryptographically gated coordinates;
- immutable audio evidence;
- guaranteed zero background drain;
- emergency-service dispatch.

### Hackathon MVP: the focused, defensible product

#### Hackathon scope freeze

The hackathon build is Android-first and intentionally narrow. It supports one protected-user flow, real trusted contacts, and a small manually approved responder cohort. The existing governed agent is sufficient for the MVP; no additional model orchestration, multi-agent framework, autonomous planning loop, or generalized tool platform will be added before the four remaining MVP deliverables are complete.

Public responder signup, automated identity verification, general moderation, scalable geospatial infrastructure, safe-zone automation, iOS emergency entry points, multilingual expansion, and store-scale operations are post-MVP. BLE/offline mesh relay, fall-detection ML, and wearable integrations are removed from product scope rather than deferred.

The winning MVP is not “AI decides whether a person deserves help.” It is a real, resilient emergency workflow in which deterministic software guarantees the safety action and an agent explains, coordinates, and adapts using verified evidence.

#### Demo story

1. The protected user enables Guardian Protection and completes a readiness check with at least one real E.164 trusted contact.
2. While the app UI is closed, a supported rapid power/screen sequence creates an encrypted native event with a stable nonce. The device acknowledges covertly, records location quality, attempts local SMS, and queues cloud ingestion.
3. The same incident appears after app launch; retries cannot create a second incident or reopen a resolved one.
4. The orchestrator gathers authorized incident context and runs deterministic risk policy. A hardware panic is always an immediate escalation candidate.
5. Amazon Bedrock receives coarse, explicitly untrusted telemetry and produces a schema-validated explanation/advisory. It cannot cancel, downgrade, broaden recipients, disclose exact location, or directly execute a tool.
6. Trusted-contact dispatch records provider acceptance/failure. If native SMS was already accepted, cloud SMS duplication is suppressed.
7. For a closed, pre-approved hackathon responder cohort, policy may issue capped coarse-area invitations. Acceptance creates a durable mission and only a short-lived, responder/incident-bound grant can reveal navigation data.
8. Resolution revokes grants and preserves an auditable timeline. The UI describes only evidence the system actually has.

If Bedrock, the cloud, or responder matching is unavailable, local SOS durability and configured device-side contact dispatch continue. The UI must say which channels succeeded, failed, or remain unknown.

#### Agent loop and authority boundary

```text
Observe authorized incident snapshot
        |
        v
Deterministic risk + trigger policy  ---- deny/allow reason + policy version
        |
        +----> mandatory action for hardware/manual panic
        |
        v
Bedrock advisory (coarse data, strict schema, no credentials/tools)
        |
        v
Policy reconciles proposal; model can explain but cannot weaken safeguards
        |
        v
Narrow idempotent tool: contact dispatch | invite responders | request check-in
        |
        v
Persist provider evidence + timeline + correlation ID; summarize actual outcome
```

For the MVP, the agent may:

- explain the deterministic risk decision in calm language;
- select wording from server-owned safety templates;
- recommend the next approved channel after a recorded failure;
- summarize contact and responder progress from persisted evidence;
- produce user guidance through the real Bedrock companion endpoint, or return an honest unavailable state.

For the MVP, the agent may not:

- invent delivery, acknowledgement, responder, police, or ambulance status;
- choose arbitrary recipients or contact the general public;
- lower the severity of manual/hardware panic;
- reveal exact coordinates without a valid mission grant;
- close an incident, suspend a person, or mutate trust/verification state;
- execute model-authored URLs, code, or free-form tool arguments.

#### Code-complete gate for the demo

- Real Cognito staging login and Guardian session revocation pass end to end.
- Hardware/manual SOS produces one durable incident and one traceable set of delivery attempts.
- Bedrock-enabled and Bedrock-unavailable runs reach the same mandatory safety action.
- Every agent side effect has an idempotency key, policy decision, correlation ID, and stored result evidence.
- Only approved, currently available responder accounts can receive a capped invitation.
- Uninvited, revoked, expired, or excess responders cannot obtain precise navigation data.
- The demo uses real test phone numbers/devices and explicitly labeled test recipients; no runtime fixtures or fabricated success states are present.
- Android release build and CI pass. iOS is outside the hackathon MVP and remains unverified until later macOS/Xcode work.

#### Only four remaining MVP deliverables

1. **Targeted invitations:** deliver coarse invitations to only policy-selected approved responder endpoints, persist transport evidence, and show an authenticated invitation inbox.
2. **Mission journey:** finish conditional mission transitions, bind navigation to the authenticated mission/grant, and revoke grants on every terminal or unsafe condition.
3. **Understandable demo:** add one readiness screen, one explicitly non-emergency real-recipient test flow, and one owner-safe incident/agent evidence timeline.
4. **Package and prove:** fix notification deep links, run the two-device Android staging flow, and build the distributable APK with its real staging endpoint and selected identity/signing.

The agent ledger, signed policy capabilities, deterministic quorum/cap/precision policy, bounded Bedrock calls, session revocation, and Android release compilation are already implemented. They are frozen except for defects discovered while completing these four deliverables.

## 3. Target architecture

```text
Trigger sources
  Android native panic | iOS supported shortcut/widget | in-app SOS
  check-in expiry | safe-zone rule | optional sensor signal
        |
        v
Durable on-device Emergency Event Journal
  append event -> acquire location -> local contact alert -> cloud retry
        |                      |                    |
        |                      |                    +-> SMS/dialer/push evidence
        |                      +-> encrypted local state
        +-> authenticated incident API (idempotency key)
                                   |
                                   v
                        Incident Orchestrator
                  deterministic policy/state machine
                    /          |             \
          trusted contacts   responder       emergency guidance
                             dispatch
                                |
                     coarse-area invitation
                                |
                     verified acceptance + quorum
                                |
                     short-lived mission grant
                                |
                   precise navigation/coordination
```

### Architectural boundaries

- **Mobile UI:** displays state and gathers intent. It is not the durable workflow engine.
- **Native emergency runtime:** receives platform triggers and writes a durable event before attempting Flutter or network work.
- **Local safety repository:** Drift is the authoritative on-device source for incidents, contacts, check-ins, delivery attempts, and sync state.
- **Incident API:** only authenticated ingestion and state transitions; every write is idempotent and ownership/role checked.
- **Policy engine:** deterministic risk and disclosure rules with versioned inputs and outputs.
- **Agent:** uses narrowly scoped tools after policy authorization. Bedrock produces summaries/explanations, not authorization decisions.
- **Responder service:** verification, availability, geospatial matching, invitations, acceptances, quorum, navigation grants, arrival, withdrawal, and reputation events.
- **Notification adapters:** SMS, SNS, FCM, and APNs report accepted/delivered/failed/unknown separately.

## 4. Emergency triggering without opening the app

### 4.1 Android target behavior

The user enables Guardian Protection during onboarding/settings. The app explains the persistent notification and battery settings. Once enabled:

1. `SafetyForegroundService` observes supported trigger signals.
2. A valid gesture creates a native `EmergencyTrigger` record in encrypted local storage/Room or an append-only file using an idempotency key.
3. The service immediately vibrates a configurable covert acknowledgement. It does not need an Activity.
4. The service starts a native emergency worker under Android foreground-work rules.
5. The worker obtains best available cached/fresh location with age and accuracy metadata.
6. It attempts configured local SMS and queues authenticated cloud ingestion.
7. A headless Flutter engine may process shared Dart orchestration, but native durability must not depend on it starting.
8. Opening Flutter reads the same journal and shows the active incident rather than creating another one.

Implementation requirements:

- Replace static callback-only handoff with a durable native event store and worker.
- Persist user ID alias, encrypted contact snapshot, access-token availability metadata, trigger preferences, and last safe location needed by the native path.
- Never store refresh/access tokens in plain SharedPreferences. Use Android Keystore-backed storage and a minimal native token bridge.
- Debounce screen transitions, reject impossible timing patterns, and enforce a refractory period after a valid trigger.
- Provide selectable 3/4/5 transition sensitivity and a safe test mode that cannot contact real recipients.
- Add a short cancellation window only if explicitly configured. Covert panic defaults to immediate local dispatch.
- Start after reboot only when the user opted in and required permissions remain valid.
- Detect force-stop, permission removal, location disabled, notification denial, battery restriction, and service death; show an honest “Protection degraded” state when the app next runs.
- Do not promise support on every OEM. Maintain a tested-device matrix and an in-app health check.

Important platform limitation: Android does not expose a formal “power button pressed N times” API to ordinary apps. Screen-state detection can work on many devices while a foreground service runs, but OEM behavior varies and a user force-stop disables receivers/services. The product must expose this limitation instead of guaranteeing universal behavior.

### 4.2 iOS target behavior

iOS must not claim direct interception of arbitrary side-button taps. Implement supported entry points:

- App Intent exposed to Siri and Shortcuts;
- lock-screen/Home Screen widget action where supported;
- Action Button shortcut on compatible devices;
- Apple Watch complication/action as a later dedicated target;
- notification action for check-in escalation;
- in-app SOS with an accessibility-friendly gesture.

Each entry point writes a durable local event and opens/continues the permitted background task. SMS must use supported user-confirmed composition unless an approved server messaging channel handles contact delivery.

### 4.3 Trigger conflict and false-positive controls

- One active incident per user unless a new trigger explicitly upgrades severity.
- Deduplicate by device ID, gesture time bucket, and trigger nonce.
- Coalesce shake, voice, and hardware signals occurring within the same incident window.
- Cancel requires device authentication or a duress-aware PIN policy; a simple unlocked button must not erase evidence.
- Offer a silent “false trigger, I am safe” resolution and a distinct “forced cancellation/duress” code.
- Never penalize a user automatically for cancelling; abuse decisions require evidence and appeal.

## 5. Emergency state machine and delivery evidence

Use one shared state model across Drift, API, DynamoDB, and UI:

```text
TRIGGERED
  -> LOCAL_DISPATCHING
  -> CLOUD_PENDING | CLOUD_ACCEPTED
  -> CONTACTS_NOTIFIED
  -> COMMUNITY_OFFERED
  -> RESPONDERS_ACCEPTED
  -> RESPONDERS_EN_ROUTE
  -> HELP_ARRIVED
  -> RESOLVED | CANCELLED | EXPIRED

Any non-terminal state -> DEGRADED when a required channel fails
Any state -> ESCALATED_TO_EMERGENCY_SERVICES only with a real supported action
```

Store transition records rather than overwriting history. Each transition includes actor, role, device, timestamp, policy version, reason, location quality, and correlation ID. Reject invalid or stale transitions server-side with conditional writes.

Delivery semantics:

- `queued`: stored locally or by provider;
- `accepted`: transport accepted the request;
- `delivered`: provider/device receipt exists;
- `acknowledged`: recipient explicitly responded;
- `failed`: final known failure;
- `unknown`: no reliable receipt.

The UI must use those exact meanings. “Notified” cannot mean only that an API call returned 200.

## 6. Nearby Guardian responder network

### 6.1 Roles

- **Protected user:** can create and manage their incident and trusted contacts.
- **Community responder:** can receive coarse invitations after identity and safety onboarding.
- **Verified responder:** has stronger identity/background/organization verification and may qualify for more sensitive missions.
- **Moderator/safety operator:** can review abuse evidence and suspend accounts; cannot browse live incidents without a case-bound reason.
- **Service role:** backend worker with a narrow IAM scope.

A user is never made a responder merely by installing the app. Responder mode is explicit, revocable, and off by default.

### 6.2 Responder onboarding

- Verify phone and email where available.
- Collect display alias separately from legal identity.
- Require safety code of conduct, non-confrontation training, privacy consent, and age eligibility.
- Add identity/organization verification suitable to launch geography.
- Register trusted device keys and push endpoint.
- Establish emergency contact and responder self-safety preferences.
- Start in a probation tier with constrained radius and no exact victim location.
- Trust is derived from verifiable events, not a hardcoded score.

### 6.3 Dispatch and privacy sequence

1. Policy decides whether community assistance is appropriate. Medical/fire/police guidance is never delayed waiting for volunteers.
2. Match responders using server-side geospatial indexes, recent opt-in heartbeat, capability, trust tier, distance, transport mode, and risk exclusions.
3. Send a coarse invitation: approximate area, incident category, distance band, safe rendezvous point, and explicit “do not confront” instruction.
4. Responder accepts; server authenticates their Cognito identity and verifies eligibility again.
5. Server creates a durable acceptance with a unique constraint on incident/responder.
6. For high-risk or isolated incidents, require a responder quorum or direct responders to a public rendezvous point. Never route a lone civilian toward a suspected attacker.
7. Issue a short-lived, incident-bound mission grant. Reveal only the minimum location precision required at that phase.
8. Responders share their own progress with the server while en route; the protected user sees count and verified status, not unnecessary identity data.
9. Arrival uses proximity plus an explicit check-in or rotating encounter code. GPS alone does not prove contact.
10. Incident resolution does not automatically expose either party’s future location.

### 6.4 Responder navigation

Add a dedicated responder shell and routes:

- `/respond` for the responder availability dashboard;
- `/respond/invitations`;
- `/respond/missions/:missionId` summary;
- `/respond/missions/:missionId/navigate` active navigation;
- `/respond/missions/:missionId/report` safety/abuse report.

Navigation behavior:

- Route first to a safe rendezvous point when policy requires it.
- Show turn list, reroute, remaining distance/time, other responder count, and “withdraw safely.”
- Keep a persistent mission banner if the responder leaves the screen.
- Cache the active route and minimal mission data for temporary network loss.
- Never display a historical victim-location trail to responders.
- Detect route deviation without assuming malicious intent; ask, then withdraw/reassign if necessary.
- Provide one-tap call to emergency services and a separate “I am also unsafe” action.

### 6.5 Misuse and edge cases

| Threat/edge case | Required control |
|---|---|
| Attacker creates an SOS to lure helpers | Coarse location first, safe rendezvous, quorum for isolated/high-risk areas, verified responders, withdrawal, server anomaly review |
| Stalker registers as responder | No global incident browsing, server-selected invitations, short-lived mission grants, progressive precision, device binding, access audit and rapid revocation |
| Responder accepts many missions to reveal locations | One/few active missions, eligibility recheck, rate limits, behavioral anomaly detection, no coordinates before assignment |
| Crowd converges on victim | Cap invitations/acceptances, stop dispatch at quorum, revoke excess grants, never public-broadcast exact location |
| Victim reports a legitimate responder | Immediate block/separation, preserve audit evidence, rotate grants/codes, moderator review, no direct re-contact |
| Responder harasses victim later | Ephemeral aliases/relay communication, no personal phone disclosure, location access expires, reporting and legal retention process |
| Fake/prank alerts | Tiered rate limiting and review; do not use automatic permanent punishment or discourage genuine repeated distress |
| Account takeover | Device-bound sessions, refresh-token rotation/revocation, step-up authentication for profile/contact changes, session list |
| Compromised phone under coercion | Duress PIN, silent escalation option, notification-content privacy, configurable covert feedback |
| GPS spoofing or stale location | Timestamp/accuracy/source, movement plausibility, multiple signals, label uncertainty; never silently replace stale with “live” |
| No responders nearby | Continue trusted-contact/cloud/local actions, clearly state none accepted, suggest safe public place/emergency services |
| Responder goes offline | Grace period, cached route, heartbeat expiry, reassignment without leaking new victim data |
| Victim moves rapidly | Versioned location snapshots, controlled updates to active grantees, reroute; suppress noisy updates |
| Incident resolves while responder travels | Immediate revocation/update, safe stop message, retain audit trail |
| Duplicate trigger after reboot/retry | Stable idempotency key and state restoration; no duplicate SMS/community dispatch |
| User has no contacts | Do not block SOS; cloud/community routes continue if permitted, UI warns during readiness setup |
| No SIM/SMS permission | Mark local channel unavailable, use cloud push/server messaging, expose degradation |
| No data and no SMS | Persist the event, show local emergency guidance, and retry authenticated cloud delivery when connectivity returns; do not claim off-device delivery |
| Battery critical | Reduce nonessential tracking while preserving trigger and retry; communicate degradation |
| Accessibility need | Screen-reader labels, high contrast, large targets, haptic/audio alternatives, no gesture-only critical action |
| Domestic-abuse privacy | Neutral notification mode, hidden sensitive previews, quick exit, protected settings changes |

## 7. Agentic safety design

### Appropriate agent responsibilities

- summarize incident context for contacts/responders without inventing facts;
- recommend an escalation playbook from approved options;
- choose message wording from server-controlled templates;
- correlate delivery failures and suggest the next channel;
- summarize responder progress for the protected user;
- identify anomalies for human review;
- provide localized, calm safety guidance.

### Responsibilities that remain deterministic

- creating and deduplicating incidents;
- access control and exact-location release;
- responder eligibility and mission grants;
- rate limits, quorum, and disclosure caps;
- sending an SOS explicitly requested by a user;
- state transitions and incident closure;
- retention/deletion policy;
- any claim that emergency services have been contacted.

### Agent execution contract

- Every tool call carries incident ID, actor/service identity, correlation ID, policy version, and idempotency key.
- Tool IAM is least privilege; read and write tools are separated.
- The agent cannot call arbitrary URLs or construct unrestricted recipient lists.
- Policy authorizes a proposed action before execution and records allow/deny reasoning.
- Tool results include evidence, not just booleans.
- Bedrock failure never blocks manual/local SOS.
- Prompts and model output are treated as untrusted data. Incident text cannot inject tool instructions.
- Model/version changes pass regression, red-team, hallucination, and latency evaluations before rollout.
- High-impact anomaly actions go to a human review queue; AI does not ban users autonomously.

### Current agent implementation versus MVP completion

| Layer | Implemented now | Required before the MVP is called complete |
|---|---|---|
| Observe | Incident context is loaded from the canonical incident/profile stores | Produce one redacted, versioned snapshot and reject stale context |
| Assess | Deterministic risk engine and mandatory hardware/manual panic policy | Move responder caps, quorum, invitation, and disclosure rules into the same versioned policy result |
| Reason | Real Bedrock Converse call, coarse location, low temperature, strict output schema, prompt-injection boundary | Add explicit client timeouts, authorized incident grounding, multilingual stress evaluations, and recorded model metadata |
| Authorize | Code policy selects the actual decision; Bedrock cannot downgrade hardware panic. Contact/community tools require signed, short-lived, incident/action-bound, atomically single-use capabilities | Extend the same policy service to mission quorum/disclosure decisions and rotate signing material operationally |
| Act | Contact/community side effects consume scoped capabilities; local SMS evidence suppresses duplicate cloud SMS; responder invitations no longer claim notification delivery | Split tool IAM further, add targeted responder push transport, move invitation caps into policy, and make every result retry-safe |
| Prove | Append-only ledger records proposal, policy decision, authorization, tool request/result, redacted evidence, final summary, and correlation ID | Expose an owner-safe redacted demo timeline and add operational retention/export controls |
| Degrade | Deterministic escalation continues when Bedrock is unavailable; assistant returns an honest unavailable error; Bedrock calls have bounded timeouts/retries | Add circuit-breaker metrics and staging evidence that Bedrock outage never changes mandatory dispatch behavior |

## 8. Data and API redesign

### Core records

- `User`: identity, profile, locale, account state, privacy settings.
- `Device`: installation ID, platform, push endpoint, public key, attestation state, last seen.
- `TrustedContact`: owner, normalized phone, relationship, channels, consent/verification state.
- `Incident`: owner, trigger, severity, current state, policy version, timestamps.
- `IncidentEvent`: immutable transition/action record.
- `LocationSnapshot`: encrypted coordinates, accuracy, source, captured/received times, retention class.
- `DeliveryAttempt`: channel, recipient reference, provider ID, state, attempts, timestamps.
- `ResponderProfile`: identity tier, training, capabilities, status, aggregate reputation.
- `ResponderAvailability`: coarse location/geohash, freshness TTL, radius, availability state.
- `Mission`: incident reference, responder, phase, grant scope/expiry, progress, outcome.
- `SafetyReport`: reporter, subject, incident, category, evidence references, review state.
- `CheckIn`: deadline, grace deadline, destination label, durable job/state.
- `SafeZone`: geometry, entry/exit policy, dwell/hysteresis, notification policy.

Sensitive location and evidence data must be encrypted with KMS-backed keys in cloud storage, separated from broad query indexes, and removed according to a documented retention schedule.

### API principles

- Deploy one API implementation. Prefer the FastAPI surface packaged for Lambda or a container, and delete/retire the divergent hand-written incident handler after parity.
- Cognito authorizer plus application-level role/resource checks on every protected route.
- Never accept `user_id`, `responder_id`, trust score, or role from a production request body as authority.
- Cursor pagination, bounded query radii, strict schemas, request-size limits, and normalized timestamps.
- Idempotency headers on all safety writes.
- Optimistic concurrency/version conditions on state changes.
- Structured errors with retryability and correlation IDs.
- Automatic client refresh-once for 401, then sign out; never loop retries.
- Exponential backoff with jitter and a dead-letter/recovery path.

Required route groups:

- `/auth/*`: working OTP challenge and refresh/revoke.
- `/me`, `/me/devices`, `/me/contacts`, `/me/readiness`.
- `/incidents`, `/incidents/{id}`, `/incidents/{id}/events`, `/incidents/{id}/resolve`.
- `/responder/profile`, `/responder/availability`, `/responder/invitations`.
- `/missions/{id}/accept|decline|heartbeat|arrive|withdraw|complete`.
- `/missions/{id}/navigation-grant` with minimum necessary disclosure.
- `/reports` and user-visible access/audit history.
- `/push/register|unregister` with endpoint ownership.

The current victim-owned `/incidents/{id}/nearby` route must not be the responder discovery mechanism. Responders receive server-generated invitation resources that reveal only authorized fields.

## 9. Offline-first behavior

### Local-first consolidation

- Make Drift the single source for contacts, incidents, check-ins, and safe zones.
- Migrate existing SharedPreferences contacts once, verify row counts, then remove old keys.
- Add outbox rows for every cloud mutation with operation ID, entity version, retry count, next attempt, and last error.
- Process creates before dependent updates and ensure a late create cannot resurrect a resolved incident.
- Restore active incident/check-in state on startup and after reboot.

## 10. Navigation and UX architecture

### Primary protected-user navigation

Keep four stable tabs:

1. **Home:** protection health, check-in, active incident card, readiness problems.
2. **Map:** own position, chosen destination, safe route, safe places; no public victim pins.
3. **Circle:** trusted contacts and their verification/delivery readiness.
4. **Settings:** privacy, triggers, permissions, responder enrollment, account/security.

SOS remains a persistent high-priority action, not a fifth tab. During an incident, the entire app shows a persistent incident banner leading to `/incidents/:id`.

### Required route model

- Typed route data instead of unvalidated `extra` maps.
- Stateful shell branches so each tab preserves its stack.
- Dedicated incident details/history and active emergency mode.
- Separate responder shell so protected-user and responder tasks are not mixed.
- One notification/deep-link router integrated with `go_router`; remove `Navigator.pushNamed` calls.
- Cold-start deep links wait for auth restore, validate authorization, then route or show a safe expired-link page.
- Back navigation cannot dismiss an active emergency workflow or reveal a sensitive previous screen on the lock-screen app switcher.
- Notification payload contains opaque resource IDs, never exact coordinates or victim names.

### Practical emergency UX

- Always show channel status: local SMS, cloud, contacts, responders, location freshness.
- Use verbs like “queued,” “sent,” “accepted,” and “arrived” precisely.
- Large targets, one-handed layouts, screen-reader announcements, reduced-motion support.
- Covert mode hides sensitive notification text and supports neutral app-switcher snapshots.
- Readiness wizard verifies contacts, trigger health, permissions, push token, battery restrictions, and performs a non-emergency test.
- Test mode uses explicitly marked test recipients/environment and cannot be confused with a real incident.

## 11. Authentication, security, and privacy

- Implement Cognito Define/Create/Verify custom challenge Lambdas or switch to a fully supported passwordless Cognito flow; do not ship the current incomplete hybrid.
- Rate-limit OTP by phone, device, IP risk, and account; use generic responses to prevent enumeration.
- Add WAF/API throttles, schema validation, abuse quotas, and alerting.
- Bind responder operations to token subject and server role/claims.
- Use Android Play Integrity and Apple App Attest/DeviceCheck as risk signals, never as the only access decision.
- Rotate/revoke sessions and push endpoints; list devices to the user.
- Redact phone, token, coordinates, OTP, and message bodies from logs and crash reports.
- Use TLS only, certificate/public-key pinning only if an operational rotation plan exists.
- Encrypt local sensitive fields using platform keystores; Drift file encryption should be evaluated and implemented before production data.
- Add data export/deletion, consent records, retention jobs, and incident legal-hold exceptions.
- Complete a threat model and privacy impact assessment for each launch region.
- Review Android SMS, background location, foreground-service, microphone, and iOS background-mode/store policies before release.

## 12. Safe zones, check-ins, and sensor intelligence

### Check-ins

- Delete the duplicate in-memory design and keep one Drift-backed repository.
- Schedule platform-native alarms/background tasks with exactness limitations documented.
- Restore timers after process death/reboot/timezone change.
- Notification actions call the same durable command path as UI actions.
- Grace expiry creates a real idempotent emergency event, not a log message.
- Contact updates state whether the timer expired, was extended, or the user arrived safely.

### Safe zones

- Feed evaluation from a battery-aware location stream/background geofencing API.
- Add hysteresis, minimum dwell time, accuracy threshold, stale-location rejection, and cool-down.
- Define entry/exit rules per zone and persist every generated event.
- Never infer danger from a single inaccurate fix.

### Fall/anomaly detection

- Do not ship claims of ML fall detection without a trained, versioned model and real-device validation.
- Start with transparent multi-signal heuristics, user confirmation, and conservative escalation.
- Track false positives/negatives without storing unnecessary raw sensor data.
- Clearly label confidence and preserve manual SOS priority.

## 13. Observability and operations

- Structured logs with correlation ID and no PII.
- Metrics: trigger-to-local-queue latency, location age/accuracy, cloud acceptance latency, contact delivery states, responder invite/accept/arrival times, duplicate suppression, false-trigger reports, and degraded-device count.
- Distributed traces across API, event bus, policy engine, notifications, and mission service.
- Alarms for ingestion errors, queue age, push failure spikes, OTP abuse, unauthorized location access, and state-machine violations.
- Dead-letter queues and an operator replay tool that preserves idempotency.
- Auditable administrative access with least privilege and break-glass approval.
- Feature flags and staged rollout by platform/OEM/region.

## 14. Testing and release gates

### Automated layers

- Unit tests for state transitions, trigger debounce, deduplication, disclosure policy, geospatial selection, retries, and redaction.
- Contract tests generated from one OpenAPI schema for Flutter and backend.
- Integration tests with real local dependencies/emulators; test doubles are allowed only in tests and must be clearly scoped.
- Android instrumentation tests for locked screen, background, process death, reboot, permission revocation, Doze, low battery, no SIM, no data, and OEM task killing.
- iOS tests for supported App Intent/widget/notification paths, termination, and permission states on macOS hardware.
- End-to-end staging tests using designated test phone numbers/devices and isolated AWS resources.
- Security tests for IDOR, role escalation, OTP abuse, replay, forged beacons, prompt injection, and location leakage.
- Accessibility and localization tests.
- Load/chaos tests for regional spikes and provider outages.

### Release gates

- No placeholder integration assertions.
- No production default IDs, local responder fixtures, simulation endpoints, debug signing, or example package IDs.
- Android release signed with managed production key; iOS archive signed with production bundle/team.
- Push configuration works on physical Android and iOS devices.
- All product claims map to a passing acceptance test and supported device list.
- Independent security/privacy review completed for the responder network.
- Emergency disclaimer and region-specific emergency numbers reviewed.

## 15. Implementation phases

### Phase 0 — Truth, contracts, and safety invariants

Freeze new feature claims. Define incident/mission states, API schema, delivery semantics, data classification, threat model, and acceptance tests. Correct README/UI wording.

Exit: one approved architecture contract and no known false production claims.

### Phase 1 — Reliable local emergency core

Unify contacts in Drift, add durable event/outbox schema, restore active incidents, consolidate check-ins, and make all trigger sources use one idempotent command.

Exit: manual SOS and check-in escalation survive restart and accurately report local delivery.

### Phase 2 — Native trigger durability

Implement Android native event journal/worker, secure native configuration snapshot, process-death/reboot handling, trigger health, and real-device matrix. Add supported iOS App Intent/widget paths on macOS.

Exit: tested emergency trigger paths do not depend on an already-running Flutter Activity, within documented OS limits.

### Phase 3 — One secure backend

Complete Cognito OTP, deploy one API architecture, add idempotent state transitions, ownership/roles, refresh-once client behavior, outbox retries, and production-grade observability contracts.

Exit: staging end-to-end incident lifecycle works without dev fallbacks.

### Phase 4 — Trusted contacts and notifications

Complete contact verification/consent, push registration, notification deep links, delivery evidence, resolution messages, and channel degradation UX.

Exit: physical-device tests prove send/receive/acknowledge flows on Android and iOS.

### Phase 5 — Controlled responder MVP

Build responder enrollment, availability, invitation, durable mission lifecycle, progressive disclosure, safe rendezvous, quorum, navigation, reporting, and moderation queue. Launch initially with a closed verified cohort, not the general public.

Exit: no responder can browse incidents or obtain exact location without a valid, short-lived mission grant; all access is audited.

### Phase 6 — Navigation and safety automation

Implement stateful typed routing, incident history, responder shell, robust deep links, safe-zone monitoring, and restored check-ins.

Exit: all cold/warm notification routes and interrupted workflows recover correctly.

### Phase 7 — Agent hardening

Put policy authorization around tools, persist action evidence, add prompt-injection defenses/evals, constrain IAM, and distinguish deterministic actions from model-generated guidance.

Exit: Bedrock outage or malicious incident text cannot prevent, forge, broaden, or close an emergency action.

### Phase 8 — Release hardening

Remove dead code/dev endpoints, upgrade build tooling, production identifiers/signing, physical-device matrix, accessibility, localization, policy review, penetration test, staged beta, and rollback drills.

Exit: store-ready builds and operational runbooks, with AWS production provisioning performed separately.

## 16. Definition of done

A capability is complete only when:

- it uses real production code paths with no runtime fixture/default identity;
- its failure and offline behavior are explicit;
- authorization and privacy tests pass;
- state survives process death where the promise requires it;
- observability can prove what occurred without exposing sensitive data;
- UI language matches delivery evidence;
- Android and iOS platform limits are documented;
- automated tests and at least one relevant physical-device test pass;
- support, rollback, retention, and abuse procedures exist.
