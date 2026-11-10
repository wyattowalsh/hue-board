# ADR 0002: Use independent version domains

- **Status:** Accepted
- **Date:** 2026-11-10
- **Owners:** Product Architecture, Migration, Release Engineering

## Context

The repository currently uses `5.3.0` for the source package and generated native contract while the native target has a separate pre-release marketing version. Product, persistence, catalog, engine, and transport compatibility are different concerns. Coupling them makes migration, release, and rollback reasoning ambiguous.

## Decision

Hue Board uses these independent domains:

| Domain | Initial v6 value | Meaning |
|---|---:|---|
| Product version | `6.0.0` | User-visible native application release |
| Native build number | monotonic integer | App Store build identity |
| Persistence schema | `2` | On-device native state compatibility |
| Scene document schema | `2` | Import/export compatibility |
| Engine ABI | `1` | Inputs and outputs of the deterministic scene engine |
| Controller protocol | `1` | Operation, transport, capability, and state messages |
| Catalog revision | SHA-256 digest | Exact looks, palettes, and pattern catalog content |
| Scriptable compatibility line | `5.3.x` | LTS runtime and rollback family |

## Rules

1. A product release does not automatically increment every schema.
2. A schema increment requires an explicit migration and rollback policy.
3. The native build number never decreases for a distributed bundle.
4. The engine ABI changes only when a consumer-visible engine contract changes.
5. Catalog content is identified by digest rather than by product version.
6. Importers reject unsupported major schemas and never expand target scope implicitly.
7. Release evidence binds every domain to the exact source commit and artifact hashes.
8. Scriptable and native may have different product versions while sharing compatible scene and engine contracts.

## Compatibility policy

- Readers must accept the current schema and explicitly supported prior schemas.
- Writers emit only the current schema.
- Migrations are deterministic and idempotent.
- Unknown required fields or newer major schemas fail closed with export and recovery options.
- Old records are retained until the migrated state is validated.

## Consequences

- Catalog updates can ship without falsely becoming persistence migrations.
- Native and Scriptable compatibility can be stated precisely.
- Rollback and release manifests can identify the exact data and engine contracts involved.

## Rejected alternative

A single version string for app, engine, catalog, persistence, and exported documents was rejected because it conflates independent compatibility boundaries.
