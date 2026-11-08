# Hue Board v5.3.0 source candidate

**Unreleased development candidate.** The GitHub pinned installer and checked-in distribution on the feature branch remain v5.2.0. They do not yet install v5.3 behavior. The `dist/hue-board.js` shipped in **this archive** is locally rebuilt from the included v5.3 source and is intended for controlled testing. It has not been validated on actual Hue hardware or Scriptable on iPhone.

## Highlights

- **Play** on compatible Hue rooms/zones automatically starts Bridge-native dynamic palette playback; no background preference toggle. Lock the phone only after Hue reports recall acceptance.
- **Live Studio** remains an explicit high-fidelity foreground-only mode. The exact patterns cannot reliably continue after Scriptable is suspended; a continuously running companion is required for that capability.
- Unacknowledged scene recall is displayed as **uncertain** and remains recoverable. Existing restore points and fixture caps are preserved. Opening the app never automatically changes lights.

## Candidate testing

Install [Scriptable](https://scriptable.app/) on trusted home Wi-Fi, make a backup of the existing working script, and paste the *locally built candidate* `dist/hue-board.js` into a **separate** Scriptable script. Do not use `install/install-hue-board.js` in this archive as a v5.3 installer: it is still pinned to v5.2.0.

Read [the detailed engineering audit](docs/audit-2026-11-08.md), [background playback contract](docs/background-playback.md), and [candidate release status](CANDIDATE_STATUS.md). Build with Node 22 / pnpm 10.17.1. The release/installer validation test is expected to fail until a new published revision and SHA-256 manifest exist. No real device was used in our tests.

This is an independent, MIT-licensed project, not affiliated with Philips Hue or Signify. Existing Scriptable transport relaxes Bridge TLS certificate checking; use trusted Wi-Fi only.

## Native iOS app

The native SwiftUI app is under [`ios/`](ios/README.md). It shares a source-generated contract with Scriptable: 32 looks, 24 patterns, 19 palettes, and 512 deterministic engine parity vectors. Bridge-native **Play** remains the default phone-free path. Native **Live** is foreground-only on iOS 18–25 and can request a bounded, user-visible continued-processing session on iOS 26+. The current native app is a source vertical slice, not yet an App Store release. Its [parity matrix, build path, and validation boundary](ios/README.md) are tracked explicitly.

