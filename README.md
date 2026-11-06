<p align="center">
  <img src="assets/readme/hero.svg" alt="Hue Board — beautiful, intuitive lighting control for Philips Hue" width="100%" />
</p>

<p align="center">
  <a href="#get-started">Get started</a> · <a href="docs/v6-plan.md">What's next</a> · <a href="LICENSE">MIT license</a>
</p>

**Hue Board** is an independent, open-source control surface for **Philips Hue**. Set the mood in seconds, fine-tune individual lights, or choreograph a room-wide show.

### Get started

1. Install [Scriptable](https://scriptable.app/) on your iPhone and connect to the same trusted Wi-Fi as your Hue Bridge.
2. Create a Scriptable script, paste the [one-time installer](install/install-hue-board.js), and run it.
3. Open **Hue Board** and connect your Bridge. Alternatively, [copy the complete controller](dist/hue-board.js) directly.

### Develop

```sh
corepack enable
pnpm install --frozen-lockfile
pnpm build && pnpm test
```

The iPhone controller works on the local network. Custom live animations require Scriptable to remain open; browser control and sound-reactive features are [planned](docs/v6-plan.md). The current Scriptable transport relaxes local TLS validation, so use **trusted Wi-Fi only**. [Upgrade notes](docs/migration.md) · [Technical details](docs/validation-v5.md) · [Third-party notices](THIRD_PARTY_NOTICES.md)

<sub>Unofficial project. Not affiliated with or endorsed by Signify or Philips Hue.</sub>
