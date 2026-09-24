# Guardian Post-Remediation System Architecture & Invariants

This document outlines the architecture, component relationships, data flows, and safety-critical execution sequences of Guardian across mobile clients (Flutter, Android native, iOS native), local durability layers (Drift/SQLite), cloud infrastructure (AWS API Gateway, FastAPI Lambda, DynamoDB, EventBridge, Amazon SNS, Amazon Bedrock), and mapping services (OpenStreetMap & OSRM).

---

## 1. High-Level Component Architecture Map

```mermaid
flowchart TB
    subgraph MobileDevice["Mobile Device (Android / iOS)"]
        subgraph FlutterApp["Flutter Application Layer"]
            UI["UI / Presentation (GoRouter, Riverpod)"]
            SosTrigger["SosTriggerProvider (Hold SOS, Volume/Screen Listeners)"]
            EmergencyProvider["EmergencyProvider (12-Stage Lifecycle)"]
            LocationSvc["LocationService (GPS, Freshness Filter)"]
            HeartbeatProvider["ResponderHeartbeatProvider (TTL & Availability)"]
            OfflineSync["OfflineSyncService (Outbox Queue Worker)"]
        end

        subgraph LocalDurability["Local Persistence Layer"]
            DriftDB[("Drift SQLite Database\n(Encrypted Outbox, Incidents, Contacts)")]
        end

        subgraph AndroidNative["Android Native Layer (Kotlin Foreground Service)"]
            Service["SafetyForegroundService (Foreground Notification)"]
            NativePanic["PowerButtonReceiver & NativeEmergencyDispatcher"]
            NativeStore["NativeEmergencyStore (Encrypted Master Snapshot)"]
            SmsMgr["SmsManager (Direct Cellular Telephony Dispatch)"]
        end
    end

    subgraph AWSCloud["AWS Cloud Infrastructure (ap-south-1)"]
        APIGW["Amazon API Gateway (REST API + Auth Rate Limits)"]
        AuthMiddleware["FastAPI Lambda Middleware\n(Cognito JWT Validation + X-Guardian-Session-ID Verification)"]
        
        subgraph ServerlessCore["Core Serverless Application"]
            Server["FastAPI Application Surface (aws/server.py)"]
            AuthSvc["Session & Auth Service"]
            IncidentHandler["Incident Lifecycle & Trajectory Engine"]
            EscalationEngine["Progressive Escalation Policy Engine\n(1km -> 2km -> 5km -> 10km)"]
        end

        subgraph CloudStorage["Persistence & Ledger"]
            DDB_Users[("DynamoDB: Users & Sessions")]
            DDB_Incidents[("DynamoDB: Incidents & Missions")]
            DDB_Responders[("DynamoDB: Responders & Geohashes")]
            ActionLedger[("DynamoDB: Append-Only Audit Ledger")]
        end

        subgraph SafetyAI["Safety Governance & Advisory Engine"]
            SafetyPolicy["Deterministic Risk & Capability Policy\n(Strict Invariants, Capability Minting)"]
            Bedrock["Amazon Bedrock (Claude / Nova Advisory Summarization)"]
        end

        subgraph Notifications["Outbound Notifications"]
            SNS["Amazon SNS (Topic & Direct Push)"]
            FCM["Firebase Cloud Messaging (Android FCM HTTP v1)"]
            APNs["Apple Push Notification service (iOS APNs)"]
            AwsSms["AWS SNS SMS (Trusted Contacts Cloud Fallback)"]
        end
    end

    subgraph ExternalServices["External Navigation & Mapping"]
        OSRM["OSRM Walking Router (Free Foot Routing)"]
        OSM["OpenStreetMap Nominatim & Tile Servers"]
        ExternalNav["External Turn-by-Turn GPS (Google Maps / Apple Maps Intent)"]
    end

    %% Mobile Internal Wiring
    SosTrigger --> EmergencyProvider
    EmergencyProvider --> DriftDB
    EmergencyProvider --> NativeStore
    OfflineSync --> DriftDB
    OfflineSync --> APIGW
    EmergencyProvider --> APIGW
    LocationSvc --> EmergencyProvider
    HeartbeatProvider --> APIGW
    NativePanic --> NativeStore
    NativePanic --> SmsMgr
    NativePanic -.-> EmergencyProvider

    %% Cloud Wiring
    APIGW --> AuthMiddleware
    AuthMiddleware --> Server
    Server --> AuthSvc
    Server --> IncidentHandler
    Server --> EscalationEngine
    AuthSvc --> DDB_Users
    IncidentHandler --> DDB_Incidents
    EscalationEngine --> DDB_Responders
    EscalationEngine --> SafetyPolicy
    SafetyPolicy --> Bedrock
    SafetyPolicy --> ActionLedger
    EscalationEngine --> SNS
    SNS --> FCM
    SNS --> APNs
    SNS --> AwsSms

    %% Mapping Wiring
    UI --> OSM
    UI --> OSRM
    UI -.-> ExternalNav
```

