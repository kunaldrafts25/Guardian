# Guardian Public & Protected API Documentation

This document defines the REST API endpoints served by the Guardian AWS Serverless backend (`aws/server.py` via AWS Lambda and Amazon API Gateway).

---

## Global Authentication & Security Headers

All endpoints except `GET /health` and `POST /auth/phone/*` or `POST /auth/google` require:

1. **Bearer Authentication**: `Authorization: Bearer <cognito_access_token>`
2. **Guardian Session Verification**: `X-Guardian-Session-ID: <session_uuid>`
3. **Correlation Tracking**: `X-Correlation-ID: <uuid>` (auto-injected by API Gateway if missing)

---

## 1. Authentication & Session Endpoints

### `POST /auth/send-otp`
- **Purpose**: Initiates SMS OTP delivery via Amazon Cognito Custom Challenge.
- **Auth**: None (Public)
- **Role**: Any
- **Request Schema**:
  ```json
  {
    "phone_number": "+919876543210" // E.164 format
  }
  ```
- **Response Schema** (200 OK):
  ```json
  {
    "session": "cognito_challenge_session_string",
    "delivery_medium": "SMS",
    "recipient": "+919876543210"
  }
  ```
- **Error Codes**: `400 Bad Request` (invalid phone format), `500 Internal Error` (Cognito failure).
- **Privacy Level**: Restricted (phone number PII).

### `POST /auth/verify-otp`
- **Purpose**: Verifies phone SMS OTP, returns Cognito JWT tokens, and issues an authenticated Guardian device session.
- **Auth**: None (Public challenge)
- **Role**: Any
- **Request Schema**:
  ```json
  {
    "phone_number": "+919876543210",
    "otp_code": "123456",
    "session": "cognito_challenge_session_string",
    "device_label": "Pixel 8 Pro",
    "platform": "android"
  }
  ```
- **Response Schema** (200 OK):
  ```json
  {
    "access_token": "ey...",
    "id_token": "ey...",
    "refresh_token": "ey...",
    "expires_in": 3600,
    "user_id": "cognito-sub-uuid",
    "session_id": "guardian-session-uuid"
  }
  ```
- **Error Codes**: `401 Unauthorized` (invalid or expired OTP), `500 Internal Error`.
- **Privacy Level**: Highly Sensitive (Tokens & Session ID).

### `POST /auth/refresh`
- **Purpose**: Refreshes expired access tokens. Validates matching `session_id`.
- **Auth**: None (Uses `refresh_token` and `session_id`)
- **Request Schema**:
  ```json
  {
    "refresh_token": "ey...",
    "session_id": "guardian-session-uuid"
  }
  ```
- **Response Schema** (200 OK):
  ```json
  {
    "access_token": "ey...",
    "id_token": "ey...",
    "session_id": "guardian-session-uuid"
  }
  ```
- **Error Codes**: `401 Unauthorized` (revoked session or invalid refresh token).

### `POST /auth/sign-out`
- **Purpose**: Global logout from Cognito and revokes all active sessions for user.
- **Auth**: Required (`Bearer` + `X-Guardian-Session-ID`)
- **Response Schema** (200 OK): `{"success": true}`

### `GET /auth/sessions`
- **Purpose**: List all active sessions and registered devices for authenticated user.
- **Auth**: Required
- **Response Schema** (200 OK):
  ```json
  {
    "sessions": [
      {
        "session_id": "sess-1",
        "device_label": "Pixel 8 Pro",
        "platform": "android",
        "created_at": "2026-09-24T12:00:00Z",
        "last_seen_at": "2026-09-24T12:30:00Z",
        "current": true
      }
    ]
  }
  ```

### `DELETE /auth/sessions/{session_id}`
- **Purpose**: Revoke a specific session (remotely logs out that device).
- **Auth**: Required
- **Error Codes**: `404 Not Found` (session does not exist or owned by another user).

---

## 2. Emergency Incident Endpoints

### `POST /incidents` (Status: 201 Created)
- **Purpose**: Create a new emergency incident and trigger deterministic safety policy / Bedrock evaluation.
- **Auth**: Required (`Bearer` + `X-Guardian-Session-ID`)
- **Role**: Protected User
- **Idempotency**: Enforced by `event_id` (client nonce). Submitting the same `event_id` returns the existing incident without duplicating alerts.
- **Request Schema**:
  ```json
  {
    "event_id": "b7891234-5678-4321-abcd-ef0123456789", // Client nonce
    "event_type": "sos_button_hold", // "fall_detected", "hardware_panic", etc.
    "location": {
      "latitude": 19.0760,
      "longitude": 72.8777,
      "accuracy": 12.5,
      "captured_at": "2026-09-24T12:00:00Z",
      "source": "gps"
    },
    "motion_data": null
  }
  ```
- **Response Schema** (201 Created):
  ```json
  {
    "incident_id": "inc-456789",
    "event_id": "b7891234-5678-4321-abcd-ef0123456789",
    "user_id": "cognito-sub-uuid",
    "state": "ACTIVE",
    "created_at": "2026-09-24T12:00:01Z",
    "initial_location": { ... },
    "current_location": { ... }
  }
  ```
- **Privacy Level**: Highly Sensitive (Victim GPS location).

### `GET /incidents/{incident_id}`
- **Purpose**: Retrieve current incident state and timeline metadata.
- **Auth**: Required
- **Authorization**: Caller must be incident owner (`user_id`).
- **Response Schema** (200 OK): Full incident document including `state`, `escalation_stage`, `missions`.

