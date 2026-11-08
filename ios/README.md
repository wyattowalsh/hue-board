# Hue Board native iOS app

The native SwiftUI app is the primary product direction for Hue Board. Scriptable remains a compatibility implementation and source-of-truth parity oracle while the native feature set converges.

## Playback contract

- **Play** creates or updates a compatible Hue Bridge dynamic scene, recalls it, and then lets the Bridge continue independently of the phone.
- **Native Live** executes the same deterministic JavaScript engine bundled with Scriptable through JavaScriptCore. Sessions are explicitly user-started and duration-bounded.
- On iOS 18–25, Native Live is foreground-only. On iOS 26+, it automatically requests `BGContinuedProcessingTask` after the user taps Start. The system displays progress and can cancel or expire the task.
- Force-quitting the app ends continued processing. It is not an unlimited daemon.
- Opening, pairing, refreshing, browsing, and changing tabs never write to lights.

## Architecture

- `HueBoardKit`: platform-neutral Hue models, API decoding, scene payloads, restore snapshots, playback state and generated parity contract.
- `HueBoardAppleEngine`: SHA-256-verified JavaScriptCore adapter around the exact shared Hue Board engine runtime.
- `HueBoardNativeCore`: persistence, strict private-host validation, redirect-rejecting HTTPS transport, Hue pairing, inventory and writes.
- `AppModel`: one-writer main-actor orchestration, restore journal, scene registry, everyday control, Bridge Play and Native Live.
- `App/Services`: Keychain credentials and iOS 26 continued-processing integration.
- `App/Views`: Lights, Scenes, Live, connection, playback status and Settings surfaces.
- `project.yml`: deterministic XcodeGen source. The generated `.xcodeproj` is intentionally ignored.

## Generate and verify

Requirements: Xcode 26+, XcodeGen 2.46.0, Node 22, pnpm 10.17.1, and a physical iPhone/Hue Bridge for integration qualification.

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

## Security boundary

The client accepts only private-LAN IPv4 addresses or syntactically valid `.local` hostnames, rejects HTTP redirects, uses standard system HTTPS trust, and keeps the Hue application key in Keychain with `AfterFirstUnlockThisDeviceOnly` accessibility. Actual Hue Bridge certificate-chain behavior still requires physical-device validation; this document does not claim certificate pinning.

## Verified in the current non-Xcode environment

- The shared native package previously compiled with Swift 6.2 before the app layer was added.
- The parity contract covers 32 looks, 24 patterns and 19 palettes; the Apple engine validates the bundled runtime digest before execution.
- All new SwiftUI and service sources pass the Swift parser.
- Existing JavaScript regression and synthetic timing suites remain independent of the unpublished v5.3 installer manifest.

## Not yet verified

- Xcode/iOS semantic typechecking, simulator build, code signing, installation or launch.
- Real Hue Bridge TLS, pairing, firmware resource variations, scene creation, lock-screen continuation or physical output.
- VoiceOver, Dynamic Type extremes, Reduce Motion, landscape, battery/thermal behavior and multiple competing Hue controllers.
- High-rate Hue Entertainment streaming. Native Live currently uses conservative paced REST transitions.

Do not call this App Store-ready until the Xcode and physical-device matrix passes.

## Current parity

| Capability | Scriptable 5.3 candidate | Native app |
| --- | --- | --- |
| Room/zone discovery and selection | Yes | Yes |
| Everyday power and brightness | Yes | Yes |
| 32 looks and automatic Bridge Play | Yes | Yes |
| Phone-free Bridge playback | Yes | Yes |
| Exact 24-pattern engine | Yes | Yes, shared JavaScriptCore runtime |
| Exact Live choreography | Foreground REST | Foreground, or bounded continued processing on iOS 26+ |
| Static restore baseline | Yes | Yes |
| Hue layout editor, gradients, cue sequencer, saved-scene copy | Yes | Planned |
| Hue Entertainment high-rate streaming | No | Planned transport |
