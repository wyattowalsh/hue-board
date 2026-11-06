# Hue Board contributor guidance

- Follow the repository's verified source and tests before proposing changes.
- Keep the user's Hue Bridge pairing keys and home-network details out of source, logs, examples, and tests.
- Preserve `src/` and `frontend/` source boundaries; generated `dist/` files are not the source of truth.
- Use Hue Board names for all active UI, exports and code. Keep legacy Keychain identifiers only in `src/legacy.js` for tested, additive migration. Never delete an old key during upgrade.
- Never equate Bridge acknowledgements with measured optical output. Separate design previews, accepted targets, and readback.
- Every lighting action must obey per-light capability limits, single-writer ownership, and restoration semantics.
- No new phone background-execution, Entertainment-streaming, or native audio capability may be claimed without device validation.
- Changes should include focused regression tests, typecheck or explicit gap, and user-facing documentation.
- All new application source must be MIT-compatible; record third-party notices and verify redistribution rights before adding dependencies.
- No automatic Hue writes on app open. Do not silently change ceiling limits or restore baselines.
