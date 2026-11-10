# ADR 0003: Initial v6 support matrix is intentionally narrow

- **Status:** Accepted
- **Date:** 2026-11-10
- **Owners:** Product Architecture, Apple Platform, Hardware Qualification

## Decision

### Native platform

- **Advertised device family for 6.0:** iPhone only.
- **Primary release toolchain:** Xcode 27.2 and Swift 6.4.
- **Primary qualification OS:** iOS 27.2.
- **Minimum deployment target:** remains iOS 18.0 only if the oldest supported behavior is physically and lifecycle-qualified. Otherwise the deployment target is raised before release.
- **Orientation:** portrait is required. Landscape is not advertised until it passes the full interaction and accessibility matrix.
- **iPad:** not advertised in 6.0. The target must not claim iPad support until the iPad layout and lifecycle matrix passes.

### Hue system

- **Required:** current Hue Bridge v2 firmware available to the qualification environment.
- **Bridge Pro:** modeled without hard-coded exclusion, but not advertised until physically qualified.
- **Active control:** one active Bridge at a time.
- **Saved state:** multiple Bridge profiles may be stored, with strict identity isolation.
- **Remote cloud control:** out of scope for 6.0.
- **Local transport:** pinned HTTPS to a private-LAN IPv4 address or trusted `.local` host. Redirects are rejected.

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

## Qualification rule

A platform, OS, orientation, Bridge generation, firmware, or fixture class is supported only when it appears in the release evidence matrix for the exact release candidate. Compilation alone is not qualification.

## Consequences

- `TARGETED_DEVICE_FAMILY` and supported orientations must match the release matrix.
- Marketing and store metadata list only qualified configurations.
- The data model remains forward-compatible with multiple Bridges and newer fixtures without claiming untested support.

## Rejected alternative

Advertising every compile-time target was rejected because it would turn untested iPad, landscape, Bridge Pro, and older-OS paths into unsupported product promises.
