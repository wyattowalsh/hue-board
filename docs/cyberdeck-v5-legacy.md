# BOYZ.EXE Cyberdeck 5.0.0

Everyday Hue management first, animation studio second. Standalone Scriptable app for iPhone with the existing bundled React, compiled Tailwind v4, source-owned shadcn-derived controls, and React Bits SpotlightCard. No runtime CDN or new account.

## Install

Stop the older controller and keep it as a backup. Create a Scriptable script named `BOYZ_EXE_CYBERDECK_v5` and paste the entire `.txt`, or import the identical `.js`. Run **Open control deck**. **Compatibility controls (no WebView)** remains available and now includes everyday lighting controls.

Existing Hue authorization is reused. A valid saved key avoids pairing again. Existing settings, Hue positions, show selection, native scenes and restore records are retained. Do not run two versions against the same lights. Nothing changes simply because this interface opens; opening does perform read-only inventory/telemetry requests.

## Four surfaces

- **Lights** is the new default. Select a room, zone, or **All lights** on the connected Bridge. Use area/selected scope, on/off, brightness, Warm/Focus/Bright, individual light controls, search/filter, and saved Hue scenes. Tap a lamp name to reveal its supported controls.
- **Looks** is the existing library of 32 curated presets, favorites and cue sequencing. **Preview** edits the look without starting playback; **Play** explicitly applies and starts it. Editing an already-running show affects its subsequent targets.
- **Studio** retains all 24 patterns, 18 factory palettes plus custom colors, A/B morphing and advanced controls. The readback map is collapsed by default here so the controls are easier to reach on a phone.
- **Settings** groups **Room setup** (saved Hue positions, layout, selection, roles, trim/ceiling) and **App & recovery** (system theme, diagnostics, restore sessions and advanced settings).

The UI follows system light/dark appearance by default and still permits explicit overrides. Reduced-motion handling is retained.

## Brightness, including the old 85% limit

The artificial 85% application ceiling is removed. Master brightness, new fixture ceilings, manual dimming and relevant native/animation output paths now permit **100%**, the normal maximum brightness setting. Nothing requests more than 100% or overrides device firmware.

Existing lower fixture ceilings and output trims are **not silently raised**. On Lights, use **Review 100% ceilings** and confirm to raise ceilings in the current control scope. This edits limits only, not the current light level. Existing output trims remain; set a lamp's trim to 100% in Settings > Room setup when that is intentional. A running show may use a newly raised ceiling on its next target, which the confirmation explains.

Then tap **Bright** or commit the brightness slider at 100%. Bright retains the current color. A show with master at 100% still has intentionally darker phases; master is its upper bound, not a demand that every lamp always run at 100%. No lumen measurement or calibrated screen-to-room brightness claim is made.

Explicit manual dimming honors the fixture's advertised minimum dim level. A ceiling below that minimum rejects the action instead of silently exceeding the ceiling. Zero brightness is not used as an Off command; on/off is separate.

## Everyday behavior

Brightness sliders submit on release, relevant key-up, or blur, rather than emitting a network command on every drag frame. The slider represents an edit target; lamp rows show Bridge-reported properties and freshness. Changing brightness, white temperature or color turns the addressed lamps on and pauses the local animation/cue sequence. An already-sent request or fade can finish. Power-only On retains existing reported brightness, bounded by the saved ceiling, and does not repeatedly compound the trim.

Warm requests 2700 K and 45%; Focus requests 4000 K and 80%, only for adjustable-white fixtures. Each request is bounded to that fixture's advertised temperature range. Color controls appear only for color-capable fixtures. On/off-only resources, including supported plugs exposed through the Bridge's `light` resources, get power controls but no invented color or dimming controls. Manual APIs revalidate capabilities against a fresh read before writing.

Area switching keeps one active controller. It pauses the old live show, waits for its in-flight writer to finish, then opens the new scope without a lighting change. It discards old pending UI commands and draft edits so they cannot land in the new room. Lights outside the selected scope are not targeted. Existing Bridge-native playback is not automatically stopped merely by switching areas.

**All lights** is a deduplicated local view of the connected Bridge's controllable `light` resources, including unassigned lights. It is not a fake Hue room. Native palette creation requires an actual room/zone. Ordinary direct controls work in larger scopes; custom live shows remain limited to 28 selected dimmable resources. Multiple Bridges can be chosen through the existing main menu, but this is not a simultaneous multi-Bridge controller.

