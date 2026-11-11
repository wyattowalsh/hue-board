# ADR 0001: Hue Board 6 is the qualified native iPhone GA core

- **Status:** Accepted
- **Date:** 2026-11-10
- **Owners:** Product Architecture, Apple Platform, Release Captain
- **Issues:** #4, #5, #11, #20

## Context

Hue Board now has a native SwiftUI foundation, automatic Bridge-owned Play, a deterministic shared scene engine, certificate pinning, Hue event readback, recovery journals, and a deterministic physical-device runner. The historical v6 plan combined native GA, Entertainment streaming, audio capture, browser control, AI, companion hosts, and multiple platform adapters into one milestone. That program had no bounded release definition.

## Decision

The release train is:

1. **Scriptable 5.3.0** is the final Scriptable feature release and immutable LTS rollback baseline.
2. **Native 6.0.0** is a qualified native iPhone application containing everyday Lights, isolated scene preview, explicit Apply and Play, automatic Bridge-owned Play, accurately named low-rate Ambient Live, durable recovery, versioned migration, redacted diagnostics, accessibility, privacy, physical-light safety, TestFlight, and App Store distribution.
3. **Native 6.1.0** is the conditional Hue Entertainment Live release. It proceeds only after licensing, distribution, technical, ownership, performance, and physical-hardware feasibility are proven.
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

- 6.0 may ship once the native core is safe, migratable, accessible, physically qualified, and distributable.
- Deferred capabilities must not appear as placeholder controls or be marketed as available.
- Entertainment and Sound use independent evidence bundles and release gates.
- Scriptable remains a compatibility and rollback implementation, not an obligation to reproduce native-only capabilities.
- New feature proposals are evaluated against the 6.0 critical path rather than appended automatically.

## Migration and compatibility impact

- Scriptable 5.3 must be published before v6 native migrations are frozen.
- Native 6.0 must import the explicitly supported Scriptable/native schemas without deleting the source record on first migration.
- Rollback instructions must identify which data remains readable by Scriptable 5.3 and which native-only state is exported separately.

## Evidence required

- Exact Xcode build, signed installation, launch, pairing, Bridge Play, stop, and restore on the supported physical matrix.
- Hosted CI that executes real steps.
- Immutable Scriptable 5.3 artifact, manifest, installer pin, migration, and rollback evidence.
- Internal and invited external TestFlight completion with zero open P0/P1 defects.

## Rejected alternatives

### Ship every planned capability in 6.0

Rejected because licensing, audio routing, browser security, streaming ownership, and AI availability would make release completion unbounded.

### Treat the current native vertical slice as 6.0

Rejected because the exact app target, signed-device behavior, migrations, privacy, accessibility, physical-light safety, and App Store path are not yet qualified.

### Keep Scriptable as the primary product indefinitely

Rejected because native lifecycle, security, system integration, and distribution are required for the intended product quality.

## Supersession conditions

Entertainment or Sound may move into 6.0 only if every corresponding acceptance gate closes before release-candidate freeze without delaying or weakening native core qualification. Any scope expansion requires a superseding ADR and updated release evidence plan.
