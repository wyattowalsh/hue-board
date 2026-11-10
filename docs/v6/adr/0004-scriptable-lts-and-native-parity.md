# ADR 0004: Scriptable 5.3 LTS and native parity policy

- **Status:** Accepted
- **Date:** 2026-11-10
- **Owners:** Product Architecture, Scriptable Release, Apple Platform
- **Issues:** #5, #11, #20

## Context

Hue Board began as a standalone Scriptable application. The native SwiftUI application is now the primary product direction, but Scriptable remains valuable as:

- a low-friction fallback;
- an immutable rollback path;
- an independent implementation of core semantics;
- a source of migration fixtures;
- a compatibility option when native distribution is unavailable.

Requiring identical feature sets across Scriptable and native iOS would either prevent native capabilities or force Scriptable to claim behavior its runtime cannot guarantee.

## Decision

Scriptable `5.3.x` becomes the **LTS compatibility line** after the immutable 5.3.0 release is published. Native `6.x` becomes the primary product line.

Parity means **shared semantics and compatible data**, not identical platform capability or identical UI.

## Required shared semantics

The two implementations must preserve compatible behavior for:

- canonical scene, pattern, palette, and preset identifiers;
- deterministic engine ABI and catalog revision tracking;
- fixture capability filtering;
- brightness caps, trims, roles, and unsupported-state handling;
- no-write-on-open behavior;
- explicit preview versus physical Play boundaries where the surface supports preview;
- automatic Bridge-owned Play on eligible rooms and zones;
- accepted, failed, skipped, externally owned, and uncertain outcome terminology;
- recovery capture before mutation;
- immutable original recovery snapshots;
- partial restore retention;
- versioned scene and mix import/export;
- migration from Scriptable 5.3 into native 6.x;
- safety validation for built-in and imported scenes.

Shared semantics are tested with frozen fixtures and canonical digests rather than visual similarity alone.

## Native-only capabilities

Native iOS may provide capabilities that Scriptable cannot reproduce safely or reliably:

- TLS identity verification and certificate fingerprint pinning;
- Keychain access under native accessibility classes;
- Hue v2 event-stream readback;
- continued-processing tasks;
- App Intents and system deep links;
- App Store and TestFlight distribution;
- native document import/export;
- future Hue Entertainment integration;
- future microphone and local-file audio capture;
- native accessibility and diagnostics integrations.

The absence of these features in Scriptable is not a parity failure.

## Scriptable-only capabilities

Scriptable may retain:

- a pasteable standalone artifact;
- the embedded WebView control deck;
- a native table compatibility surface;
- Scriptable document installation and backup behavior;
- foreground Studio controls that do not map directly to native product navigation.

The absence of these implementation details from native iOS is not a parity failure.

## LTS support policy

Scriptable 5.3.x receives:

- critical safety fixes;
- Bridge compatibility fixes;
- installer and rollback fixes;
- credential and migration preservation fixes;
- shared catalog corrections that remain schema-compatible;
- documentation corrections.

Scriptable 5.3.x does not automatically receive:

- native-only system integrations;
- Entertainment streaming;
- microphone Sound;
- browser or companion features;
- major navigation redesigns;
- new features that require breaking the 5.3 persistence or document schema.

A Scriptable change must remain compatible with the immutable 5.3 migration baseline or ship through a separately reviewed patch release with explicit rollback evidence.

## Shared-source policy

Use shared assets only when they are genuine compatibility boundaries:

- deterministic engine runtime;
- catalog data;
- schema definitions;
- migration fixtures;
- capability and outcome terminology;
- safety rules that apply to physical output.

Do not force UI, lifecycle, networking, storage, or platform-specific adapters into one abstraction merely to maximize code sharing.

## Import and migration policy

Native 6.x must import supported Scriptable 5.3 scene/mix documents through the versioned scene schema. It must not ingest Scriptable Keychain values or private Bridge configuration through a generic export.

Migration requirements:

- explicit source version and schema;
- preview of affected records;
- no physical writes during import;
- no implicit target-scope expansion;
- no credential transfer in ordinary scene documents;
- redacted migration report;
- backup and rollback before replacing durable native state.

## Release and rollback policy

Before native 6.0 GA:

1. Publish immutable Scriptable 5.3.0.
2. Verify clean install, reinstall, update, backup, tamper rejection, and rollback.
3. Preserve a documented path back to Scriptable without requiring native data destruction.
4. Prove native import from frozen 5.3 fixtures.

Native release notes state which Scriptable data can migrate and which platform-specific settings cannot.

## Consequences

### Positive

- Native iOS can use platform capabilities without misleading parity claims.
- Scriptable remains a stable fallback rather than an indefinitely expanding second product.
- Compatibility can be tested through schemas, fixtures, and engine parity.
- Migration and rollback are explicit.

### Costs

- Some features will intentionally differ by platform.
- Documentation must clearly distinguish semantic compatibility from feature parity.
- Shared changes require validation in both implementations.

## Rejected alternatives

### Feature-for-feature parity

Rejected because Scriptable cannot provide equivalent background execution, native event streams, App Intents, Entertainment, or audio lifecycle guarantees.

### Abandon Scriptable immediately

Rejected because the immutable fallback and migration baseline reduce release and rollback risk.

### Maintain two fully independent products

Rejected because scene identity, engine behavior, safety, migration, and recovery semantics would drift.

## LTS exit criteria

A later ADR may end Scriptable LTS only after:

- native migration and rollback have been proven across a stable release window;
- the public Scriptable artifacts remain archived and verifiable;
- no supported user depends on Scriptable for a capability absent from native;
- support and release notes state the end-of-support policy in advance.