Fixture ceilings and trims are shared across overlapping rooms, zones and All lights, keyed by authenticated Bridge identity and light ID. One-time migration conservatively retains the lowest saved preexisting values; explicit later edits are preserved. Global fixture limits use `boyzexe.hue.fixtureLimits.v5`.

## Saved scenes and restoration

**Your saved Hue scenes > Read saved scenes** retrieves applicable scenes. Selecting a scene applies a **static copy** of its compatible actions inside the current area. It respects current ceilings/trims and never edits, deletes or recalls the original scene. Dynamic effects and animation timing are not reproduced. This intentionally differs from native scene recall.

Manual changes and static scene copies use the same captured-state journal and paced writer as the show engine. **Restore session** restores captured static settings, not an earlier animation. Recovery choices are surfaced before the first On/brightness/color operation; explicit Off remains available. Failed restores keep their remaining snapshots for retry.

Restore sessions are still area-specific. Overlapping areas can have different baseline times. Review the session timestamp before restoring an older area; restoration can intentionally overwrite changes made later through another area or app. Choosing a fresh baseline archives the prior point instead of discarding it.

Streaming-owned lights are not overridden, even by Area Off. Unsupported, missing, streaming and failed lamps are disclosed. Ordinary local manual edits do not automatically stop independent effects on other lamps outside the addressed subset.

## What remains deliberately unchanged

The paced REST engine, truthful Reported / Sent target / Design distinction, saved Entertainment XYZ import, explicit import/undo, static restoration, one-writer policy, credential isolation, and native compatibility path remain. Bridge-reported values may be cached or target values; they are not optical measurements or guaranteed intermediate frames of a fade.

Live custom shows and cue sequences require Scriptable in the foreground with the phone awake. Static manual changes do not require a continuing script loop once accepted. Bridge-native playback is the existing independent option. No audio capture, background iOS service, SSE, Entertainment streaming, firmware updates, device onboarding, room-membership editing, Hue automations or account administration were added. This is a day-to-day lighting controller, not a claim to replace every Hue administration feature.

Trusted home Wi-Fi only: authenticated requests are private-IP restricted and reject redirects, but local Hue certificate validation remains disabled. Keys stay outside the HTML in Scriptable Keychain. No real Hue commands were issued while building/testing this release.

## Source and reproducible checks

The source archive contains actual modules, pinned build metadata, vendor notices, precompiled frontend assets and tests. No new frontend dependency was introduced. React 18.2.0, Tailwind 4.1.10 and TypeScript 5.8.3 are retained; no latest-version claim is made. shadcn/React Bits remain the previously vendored source adaptations, not a newly successful registry-CLI install. The fresh CLI documentation attempt timed out. Full React semantic typechecking and fresh network package installation were not performed.

On a normal Node/Python environment with the declared tooling available:

```sh
pnpm install --frozen-lockfile
pnpm build
pnpm test
pnpm test:timing
pnpm demo
node tests/everyday_host.cjs --demo
python tests/react_ui_qa.py
python tests/v5_ui_qa.py
python tests/react_controller_e2e.py
python tests/v5_controller_e2e.py
```

The Python browser scripts require Playwright and a Chromium executable at `/usr/bin/chromium` (adapt that executable path on another platform). `node build.cjs` can rebundle the controller from the included compiled frontend without reinstalling frontend tooling.

See `VALIDATION.md` for exactly what was executed, what was simulated, and what remains unverified on iPhone/Hue hardware.

## Documentation consulted

- Hue feature model, brightness maximum and minimum dim level: https://raw.githubusercontent.com/home-assistant-libs/aiohue/main/aiohue/v2/models/feature.py
- Philips Hue brightness explanation: https://www.philips-hue.com/en-us/explore-hue/faq/bulbs/how-bright-are-hue-bulbs
- Scriptable WebView: https://docs.scriptable.app/webview/
- shadcn Button / Field / Slider: https://ui.shadcn.com/docs/components/button , https://ui.shadcn.com/docs/components/field , https://ui.shadcn.com/docs/components/slider

Public API information is checked against vendor documentation and the primary aiohue implementation. Mocked tests are not a substitute for a run on the actual device.
