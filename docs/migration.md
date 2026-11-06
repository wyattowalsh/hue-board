# Upgrading to Hue Board

Hue Board can open existing Scriptable controller settings and Bridge authorization **without deleting or invalidating your saved data**.

The first launch copies legacy Keychain entries into new `hue-board.*` keys only when the new destination is absent. Existing values are retained as a rollback source. The app does not write new controller state under the legacy namespaces. Previously saved static restore points, scene resource IDs, fixture ceilings, room positions, and custom presets are migrated conservatively.

To upgrade:

1. Stop the older Scriptable controller; do not run two controllers against the same Hue lights.
2. Install `dist/hue-board.js` as a new Scriptable script and run it on trusted home Wi-Fi.
3. Verify the saved Bridge pairing and current room/zone. No button press should be necessary with a valid existing key.
4. Review any recovery/restore point **before** starting a new show or restoring. Older snapshots may predate changes from another app.
5. Keep the earlier script for rollback. Do not delete old Keychain entries until you have independently confirmed the new version works.

Mix imports accept the previous schema-3 app identifier in addition to `hue-board`. Newly exported mixes use `hue-board` and remain schema 3. The migration does not send a lighting command when the app opens.

The old Keychain identifiers appear **only** in `src/legacy.js` and tests intentionally exercising backwards compatibility. Changing them without a planned migration would break saved settings or force re-pairing.

## Transport boundary

The current Scriptable implementation disables local TLS certificate checks for private LAN Bridge addresses. It should run only on trusted Wi-Fi, with the application key stored in Scriptable Keychain. Browser control, system-audio integration, and high-rate Entertainment output are not part of this baseline.
