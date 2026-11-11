# ADR 0002: Use independent version domains

- **Status:** Accepted
- **Date:** 2026-11-10
- **Owners:** Product Architecture, Migration, Release Engineering
- **Issues:** #5, #11, #13, #18

## Context

The repository currently uses `5.3.0` for source and generated native contract data while the native target has a separate pre-release marketing version. Product, persistence, scene documents, engine behavior, catalog content, controller messages, and distributed builds are different compatibility concerns. Coupling them makes migration, release, and rollback reasoning ambiguous.

## Decision

Hue Board uses these independent domains:

| Domain | Initial v6 value | Meaning |
|---|---:|---|
| Product version | `6.0.0` | User-visible native application release |
| Native build number | monotonic integer | App Store/TestFlight build identity |
| Persistence schema | `2` | On-device native state compatibility |
| Scene document schema | `2` | Import/export compatibility |
| Engine ABI | `1` | Inputs and outputs of the deterministic scene engine |
| Controller protocol | `1` | Operation, transport, capability, and state messages |
| Catalog revision | SHA-256 digest | Exact looks, palettes, patterns, and defaults |
| Safety-policy revision | explicit integer or digest | Validation envelope used before physical playback |
| Scriptable compatibility line | `5.3.x` | LTS runtime and rollback family |

## Rules

1. A product release does not automatically increment every schema.
2. A schema increment requires an explicit migration, compatibility window, and rollback policy.
3. The native build number never decreases for a distributed bundle.
4. The engine ABI changes only when a consumer-visible engine contract changes.
5. Catalog content is identified by digest rather than product version.
6. Importers reject unsupported major schemas and never expand target scope implicitly.
7. Release evidence binds every version domain to the exact source commit and artifact hashes.
8. Scriptable and native may have different product versions while sharing compatible scene and engine contracts.
9. A safety-policy change revalidates stored scenes before physical playback without silently rewriting the user’s source document.

## Compatibility policy

- Readers accept the current schema and explicitly supported prior schemas.
- Writers emit only the current schema.
- Migrations are deterministic and idempotent.
- Unknown required fields or newer major schemas fail closed with export and recovery options.
- Old records are retained until migrated state is validated.
- Downgrade behavior is documented per release; unsupported downgrade never pretends success.

## Consequences

- Catalog updates can ship without falsely becoming persistence migrations.
- Native and Scriptable compatibility can be stated precisely.
- Rollback and release manifests identify the exact data and engine contracts involved.
- Diagnostics can report compatibility facts without relying on one overloaded version string.

## Migration impact

Persistence schema 2 introduces an envelope containing schema version, writer version, timestamp, integrity data, and payload. Scene schema 2 becomes the native import/export target. Existing v1 and Scriptable fixtures remain frozen inputs to the migration test matrix.

## Evidence required

- Golden encode/decode fixtures for every supported schema.
- Repeated migration produces equivalent logical state.
- Unknown/newer schemas fail closed and preserve exportable source data.
- Release manifest records all version domains and their digests.

## Rejected alternatives

### One semantic version for every contract

Rejected because it conflates independent compatibility boundaries and forces unnecessary migrations.

### Infer compatibility from product version ranges

Rejected because catalog, engine, and persistence contracts may evolve independently within a product line.

## Supersession conditions

A later ADR may add or remove a version domain only with a migration plan, release-manifest update, supported reader/writer matrix, and rollback consequences.
