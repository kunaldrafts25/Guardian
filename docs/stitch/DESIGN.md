# Guardian — Warm Safety System
## Design System Specification & Developer Handoff (DESIGN.md)

**Product:** Guardian Personal Safety Orchestration  
**Platforms:** Android, iOS (Flutter Mobile Application)  
**Stitch Project ID:** `2140278846071013532` (`projects/2140278846071013532`)  
**Stitch Design System ID:** `assets/17773622498288641402`  
**Visual Language:** "Warm Guardian"  

---

## 1. Brand Concept & Philosophy

Guardian is a real personal-safety application for durable SOS reporting, trusted-contact escalation, safety check-ins, and controlled nearby-responder coordination. 

### Brand Essence
- **Calm**: Reduces cognitive load during panic and high-stress situations.
- **Protective & Human**: Warm, grounded, trustworthy; communicates safety through clarity, structure, and reliability.
- **Strictly Non-Militaristic**: Zero police badges, shields, crosshairs, sirens, radars, or surveillance imagery.
- **Zero Blue**: Blue is completely banned across primary actions, selected states, links, backgrounds, and illustrations.
- **Restrained Red**: Coral-red (`#C6424E`) is reserved strictly for genuine emergencies, active critical incidents, and destructive confirmation.

### Abstract Logo Mark
The Guardian identity combines:
1. An enclosing protective arch with a hidden **"G"** profile in deep forest green (`#244D3C`).
2. A calm, central human presence beacon in controlled coral-red (`#C6424E`) with a porcelain center.
3. Symbol assets:
   - Primary Symbol: `assets/icons/guardian_symbol.svg`
   - Dark Mode Symbol: `assets/icons/guardian_symbol_dark.svg`
   - Monochrome Silhouette: `assets/icons/guardian_symbol_mono.svg`
   - Horizontal Wordmark: `assets/icons/guardian_wordmark.svg`
   - Stacked Logo: `assets/icons/guardian_logo_stacked.svg`
   - Android Flat Silhouette: `android/app/src/main/res/drawable/ic_notification_guardian.xml`

---

## 2. Color System & Semantic Tokens

### Light Theme Tokens ("Warm Porcelain")
| Token Name | Hex Value | Role & Usage |
| :--- | :--- | :--- |
| `appCanvas` | `#F7F5EF` | Primary application canvas background |
| `primarySurface` | `#FFFFFF` | Solid elevated cards, dialogs, bottom sheets |
| `secondarySurface` | `#EEF1EC` | Input fills, subtle card backgrounds, chips |
| `primaryBrand` | `#244D3C` | Deep forest green; primary readiness, main CTA, tab focus |
| `primaryPressed` | `#173A2C` | Active pressed state for primary brand buttons |
| `primaryContainer` | `#DDE9E1` | Muted green container for readiness and success tags |
| `secondaryAccent` | `#8A684E` | Warm earth accent for secondary indicators |
| `emergency` | `#C6424E` | Controlled coral-red; hold SOS, emergency actions |
| `emergencyPressed` | `#98313A` | Pressed state for SOS and critical actions |
| `emergencyContainer`| `#F8E1E3` | Emergency banner background |
| `warning` | `#A96624` | Warm amber; setup incomplete, degraded readiness |
| `success` | `#39705A` | Confirmation, safe completion, test verified |
| `mainText` | `#1C2520` | Highest contrast text (minimum 4.5:1 ratio) |
| `secondaryText` | `#5E6B64` | Subtitles, supporting copy, timestamps |
| `disabledText` | `#929B96` | Disabled labels, inactive icons |
| `border` | `#D7DDD8` | 1px card outlines, field borders |
| `divider` | `#E7EAE7` | List item dividers, hairline separators |

### Dark Theme Tokens ("Quiet Forest")
| Token Name | Hex Value | Role & Usage |
| :--- | :--- | :--- |
| `appCanvas` | `#101613` | Deep nocturnal canvas |
| `primarySurface` | `#18201C` | Elevated dark card surface |
| `secondarySurface` | `#202A25` | Subtle dark card background / input background |
| `primaryBrand` | `#82B89D` | Lighter forest sage for dark contrast |
| `primaryContainer` | `#284B3B` | Dark green container |
| `secondaryAccent` | `#C5A184` | Lighter warm earth accent |
| `emergency` | `#F06B74` | Radiant coral-red for dark-mode emergency |
| `emergencyContainer`| `#512A2E` | Deep emergency container |
| `warning` | `#E0A15C` | Warm amber for dark mode |
| `success` | `#79B89A` | Soft forest green success |
| `mainText` | `#F2F5F2` | High contrast white text |
| `secondaryText` | `#B8C2BC` | Secondary muted text |
| `border` | `#35423B` | Card outlines and subtle borders |

