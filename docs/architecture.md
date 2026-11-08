# Architecture and repository guide

Hue Board is a self-contained **Scriptable application**, not a browser app that needs a persistent web server. The iPhone installer is intentionally small and pinned to an immutable published controller. The application itself is assembled from readable source modules.

## Where to look

| Path | Responsibility |
| --- | --- |
| `src/core.js`, `src/model.js`, `src/engine.js`, `src/presets.js` | Configuration primitives, capability-aware actions, deterministic procedural scene generation, looks |
| `src/hue.js`, `src/telemetry.js`, `src/hue-layout.js` | Hue network boundary, real Bridge readback, fixture geometry imports |
| `src/controller.js`, `src/workspace.js` | Single writer, playback state machine, restore journaling, room transitions |
| `src/legacy.js` | Migration-only legacy Keychain identifiers. Never repurpose/delete without preserving compatibility |
| `src/ui-react.js`, `src/ui-native.js`, `src/runtime.js` | Embedded WebView bootstrap, native compatibility UI, Scriptable lifecycle |
| `frontend/App.tsx`, `frontend/components/` | UI composition and feature panels |
| `frontend/components/lights/` | Individual light controls and commit-on-release range control |
| `frontend/lib/bridge.ts`, `frontend/types.ts` | Typed frontend/controller exchange and data model |
| `build.cjs`, `frontend/build.cjs` | Deterministic-order Scriptable and React bundling |
| `dist/` | Checked-in release/distribution snapshots, not editable source |
| `releases/v5.2.0.json` | Immutable release revision and SHA-256 attestation |
| `tests/` | Unit, integration, fixture, timing and optional browser-driven tests |

## Boundaries and invariants

1. **Design is not control.** A preview must not write to lights, and a Bridge response must not be called optical telemetry.
2. **One writer per selected scope.** State transitions, cancellations, and room switches must not create concurrent writers or duplicate effects.
3. **Opt-in background operation.** iOS Scriptable work may be suspended. Bridge playback begins before leaving; Studio choreography does not magically keep running.
4. **Keep app state private.** No Hue keys, bridge IPs, home layouts, or exports belong in Git or browser storage.
5. **Migration is additive.** Existing lights, scene IDs, fixture limits, restore history and old Keychain entries remain available.
6. **Capability-aware writes.** On/off, dimming, white temperature, color, gradient and dynamic effects require individually verified support. Test with synthetic fixtures first.
7. **Explicit source/output separation.** Development source is modular; the iPhone distribution remains one file. Do not manually patch generated `dist` files or claim a development rebuild equals a published artifact without hashing it.

## Releasing safely

1. Make source changes and update focused regression coverage. Run `pnpm build`, `pnpm test`, and `pnpm test:timing`.
2. Review generated assets, semantic typecheck gaps, third-party notices, WebView mobile UI and real-device constraints. Never assume mocked Hue resources prove physical behavior.
3. Publish the verified distribution as its **own commit/tag** and record its SHA-256. Then, in a following commit, update `releases/<version>.json` and the immutable Scriptable installer pin.
4. Run `pnpm verify:release` against the checked-in published bundle **before** rebuilding it. CI keeps this separate from a source compilation and test.
5. Do not tag or publish a new release until a green CI run and installation/rollback instructions are available.

## How to split files further

Refactor around **stable responsibilities**, not an arbitrary line count. The light UI's `CommitRange` and `LightCard` were extracted without changing the controller protocol. Next candidates: pure scene math and serialization in `src/controller.js`, then network/request orchestration. Extract one capability at a time behind a narrow function boundary, test the old and new state-machine behavior with the same fixtures, and confirm standalone bundle syntax and behavior. Do not introduce a second controller or a second build system only to shorten files.

## README artwork

The checked-in `assets/readme/hero.svg` is a lightweight accessible vector illustration with no external dependencies or credentials. `scripts/readme-art/generate.mjs` provides a Takumi-based alternate renderer for exploring and regenerating a lighting-console design. The rendered Takumi result has **not yet been visually validated in the actual Node native renderer** and should be reviewed before replacing the checked-in SVG; the manual workflow does not automatically push artwork to `main`.
