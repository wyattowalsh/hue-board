# ADR 0003: Supported platform and hardware matrix

- **Status:** Accepted
- **Date:** 2026-11-10
- **Owners:** Product Architecture, Apple Platform, Hardware Qualification
- **Issues:** #4, #11, #12, #18, #20

## Context

A compiled target is not automatically a supported target. Hue Board currently declares iPhone and iPad device families, portrait and landscape orientations, an iOS 18 deployment target, and an Xcode 26-era build path. Real Xcode, simulator, signed-device, Bridge, fixture, lifecycle, accessibility, battery, and thermal qualification remains incomplete.

Support claims must be tied to the exact release commit, toolchain, OS, Bridge firmware, fixture capability, and observed evidence. API acceptance is not physical-light evidence.

Apple's current Xcode system requirements list Xcode 27.2 with Swift 6.4 and the iOS 27.2 SDK. Apple also states that App Store uploads will require the iOS 27 SDK or later beginning in April 2027.

Official references checked 2026-11-10:

- https://developer.apple.com/xcode/system-requirements
- https://developer.apple.com/app-store/submitting/
- https://developer.apple.com/help/app-store-connect/release-notes/

## Decision

Hue Board 6.0 is qualified and advertised only for the matrix below. A capability remains conditional until the exact matrix row passes.

## Apple release toolchain

| Item | 6.0 decision |
|---|---|
| Primary compiler | Xcode 27.2 |
| Swift compiler | Swift 6.4 |
| Swift language mode | Swift 6 with complete concurrency checking |
| Primary SDK | iOS 27.2 |
| Deployment target candidate | iOS 18.0 |
| Project generation | Pinned XcodeGen revision, generated project not committed |
| Distribution | Direct development build, internal TestFlight, invited external TestFlight, then phased App Store release |

The toolchain is rechecked before release candidate freeze. If Apple changes App Store requirements, the release lane follows the current supported requirement rather than preserving this table blindly.

## OS qualification tiers

| OS | Required behavior | Release status |
|---|---|---|
| iOS 18.x | Foreground application, Bridge Play, Ambient Live only while active, migration, recovery, accessibility | Required if the deployment target remains iOS 18 |
| iOS 26.x | All iOS 18 behavior plus user-started continued-processing acceptance, progress, cancellation, expiration, force-quit, and relaunch recovery | Required if continued processing is advertised |
| iOS 27.2 | Primary release and App Store qualification target | Required |
| Future iOS | No support claim until beta and release qualification | Unqualified |

The documentation must not refer to nonexistent intermediate marketing versions such as “iOS 18–25.” It states the exact versions tested.

## Device-family and orientation policy

### Required for 6.0

- iPhone.
- Portrait orientation.
- The user's actual target iPhone.
- At least one additional representative supported performance tier before broad App Store claims.

### Conditional

- iPad.
- Landscape.

If iPad or landscape has not completed the app, accessibility, layout, lifecycle, and physical-control matrix before beta freeze, the target configuration is narrowed before release. Compilation alone does not justify enabling or advertising those surfaces.

## Bridge support

| Bridge class | 6.0 policy |
|---|---|
| Hue Bridge v2 | Required on documented current firmware/API versions |
| Hue Bridge Pro | Conditional on physical access and a completed matrix; otherwise modeled but not advertised |
| Multiple saved Bridge profiles | Required in persistence design |
| Multiple simultaneously active Bridges | Out of scope for 6.0 |
| Remote/cloud Hue control | Out of scope |
| Local HTTPS API | Required |
| Plain HTTP or redirect-based access | Rejected |

Hue announced Bridge Pro-specific APIs and migration capabilities. The data model therefore avoids treating one Bridge identity as permanent, while the initial product still coordinates one active Bridge at a time.

Official Hue reference checked 2026-11-10:

- https://developers.meethue.com/

## Network support

Supported:

- trusted local LAN;
- Bonjour `_hue._tcp` discovery;
- Hue discovery broker as an auxiliary discovery path;
- manual private IPv4 or validated `.local` hostname;
- explicit first-use certificate identity verification and fingerprint pinning.

Not supported:

- arbitrary public hosts;
- redirects;
- guest networks with client isolation;
- remote access through an unqualified relay;
- disabling certificate checks as an installation requirement.

## Fixture capability tiers

| Fixture capability | 6.0 required behavior |
|---|---|
| Dimmable | Power and brightness; no fabricated color controls |
| White | Power and brightness; preserve unsupported states explicitly |
| White ambiance | Power, brightness, and validated color-temperature range |
| Color | Power, brightness, and gamut-aware XY color |
| Gradient | Safe aggregate behavior unless segment-specific support is explicitly qualified; no false segment-parity claim |
| Offline/unreachable | Visible stale/offline state and per-fixture failure retention |
| Externally streaming | Ordinary writes blocked; ownership displayed |
| Unsupported dynamic scene | Explicitly skipped or refused, never silently downgraded |

Every batch operation reports eligible, accepted, skipped, unsupported, externally owned, failed, and uncertain outcomes separately.

## Qualification record

Every supported row records:

```text
app commit and build
Xcode, Swift, SDK
OS and device model
Bridge model, firmware, API version
fixture models and capabilities
network conditions
permission state
operation and recovery results
battery and thermal observations where relevant
redacted logs and physical-output evidence
```

## Consequences

### Positive

- Store and documentation claims remain evidence-bound.
- Unsupported surfaces can be disabled instead of accumulating hidden defects.
- Bridge Pro and future OS work can be added without corrupting Bridge v2 support.
- Mixed fixture behavior is explicit.

### Costs

- The initial GA matrix may be narrower than the project currently compiles for.
- Hardware access and repeated physical tests are required.
- Support expansion becomes a deliberate release activity.

## Rejected alternatives

### Advertise every compile target

Rejected because compiler acceptance does not establish interaction, lifecycle, accessibility, networking, or physical-output correctness.

### Support all Bridges through a generic Hue label

Rejected because Bridge generation, firmware, certificate, resource, and Entertainment behavior differ.

### Treat private-LAN placement as sufficient trust

Rejected because local networks can contain hostile or misconfigured devices.

## Expansion rule

A new OS, device family, orientation, Bridge, firmware, or fixture tier becomes supported only after its matrix is attached to the exact candidate build and incorporated into release evidence.
