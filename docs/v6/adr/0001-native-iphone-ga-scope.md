# ADR 0001: Native iPhone GA scope for Hue Board 6

- **Status:** Accepted
- **Date:** 2026-11-10
- **Owners:** Product Architecture, Release Captain
- **Issues:** #11, #20

## Context

Hue Board has evolved from a Scriptable controller into a native SwiftUI application with Bridge discovery, TLS identity verification, Keychain credentials, Hue v2 readback, Bridge-owned scene playback, bounded low-rate Live, deterministic engine parity, and durable recovery concepts.

The historical v6 roadmap combined native iOS, browser control, a local companion, Entertainment streaming, audio capture across multiple platforms, App Intents, Foundation Models, spatial editing, and App Store distribution into one terminal milestone. That scope had no stable definition of done and made unrelated research risks block the core native product.

## Decision

Hue Board `6.0.0` is a **qualified native-iPhone GA core release**.

### Required for 6.0

- Native iPhone application distributed through TestFlight and the App Store.
- Everyday room, zone, and fixture controls.
- Scene library, favorites, saved looks, isolated preview, and versioned import/export.
- Explicit draft, Apply, and Play boundaries.
- Automatic Bridge-owned Play that continues independently after accepted recall.
- Honest low-rate **Ambient Live** over REST, with bounded duration and explicit lifecycle.
- Exactly one Hue Board physical writer per coordinated Bridge/scope.
- Writer epochs and operation IDs that reject stale asynchronous responses.
- Durable recovery, unresolved-fixture retention, emergency off, and explicit restore.
- Versioned migration from Scriptable 5.3 and early native state.
- Real app and UI tests, fake-Bridge integration, physical iPhone/Hue qualification, accessibility, privacy, and physical-light safety.
- Internal and invited external TestFlight, release evidence, rollback, and zero open P0/P1 defects.

### Conditional for 6.0

- Basic App Intents, only if capability-gated and non-blocking.
- iPad and landscape, only if the exact enabled surfaces pass the complete qualification matrix.
- Hue Bridge Pro, only if physically qualified. The data model remains forward-compatible without claiming support.

### Deferred from 6.0

- Hue Entertainment streaming to conditional `6.1.0`.
- Microphone and local-file Sound to conditional `6.2.0`.
- Browser control, local companion, cloud sync, Foundation Models, cross-app audio, Apple Watch, MIDI/OSC, and desktop capture to later releases.

No deferred capability may appear as a working-looking placeholder control in 6.0.

## Release sequence

1. Publish Scriptable `5.3.0` as the final feature release and LTS rollback baseline.
2. Qualify and release native `6.0.0`.
3. Begin product Entertainment implementation only after legal and technical feasibility is approved.
4. Begin shipping Sound only after the output transport is qualified.

## Consequences

### Positive

- The native release has a bounded, auditable completion state.
- Entertainment licensing and audio lifecycle risks cannot indefinitely block daily-lighting GA.
- Scriptable remains a tested fallback without forcing identical platform capabilities.
- TestFlight and hardware qualification can focus on one coherent product.

### Costs

- 6.0 does not satisfy every idea in the historical v6 roadmap.
- Some users will wait for high-rate streaming and Sound.
- Two maintained release lines exist temporarily: Scriptable 5.3 LTS and native 6.x.

## Rejected alternatives

### Ship Entertainment and Sound in 6.0

Rejected because EDK redistribution, stream ownership, physical cadence, microphone lifecycle, privacy, battery, and thermal behavior are not yet qualified.

### Keep Scriptable as the primary product

Rejected because Scriptable cannot provide the native security, lifecycle, integration, audio, and distribution capabilities required for the long-term product.

### Perform a wholesale repository rewrite first

Rejected because the current boundaries are already meaningful. Repository-wide movement would add review and migration risk before resolving real Xcode and hardware defects.

## Evidence required before changing this decision

A later ADR may expand 6.0 only if the proposed capability has already passed its legal, platform, safety, hardware, accessibility, and release gates without delaying or weakening the native core.
