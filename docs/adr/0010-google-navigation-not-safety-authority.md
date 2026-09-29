# ADR 0010: Google Navigation Services Are Not Guardian Safety Authority

## Status
Accepted — Phase 5

## Context

The earlier mobile experience depended on public OpenStreetMap tiles, public
Nominatim autocomplete, and public OSRM routing. Those public community endpoints
are not an appropriate production dependency for Guardian's interactive safety UX.

At the same time, a third-party mapping provider must never become the source of
truth for an emergency, responder authorization, or victim location.

## Decision

Guardian uses:

- Google Maps SDK for Android/iOS map rendering using platform-restricted SDK keys.
- Google Places API (New) Autocomplete and Place Details through authenticated
  Guardian backend endpoints.
- Google Routes API through an authenticated Guardian backend endpoint for ordinary
  walking geometry, distance, and duration.
- A server-only Google Maps Platform credential stored in AWS Secrets Manager for
  Places/Routes web-service calls.
- Guardian/native location providers for victim GPS truth.
- Guardian AWS services for incident state, responder discovery, exact-location
  authorization, progressive responder escalation, and safety policy.
- External Google Maps / Apple Maps handoff where platform turn-by-turn navigation
  is desired.

## Safety semantics

A Google route is an ordinary walking route. Guardian does not label it "safe",
"verified", "well-lit", or police-approved without independent evidence.

Only authoritative routable geometry may arm Guardian's route-deviation detector.
If Routes is unavailable, a direct-line display fallback may be shown, but route
deviation monitoring is cleared.

## Credential boundary

Mobile SDK keys must be restricted to the corresponding Android package/signing
identity or iOS bundle identifier and only to the Maps SDK API required by that
platform. Places/Routes web-service credentials are never shipped in the mobile
application.

## Consequences

- Public OSM/Nominatim/OSRM infrastructure is removed from Guardian's production
  user-facing map/search/routing path.
- Google answers navigation/place questions, while Guardian remains authoritative
  for safety and emergency state.
- Google Maps Platform billing, quotas, key restrictions, and staging verification
  become deployment requirements.
