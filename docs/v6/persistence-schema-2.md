# Native persistence schema 2

## Purpose

Schema 2 replaces independent native `.v1` preference records with integrity-checked, migration-aware state while keeping recovery independently durable.

## Stores

| Key | Contents | Policy |
|---|---|---|
| `hue-board.native.state.v2` | profiles, active Bridge, selected areas, scene registry, Live descriptor/status | SHA-256 envelope, schema/version/timestamp metadata |
| `hue-board.native.recovery.v2` | one active restore journal | separate SHA-256 envelope; ordinary preference cleanup cannot remove it |
| `hue-board.native.legacy-backup.v1` | exact legacy values captured before first migration | retained for rollback |
| `hue-board.native.migration-report.v2` | redacted migrated/quarantined key report | no values or home identifiers |
| `hue-board.native.quarantine.v2` | malformed raw records and local reasons | local-only; excluded from default diagnostics |

The Hue application key remains in Keychain and never enters this envelope.

## Migration contract

1. Capture exact legacy data before writing schema 2.
2. Decode each independent legacy record.
3. Quarantine malformed records without replacing valid unrelated records.
4. Write the schema-2 state envelope and, separately, the recovery envelope.
5. Retain all legacy keys and the exact backup on first successful migration.
6. Reopening schema 2 is idempotent and does not rewrite state.
7. Rollback restores the captured legacy records and removes only schema-2 state/recovery/report records.

## Recovery contract

- Recovery blocks ordinary Bridge deletion.
- Only the explicitly confirmed destructive reset may discard matching recovery.
- Metadata removal commits before the recovery key is removed.
- Recovery for another Bridge is never removed by unrelated Bridge cleanup.

## Compatibility

- Schema 2 is the first native v6 persistence schema.
- Newer unsupported schemas fail closed and remain untouched.
- Scene document schema and engine ABI are independent version domains.
