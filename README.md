<p align="center">
  <img src="assets/readme/hero.svg" alt="Hue Board: a luminous lighting console with six colorful lamps and a prismatic scene wave" width="100%">
</p>

<p align="center"><strong>Light, composed.</strong> An independent open-source Philips Hue lighting dashboard and creative scene studio for iPhone.</p>

<p align="center">
  <a href="#iphone-installation">Install</a> ·
  <a href="#playback-and-background-behavior">Playback</a> ·
  <a href="docs/architecture.md">Architecture</a> ·
  <a href="docs/audit-2026-11-08.md">Audit</a> ·
  <a href="docs/v6-plan.md">Roadmap</a> ·
  <a href="LICENSE">MIT</a>
</p>

## A lighting instrument for everyday rooms

- **Lights:** room and zone power, brightness, color, white temperature, individual lamps, and saved Hue scenes.
- **Scenes:** 32 curated looks, favorite scenes, illustrative thumbnails, and one-tap **Play**.
- **Studio:** precise procedural animation, spatial placement, gradients, cue sequencing, and fixture-specific controls.

## iPhone installation

**Release qualification pending:** This branch implements automatic phone-free Play in source, but the published GitHub installer and checked-in `dist/` still contain **v5.2.0**. Do not use those files expecting v5.3 behavior. A new compiled bundle, immutable release SHA-256, and pinned installer must be published and checked before release.

For now, use the verified v5.2.0 installer from `main` or inspect the local v5.3 source candidate. The source branch is **not a new installable release**.

The eventual v5.3 installation will remain Scriptable-based, require trusted Wi-Fi, preserve existing Hue credentials and baselines, and never turn lights on merely by opening the app.

## Playback and background behavior

| User action | When phone locks | Fidelity |
| --- | --- | --- |
| **Play** on a compatible room | **Hue Bridge keeps playing automatically** after accepted scene recall | Compatible native dynamic palette, not exact Studio choreography |
| **Live Studio · foreground** | Stops sending animation updates when Scriptable is suspended | Exact custom foreground patterns, gradients and timings |
| **Cue sequence** | Stops progressing when Scriptable is suspended | Foreground-only authored cues |
| **Stop Bridge / Restore** | Explicit requests when controller is available | State changes may override actions in the official Hue app; check restore timestamps |

There is **no background toggle** and no silent fallback to a foreground-only animation when Play is unsupported. Real Hue **rooms/zones** and eligible dynamic color lamps are required. The local *All lights* view and incompatible lamps cannot be delegated. An unacknowledged recall is displayed as **uncertain**, not as successful playback.

Hue Bridge dynamic scenes do not run Hue Board's exact 24-pattern Studio engine. For precise choreography after locking a phone, an independently running companion controller or a suitable native host is required. See [background behavior](docs/background-playback.md) and the [v6 roadmap](docs/v6-plan.md).

## Develop and verify

For a development checkout of this *unreleased* branch, source build and tests can run, but the installer/release checks must remain blocked until the new bundle is published.\n\nNode 22 and pnpm 10.17.1:

```sh
corepack enable
pnpm install --frozen-lockfile
pnpm verify:release   # committed pinned artifact, before rebuild
pnpm build
pnpm verify:rebuild   # rebuilt artifact must match published artifact
pnpm test
pnpm test:timing
```

Source lives in `src/` and `frontend/`; `dist/` is a generated, self-contained Scriptable distribution, not a place to edit implementation. See [architecture](docs/architecture.md) for boundaries and [engineering audit](docs/audit-2026-11-08.md) for validation limits and open risks.

The illustrative [README SVG](assets/readme/hero.svg) is source-controlled. An optional, pinned [Takumi renderer](scripts/readme-art/generate.mjs) provides an alternate visual; it does not automatically push to `main`.

## Safety and provenance

Bridge application keys remain in Scriptable Keychain. Local Bridge certificate validation is relaxed in the existing Scriptable transport, so **use a trusted network only**. Bridge acceptance/readback does not prove emitted optical output. Source-level and simulated tests are not a substitute for real iOS, Hue Bridge, and accessibility validation. Restore points and previous Keychain data are preserved through migration.

[MIT license](LICENSE) · [Third-party notices](THIRD_PARTY_NOTICES.md) · [Migration](docs/migration.md)

*Unofficial project, not affiliated with or endorsed by Signify or Philips Hue.*
