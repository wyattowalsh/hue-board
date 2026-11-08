<p align="center">
  <img src="assets/readme/hero.svg" alt="Hue Board: an illustrated lighting console with six colorful lamps, a scene preview, and a spectrum wave" width="100%">
</p>

<p align="center"><strong>Light, composed.</strong> An open-source Philips Hue lighting dashboard and creative scene studio for iPhone.</p>

<p align="center">
  <a href="#install-on-iphone">Install</a> ·
  <a href="#how-playback-works">Playback modes</a> ·
  <a href="docs/architecture.md">Architecture</a> ·
  <a href="docs/v6-plan.md">Roadmap</a> ·
  <a href="LICENSE">MIT License</a>
</p>

## Turn a room into an instrument

**Lights** makes everyday lighting effortless: room or zone control, power, brightness, per-light color and temperature, saved Hue scenes, and practical quick looks.

**Scenes** lets you explore a curated library of 32 looks, with previews and favorites. **Studio** adds custom procedural animation, spatial lamp placement, transitions, presets and cue sequences. An accessible compatibility interface is available if the embedded React view cannot open.

This project is independent and not affiliated with, endorsed by, or sponsored by Signify or Philips Hue.

## Install on iPhone

1. Install [Scriptable](https://scriptable.app/) and connect your phone to the **same trusted Wi-Fi** as your Hue Bridge.
2. Create a script in Scriptable and paste the [pinned installer](install/install-hue-board.js). Run the installer once. It downloads the immutable v5.2 release, verifies its SHA-256, and backs up an existing Hue Board script before replacement.
3. Run **Hue Board**, pair with the Bridge if necessary, and select a room or zone. Opening Hue Board does **not** automatically turn on lights.

Alternatively, paste the [standalone controller](dist/hue-board.js) directly into a new Scriptable script. The controller contains its own UI assets; installation does not require a backend service.

## How playback works

| Mode | Runs after iPhone locks? | Behavior |
| --- | --- | --- |
| Everyday lighting | Light settings persist | Ordinary Hue power, brightness, and color settings |
| **Keep playing when I leave** | **Yes, for compatible Hue rooms/zones** | When enabled before Play, a native Hue Bridge dynamic palette is recalled while Scriptable is foregrounded; wait for Bridge confirmation |
| Live Studio choreography | **No** | Custom 24-pattern animation, gradient timing, cue sequences and other live updates require Scriptable to stay active |

The background preference defaults **off**. A Bridge handoff is not a perfect reproduction of Studio effects; it delegates a compatible palette. Virtual **All lights** and unsupported fixtures cannot use that mode. See [background playback details](docs/background-playback.md).

## Develop

Requirements: Node.js 22, pnpm 10.17.1. Source is in `src/` (lighting behavior) and `frontend/` (React/WebView). The standalone Scriptable distribution in `dist/` is generated, not hand-edited.

```bash
corepack enable
pnpm install --frozen-lockfile
pnpm build
pnpm test
pnpm test:timing
```

`pnpm verify:release` verifies the **committed published bundle** before a local rebuild changes it. Release artifacts and development builds have intentionally separate validation. See [architecture and contributor workflow](docs/architecture.md), [v5 validation scope](docs/validation-v5.md), and [migration guidance](docs/migration.md).

## Safety and transparency

- Hue application keys remain in Scriptable Keychain; never commit credentials, IPs, or configuration.
- The Scriptable LAN transport relaxes local Bridge TLS certificate validation. **Use trusted Wi-Fi only.**
- Per-fixture ceilings and saved restore points are preserved. Review timestamps before restoring, especially after another controller has changed lights.
- Bridge acknowledgments and readback are **not** measurements of emitted light. Physical Hue Bridge behavior, real iOS suspension, and complete accessibility still require device testing.
- Visual previews are illustrative. Planned browser, sound-reactive and native Apple integrations are described in the [v6 plan](docs/v6-plan.md), not claimed as released features.

<sub>Hero artwork: source-controlled SVG plus an optional [Takumi renderer](scripts/readme-art/generate.mjs). The illustration represents an example room, not a connected lighting system. [Third-party notices](THIRD_PARTY_NOTICES.md).</sub>
