# ADR 0002: Independent version and schema domains

- **Status:** Accepted
- **Date:** 2026-11-10
- **Owners:** Product Architecture, Migration, Release Engineering
- **Issues:** #11, #13, #20

## Context

Hue Board currently exposes several values that look like versions but describe different compatibility boundaries:

- the root package identifies the source as `5.3.0`;
- the native target still uses a development marketing version;
- the generated engine/catalog contract contains a release string and schema;
- native persistence uses individual `.v1` keys;
- the public Scriptable installer remains pinned to the immutable 5.2 artifact.

Using one product version to decide whether persistence, scene documents, engine calls, or network messages are compatible creates unnecessary migrations and unsafe assumptions.

## Decision

Hue Board uses independent version domains. No domain may be inferred from another.

| Domain | Representation | Initial v6 value | Purpose |
|---|---|---:|---|
| Product version | Semantic version | `6.0.0` | User-visible native release and release notes |
| Native build number | Monotonic integer | assigned by release automation | App Store and TestFlight build identity |
| Scriptable line | Semantic version | `5.3.x` | Independent LTS compatibility and rollback line |
| Persistence schema | Monotonic integer | `2` | On-device state decoding and migration |
| Scene document schema | Monotonic integer | `2` | Imported/exported looks, mixes, and sessions |
| Operation protocol | Monotonic integer | `1` | Typed commands, events, errors, and handoff semantics |
| Engine ABI | Monotonic integer | `1` | Input/output shape of deterministic engine calls |
| Catalog revision | SHA-256 digest | generated | Exact pattern, palette, preset, and default content |
| Runtime engine digest | SHA-256 digest | generated | Exact JavaScript engine bytes executed by native and Scriptable |
| Release manifest schema | Monotonic integer | `1` | Artifact, checksum, provenance, and evidence metadata |

## Rules

### Product version

- Follows semantic versioning for shipped product behavior.
- Never determines whether persisted data or imported documents can be decoded.
- A catalog-only update does not require a product-major bump unless user-visible compatibility changes.

### Build number

- Strictly increases for every App Store Connect upload.
- Is generated outside source semantic versioning.
- Must be recorded in the release evidence manifest.

### Persistence schema

- Changes only when the durable state envelope or interpretation changes.
- Unknown future schema versions fail closed without overwriting existing data.
- Migration is explicit, idempotent, backed up, and verified before the new state replaces the old state.
- Downgrade behavior is documented; rollback must not assume a newer schema can be read by an older binary.

### Scene document schema

- Is independent of app and persistence versions.
- Readers reject unsupported required capabilities and preserve unknown optional fields where safe.
- Imports never expand target scope, credentials, fixture limits, or ownership implicitly.

### Operation protocol

- Every command and event includes a protocol version, operation ID, and writer epoch when applicable.
- Incompatible protocol versions return a typed incompatibility error rather than partial execution.

### Engine ABI

- Changes only when engine inputs, outputs, error semantics, or canonical parity encoding change.
- The runtime digest identifies exact bytes; the ABI identifies compatible shape.
- Native startup verifies the runtime digest before execution.

### Catalog revision

- Is computed from a canonical serialization of defaults, patterns, palettes, and presets.
- Catalog changes do not masquerade as engine, persistence, or product-version changes.
- Saved scenes record both schema and catalog revision for diagnostics; they remain valid when their referenced IDs and semantics remain supported.

## Compatibility policy

| Producer | Consumer | Required behavior |
|---|---|---|
| Older persistence schema | Newer app | Migrate from frozen fixture, verify, then commit |
| Newer persistence schema | Older app | Preserve state and refuse destructive downgrade |
| Older scene schema | Newer app | Import through explicit migration and show a report |
| Newer scene schema | Older app | Reject without modifying live or persisted state |
| Same engine ABI, different digest | Compatible app | Permit only when catalog/runtime integrity checks pass |
| Different engine ABI | Any app | Refuse execution until an adapter or migration exists |
| Scriptable 5.3 document | Native 6.x | Import through the documented scene-schema compatibility path |

## Source-of-truth files

Implementation should converge on generated constants and manifests rather than duplicated strings:

```text
versioning/product.json
versioning/schemas.json
versioning/catalog-manifest.json
releases/<version>.json
```

The exact locations may change during implementation, but a single generated source must feed JavaScript, Swift, tests, and release evidence.

## Consequences

### Positive

- Persistence migrations are not triggered by ordinary releases.
- Catalog revisions and engine compatibility can be audited precisely.
- Scriptable LTS can evolve independently from the native app.
- Import/export compatibility becomes testable with frozen fixtures.

### Costs

- Release tooling must maintain several explicit values.
- Diagnostics and support material must display the relevant domain rather than one generic version.
- Tests must cover compatibility matrices, not only current-current operation.

## Rejected alternatives

### Use the product semantic version everywhere

Rejected because it conflates release marketing, durable state, engine shape, and document compatibility.

### Infer compatibility from source commit

Rejected because commits identify provenance, not semantic compatibility.

### Store no schema version and rely on optional decoding

Rejected because silent defaulting can destroy recovery obligations and misinterpret old state.

## Reversal conditions

A future ADR may combine domains only if they have identical compatibility and migration lifecycles demonstrated across multiple releases. Convenience alone is insufficient.
