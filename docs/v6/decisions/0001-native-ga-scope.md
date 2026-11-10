# ADR 0001: Hue Board 6 is the qualified native iPhone GA core

- **Status:** Accepted
- **Date:** 2026-11-10
- **Owners:** Product Architecture, Apple Platform, Release Captain

## Context

Hue Board now has a native SwiftUI foundation, automatic Bridge-owned Play, a deterministic shared scene engine, certificate pinning, event readback, recovery journals, and a physical-device runner. The earlier v6 plan combined native GA, Entertainment streaming, audio capture, browser control, AI, companion hosts, and multiple platform adapters into one terminal milestone. That scope did not have a bounded definition of done.

## Decision

The release train is:

1. **Scriptable 5.3.0** is the final Scriptable feature release and immutable LTS rollback baseline.
2. **Native 6.0.0** is a qualified native iPhone application containing everyday Lights, isolated scene preview, explicit Apply and Play, automatic Bridge-owned Play, accurately named low-rate Ambient Live, durable recovery, versioned migration, diagnostics, accessibility, privacy, physical-light safety, TestFlight, and App Store distribution.
3. **Native 6.1.0** is the conditional Hue Entertainment Live release. It proceeds only after legal, distribution, technical, ownership, performance, and physical-hardware feasibility are proven.
4. **Native 6.2.0** is the conditional microphone and local-file Sound release. It depends on the qualified Entertainment transport.

The following do not block 6.0:

- browser control or a local companion;
- Foundation Models or other AI scene generation;
- cross-app or protected-media audio capture;
- cloud sync or accounts;
- Apple Watch;
- MIDI, OSC, or DAW adapters;
- desktop system-audio capture;
- arbitrary remote access.

## Consequences

- 6.0 can ship once the native core is safe, migratable, accessible, qualified, and distributable.
- Deferred features must not appear as placeholder controls or be marketed as available.
- Entertainment and Sound keep independent evidence bundles and release gates.
- Scriptable remains supported as a compatibility and rollback implementation, not as an obligation to duplicate native-only capabilities.

## Rejected alternatives

### Ship every planned capability in 6.0

Rejected because licensing, audio routing, browser security, physical streaming, and AI availability would make the release unbounded.

### Treat the current vertical slice as 6.0

Rejected because the exact Xcode target, signed-device behavior, migrations, privacy, accessibility, physical-light safety, and App Store path are not yet qualified.

## Reversal conditions

Entertainment or Sound may move into 6.0 only if their full acceptance gates close before release-candidate freeze without delaying or weakening native core qualification. Moving them requires a superseding ADR.
