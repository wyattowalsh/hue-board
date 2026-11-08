# Hue Board native iOS app

The native SwiftUI app is the primary product direction for Hue Board. Scriptable remains a compatibility implementation and source-of-truth parity oracle while the native feature set converges.

## Playback contract

- **Play** creates or updates a compatible Hue Bridge dynamic scene, recalls it, and then lets the Bridge continue independently of the phone.
- **Native Live** samples the same deterministic JavaScript engine bundled with Scriptable through JavaScriptCore. The current transport uses conservative, long REST transitions; sessions are explicitly user-started and duration-bounded.
- On iOS 18–25, Native Live is foreground-only. On iOS 26+, it requests `BGContinuedProcessingTask` after the user taps Start. The system displays progress and can cancel or expire the task.
- Force-quitting the app ends continued processing. It is not an unlimited daemon.
- Opening, pairing, refreshing, browsing, and changing tabs never write to lights.

## Architecture

- `HueBoardKit`: platform-neutral Hue models, API decoding, scene payloads, restore snapshots, playback state and generated parity resources.
- `HueBoardAppleEngine`: SHA-256-verified JavaScriptCore adapter around the exact shared Hue Board engine runtime.
- `HueBoardNativeCore`: persistence, strict private-host validation, Bridge-ID-aware certificate trust and pinning, redirect rejection, Hue pairing, inventory and writes.
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

The local client accepts only private-LAN IPv4 addresses or syntactically valid `.local` hostnames and rejects redirects. During verification it requires the TLS certificate Bridge ID to match the Bridge API identity, validates the certificate as a leaf trust anchor with an SSL policy for that Bridge ID, records the certificate SHA-256, and pins the fingerprint for later requests. A changed certificate fails closed.

This is explicit trust on first use, not public-web PKI. Verify first contact on a trusted home network. Legitimate certificate rotation or Bridge replacement requires deliberate re-verification and pairing. The Hue application key is stored separately in Keychain with `AfterFirstUnlockThisDeviceOnly` accessibility.

## Parity gate

The generated contract covers **32 looks, 24 patterns and 19 palettes**. `scripts/export-ios-contract.cjs` also evaluates 512 deterministic frames across every preset, four times and four positions. It writes a compact canonical SHA-256 manifest rather than a large opaque fixture dump.

On Apple test hosts, `HueBoardAppleEngineTests` executes those 512 cases through JavaScriptCore and must reproduce the same digest. Eight named anchor cases remain in the manifest for readable diagnostics. The bundled engine runtime has its own independent SHA-256 integrity check before execution.

## Verified in the current non-Xcode environment

- Swift 6.2 harnesses compile the platform-neutral certificate identity and pin-validation logic, including the Apple-specific trust branch against Security/CryptoKit API-shape stubs.
- Independent JavaScript and Swift canonical-format passes reproduce the same 512-frame parity digest.
- All new SwiftUI and service sources have passed Swift parsing and a cross-file Swift 6 API-shape/typecheck harness.
- Existing JavaScript regression and synthetic timing suites remain independent of the unpublished v5.3 installer manifest.

These checks are useful but do not substitute for the exact Xcode target, Apple Security implementation, simulator, or physical-device tests.

## Not yet verified

- Exact Xcode/iOS semantic typechecking, simulator build, code signing, installation or launch.
- Real Hue Bridge certificate chains and rotations, pairing, firmware resource variations, scene creation, lock-screen continuation or physical output.
- VoiceOver, Dynamic Type extremes, Reduce Motion, landscape, battery/thermal behavior and multiple competing Hue controllers.
- High-rate Hue Entertainment streaming. The current Native Live REST fallback deliberately revisits each light no faster than its long transition horizon; an Entertainment transport is required for high-rate temporal fidelity.

Do not call this App Store-ready until the Xcode and physical-device matrix passes.

## Current parity

| Capability | Scriptable 5.3 candidate | Native app |
| --- | --- | --- |
| Room/zone discovery and selection | Yes | Yes |
| Everyday power and brightness | Yes | Yes |
| 32 looks and automatic Bridge Play | Yes | Yes |
| Phone-free Bridge playback | Yes | Yes |
| Exact 24-pattern engine | Yes | Shared JavaScriptCore runtime plus 512-frame digest gate |
| Shared-engine Live samples | Foreground REST | Low-rate REST fallback, foreground or bounded continued processing on iOS 26+ |
| Static restore baseline | Yes | Yes |
| Hue layout editor, gradients, cue sequencer, saved-scene copy | Yes | Planned |
| Hue Entertainment high-rate streaming | No | Required future transport for exact temporal choreography |