---

## 3. Typography Scale

- **Headline Font**: Manrope (System Sans-serif fallback: Roboto on Android, SF Pro on iOS)
- **Body Font**: Inter (System Sans-serif fallback)
- **Rules**:
  - Always use sentence case. No all-caps except short status tags (e.g. `TEST`, `SOS`).
  - Use tabular numerals (`fontFeatures: [FontFeature.tabularFigures()]`) for countdown timers.
  - Minimum body text: 16sp.
  - Minimum supporting text: 13sp.
  - Emergency instructions: at least 16sp bold.
  - Support text scaling up to 200% without layout truncation or clip.

| Style Role | Font Size | Weight | Line Height | Tracking |
| :--- | :--- | :--- | :--- | :--- |
| `displayLarge` | 44sp | Bold (700) | 52px | -0.5px |
| `headlineLarge`| 32sp | SemiBold (600) | 40px | -0.25px |
| `headlineMedium`| 26sp | SemiBold (600) | 34px | 0px |
| `headlineSmall`| 22sp | SemiBold (600) | 28px | 0px |
| `titleLarge` | 20sp | SemiBold (600) | 26px | 0px |
| `titleMedium` | 17sp | SemiBold (600) | 24px | 0px |
| `titleSmall` | 15sp | Medium (500) | 20px | 0px |
| `bodyLarge` | 16sp | Regular (400) | 24px | 0.15px |
| `bodyMedium` | 14sp | Regular (400) | 20px | 0.15px |
| `bodySmall` | 13sp | Regular (400) | 18px | 0.15px |
| `labelLarge` | 15sp | SemiBold (600) | 20px | 0.1px |
| `labelMedium` | 13sp | SemiBold (600) | 16px | 0.2px |

---

## 4. Spacing, Radii & Grid System

- **Base Unit**: 8-point grid (8, 16, 24, 32, 40, 48, 56, 64px).
- **Horizontal Screen Padding**: 20px base margin.
- **Minimum Interactive Touch Target**: 48x48 logical pixels.
- **Corner Radii**:
  - Cards: 20px (`Radius.circular(20)`)
  - Buttons: 16px (`Radius.circular(16)`)
  - Inputs: 16px (`Radius.circular(16)`)
  - Bottom Sheets: 24px top radius (`Radius.vertical(top: Radius.circular(24))`)
  - Dialogs: 20px (`Radius.circular(20)`)
  - Status Pills / Badges: Fully rounded (999px)
- **Elevation**: Low, soft, diffuse elevation (elevation: 0 with 1px border is preferred).

---

## 5. Component Inventory & States

1. **Emergency Hold Button (`GuardianHoldButton`)**
   - States: Idle, Holding, Progress Ring Animating (1s to 5s), Cancelled on early release, Activated.
   - Haptic feedback at press start, each countdown tick, and activation.
   - Screen-reader accessible alternative: Direct "Send Now" button and keyboard activation.

2. **Action Card (`GuardianActionCard`)**
   - Icon container (44x44, tone tint), Title, Description, Trailing chevron.
   - Min height: 88px, 48px touch target guaranteed.

3. **Status Pill (`GuardianStatusPill`)**
   - Tones: `neutral`, `success`, `warning`, `emergency`.
   - Semantic accessibility label prefix: `Status: [label]`.

4. **Readiness Checklist Item (`GuardianReadinessRow`)**
   - Leading status icon (check or warning amber), Name, Detailed evidence status, Corrective action button.

5. **Contact Card (`GuardianContactCard`)**
   - Name, E.164 phone, Primary contact badge, SMS readiness status, Edit & Delete actions.

6. **Responder Invitation Card (`GuardianInvitationCard`)**
   - Coarse distance / landmark, risk category, countdown to expiration, approximate location disclaimer.

7. **Active Mission Stepper (`GuardianMissionStepper`)**
   - Progression: `INVITED → ACCEPTED → EN_ROUTE → ARRIVED → COMPLETED`.

8. **Bottom Navigation (`MainBottomNavigation`)**
   - 4 destinations: Home, Map, Circle, Settings.
   - 72px height, indicator in forest green tint (alpha 0.12), labels in sentence case.

---

## 6. Motion & Accessibility Specifications

- **Micro-interactions**: 150–220ms ease-out.
- **Page transitions**: 250–350ms subtle slide & fade.
- **Hold-to-SOS Animation**: Fluid circular progress ring synchronized to countdown seconds; zero delay between ring completion and incident trigger.
- **Accessibility**:
  - All text meets WCAG AA 4.5:1 contrast.
  - Large text and icons meet 3:1 contrast.
  - Reduced Motion mode: disables transitions and progress pulsing; timer displays clear numeric countdown.
  - Scalable to 200% font size without overflow.

