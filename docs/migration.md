# Upgrading to Hue Board

Hue Board can open existing Scriptable controller settings and Bridge authorization **without deleting or invalidating your saved data**.

The first launch copies legacy Keychain entries into new `hue-board.*` keys only when the new destination is absent. Existing values are retained as a rollback source. The app does not write new controller state under the legacy namespaces. Previously saved static restore points, scene resource IDs, fixture ceilings, room positions, and custom presets are migrated conservatively.

To upgrade:

1. Stop the older Scriptable controller; do not run two controllers against the same Hue lights.
2. Install `dist/hue-board.js` as a new Scriptable script and run it on trusted home Wi-Fi.
3. Verify the saved Bridge pairing and current room/zone. No button press should be necessary with a valid existing key.
4. Review any recovery/restore point **before** starting a new show or restoring. Older snapshots may predate changes from another app.
5. Keep the earlier script for rollback. Do not delete old Keychain entries until you have independently confirmed the new version works.

## Scene and mix documents

New exports use the scope-free `hue-board.scene` schema 2 format. The document describes lighting intent only and cannot carry a Bridge host, application key, room/zone ID, fixture ID, or implicit physical target. The user selects the active room or zone when applying or playing the imported look.

Hue Board continues to import legacy Scriptable schema-3 mixes from both the `hue-board` and `BOYZ.EXE` app identifiers. Legacy values are normalized through the deterministic engine bounds and returned with a migration warning. Importing or previewing a document does not start lights.

Schema 2 imports:

- require a supported engine ABI;
- require a complete deterministic settings payload;
- reject unknown top-level, source, or setting fields;
- reject unsupported patterns, palettes, ranges, modes, colors, and sequence identifiers;
- reject an embedded physical scope or credential-shaped metadata;
- preserve Scriptable-only settings for round-trip compatibility even when the current native engine does not use each setting;
- produce a deterministic identifier when migrating the same legacy logical settings repeatedly.

The canonical schema contract and security boundary are documented in [`docs/v6/scene-document-schema2.md`](v6/scene-document-schema2.md).

## Native persistence migration

Native schema 2 uses integrity-checked state and separately durable recovery records. The migration path preserves legacy data as a rollback source, quarantines malformed records rather than replacing them with defaults, and keeps Bridge-specific state isolated. Native migration and rollback remain subject to the exact Xcode/device qualification tracked in issue #4.

The old Keychain identifiers appear **only** in `src/legacy.js` and tests intentionally exercising backwards compatibility. Changing them without a planned migration would break saved settings or force re-pairing.

## Transport boundary

The current Scriptable implementation disables local TLS certificate checks for private LAN Bridge addresses. It should run only on trusted Wi-Fi, with the application key stored in Scriptable Keychain. Browser control, system-audio integration, and high-rate Entertainment output are not part of this baseline.
