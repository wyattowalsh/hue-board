# Hue Board

**An unofficial, open-source Philips Hue lighting dashboard and creative scene controller.**

Hue Board combines everyday lighting management with a procedural scene studio. The current stable baseline is the iPhone [Scriptable](https://scriptable.app/) controller formerly named BOYZ.EXE Cyberdeck v5. The future browser, audio-reactive, and native integrations in [the v6 plan](docs/v6-plan.md) are **planned**, not represented as implemented.

## Current capabilities

- Per-room, per-zone and Bridge-wide power, brightness (up to 100% within fixture limits), color and color temperature.
- Saved Hue scene browsing, static copies, and explicit Bridge-native playback where supported.
- Procedural lighting effects and palettes, A/B blending, scene presets and cue sequences.
- Readback from the Hue Bridge separated from requested targets and simulated design previews.
- Read-only import of saved Hue Entertainment positions and per-fixture roles/brightness ceilings.
- Foreground Scriptable controller with native compatibility controls, recovery, and light/dark UI preferences.

## Install on iPhone

1. Install Scriptable and join your trusted local network with the Hue Bridge.
2. Copy [the generated standalone script](dist/BOYZ_EXE_CYBERDECK_v5.js) into a new Scriptable script.
3. Run it, choose the Bridge, pair with its center button if you haven't paired before, then choose **Open control deck** or **Compatibility controls**.
4. Keep earlier versions as backups. Existing `boyzexe.hue.*` Keychain names are intentionally retained for migration.

**Warning:** The current Scriptable transport relaxes certificate validation for local Hue endpoints. Use trusted Wi-Fi only. Keys remain in Scriptable's Keychain and never enter the React interface. Custom real-time shows require Scriptable in the foreground. Philips Hue and Signify are trademarks of their respective owners. Hue Board is not affiliated with or endorsed by Philips/Signify.

## Source and development

- `src/`: lighting engine, Hue transport, controller, telemetry, layouts, sessions, and native UI.
- `frontend/`: React + Tailwind interface and source-owned shadcn-derived primitives.
- `build.cjs` and `frontend/build.cjs`: produce the offline single-file Scriptable build.
- `tests/`: deterministic unit/integration and browser-test harnesses; no access to real Hue hardware.
- `vendor/`: MIT-licensed React runtime for offline Scriptable execution.
- `licenses/` and [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md): mandatory third-party attributions.

```bash
corepack enable
pnpm install --frozen-lockfile
pnpm build
pnpm test
pnpm test:timing
```

Browser QA requires Playwright and a compatible installed browser; see [the historical validation record](docs/validation-v5.md) for coverage and known gaps. Full semantic TypeScript checking, a reproducible clean-machine `pnpm install`, physical Hue performance, and native iOS WebView remain acceptance items, not implied guarantees.

## Roadmap

See [v6 plan](docs/v6-plan.md) for responsive browser control, isolated animated previews, progressive status, configurable sound capture, Hue Entertainment output, and optional Apple intelligence/native adapters. Those features are intentionally not yet part of this baseline.

## License

**MIT** for Hue Board's application code. The bundled React, shadcn-derived primitives and Tailwind assets retain their MIT notices. The prior React Bits Commons-Clause visual component was replaced with an original MIT scene surface before public publication; it is not included.

See [LICENSE](LICENSE) and [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