---

## 7. Stitch MCP Screen Registry & Visual Assets

All screens have been generated directly into Stitch Project `projects/2140278846071013532` using Stitch Design System `assets/17773622498288641402` ("Warm Guardian Safety System"):

| Screen Name | Screen ID | Stitch Artifact & Preview | Key Design Attributes |
| :--- | :--- | :--- | :--- |
| **Guardian Calm Dashboard** | `bf25857e07354c79aea5eda6642ff965` | [View Design Artifact](https://lh3.googleusercontent.com/aida/AEtjO1XDBGw8iOXc2tjQk6fSyEa5UfzDNJs6IjTIsvHngf9-ejizV2Wm6XRggUxXPtgzTiqsZMr8TDsH44eqHIKGGS-tlrb86z3Gz3ewQUGNHC_gKeW_rqk-LivaWVlSnXqEJJrpjfd-vhdLIzuwp7A0_6yjcLkxB3I-EMoKODogIxbBhh4pNKW3e728mYuiBZYaApXjK8ENm7LUEbN7xFTvgMfpF8gnsjhAcEVGStX8KW-uQINJDBXtaIUkSgQ) | Calm greeting, readiness status pill, hold-to-SOS entry, check-in card, Circle counter, zero blue |
| **Active Emergency Incident & Evidence** | `412470452afb479aa0d146debad3e956` | [View Design Artifact](https://lh3.googleusercontent.com/aida/AEtjO1Un4HUdmeu9WFab0DBKAsMXIU0HboyYlN36KgwnXYE6NIDAlmfG_NjkFr6bZJPmscvaZmgweR3taWeZzXlGuSCxsGgVD7QCttfopwab7wG4Wo_0BSBiaR_7O5ivzGnVbCA97SSD-LkVZIJVP7nH16-8e01NW6xjTX3CWtsI8qWXWsYy-zkj5xiRAWW0gPGXZfJFMTHUJr4KEWooYvVoTvBD1FFsmcLluPCOJuEX44swoi5wNkPDNzJ4wfM) | Active incident alert with coral border `#C6424E`, contact delivery audit, direct 112 emergency CTA, "I am safe" resolution |
| **Emergency SOS Hold & Countdown** | `82fc8b2f59124bd18dca99d0469a692e` | [View Design Artifact](https://lh3.googleusercontent.com/aida/AEtjO1XRcelMed0KR-ZoHGRpCm5GWMxVVpIeYULTFV3nyQSNg1WLxegA0n2b-HFDszr4ZhtOaboj2DzoZxOibiltfvXYxLwYY4APTaU60yFMSLFNKzSDES4KOuXIsd73QiQThpg2wyQw1Ag_xmmykbn18vFqqMwkBl8um5Wdm30ZR2Ria4dgEL9C4nfig0OeC0D8wdlo_dTBXleiMCqfDrLW_yMfGj6jPsz4bZQCoQiyeUfVQvRaU0iyk7-Rztk) | Circular progress countdown ring, "Keep holding to send SOS", "Send SOS Now" override, accidental protection |
| **Guardian Circle & Trusted Contacts** | `44cc07e0f8bb4921979c7122748868d3` | [View Design Artifact](https://lh3.googleusercontent.com/aida/AEtjO1VgCWEcnZ6tJAz_FZLNKBc_z2XcgORMj_NZj-Nhcyxym5LDAmdEgj55LRLv4tn-W6EM0F6LEOD1AWyU4n335SxOymFTGcy5uUd8WTKYrxKMQ7yzh0-vf8Bx_RA3AhIp0RBhRhQjY3m3-4D7Ete0UgvMF_knWG2knJuldFmfJG4Y4qpdByyotEfWiLf7YyXS3-eFMwxaEB-ttyj82B_9JhW--pqkz9LxqR2VwMIB4nFY-lPTDG6rQ0hIzy0) | 5-contact capacity, primary contact forest green badge, SMS & Push status, "+ Add Contact", test SMS trigger |
| **Protection Readiness Diagnostic** | `b3754169d8e04dfdabdb12de5af585a4` | [View Design Artifact](https://lh3.googleusercontent.com/aida/AEtjO1WT-UulqYt5OjdjD25pmXjljZ8Fw81reupoVaIeG-Yo0uytwCAVsh7_yvUb3iL-FGZaN_wJwf8lgfP8KLxE7eC0hF93Xz42TA23iN7ARt0izB4W3U8cfgr2dpSLBDD-VYl8ZjsjZpC03X7k5ELkk_tH7GyOBzAyFsXE2yL3IdoRqJqOEUDuXJvprTUmU1jzhu6TukaNEGdhiZeG-tvycoUsmrk5yU24EZmvM2LEX1S5iOVyy0DuNf3UUGI) | 7-point subsystem checklist, battery optimization exclusion CTA, WebSocket carrier handshake, diagnostic action |
| **Active Responder Mission** | `b9b071947044459cbdb91ab813fa2637` | [View Design Artifact](https://lh3.googleusercontent.com/aida/AEtjO1XcMM0JeVUHirx4DHObET5kVzTsEBUj8dQdUoMksB1dCYF_spY3Ia44nH6SJpnZeIFD6oJYRrkCI7tSs-zSbjwlepNq6ST1WwDjYPCpFam7C2zAzldBI3nMK1WuOFba62IDpUmFf2-RJjFU1icMyQSdXv9LcsB1USzc64Yttf8Qyv07-voOJoF2FVcL9UyPvF3k2WuLJczTDIe504ceQNawH4BAU1yY-dE-3PJkFu3FSS1aRScfNVZJBds) | Coarse area preview, safety advisory banner, navigation handoff, 112 emergency dial, arrival verification |
| **Truthful Onboarding** | `b97c12c9c2d94684879e93aa64efa8fb` | [View Design Artifact](https://lh3.googleusercontent.com/aida/AEtjO1VX2-tgmhjf31_68BHu_H2ECHObzb5mOQKY2o7gFkGgl9b5J5An8T_D8M1orNOU9w_QMShb_6j7ehR7rbOkcJ9upf_crEnYMuPaMim5xq7MgK1KJ2tCQvjmVoE3jVt6B6epKmRlJJb9griiEDmR5u3viMKaX65SGM5RZ9UU8FRzG0rCeG8zzwepA5e7VqkE5vnH7Uube4KFp1mrqrfleH7BaGWMFp7pCzo7tfKiVynF3RbTeSu9wFkwREs) | Step 3 of 8 boundary disclaimer, no automated police dispatch truth, carrier dependency, location privacy |
| **Phone Login & OTP Verification** | `21b6f8e48543411981308664311fbcb7` | [View Design Artifact](https://lh3.googleusercontent.com/aida/AEtjO1UVd6_uzmM7GbTeBKcHpDXFuTkfBZ9UiuMZZHnDGjJ843szcutFYa4X05624mLcKHxukdYyDNyJP4lVvn843VbBzLI55YfJ71vrWKK680pe5ZoP1PqS6uNqPsshBBEztSaQjmfvYAU2lVUMIOOlJVIFSJUKOUNac-A4OQ6w1D7PkrAf_HYz_BVmc4SD-3D6flB4zNOyu-bJvq8V4Oz1LSLUl2f6kajSPt9I4K_ObBupwBTpa_WHXI1BGw) | Abstract brand mark, 6-digit accessible OTP grid, paste & autofill support, resend countdown, "Verify & Continue" |

---

## 8. Interactive Prototype (`docs/stitch/prototype.html`)

A complete, self-contained interactive prototype is maintained in `docs/stitch/prototype.html` allowing visual and interactive verification of all 5 core safety flows:
1. **Flow 1 (Onboarding to Home)**: Onboarding → Login → OTP Verification → Profile Setup → Permissions → Readiness → Home.
2. **Flow 2 (Emergency SOS to Resolution)**: Home → Hold to Activate SOS → 3-Second Countdown → Active Incident Alert → Contact Dispatch Audit → Location Evidence → "I am safe" Confirmation.
3. **Flow 3 (Responder Coordination)**: Nearby Push Notification → Responder Inbox → Approximate Area Preview → Mission Acceptance → Navigation Hand-off → Confirm Arrival → Complete.
4. **Flow 4 (Trusted Circle Management)**: Home → Circle → Contact List → Add Contact Modal → Primary Contact Assignment → Non-Emergency Test SMS Trigger.
5. **Flow 5 (Readiness Checklist)**: Home → Readiness → 7-Subsystem Audit → Corrective Battery Optimization Action → Verified Status.

The prototype includes top control buttons for Theme Toggling (Light / Dark), Device Size presets (Compact 320px, Modern 390px, Large 428px), and Text Scale multiplier (100% to 200%).

---

## 9. Verification & Quality Standards

- **Zero Blue Policy**: Verified across all screens, theme tokens, indicators, and map controls.
- **Strictly Factual Status**: All contact states explicitly state delivery evidence (e.g. *\"Dispatch accepted — awaiting carrier confirmation\"*).
- **No Gamified Metrics**: Removed trust scores, star ranks, points to next rank, and badges.
- **Tactile Emergency Controls**: Minimum 48x48px touch targets, full-width 52px primary buttons, tabular countdown numerals.
- **Automated Test Coverage**: Verified with `flutter test` across 112 tests covering database durability, state machine life cycles, widget rendering, and theme token constraints.