### `PUT /incidents/{incident_id}/status`
- **Purpose**: Transition incident state (e.g. `RESOLVED`, `CANCELLED`).
- **Auth**: Required (Owner only)
- **Request Schema**:
  ```json
  {
    "state": "RESOLVED", // "ACTIVE", "RESOLVED", "CANCELLED"
    "note": "User safely reached destination"
  }
  ```
- **Side Effects**: Automatically cancels and completes all active responder missions and revokes all navigation grants.

### `POST /incidents/{incident_id}/location`
- **Purpose**: Continuous victim GPS tracking updates for an active emergency.
- **Auth**: Required (Incident owner only)
- **Request Schema**:
  ```json
  {
    "location": {
      "latitude": 19.0765,
      "longitude": 72.8780,
      "accuracy": 8.0,
      "captured_at": "2026-09-24T12:01:30Z",
      "source": "gps"
    }
  }
  ```
- **Response Schema** (200 OK):
  ```json
  {
    "incident_id": "inc-456789",
    "updated_at": "2026-09-24T12:01:31Z",
    "freshness": "FRESH"
  }
  ```
- **Error Codes**: `403 Forbidden` (not owner), `409 Conflict` (incident is terminal `RESOLVED`/`CANCELLED`).

---

## 3. Responder & Mission Endpoints

### `POST /responders/heartbeat`
- **Purpose**: Responder availability heartbeat. Updates geohash position in DynamoDB with 300s TTL.
- **Auth**: Required
- **Role**: `responder`
- **Request Schema**:
  ```json
  {
    "latitude": 19.0760,
    "longitude": 72.8777,
    "is_active": true
  }
  ```
- **Response Schema** (200 OK):
  ```json
  {
    "responder_id": "user-uuid",
    "status": "AVAILABLE",
    "geohash": "te7u8",
    "availability_expires_at": 1790250000
  }
  ```

### `GET /responders/invitations`
- **Purpose**: Lists pending coarse-location emergency invitations for the authenticated responder.
- **Auth**: Required
- **Role**: `responder`
- **Response Schema** (200 OK):
  ```json
  {
    "invitations": [
      {
        "mission_id": "mis-101",
        "incident_id": "inc-456789",
        "status": "INVITED",
        "coarse_location": {
          "approx_latitude": 19.08,
          "approx_longitude": 72.88,
          "distance_meters": 450.0
        },
        "expires_at": "2026-09-24T12:05:00Z"
      }
    ]
  }
  ```

### `POST /missions/{mission_id}/accept`
- **Purpose**: Responder formally accepts an emergency invitation. Issues a single-use navigation grant.
- **Auth**: Required
- **Role**: `responder`
- **Concurrency**: Capped at `MAX_ACCEPTED_RESPONDERS` (2). Returns `409 Conflict` if quota already met.
- **Response Schema** (200 OK):
  ```json
  {
    "mission_id": "mis-101",
    "status": "ACCEPTED",
    "navigation_grant": "grant-secret-uuid-token",
    "grant_expires_at": "2026-09-24T12:15:00Z"
  }
  ```

### `POST /incidents/{incident_id}/authorized-location`
- **Purpose**: Exchanges a valid navigation grant for the real, precise GPS coordinates of the victim.
- **Auth**: Required
- **Role**: `responder`
- **Request Schema**:
  ```json
  {
    "navigation_grant": "grant-secret-uuid-token"
  }
  ```
- **Response Schema** (200 OK):
  ```json
  {
    "latitude": 19.076543,
    "longitude": 72.878012,
    "accuracy": 8.0,
    "freshness": "FRESH",
    "age_seconds": 4.2,
    "captured_at": "2026-09-24T12:01:30Z"
  }
  ```
- **Error Codes**: `403 Forbidden` (invalid grant, expired grant, arrival reported, or incident resolved).

### `PUT /missions/{mission_id}/status`
- **Purpose**: Advances mission lifecycle: `EN_ROUTE`, `ARRIVED`, `COMPLETED`, `WITHDRAWN`.
- **Auth**: Required
- **Role**: `responder`
- **Request Schema**:
  ```json
  {
    "status": "EN_ROUTE" // "ARRIVED", "COMPLETED", "WITHDRAWN"
  }
  ```
- **Side Effects**:
  - `EN_ROUTE` notifies protected user via push notification.
  - `ARRIVED` revokes precise location grant and notifies protected user.
  - `WITHDRAWN` triggers automatic redispatch to other responders.

---

## 4. Notifications & Device Endpoints

### `POST /users/{user_id}/device`
- **Purpose**: Registers an FCM (Android) or APNs (iOS) device push token with Amazon SNS.
- **Auth**: Required (User matching `user_id`)
- **Request Schema**:
  ```json
  {
    "device_token": "fcm_or_apns_token_string",
    "platform": "android" // "ios"
  }
  ```
- **Response Schema** (200 OK):
  ```json
  {
    "endpoint_arn": "arn:aws:sns:ap-south-1:...:endpoint/...",
    "status": "REGISTERED"
  }
  ```

### `POST /notifications/contact-test`
- **Purpose**: Sends a single, explicit, non-emergency test SMS to an owned trusted contact.
- **Auth**: Required
- **Request Schema**:
  ```json
  {
    "contact_id": "contact-uuid" // Optional; defaults to primary contact
  }
  ```
- **Response Schema** (200 OK):
  ```json
  {
    "contact_id": "contact-uuid",
    "provider_accepted": true,
    "message_id": "sns-sms-message-id",
    "status": "PROVIDER_ACCEPTED"
  }
  ```
