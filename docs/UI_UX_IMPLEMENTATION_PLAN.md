# Guardian Minimal UI/UX Implementation Plan

Status: implementation-ready, intentionally uncommitted planning document.

## Product experience goal

Guardian should feel calm, trustworthy, and immediately understandable under stress. The interface must reserve strong red for true emergency actions and states. Normal screens should use quiet neutral surfaces, restrained color, plain language, and predictable navigation. The design must not use neon colors, decorative glow, gratuitous gradients, or technical language that a person in danger has to interpret.

## Current-state findings

- Two unrelated `AppColors` systems are active: red/blue in `lib/app/theme/app_theme.dart` and purple/coral in `lib/core/constants/app_colors.dart`.
- Many widgets bypass `ThemeData` with raw `Colors.*`, so light/dark modes and semantic states are inconsistent.
- The dashboard gives engineering observability too much prominence. Agent evidence is useful, but the owner first needs protection status, SOS, and the next action.
- The SOS control uses a large glow effect. This is visually loud during normal use and makes emergency red feel decorative.
- Emergency, incident, and responder mission pages are inside the regular bottom-navigation shell. High-focus journeys should not expose unrelated navigation.
- Cards, icon colors, corner radii, shadows, and spacing vary between features.
- Some labels describe implementation details instead of user outcomes, such as “agent observability” and raw state names.

## Visual direction

### Color tokens

Use one semantic palette and delete the duplicate color class after migration.

| Token | Light | Dark | Use |
| --- | --- | --- | --- |
| Background | `#F7F7F5` | `#111315` | App canvas |
| Surface | `#FFFFFF` | `#1A1D20` | Cards and sheets |
| Surface muted | `#EFF1F2` | `#24282C` | Inputs and secondary areas |
| Text primary | `#1C232B` | `#F3F5F7` | Primary copy |
| Text secondary | `#66717D` | `#AEB6BF` | Supporting copy |
| Border | `#DDE1E5` | `#343A40` | Quiet separation |
| Brand | `#34556F` | `#78A6C8` | Navigation and ordinary primary actions |
| Emergency | `#C43D4D` | `#E66A76` | SOS and confirmed danger only |
| Success | `#2F765E` | `#65B394` | Safe/ready/completed |
| Warning | `#A66B18` | `#D5A04B` | Attention without danger |
| Information | `#3F668C` | `#79A5CE` | Neutral system information |

Rules:

- No glow effects and no color-only status communication.
- Emergency red appears only on SOS, destructive confirmation, and active danger states.
- Use borders and tonal fills instead of elevated shadows. One subtle shadow level is allowed for floating sheets.
- Meet WCAG AA contrast: 4.5:1 for normal text and 3:1 for large text/icons.

### Typography and shape

- Use the platform/system typeface for faster startup and familiar readability: Roboto on Android and San Francisco on iOS.
- Base body size: 16; supporting text: 14; minimum operational label: 12.
- Use three practical weights only: regular 400, medium 500, semibold 600.
- Use an 8-point spacing system and 12-16 px component radii.
- Minimum touch target: 48x48 logical pixels; SOS target at least 144x144.
- Support 200% text scaling without clipping or hiding actions.

## Information architecture

Normal bottom navigation remains four items:

1. Home — readiness, SOS, active incident, check-in.
2. Map — current position, active route, saved places.
3. Circle — emergency contacts and contact readiness.
4. Settings — safety triggers, account sessions, appearance, privacy.

Responder inbox appears as a role-specific Home entry and notification destination, not a fifth permanent tab.

Emergency countdown, active incident, incident evidence, and responder mission become full-screen root routes outside the bottom-navigation shell. Back navigation during an active incident must ask for confirmation and must never silently cancel the incident.

## Screen redesigns

### Home

- Top: compact greeting and profile action.
- First card: one protection status row—Ready, Needs setup, or Incident active—with a direct fix/view action.
- Second: tactile SOS control with “Hold 2 seconds” instruction and visible progress; eliminate glow.
- Third: two high-value actions only—Start check-in and View circle. Move safe zones and secondary tools below a “More safety tools” section.
- Show responder entry only for users with the responder role and show the real invitation count.
- Replace the permanent agent observability panel with an active-incident summary. Keep detailed decisions in the incident timeline.
- Remove trust score from protected-user Home unless it drives a real available action.

