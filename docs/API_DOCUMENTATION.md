# Guardian API Documentation

Current API contract: Phase 5 pre-production hardening baseline.

## Authentication

### Production sign-in

Production users authenticate with Google through Cognito managed login using authorization-code + PKCE. The mobile client exchanges the Cognito authorization code directly with Cognito, then creates a Guardian device session:

`POST /auth/session`

Request:
```json
{
  "access_token": "<Cognito access token>",
  "refresh_token": "<Cognito refresh token>",
  "device_label": "Guardian Android device",
  "platform": "android"
}
```

The backend resolves the immutable Cognito subject and returns the Guardian session metadata. Protected API requests then require:

```text
Authorization: Bearer <Cognito access token>
X-Guardian-Session-ID: <Guardian session UUID>
```

Cognito ID tokens are not accepted as protected API bearer tokens.

`POST /auth/google` exists only for explicit development-mode tests and is retired in production. Phone OTP endpoints do not exist.

### Session endpoints

- `POST /auth/refresh` — refresh Cognito access/id tokens after validating the Guardian session and refresh-token hash.
- `POST /auth/sign-out` — global Cognito sign-out, revoke Guardian sessions, and disable user-bound push endpoints.
- `GET /auth/sessions` — list current account sessions.
- `DELETE /auth/sessions/{session_id}` — revoke one owned session and disable its push endpoints.

## Maps

All routes below are protected and use Guardian's server-only Google Maps Platform credential.

- `POST /maps/places/autocomplete`
- `POST /maps/places/details`
- `POST /maps/routes/walking`

Google route geometry is ordinary route data. Guardian does not label it as a verified safe route.

## Users and devices

- `GET /users/{user_id}` — owner profile read.
- `PUT /users/{user_id}` — owner profile update.
- `POST /users/{user_id}/contacts` — replace owned emergency-contact list.
- `POST /users/{user_id}/device` — register an FCM/APNs token to the authenticated Guardian session and stable device ID.

Device registration request:
```json
{
  "device_token": "<FCM-or-APNs token>",
  "device_id": "<stable local device UUID>",
  "platform": "android"
}
```

A token rebound to another account/session disables the previous Guardian binding.

## Emergency incidents

### `POST /incidents`

Creates an idempotent incident from a stable `event_id`.

```json
{
  "event_id": "client-event-uuid",
  "event_type": "MANUAL_SOS",
  "location": {
    "latitude": 18.52,
    "longitude": 73.85,
    "accuracy": 12.0,
    "captured_at": "2026-09-25T12:00:00Z",
    "source": "gps"
  },
  "motion_data": {
    "trigger_source": "button"
  }
}
```

The authenticated owner is supplied by the API boundary, not trusted from the body. Duplicate `event_id` creates return the same deterministic incident and repair orchestration emission if required.

### Other owner incident routes

- `GET /incidents/{incident_id}`
- `PUT /incidents/{incident_id}/status`
- `POST /incidents/{incident_id}/location`
- `GET /incidents/{incident_id}/timeline`
- `GET /incidents/{incident_id}/nearby`
- `POST /incidents/{incident_id}/dispatch-community`
- `POST /incidents/{incident_id}/escalate-dispatch`
- `GET /incidents/{incident_id}/escalation-status`
- `POST /incidents/{incident_id}/agent-step`
- `POST /incidents/{incident_id}/escalate`

Victim-location updates are conditional on ownership, nonterminal incident state, and a strictly newer captured timestamp.

## Responder APIs

Responder operations require the Cognito responder role plus server-side approval/trust checks where applicable.

- `POST /responders/enroll` — submit evidence digests for manual review.
- `POST /responders/heartbeat` — update active availability/location. Current server availability TTL is approximately 30 minutes; mobile heartbeat cadence is approximately 15 minutes plus movement-triggered updates.
- `GET /responders/invitations`
- `GET /responders/missions`
- `GET /missions/{mission_id}`
- `PUT /missions/{mission_id}/status`
- `POST /missions/{mission_id}/renew-grant`

### Accept an invitation

`POST /incidents/{incident_id}/accept`

Acceptance is transactionally conditioned on:
- incident nonterminal,
- responder approval/trust,
- mission still `INVITED`,
- invitation unexpired,
- mission bound to caller,
- accepted-responder capacity below the configured maximum.

A successful response includes a short-lived navigation grant.

### Read current authorized victim location

`POST /incidents/{incident_id}/authorized-location`

Requires the valid mission-bound navigation grant. The response includes coordinates plus accuracy, capture time, age, source, and freshness. Stale coordinates must be presented as last-known, not current.

## Notifications

- `POST /notifications/contacts` — server-authored owned-contact safety update.
- `POST /notifications/contact-test` — explicit non-emergency test to an owned contact.
- `POST /push/send` — push to authenticated user's currently enabled session-bound endpoints.
- `POST /push/sms` — development-only direct SMS route; production emergency contact SMS is server-side policy/tool behavior.

Provider/OS acceptance is not handset-delivery proof.

## Abuse reports

`POST /incidents/{incident_id}/report`

Only the incident owner or a responder associated with that incident may submit a report. Reports are separate TTL-backed moderation records; they do not suppress an SOS.

## Error semantics

- `401` — missing/invalid access token, revoked/invalid Guardian session.
- `403` — authenticated but not authorized for the resource/role.
- `404` — resource unavailable to caller.
- `409` — state/concurrency conflict when exposed by the route adapter.
- `422` — request validation failure.
- `503` — required service temporarily unavailable.

Operational clients should use the structured error payload and correlation ID rather than parsing provider-specific exception text.
