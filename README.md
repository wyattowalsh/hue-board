<p align="center">
  <img src="assets/readme/hero.svg" alt="Hue Board — lighting that feels effortless" width="100%" />
</p>

<p align="center">
  <a href="#get-started">Get started</a> · <a href="docs/background-playback.md">Background playback</a> · <a href="docs/v6-plan.md">Roadmap</a> · <a href="LICENSE">MIT</a>
</p>

**Hue Board** is an independent Philips Hue dashboard for everyday lighting, animated scenes, and creative control.

### Get started

1. Install [Scriptable](https://scriptable.app/) on your iPhone and join the same trusted Wi-Fi as your Hue Bridge.
2. Create a Scriptable script, paste the [one-time installer](install/install-hue-board.js), and run it. Or use the [complete controller](dist/hue-board.js).
3. Select a Hue room or zone. Tap **Play in background** for a native Hue palette that continues after the phone locks. For exact spatial animation, choose **Live Studio** and keep Scriptable open.

### Develop

```sh
corepack enable
pnpm install --frozen-lockfile
pnpm build && pnpm test
```

[Playback details and Shortcuts](docs/background-playback.md) · [Migration](docs/migration.md) · [Validation](docs/validation-v5.md) · [Notices](THIRD_PARTY_NOTICES.md)

<sub>Unofficial. Not affiliated with or endorsed by Signify or Philips Hue. Local transport currently relaxes Hue certificate verification; use trusted Wi-Fi.</sub>
