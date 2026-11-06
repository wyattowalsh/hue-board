# Hue Board v5 baseline validation, November 5, 2026

## Scope and evidence

Derived from the previous standalone v4 controller archive. The prior v4 artifact is preserved unchanged. No user's home network, Hue Bridge, actual lamp inventory or credentials were accessed. All fixture screenshots and execution tests use synthetic resources.

The target flow is: open Lights -> choose an area -> perform an explicit light change -> read independent reported state -> switch scopes without overlapping writers -> restore the captured baseline.

## Checks executed

| Check | Result | Evidence |
|---|---|---|
| Standalone Scriptable syntax | Passed AsyncFunction parsing in build | `build.cjs` |
| Actual frontend build | 13 TS/TSX modules transpiled, Tailwind 4.1.10 compiled | `dist/frontend-build.json` |
| Controller, model, transport, native UI | **125 tests passed**, zero skips | `qa/v5/node-tests.log` |
| Existing UI functionality | **98 checks passed** | `qa/v5/regression-ui-results.json` |
| New everyday UI | **62 checks passed** | `qa/v5/everyday-ui-results.json` |
| Existing React/controller flow | **7 assertions passed** | `qa/v5/animation-e2e.json` |
| Everyday React/workspace/controller flow | **22 assertions passed** | `qa/v5/everyday-controller-e2e.json` |
| Request latency / light count | **8 simulated scenarios passed** | `qa/v5/timing-results.json` |
| Identical JS/TXT, archive integrity, old file preservation | Checked when packaging | `RELEASE_MANIFEST.json` and `DELIVERY_CHECKS.json` |

The test totals are assertion/check counts, not independent hardware test runs. The 125 Node tests include the inherited 100 and 25 new assertions/tests for the everyday changes and inventory/workspace integration. The prior master-clamp test was deliberately changed from 85 to 100 to match the user's new requirement; the existing native flow now selects Studio before exercising the unchanged advanced workflow. No failures were hidden by skipping tests.

## Environment and browser route

Node.js v22.16.0, TypeScript 5.8.3, Tailwind 4.1.10, vendored React/ReactDOM 18.2.0. Python Playwright with system Chromium on Linux. The installed Browser connector exposes read-only tab listing/context, not app control, so local Playwright was used. Production HTML was loaded through `set_content`, matching the embedded/offline-document approach rather than a deployed website.

No full semantic React/TypeScript typecheck was executed. TSX compilation here establishes syntax/transpile validity, not complete type soundness. Fresh pnpm network installation was not tested. The shadcn CLI documentation attempt timed out; existing source-owned components were reused, not reinstalled or substituted with a claimed CLI run.

## Rendered UI verification

Both system light and dark modes at 320, 390 and 1024 CSS pixels. The actual production React bundle was rendered, not a static concept. No relevant page JavaScript errors or external asset/network requests occurred.

Checks exercised meaningful page content/title, Lights default, area selection, all-area versus selected scope, release-to-commit brightness, 100% values, keyboard End, explicit power, mixed capabilities, white ranges, draft-versus-applied colors, search/filter/empty state, saved scenes, explicit Play, confirmation/cancel, stale readback, streaming-disabled controls, pending scope switches, dropped stale commands, long names, live theme changes and reduced motion. Existing 98 checks additionally exercise presets, cues, imported Hue geometry, Room/Lab editing, diagnostics and recovery.

Visual review compared the preexisting v4 light interface against the new rendered home, dark home, desktop and expanded-lamp screenshots. Five concrete points checked: (1) everyday power and dimming precede animation; (2) readable light and dark semantic tokens; (3) responsive grouped/individual controls and text wrapping; (4) large, visibly labeled touch controls and keyboard focus; (5) context-aware bottom transport and disclosure of detailed lamp controls. The explanatory paragraph was collapsed and the brightness-limit callout shortened after review to reduce vertical clutter. The existing palette and typography family is retained. No claim of pixel-for-pixel fidelity to the old screen is made because the information hierarchy intentionally changed.

Native UITable is mocked, not rendered by iOS. New tests exercise native Bright100 -> Off -> Restore, switch-area intent, and metadata refresh without constructing a WebView.

## Real code with simulated integration

The new end-to-end path drives the real React bridge, workspace controller and lighting controller against mock Hue responses. It checks no startup writes; honoring a saved 85% ceiling and 75% trim; explicit ceiling increase without a light write; a later 100% command; plug power; capability-aware white changes; readback independent of accepted targets; restore; saved scene enumeration/static copy without scene mutation; room switching; cross-area isolation; All lights; shared limits; and one serialized writer.

The earlier animation flow also passes: Start -> Pause -> appearance change without writes -> preset selection -> cue advance -> Restore.

Per-light deadline simulations cover 1/6/12/28 lights at 80/250 ms mocked response latency. Fade horizons cover the observed revisits in these scenarios, with no overlapping writers and at least 350 ms write spacing. No Zigbee timing, visible smoothness or real brightness is measured.

## Remaining limits and risk

Actual iOS Scriptable WebView and UITable, physical Hue Bridge/firmware, device-reported capability correctness, visual bulb output, network load, battery use, VoiceOver behavior and OS appearance delivery require hardware verification. Chromium accessibility/keyboard checks are not proof of complete accessibility conformance. State readback is not optical telemetry. Static scene copies may not reproduce a saved scene's native dynamic behavior. Restore points are area-specific, so older snapshots in overlapping areas can restore earlier settings; timestamp review remains important.

This release remains foreground-only for custom animations and uses the existing trusted-LAN certificate compromise. It adds everyday management, not device onboarding, routine administration, streaming, or multi-Bridge simultaneous control.


## Final continuation verification

The saved v5 source and delivery archives were recovered from the Library rather than restarting the implementation. In this continuation, the frontend was recompiled (13 TypeScript/TSX modules and Tailwind 4.1.10), and the standalone script was rebuilt. The rebuilt script is byte-identical to the recovered v5 delivery: SHA-256 `9692d87663181b1f0cdfe7078fc2137ae01c75cff353143da1f90139fb88ade4`.

The complete 125-test Node suite, 98 existing UI checks, 62 everyday UI checks, seven animation integration assertions, 22 everyday integration assertions, and eight timing simulations were rerun successfully, without skips. Fresh logs are in `qa/final-verification/`; structured browser outputs are in `qa/v5/`. Browser discovery again exposed read-only tab tools, so local Playwright Chromium was used. Screenshots were generated by the actual application and reviewed at 390px in both themes and 1024px, including expanded lamp controls and the prior v4 light screen.

Visual checks covered primary action hierarchy, semantic light/dark colors, text wrapping, touch-control labels, and the fixed action bar. The everyday screen intentionally differs from v4's animation-first layout. No physical Hue or iOS Scriptable result is claimed. Full semantic React TypeScript checking remains unperformed. No lighting commands were sent to real devices.
