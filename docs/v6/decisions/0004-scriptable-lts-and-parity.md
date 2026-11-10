# ADR 0004: Scriptable 5.3 is LTS and parity is semantic

- **Status:** Accepted
- **Date:** 2026-11-10
- **Owners:** Product Architecture, Scriptable Release, Native Product

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

- certificate fingerprint pinning;
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

- security and safety corrections;
- Bridge compatibility corrections;
- migration and installer fixes;
- compatible catalog corrections;
- critical recovery fixes.

It does not automatically receive every native feature.

## Consequences

Documentation must say which semantics are shared and which capabilities are platform-specific. The word parity must not be used to imply identical lifecycle, security, background, audio, or streaming capability.