### Emergency trigger and active incident

- Countdown screen: large timer, Cancel, and Send now. Provide haptic and spoken feedback where enabled.
- Active state: show what has actually happened—incident recorded, contact provider accepted, responders invited, responder accepted—without saying “delivered” unless delivery evidence exists.
- Keep “I’m safe” and “Need help now” visually distinct and confirmation-gated.
- Keep the timeline one tap away but present human descriptions instead of raw backend state strings.
- Disable bottom navigation and unrelated actions while the critical flow is foregrounded.

### Responder inbox and mission

- Invitation card shows distance band, expiry, incident type, and approximate area only.
- Acceptance sheet explains that precise location is temporarily shared after acceptance and revoked at arrival/terminal state.
- Mission screen prioritizes current status and one next action: Accept, Start travel, Arrived, Complete, or Withdraw.
- Separate navigation launch from lifecycle transition so a map-app failure cannot incorrectly advance mission state.
- Add persistent safety controls: call emergency services, report misuse, withdraw, and contact support.

### Readiness

- Replace a flat checklist with Ready / Action needed sections.
- Each failed item gets one plain-language explanation and one direct action.
- Distinguish required MVP capabilities from optional enhancements.
- Never show green readiness when API connectivity or contact configuration is unavailable.

### Contacts, map, settings, and authentication

- Contacts: emphasize primary contact, verification/test state, and last provider-accepted test time.
- Map: simplify overlays, add attribution visibility, and preserve controls under text scaling.
- Settings: group into Safety, Privacy, Notifications, Account, and Appearance; destructive sign-out/revoke actions stay separate.
- Authentication: one task per page, clearer phone formatting, automatic OTP focus/advance, and recoverable error messages.

## Implementation sequence

### P0 — Design foundation

- Create one `GuardianTheme` and one semantic `GuardianColors` token source.
- Remove the duplicate `AppColors`, raw status colors, and obsolete theme classes.
- Add shared components: `GuardianScaffold`, `StatusPill`, `ActionCard`, `PrimaryButton`, `DangerButton`, `EmptyState`, `ErrorState`, and confirmation sheet.
- Add golden tests for light/dark tokens and component states.

Acceptance: every production screen compiles using one theme; no direct neon/decorative palette remains.

### P1 — Critical safety journey

- Redesign Home, SOS hold interaction, countdown, active incident summary, and timeline.
- Move emergency routes outside the normal navigation shell.
- Add clear state-to-copy mapping and truthful transport language.
- Verify one-handed use, 200% text scale, TalkBack/VoiceOver labels, and screen-reader focus order.

Acceptance: a first-time user can trigger, understand, escalate, and safely resolve an incident without technical knowledge.

### P2 — Responder journey

- Redesign inbox, invitation details, permission disclosure, mission actions, navigation handoff, and withdrawal/report controls.
- Prevent double taps and display server-confirmed state after each action.
- Add loading, expired, revoked, offline, and already-accepted states.

Acceptance: each screen has one obvious next action and never exposes precise location without a valid grant.

### P3 — Supporting journeys and polish

- Redesign readiness, contacts, map, settings, onboarding, authentication, and empty/error states.
- Replace remaining deprecated UI APIs and hard-coded colors.
- Add reduced-motion behavior, haptic consistency, screenshot/golden coverage, and device-size testing.

Acceptance: no overflow at 320 px width or 200% text scale; light and dark themes pass contrast checks; Android and iOS navigation behavior is consistent.

## UX validation checklist

- Test under bright light, dark mode, one-handed use, weak network, offline mode, denied permissions, and low battery.
- Test accidental SOS, repeated SOS, app process death, notification open, expired invitation, and incident cancellation.
- Test TalkBack and VoiceOver for labels, focus order, announcements, and modal focus trapping.
- Use real server states in demos and screenshots; do not add sample incidents, fake responders, or simulated delivery labels.

## Scope discipline

The first visual implementation should complete P0 and P1 before adding animation or illustration. The safety workflow, truthful state communication, accessibility, and navigation hierarchy are more valuable than decorative polish.