---

## 2. Security, Boundary & Authority Invariants

1. **Deterministic Authority Boundary**: Amazon Bedrock is **strictly advisory**. Bedrock cannot authorize emergency actions, mint capability tokens, downgrade a panic alert, or modify an incident state. All safety-critical actions are evaluated by deterministic policy rules in `aws/agent/policy.py`.
2. **Atomic Single-Use Capabilities**: Sensitive tool invocations (e.g., dispatching SMS, notifying responders, granting precise coordinates) require cryptographically signed capability tokens with short TTLs (120s) and atomic consumption to prevent replay attacks.
3. **Session Enforcement**: Every authenticated private endpoint mandates both a valid Cognito Bearer JWT and an active `X-Guardian-Session-ID`. Session revocation terminates access immediately.
4. **Data Minimization (Coarse vs Precise)**: Prior to responder mission acceptance, only coarse locations (obfuscated or neighborhood radius) are distributed. Precise coordinates require an accepted mission and an active, short-lived navigation grant.
5. **Grant Revocation**: Precise location access is immediately revoked upon:
   - Responder reaching arrival perimeter (`ARRIVED`)
   - Mission completion or withdrawal (`COMPLETED`, `WITHDRAWN`)
   - Incident conclusion (`RESOLVED`, `CANCELLED`)

---

## 3. Sequence Diagrams

### 1. Manual SOS Sequence (In-App Hold-to-Activate)

```mermaid
sequenceDiagram
    autonumber
    actor Victim as Protected User
    participant UI as Flutter Emergency UI
    participant Drift as Local Drift Database
    participant Bridge as SafetyServiceBridge
    participant Backend as AWS API Gateway (FastAPI)
    participant Dynamo as DynamoDB
    participant Native as Android SmsManager

    Victim->>UI: Hold SOS button (3s countdown)
    UI->>UI: Countdown completes (No cancellation)
    UI->>Drift: Insert local incident (status: localEmergencyActive, nonce: uuid)
    UI->>Bridge: Update Native Emergency Snapshot
    par Local SMS Fallback
        UI->>Native: Send emergency SMS to primary trusted contacts
        Native-->>UI: Telephony acceptance evidence (osAccepted)
    and Cloud Dispatch
        UI->>Backend: POST /incidents (event_id, location, contacts)
        Backend->>Dynamo: ConditionCheckNotExists(event_id) -> Insert Incident
        Backend-->>UI: 201 Created (incident_id, status: ACTIVE)
    end
    UI->>Drift: Mark outbox item ACKNOWLEDGED (status: cloudAcknowledged)
    UI->>UI: Transition to live emergency tracking HUD
```

---

### 2. Offline SOS Sequence (Durability & Outbox Synchronization)

