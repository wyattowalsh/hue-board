# Hue Board native iOS app

The native SwiftUI app is the primary product direction for Hue Board. Scriptable remains a compatibility implementation and source-of-truth parity oracle while the native feature set converges.

## Playback contract

- **Play** validates a saved scene identity, captures every light the next operation may touch, creates or updates a compatible Hue Bridge dynamic scene, recalls it, and then lets the Bridge continue independently of the phone.
- **Native Live** samples the same deterministic JavaScript engine bundled with Scriptable through JavaScriptCore. The current transport uses conservative, long REST transitions; sessions are explicitly user-started and duration-bounded.
- On iOS 18–25, Native Live is foreground-only. On iOS 26+, it requests `BGContinuedProcessingTask` after the user taps Start. The system displays progress and can cancel or expire the task.
- Force-quitting the app ends continued processing. It is not an unlimited daemon.
- Opening, verifying, pairing, reconnecting, refreshing, browsing, and changing tabs never write to lights.

## Connection and live readback

- Local discovery uses Bonjour `_hue._tcp` and combines it with the Hue discovery broker. Manual private-LAN IPv4 and trusted `.local` entry remain available.
- First verification requires the local Hue API Bridge ID to match the TLS certificate identity. Hue Board then pins the leaf SHA-256 for later requests.
- Pairing stores the application key separately in Keychain. If pairing succeeded but inventory failed, **Retry saved connection** verifies the pin and reuses the saved key instead of creating another one.
- While the app is active, the pinned Hue v2 event stream merges partial light updates into the current room/zone readback. Structural add/delete events trigger a debounced full inventory refresh.
- Passive event monitoring stops when the app backgrounds. Native Live continued processing is a separate, explicit task.
- Event payloads are bounded to 256 KiB. Authentication, TLS, malformed payload, and unsupported-platform failures stop retrying; network, 429, and Bridge 5xx failures use bounded exponential reconnects.

## Recovery contract

- A timestamped static baseline is captured before any scene create, scene update, scene recall, or Native Live write that may affect lights.
- Replaying in the same area preserves existing snapshots and appends only newly touched lights. Earlier pre-playback baselines are never replaced by later state.
- **Turn off now** cancels Native Live and, during a recovery session, targets only lights covered by that baseline. Missing, streaming, and failed lights are reported explicitly; the restore journal is retained.
- Partial restore failures retain all unresolved snapshots for another attempt.
- Normal credential removal remains restore-first. If the original Bridge is permanently unreachable or replaced, a separately confirmed **Discard recovery & forget Bridge** action removes the application key, certificate pin, scene registry, and unrecoverable baseline.

## Architecture

- `HueBoardKit`: platform-neutral Hue models, API/event decoding, scene payloads, restore snapshots, spatial layouts, cue plans, playback state and generated parity resources.
- `HueBoardAppleEngine`: SHA-256-verified JavaScriptCore adapter around the exact shared Hue Board engine runtime.
- `HueBoardNativeCore`: persistence, private-host validation, Bridge-ID-aware certificate trust and pinning, redirect rejection, Hue pairing, inventory, event streaming, writes, and the single-session Live sampler.
- `AppModel`: one-writer main-actor orchestration split into connection, reconnect, events, everyday controls, Bridge Play, Native Live and recovery extensions.
- `App/Services`: Bonjour discovery, Keychain credentials, validated saved-mix storage, and iOS 26 continued-processing lease management.
- `App/Views`: Lights, Scenes, Studio, Room layout, individual light controls, cue/library controls, connection, playback/recovery status and Settings surfaces.
- `project.yml`: deterministic XcodeGen source. The generated `.xcodeproj` is intentionally ignored.

## Generate and verify

Requirements: Xcode 27.2 or newer, XcodeGen 2.46.0, Node 22, pnpm 10.17.1, and a physical iPhone/Hue Bridge for integration qualification. The device path fails closed below Xcode 27.2.

```sh
corepack enable
pnpm install --frozen-lockfile
cd ios
make parity
make project
make build
open HueBoard.xcodeproj
```

Select a signing team before installing on a device. Pairing requires the physical Bridge button and Local Network permission.

## Test on an iPhone

Use the [one-command device runner](DEVICE_RUNNER.md) to perform fail-closed preflight, source tests, pinned XcodeGen generation, automatic-signing device build, installation, and launch. The shortest route after local configuration is:

```sh
cd ios
make iphone-preflight
make iphone-list
make iphone-run
```

Use the [physical iPhone testing guide](DEVICE_TESTING.md) for the exact repository checkout, signing and Developer Mode setup, Local Network permission, Bridge pairing, low-risk playback matrix, evidence capture, troubleshooting, and later TestFlight path.

