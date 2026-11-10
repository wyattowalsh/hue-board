# Native persistence migration fixtures

Synthetic, redacted fixtures for the Hue Board native v1-to-v2 migration path.

- `v1-profile.json`: legacy single Bridge profile.
- `v1-selected-areas.json`: legacy per-Bridge selected area dictionary.
- `v1-scene-registry.json`: legacy per-Bridge/area scene registry.
- `v1-malformed-profile.bin.txt`: malformed legacy payload used to verify quarantine.

These values are deliberately nonproduction examples. They contain no application key, real private address, room name, certificate, or household identifier. Runtime tests also construct a timestamped restore journal and prove that it moves to the independently durable v2 recovery envelope.