```mermaid
sequenceDiagram
    autonumber
    actor Victim as Protected User
    participant UI as Flutter Emergency UI
    participant Drift as Local Drift Database
    participant Native as Android SmsManager
    participant Sync as OfflineSyncService
    participant Backend as AWS API Gateway

    Victim->>UI: Trigger SOS (No internet connectivity)
    UI->>Drift: Persist incident in Outbox (status: PENDING_SYNC, nonce: uuid)
    UI->>Native: Dispatch direct cellular SMS to contacts
    Native-->>UI: SMS dispatched via cellular network
    UI->>UI: Display Offline Emergency HUD (SMS sent, Cloud pending)
    
    Note over Sync,Backend: Time passes; network connectivity is restored
    
    Sync->>Drift: Query pending outbox entries
    Drift-->>Sync: Return pending SOS incident
    Sync->>Backend: POST /incidents (event_id: uuid, timestamp: T0, location)
    Backend-->>Sync: 201 Created (incident_id: inc-123)
    Sync->>Drift: Update outbox record (synced: true, cloud_incident_id: inc-123)
    Sync->>UI: Notify emergency state updated (cloudAcknowledged)
```

---

### 3. Android No-Flutter SOS (Native Hardware Panic Trigger)

```mermaid
sequenceDiagram
    autonumber
    actor Victim as Protected User
    participant HW as Hardware Power / Screen Toggle
    participant Service as SafetyForegroundService
    participant Store as NativeEmergencyStore (Encrypted)
    participant Sms as Native SmsManager
    participant Flutter as Flutter Engine (Killed / Sleeping)
    participant Backend as AWS API Gateway

    Victim->>HW: Rapid 3-tap power/screen toggle
    HW->>Service: PowerButtonReceiver onReceive()
    Service->>Store: Check debounce window & retrieve cached emergency contacts
    Store-->>Service: Valid non-debounced panic event
    Service->>Sms: Directly send emergency SMS with cached GPS coordinates
    Service->>Store: Buffer pending native emergency event (nonce: uuid)
    
    Note over Flutter: User opens app OR OS restarts Flutter in background
    
    Flutter->>Service: getPendingNativeEmergencyEvents()
    Service-->>Flutter: Return buffered panic event (nonce, timestamp, coords)
    Flutter->>Flutter: Acknowledge native event & trigger emergency provider
    Flutter->>Backend: POST /incidents (event_id: native_nonce)
    Backend-->>Flutter: 201 Created
```

---

### 4. Victim Location Update Sequence

```mermaid
sequenceDiagram
    autonumber
    actor Victim as Protected User
    participant GPS as LocationService (Geolocator)
    participant Provider as EmergencyProvider
    participant Backend as AWS API Gateway
    participant Dynamo as DynamoDB
    participant Responders as Active Responders

    GPS->>Provider: Position stream tick (lat, lng, accuracy, time)
    Provider->>Provider: Calculate freshness (quality: FRESH / ACCEPTABLE)
    alt Freshness Valid (< 120s and acceptable accuracy)
        Provider->>Backend: POST /incidents/{incident_id}/location (location payload)
        Backend->>Dynamo: Append coordinate to trajectory history
        Backend->>Dynamo: Update current_location with freshness timestamp
        Backend-->>Provider: 200 OK
        Backend->>Responders: Push location update notification (if holding active grant)
    else Stale or Inaccurate
        Provider->>Provider: Suppress remote broadcast until fresh GPS fix acquired
    end
```

---

### 5. Responder Discovery Sequence

```mermaid
sequenceDiagram
    autonumber
    participant Escalation as EscalationPolicyEngine
    participant Dynamo as DynamoDB (guardian-responders)
    participant Policy as SafetyPolicyEngine
    participant SNS as Amazon SNS
    participant FCM as Firebase Cloud Messaging
    participant Responder as Approved Responder Device

    Escalation->>Dynamo: Query available responders in current geohash cell
    Dynamo-->>Escalation: Return active responder candidates (heartbeat age < 300s)
    Escalation->>Policy: Evaluate candidate eligibility & cap (stage 1: max 3)
    Policy-->>Escalation: Authorized candidate list (coarse coordinates only)
    loop For each authorized responder
        Escalation->>Dynamo: Create mission record (status: INVITED)
        Escalation->>SNS: Publish targeted coarse invitation
        SNS->>FCM: Deliver FCM high-priority push
        FCM->>Responder: Display Emergency Invitation Notification (Coarse Area)
    end
```

---

### 6. Radius Expansion Sequence (Progressive Escalation)

