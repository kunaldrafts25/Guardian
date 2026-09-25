# ADR 0008: External Turn-by-Turn Navigation Guidance for Responders

## Status
Accepted (P0/P1/P2/P3 Invariant)

## Context
Building an in-app turn-by-turn routing, voice guidance, lane-assist, and real-time traffic re-routing engine within Flutter is fraught with safety hazards. Specialized native navigation apps (Google Maps on Android, Apple Maps on iOS) possess billions of dollars in real-time road condition, turn restriction, traffic jam, and audio guidance engineering. In an emergency, a responder navigating through unfamiliar terrain requires the fastest, most reliable routing available.

## Decision
Hand off turn-by-turn guidance to the device's native navigation application via platform intents (`geo:lat,lng` URI scheme on Android, `maps.apple.com` on iOS, or Google Maps intent):
- Guardian provides an in-app Google Maps overview with ordinary Google Routes walking geometry for proximity and deviation monitoring.
- When driving or cycling en route, the responder clicks "Start Navigation", which launches the external navigation app directly to the authorized coordinates.
- Guardian retains background tracking to detect arrival within the target perimeter.

## Consequences
- **Positive**: Responders receive battle-tested live traffic re-routing and audio voice guidance.
- **Positive**: Zero proprietary navigation bugs or incorrect one-way turn instructions during critical rescue runs.
- **Negative**: The responder temporarily switches out of the Guardian UI into their preferred mapping application.


## Phase 5 provider update

Guardian's map/search/route overview now uses Google Maps SDK, Guardian-proxied
Google Places (New), and Guardian-proxied Google Routes. Turn-by-turn handoff
remains separate because the current Guardian route response deliberately does not
pretend to provide lane guidance, voice instructions, traffic expertise, or a
verified-safe route. See ADR 0010.
