# Guardian Phase 4 — Final Critical Repair Report

## Scope

This report records the code-level completion state of the automatic-SOS and agentic-reliability repair pass on `phase4-critical-repair`. It distinguishes automated/code verification from work that still requires AWS staging or physical-device validation.

## Final verified issue register

| Area | Severity | Status | Evidence / implementation |
|---|---:|---|---|
| Agent initial execution lease | P0 | Fixed | Dedicated `agent_execution_state` / run lease is separate from `agent_decision`; duplicate runs are suppressed atomically. |
| Agent timeout routing | P0 | Fixed | Initial reasoning, user-verification timeout, and responder-escalation timeout use separate deterministic handlers. |
| EventBridge Scheduler role/runtime | P0 | Fixed | SAM defines scheduler role, pass-role permission, Lambda invoke trust, and required scheduler runtime imports. |
| SAM YAML merge lint failure | P0 | Fixed | Shared YAML merge anchor removed; `sam validate --lint` is a required CI gate. |
| Native Android cloud endpoint/auth contract | P0 | Fixed | WorkManager posts to `/incidents` with Cognito access token plus `X-Guardian-Session-ID`, stable event ID, and API-compatible payload. |
| Native contact snapshot overwriting auth | P0 | Fixed | Emergency configuration and cloud-auth records are stored separately. |
| Native access-token refresh | P1 | Fixed | Worker uses the existing Guardian refresh endpoint and retries the same event identity. |
| Native event retention | P1 | Fixed | Unresolved events are not trimmed simply because the journal exceeds the nominal retention count. |
| Native GPS timestamp replay | P0 | Fixed | Original native GPS capture time remains distinct from emergency occurrence/import time. |
| Native/Flutter duplicate trigger callbacks | P0 | Fixed | One native callback owns trigger authority; anomaly callbacks are supplemental evidence. |
| Trigger priority / refractory window | P0 | Fixed | Explicit distress can upgrade/override lower-confidence automatic triggers instead of being suppressed by a global cooldown. |
| Check-in AlarmManager vs Flutter race | P0 | Fixed | Both paths converge on a shared native `operation_id` and canonical native event. |
| Route-deviation Flutter/native policy mismatch | P1 | Fixed | Native confirmation/countdown is authoritative; Flutter mirrors/imports the confirmed native event rather than bypassing confirmation. |
| Straight-line route fallback causing false deviation | P1 | Fixed | Native route monitoring is cleared/disabled when only degraded straight-line geometry is available. |
| Per-recipient SMS fallback | P1 | Fixed | Cloud fallback skips only the contact with local OS-accepted evidence. |
| Dev-mode fake delivery | P1 | Fixed | `DEV_MODE_NOT_SENT` is not treated as provider acceptance for SMS or responder invitations. |
| SMS provider failure blocking responders | P0 | Fixed | Contact and responder actions execute independently and record separate outcomes. |
| Automatic responder radius progression | P1 | Fixed | Community dispatch starts the same 1→2→5→10 km engine; zero reachable invitations widen immediately; scheduled checks handle pending accepted deliveries. |
| Responder withdrawal recovery | P1 | Fixed | Withdrawal with no remaining active accepted responder re-enters deterministic redispatch. |
| EventBridge incident-created failure recovery | P1 | Fixed | Incident stores orchestration state; idempotent re-create retries event emission when the previous emission was not recorded as emitted. |
| Concurrent agent/tool side effects | P0 | Fixed | Initial agent execution and individual external actions have independent atomic execution claims. |
| Bedrock authority boundary | P0 | Fixed | Bedrock remains schema-validated advisory input; deterministic policy/capabilities authorize side effects. |
| Responder enrollment evidence digests | P2 | Fixed/limited | Hash evidence is stored for manual review; the repository does not implement a full document-storage/identity-verification provider. |
| Android Kotlin release compilation | P0 | Fixed | Native Kotlin changes compile under the release APK CI build. |

## Trigger matrix

| Trigger | Current status | Background / locked Android | Flutter-dead Android | Cloud-capable | Confirmation / policy |
|---|---|---:|---:|---:|---|
| Manual in-app SOS | Implemented | No — requires app interaction | No | Yes | Explicit; immediate after user countdown/activation |
| Android power/screen panic | Implemented | Yes while native safety service is operating | Yes | Yes through native WorkManager outbox | Explicit; immediate |
| Android native shake | Implemented | Yes while native safety service is operating | Yes | Yes through native WorkManager outbox | Inferred; deterministic verification policy |
| Flutter shake fallback | Implemented while Flutter is active | App/runtime dependent | No | Yes | Inferred; deduped against active/native emergency state |
| Android native fall | Implemented heuristic detector | Yes while native safety service is operating | Yes | Yes through native WorkManager outbox | Inferred; deterministic verification policy |
| Scheduled check-in expiry | Implemented | Yes via AlarmManager | Yes | Yes through native WorkManager outbox | User-preauthorized timer; shared operation identity |
| Route deviation | Implemented for authoritative route geometry | Yes via native route monitor | Yes | Yes once confirmation/timeout creates canonical event | Confirmation first; degraded straight-line route does not arm deviation SOS |
| Voice SOS | Code-only / not product-wired | No production claim | No | N/A | Deliberate phrases exist in helper code, but no normal runtime start caller is present |
| Screen/UI multi-tap | Code-only / not product-wired | No production claim | No | N/A | `registerTap()` has no product caller; do not advertise as an active trigger |
| Native screen/power gesture | Implemented separately from UI multi-tap | Yes | Yes | Yes | Explicit hardware gesture |