```mermaid
sequenceDiagram
    autonumber
    participant Engine as EscalationPolicyEngine
    participant Dynamo as DynamoDB (guardian-incidents)
    participant SNS as Amazon SNS
    participant Responders as Tier-2 Responder Candidates

    Note over Engine: Stage 1 (1000m, 60s timeout) expires without quorum
    
    Engine->>Dynamo: Check incident mission acceptance count
    alt Accepted Responders < Quorum (1)
        Engine->>Dynamo: Advance escalation_stage from 1 to 2
        Engine->>Dynamo: Expand search_radius_meters from 1000m to 2000m
        Engine->>Engine: Search expanded geohash radius
        Engine->>SNS: Dispatch invitations to newly discovered Stage 2 responders
        Note over Engine: Start Stage 2 timeout timer (90s)
    else Quorum Achieved
        Engine->>Engine: Halt radial expansion
    end
```

---

### 7. Responder Acceptance Sequence

```mermaid
sequenceDiagram
    autonumber
    actor Resp as Approved Responder
    participant RespUI as Responder Mission UI
    participant Backend as AWS API Gateway
    participant Dynamo as DynamoDB
    participant Ledger as ActionLedger

    Resp->>RespUI: Click "Accept Emergency Mission"
    RespUI->>Backend: POST /missions/{mission_id}/accept
    Backend->>Dynamo: ConditionalUpdate: Status == 'INVITED' & ActiveMissions < Max (2)
    alt Acceptance Successful
        Backend->>Dynamo: Set mission status = 'ACCEPTED', accepted_at = now
        Backend->>Ledger: Record acceptance decision & responder ID
        Backend-->>RespUI: 200 OK (mission_status: ACCEPTED, navigation_grant: grant_token)
        RespUI->>RespUI: Unlock navigation HUD & precise coordinate viewer
    else Conflict / Already Full
        Backend-->>RespUI: 409 Conflict (Mission already assigned to maximum responders)
    end
```

---

### 8. Exact Location Authorization Sequence

```mermaid
sequenceDiagram
    autonumber
    participant RespUI as Responder App
    participant Backend as AWS API Gateway
    participant Dynamo as DynamoDB
    participant ExtNav as External Navigation App (Google/Apple Maps)

    RespUI->>Backend: GET /missions/{mission_id}/location (Header: X-Guardian-Session-ID)
    Backend->>Dynamo: Verify mission status in ['ACCEPTED', 'EN_ROUTE']
    Backend->>Dynamo: Verify incident status == 'ACTIVE'
    alt Authorization Valid
        Backend->>Dynamo: Retrieve latest victim current_location & freshness
        Backend-->>RespUI: 200 OK (latitude, longitude, freshness: "FRESH", age_seconds)
        RespUI->>ExtNav: Launch turn-by-turn navigation intent (geo:lat,lng URI)
    else Mission Cancelled, Arrived, or Expired
        Backend-->>RespUI: 403 Forbidden (Precise location grant expired or revoked)
        RespUI->>RespUI: Clear cached coordinates & close navigation HUD
    end
```

---

### 9. Incident Resolution Sequence

```mermaid
sequenceDiagram
    autonumber
    actor Victim as Protected User
    participant UI as Flutter Emergency UI
    participant Backend as AWS API Gateway
    participant Dynamo as DynamoDB
    participant SNS as Amazon SNS
    participant Resp as Assigned Responder

    Victim->>UI: Enter cancellation/resolution PIN
    UI->>Backend: POST /incidents/{incident_id}/resolve (reason: "User safe")
    Backend->>Dynamo: Update incident status = 'RESOLVED', resolved_at = now
    Backend->>Dynamo: Revoke all active navigation grants for this incident
    Backend->>Dynamo: Mark all linked missions 'COMPLETED'
    Backend->>SNS: Publish incident resolution event
    SNS->>Resp: Push notification: Incident resolved, return to standby
    Resp->>Resp: Navigation HUD revoked, coordinates wiped from memory
    Backend-->>UI: 200 OK (status: RESOLVED)
    UI->>UI: Return to Dashboard
```
