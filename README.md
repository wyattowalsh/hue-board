<p align="center"><img src="assets/readme/hero.svg" alt="Hue Board" width="100%" /></p>

An independent open-source Philips Hue lighting controller and creative scene studio.

Control rooms, fine-tune individual lights, explore scenes, and build spatial animations from your iPhone.

### Install

Install [Scriptable](https://scriptable.app/) and paste the [pinned installer](install/install-hue-board.js). Or copy the [complete controller](dist/hue-board.js) into Scriptable. Pair with your Hue Bridge once on trusted home Wi-Fi.

### Background playback

Enable **Keep playing when I leave** in Scenes, Studio, or App & recovery. Play starts a Hue Bridge dynamic scene immediately so you can lock your phone after the Bridge confirms. Complex Studio choreography and cue sequences still require an active controller. See [background playback](docs/background-playback.md).

### Develop

```sh
pnpm install --frozen-lockfile
pnpm build
pnpm test
```

MIT licensed. Unofficial; not affiliated with or endorsed by Signify or Philips Hue. [Roadmap](docs/v6-plan.md) · [Third-party notices](THIRD_PARTY_NOTICES.md).