## Agentic workflow

```text
incident persisted
  -> incident.created EventBridge emission
  -> atomic initial-agent lease
  -> deterministic context/risk assessment
  -> optional schema-validated Bedrock advisory
  -> deterministic safety policy
  -> short-lived action-scoped policy authorization
  -> independently idempotent contact/responder actions
  -> backend-owned verification/escalation fallback timers
  -> responder mission lifecycle + temporary precise-location grants
```

Bedrock is not treated as an authorization source. It cannot directly mint capabilities, execute arbitrary tools, cancel an explicit SOS, or independently expose precise victim location.

## Failure behavior

| Failure | Expected behavior |
|---|---|
| No network during Android native SOS | Native event and local telephony evidence remain durable; WorkManager retries the same event when connectivity returns. |
| Flutter process is dead | Android native triggers, direct SMS submission attempt, encrypted event journal, and WorkManager cloud outbox remain available subject to Android/permission/OEM constraints. |
| Cognito access token expires | Native worker uses Guardian refresh flow when stored refresh/session context is valid, then retries the same event. |
| AWS/SNS SMS unavailable | Contact action records failure; responder dispatch remains independently eligible to execute. |
| Bedrock unavailable | Deterministic safety policy continues without model advisory. |
| Push invitation unavailable | Mission delivery remains failed/not-sent; the escalation engine does not treat the mission row as a responder being reached. |
| Zero reachable responders | Search widens immediately through configured stages rather than waiting on a response that cannot arrive. |
| EventBridge publish fails | Incident stores failed orchestration state; an idempotent incident re-create retries the emission. |
| Duplicate EventBridge delivery | Initial agent lease and action-level claims prevent duplicate side effects. |
| Incident becomes terminal | Timeout/redispatch paths check terminal state and become no-ops; active mission cleanup/revocation is applied by terminal transition handling. |
| GPS is stale | Original capture time is preserved; backend freshness cannot be made newer merely by replay/import time. |
| Account changes | Native emergency configuration and cloud auth are account-bound; worker rejects owner/auth mismatch. |

## Delivery truth

The Android native SMS transport currently treats successful platform submission as OS acceptance/submission evidence. The repository does **not** yet persist end-to-end carrier handset-delivery receipts; therefore `DELIVERED` must not be presented as a transport result unless real delivery evidence is later added.

Push provider acceptance likewise means the provider accepted the request, not that a human responder saw or accepted the mission.

## Verification levels

- **Code verified:** architecture and repaired code paths reviewed.
- **Automated verified:** backend and Flutter regression suites cover critical orchestration/idempotency invariants.
- **CI build verified:** backend tests, SAM validation/build, Flutter formatting/analyze/tests, Android release APK build, and iOS simulator build are required to pass on the final PR head.
- **AWS staging verified:** not implied by local/CI tests; production credentials/provider configuration must be exercised separately.
- **Physical device verified:** not implied by CI; Android hardware/background behavior still requires the device matrix below.

## Remaining limitations

1. Physical Android tests are still required for locked screen, Doze, reboot, OEM task killing, real SMS permission/radio behavior, sensor false positives, and the exact AlarmManager/Flutter race.
2. AWS SMS production access/provider approval is external to this codebase; cloud SMS failure is now isolated from responder dispatch.
3. Voice SOS helper code exists but is not product-wired and should not be advertised as an active safety trigger.
4. UI/screen multi-tap helper code exists but has no product caller; the native power/screen panic is a separate implemented trigger.
5. iOS does not have Android-equivalent native power/shake/fall/direct-SMS/no-Flutter durability; see `IOS_PARITY_MATRIX.md`.
6. Responder enrollment stores evidence digests for manual review but is not a complete third-party identity-verification/KYC system.
7. Public OSM/Nominatim/OSRM productionization and any Google Maps migration are outside this repair phase.

## Physical Android test matrix

Before production promotion, execute and record outcomes for:

- app foreground/background;
- Flutter process killed;
- screen locked;
- reboot;
- Doze/battery optimization;
- no network then reconnect;
- GPS disabled/stale/low-accuracy;
- SMS permission denied;
- notification permission denied;
- power/screen panic;
- shake false-positive scenarios (walking/running/vehicle/bag movement);
- controlled fall simulation using safe methodology;
- check-in expiry with Flutter alive and killed;
- simultaneous AlarmManager/Flutter check-in deadline;
- route deviation with authoritative route geometry;
- logout/account switch with pending native event.

Do not mark those scenarios as physically verified until they have been executed on representative devices.
