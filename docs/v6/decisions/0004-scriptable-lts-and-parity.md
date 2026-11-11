# ADR 0004: Scriptable 5.3 is LTS and parity is semantic

- **Status:** Accepted
- **Date:** 2026-11-10
- **Owners:** Product Architecture, Scriptable Release, Native Product
- **Issues:** #5, #11, #13, #15

## Context

Scriptable and native iOS run under different lifecycle, security, UI, audio, background, and system-integration constraints. Requiring identical features would either weaken the native product or create misleading Scriptable claims.

## Decision

Scriptable 5.3 becomes the long-term compatibility and rollback line after its immutable release is published.

### Shared parity obligations

- scene, palette, and pattern identifiers;
- deterministic engine output for the shared engine ABI;
- fixture capability filtering and output limits;
- scene and mix import/export semantics;
- automatic Bridge Play behavior;
- no-write-on-open and no-write-on-preview invariants;
- recovery semantics and partial-failure disclosure;
- status terminology for accepted, reported, failed, and uncertain outcomes;
- migration fixtures and rollback documentation.

### Native-only capabilities

- certificate fingerprint pinning under the native trust model;
- Keychain integration under the native app identity;
- Hue v2 event streaming;
- continued-processing requests;
- App Intents and native system surfaces;
- future Entertainment transport;
- future microphone and local-file audio;
- TestFlight and App Store distribution.

### Scriptable-only capabilities

- pasteable standalone controller;
- Scriptable document installer and backup flow;
- compatibility table UI;
- foreground WebView Studio.

## Maintenance policy

Scriptable 5.3.x receives:

- security and physical-light safety corrections;
- Bridge compatibility corrections;
- migration and installer fixes;
- compatible catalog corrections;
- critical recovery fixes.

It does not automatically receive every native feature.

## Consequences

- Documentation states which semantics are shared and which capabilities are platform-specific.
- The word parity does not imply identical lifecycle, security, background, audio, streaming, or distribution behavior.
- Scriptable remains a proven rollback path while native releases can advance independently.

## Migration impact

- Scriptable 5.3 exports remain accepted inputs to the v6 migration corpus.
- Native-only persistence is not written back into Scriptable stores unless an explicit compatible export exists.
- Rollback exports preserve shared scene semantics and clearly label native-only data that cannot be represented.

## Evidence required

- Shared engine and catalog golden fixtures across both runtimes.
- No-write and recovery conformance tests.
- Import/export round-trip fixtures.
- Documented capability table generated or checked against shipped builds.
- Immutable Scriptable 5.3 release and verified installer before native GA.

## Rejected alternatives

### Feature-identical parity

Rejected because Scriptable cannot honestly reproduce native certificate, background-task, App Intent, audio, streaming, or distribution capabilities.

### Abandon Scriptable immediately

Rejected because it removes the current installation path and rollback baseline before native qualification is complete.

## Supersession conditions

Scriptable LTS may be retired only after a later ADR defines support duration, export and rollback treatment, user communication, and evidence that native migration is complete for supported users.
