# Guardian Domain Glossary & Terminology Standards

This glossary defines standard safety, identity, and mission terminology across the Guardian mobile app (Flutter & Android native), backend APIs (FastAPI & AWS Lambda), database persistence layers (Drift & DynamoDB), and operational documentation.

---

## 1. Core Domain Concepts

| Term | Category | Definition | Flutter Representation | Backend / DynamoDB | API JSON |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Incident** | Life Cycle | A server-recognized emergency event initiated by a protected user. Represents the top-level entity orchestrating policy, SMS dispatches, and responder missions. | `SosAlert` / `EmergencyModel` | `guardian-incidents` (`incident_id`) | `incident_id` |
| **Emergency** | State / UI | The active safety condition experienced by the victim device. Reflects the localized, multi-phase lifecycle of an emergency. | `EmergencyStatus` / `SosAlertStatus` | `status` (`ACTIVE`, `RESOLVED`, `CANCELLED`) | `status` |
| **Alert** | Evidence / Event | A specific dispatch, signal, or notification generated within an incident (e.g. SMS alert to trusted contact, FCM notification to responder). | `SosAlert` / `ContactAlertStatus` | `guardian-incident-events` | `alert` / `event` |
| **Mission** | Responder Life Cycle | A closed-cohort response assignment linked to an incident, tracking a specific responder's journey from invitation to completion. | `ResponderMission` | `guardian-incidents` (`missions` map) | `mission_id`, `mission_status` |
| **Invitation** | Responder Discovery | A coarse-location dispatch sent to an eligible, active nearby responder offering them an opportunity to accept a mission. | `MissionStatus.invited` | `status: "INVITED"` | `invitation_id` |
| **Responder** | Identity / Role | A vetted, approved individual authorized to participate in emergency assistance missions. | `NearbyResponderSummary` | `guardian-responders` (`user_id`, `role: "responder"`) | `responder_id` |
| **Trusted Contact** | Personal Safety | An individual designated by the protected user to receive immediate SMS notifications and emergency status updates. | `EmergencyContact` / `ContactAlertStatus` | `contacts` in user profile & incident payload | `contacts` |

---

## 2. Location & Coordinate Terminology

| Term | Definition | Privacy Level | Accuracy / Freshness Invariants |
| :--- | :--- | :--- | :--- |
| **Initial SOS Location** | The precise coordinate captured at the exact moment the SOS event was triggered (button press, hardware panic, or gesture). Immutable for forensic audit. | High (Restricted) | Captured at $T_0$. Never overwritten by subsequent tracking updates. |
| **Current Emergency Location** | The most recently captured coordinate of the protected user while the emergency remains active. | High (Authorized Only) | Dynamically updated via `POST /incidents/{id}/location`. Exposed only to authorized en-route responders holding a valid grant. |
| **Coarse Location** | Obfuscated or city/neighborhood-level coordinate (truncated geohash or rounded ~1-2km) provided to responders prior to mission acceptance. | Medium (Pre-acceptance) | Protects victim exact residence or position from unaccepted/unvetted discovery requests. |
| **Location Freshness** | Metric describing temporal age and horizontal accuracy quality. | System / Audit | **Client Display:**<br>• `FRESH`: $\le 15$s and accuracy $\le 50$m<br>• `ACCEPTABLE`: $\le 60$s and accuracy $\le 100$m<br>• `STALE`: $\le 120$s<br>• `EXPIRED`: $> 120$s<br>**Backend Network Freshness:**<br>• `FRESH`: age $\le 30$s<br>• `STALE`: age $> 30$s |

---

## 3. Mission & Emergency Lifecycle States

### Emergency Incident States (`SosAlertStatus` / Backend `IncidentStatus`)
- **`ACTIVE`**: Incident is declared and ongoing. Responder escalation, SMS alerts, and location streaming are active.
- **`RESOLVED`**: Emergency has safely concluded (marked by user or verified emergency services). Precise location grants are immediately revoked.
- **`CANCELLED`**: SOS trigger was aborted during countdown or cancelled by user PIN. Responders and contacts receive cancellation notices.

### Detailed Client Emergency Stages (`EmergencyStatus`)
1. `idle`: No active emergency.
2. `localEmergencyActive`: Trigger recorded locally in Drift outbox journal.
3. `cloudQueued`: Awaiting outbound network transmission.
4. `cloudDelivering`: In-flight HTTP request to AWS API Gateway.
5. `cloudAcknowledged`: Server confirmed incident creation with UUID.
6. `contactDeliveryPending`: Local SMS dispatch initiated.
7. `contactDeliveryConfirmed`: At least one contact dispatch accepted by Android OS telephony sub-system.
8. `contactDeliveryPartial`: Some contacts succeeded, others failed.
9. `contactDeliveryFailed`: All SMS submissions rejected by telephony sub-system.
10. `respondersSearching`: Backend escalation engine evaluating candidate radius.
11. `responderAssigned`: At least one approved responder accepted the mission.
12. `resolved`: Emergency concluded safely.

### Responder Mission States (`MissionStatus`)
- **`INVITED`**: Coarse invitation sent to responder. Exact coordinates withheld.
- **`ACCEPTED`**: Responder formally accepted mission. Single-use precise location grant issued.
- **`EN_ROUTE`**: Responder is navigating toward victim location. Real-time updates permitted under grant TTL.
- **`ARRIVED`**: Responder reached target vicinity. Precise location grant immediately revoked to minimize exposure.
- **`COMPLETED`**: Mission finalized by responder or user resolution.
- **`WITHDRAWN`**: Responder withdrew before arrival; triggers automatic backend redispatch.
- **`EXPIRED`**: Invitation was not accepted within stage timeout; triggers radial expansion.

---

## 4. SMS Dispatch & Evidence Terminology

| Field / State | Meaning | Truth-in-Advertising Standard |
| :--- | :--- | :--- |
| `SmsDeliveryState.pending` | Initial dispatch creation | SMS is queued in device memory. |
| `SmsDeliveryState.osAccepted` | Handed off to Android `SmsManager` | Telephony accepted bytes for cellular dispatch. **Does not prove recipient receipt.** |
| `SmsDeliveryState.composerOpened` | Native SMS app launched | User opened SMS app; no delivery confirmation. |
| `SmsDeliveryState.deliveryConfirmed` | Carrier delivery PDU receipt | Carrier confirmed SMS delivery to tower/recipient device. |
| `SmsDeliveryState.failed` | Radio, SIM, or carrier error | Dispatch explicitly rejected or aborted. |

---

## 5. Storage Field Mapping Standards

| Domain Concept | Flutter Drift Table (`local_incidents`) | DynamoDB (`guardian-incidents`) | API JSON Key |
| :--- | :--- | :--- | :--- |
| Unique Incident ID | `id` (TEXT PK) | `incident_id` (String HASH) | `incident_id` |
| Client Event Nonce | `nonce` (TEXT UNIQUE) | `event_id` (String GSI) | `event_id` |
| Emergency Status | `status` (TEXT) | `status` (String) | `status` |
| Initial Location | `latitude`, `longitude` | `initial_location` (Map: `latitude`, `longitude`, `captured_at`, `accuracy`) | `initial_location` |
| Current Location | `current_latitude`, `current_longitude` | `current_location` (Map: `latitude`, `longitude`, `captured_at`, `freshness`, `source`) | `current_location` |
| Escalation Radius | N/A (Cloud Orchestrated) | `escalation_stage`, `search_radius_meters` | `radius_meters` |
| Mission Mapping | Local outbox journal | `missions` (Map: `mission_id` -> Object) | `missions` |
