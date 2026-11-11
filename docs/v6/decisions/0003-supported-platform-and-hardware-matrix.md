# ADR 0003: Initial v6 support matrix is intentionally narrow

- **Status:** Accepted
- **Date:** 2026-11-10
- **Owners:** Product Architecture, Apple Platform, Hardware Qualification
- **Issues:** #4, #11, #12, #18

## Context

Compile-time target settings currently include iPhone and iPad and multiple orientations, while actual Xcode, device, lifecycle, and Hue hardware qualification remains incomplete. A supported product surface must reflect observed evidence rather than every platform that happens to compile.

## Decision

### Native platform

- **Advertised device family for 6.0:** iPhone only.
- **Primary release toolchain:** Xcode 27.2, iOS 27.2 SDK, Swift 6.4 in Swift 6 language mode.
- **Primary qualification OS:** iOS 27.2.
- **Minimum deployment target:** remains iOS 18.0 only if the oldest supported behavior is physically and lifecycle-qualified. Otherwise it is raised before release.
- **Orientation:** portrait is required. Landscape is not advertised until it passes the complete interaction and accessibility matrix.
- **iPad:** not advertised in 6.0. Target settings must not claim iPad support until iPad layout, lifecycle, and accessibility qualification pass.

Apple’s published Xcode support table identifies Xcode 27.2 with Swift 6.4 and the iOS 27.2 SDK. Apple states that App Store submissions will require the iOS 27 SDK or later beginning in April 2027.

### Hue system

- **Required:** Hue Bridge v2 on a firmware version present in the qualification environment.
- **Bridge Pro:** modeled without hard-coded exclusion, but not advertised until physically qualified.
- **Active control:** one active Bridge at a time.
- **Saved state:** multiple Bridge profiles may be stored with strict identity isolation.
- **Remote cloud control:** out of scope for 6.0.
- **Local transport:** pinned HTTPS to a private-LAN IPv4 address or a verified `.local` host. Redirects are rejected.

### Fixture tiers

The support report distinguishes:

- dimmable;
- white;
- white ambiance;
- color;
- gradient or segmented color;
- dynamic-palette capable;
- Entertainment capable;
- offline or unreachable;
- externally streamed or otherwise owned.

Every operation reports eligible, accepted, skipped, unsupported, externally owned, failed, or uncertain. Unsupported fixtures are not silently omitted from a success claim.

## Consequences

- `TARGETED_DEVICE_FAMILY`, orientation declarations, store metadata, and screenshots must match the qualified matrix.
- The data model remains forward-compatible with multiple Bridges and newer fixtures without claiming untested support.
- A platform or fixture class may be added in a minor release after its own matrix passes.

## Migration impact

Stored Bridge profiles include an explicit Bridge identity and capability snapshot. Profile migration must not merge credentials, scene IDs, selected areas, or recovery journals across Bridge identities. Existing target settings may be narrowed before GA without altering user data.

## Evidence required

For every advertised configuration, release evidence records exact app commit/build, Xcode/SDK, OS, device model, Bridge model and firmware, fixture classes, permission state, and results for launch, connection, writes, playback, interruption, recovery, accessibility, battery, and thermal behavior.

Compilation alone is not qualification.

## Rejected alternatives

### Advertise every compile-time target

Rejected because it turns untested iPad, landscape, Bridge Pro, and older-OS paths into unsupported product promises.

### Require every modern Apple device for 6.0

Rejected because it expands the hardware matrix without improving the core iPhone release.

## Supersession conditions

A later ADR may expand device families, orientations, operating systems, Bridge generations, or fixture classes only after target settings and store metadata are reconciled with an exact evidence matrix.

## Sources

- https://developer.apple.com/xcode/system-requirements
- https://developer.apple.com/app-store/submitting/