The fastest first install is a direct Xcode development build. A free Personal Team is sufficient for a personal device, although its provisioning expires and requires periodic reinstallation. Do not begin with TestFlight because direct Xcode installation exposes signing, local-network, TLS, pairing, and runtime diagnostics immediately.

## Security boundary

The local client accepts only private-LAN IPv4 addresses or syntactically valid `.local` hostnames and rejects redirects. During verification it requires the TLS certificate Bridge ID to match the Bridge API identity, validates the certificate as a leaf trust anchor with an SSL policy for that Bridge ID, records the certificate SHA-256, and pins the fingerprint for later requests. A changed certificate fails closed.

This is explicit trust on first use, not public-web PKI. Verify first contact on a trusted home network. Legitimate certificate rotation or Bridge replacement requires deliberate re-verification and pairing. The Hue application key is stored separately in Keychain with `AfterFirstUnlockThisDeviceOnly` accessibility.

## Parity gate

The generated contract covers **32 looks, 24 patterns and 19 palettes**. `scripts/export-ios-contract.cjs` also evaluates 512 deterministic frames across every preset, four times and four positions. It writes a compact canonical SHA-256 manifest rather than a large opaque fixture dump.

On Apple test hosts, `HueBoardAppleEngineTests` executes those 512 cases through JavaScriptCore and must reproduce the same digest. Eight named anchor cases remain in the manifest for readable diagnostics. The bundled engine runtime has its own independent SHA-256 integrity check before execution.

## Local candidate evidence (November 17, 2026)

This section describes tests actually run against a **local, uncommitted development worktree**. It is not the published GitHub release.

- Xcode 27.2 signed generic iPhoneOS Debug build: passed, code signature verified. **This spatial/cue candidate has not been installed on the physical iPhone.**
- Swift package tests: nine spatial/cue model and persistence tests passed, plus two synthetic Native Live frame tests with no Bridge writes.
- JavaScript controller and native structural regression suite: 201/201 passed.
- The earlier native candidate had six passing iOS simulator tests, but after these changes the new simulator app-level test execution stalled during Apple test launch. Build-for-testing passed; the current UI/runtime tests are **unverified**, not passed.
- Previous physical-iPhone installation, launch, and Hue Bridge pairing applied to the *earlier* native build. They cannot qualify new spatial controls or cue playback.

## Remaining release gates

- Repeat current UI/app tests to completion on a working simulator, or verify their equivalent on a connected physical device; inspect screenshots of the actual new screens.
- Validate tap/drag interactions, scene filtering, saved mixes, and VoiceOver/Dynamic Type/Reduce Motion with rendered evidence.
- With explicit user-started sessions, test spatial selection, output trims/ceilings, ordered/shuffled cues, custom palette editing, stop/restore, interruptions, and Bridge readback on the real iPhone/Bridge. No automatic light writes on opening or browsing.
- Validate reconnect and restored baseline behavior after termination and certificate rotation. Do not assume a successful Hue API acknowledgment measures physical emitted light.
- High-rate Entertainment streaming, Hue Entertainment layout import, gradient-strip editing, and saved Hue scene copying remain unsupported.

Do not call this parity-complete or App Store-ready before the applicable physical-device gates pass.

## Current parity

| Capability | Scriptable 5.3 candidate | Native app |
| --- | --- | --- |
| Room/zone discovery and selection | Yes | Bonjour + broker + manual verified host |
| Everyday power and brightness | Yes | Yes, plus Hue event-stream readback |
| 32 looks and automatic Bridge Play | Yes | Yes |
| Phone-free Bridge playback | Yes | Yes |
| Exact 24-pattern engine | Yes | Shared JavaScriptCore runtime plus 512-frame digest gate |
| Shared-engine Live samples | Foreground REST | Low-rate REST fallback, foreground or bounded continued processing on iOS 26+ |
| Static restore baseline | Yes | Expands safely for newly touched lights; partial failures retained |
| Individual per-light power, brightness, color, white controls | Yes | New native editing sheet with capability and temperature-range gating |
| Local spatial editor (fixture selection, positions, phase, roles, trim, ceilings) | Yes | New native room-scoped editor; direct Hue layout import not implemented |
| Saved Studio mixes | Yes | New validated, scope-free local scene documents; not synced to other devices |
| Custom four-color palettes and engine-sampled thumbnails | Yes | New editable Studio palette and sampled visual previews; no optical-output claims |
| Cue sequencing | Yes | New ordered/seeded-shuffle cues within one bounded Native Live lease; still requires device verification |
| Hue layout import, gradient-strip editing, saved Hue scene copying | Yes | Not yet implemented |
| Hue Entertainment high-rate streaming | No | Required future transport for exact temporal choreography |
