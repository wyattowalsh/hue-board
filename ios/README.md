# Hue Board for iOS

This directory contains the native SwiftUI vertical slice stacked on the Hue Board 5.3 source candidate.

## Product contract

- **Play** creates or updates a Hue Bridge-native dynamic scene and recalls it. Once the Bridge acknowledges the recall, playback is independent of the phone.
- **Native Live** runs the deterministic Hue Board engine in Swift. On iOS 18–25 it is foreground-only. On iOS 26+, a user-started, duration-bounded session can request `BGContinuedProcessingTask` support so network updates may continue after the app backgrounds. iOS shows progress and can cancel or terminate the task.
- The current Live transport is deliberately rate-limited REST with long transitions. It is not a claim of exact high-frequency Hue Entertainment parity. A future production transport should integrate the Hue Entertainment Development Kit.
- Opening, pairing, refreshing, or changing tabs never writes to lights.

## Structure

- `Packages/HueBoardKit`: platform-neutral models, generated parity contract, full Swift engine port, scene payload builder, playback state machine, Hue v2 resource decoding, and Linux-testable parity tests.
- `Packages/HueBoardKit/Sources/HueBoardNativeCore/HueBridgeClient.swift`: strict HTTPS local Bridge transport, redirect rejection, application-key headers, request pacing, inventory and scene/light writes.
- `Packages/HueBoardKit/Sources/HueBoardNativeCore/NativeLiveRunner.swift`: bounded rate-limited Live loop.
- `App/Services/ContinuedLiveCoordinator.swift`: iOS 26 continued-processing registration, progress, persistence and cancellation.
- `App/AppModel.swift`: main-actor orchestration, recovery journal, Bridge scene registry, everyday controls and app state.
- `project.yml`: deterministic XcodeGen project source.

## Generate and run

Requirements:

- macOS with Xcode 26 or newer for `BGContinuedProcessingTask` compilation and device testing
- XcodeGen 2.46.0
- A physical iPhone and Hue Bridge on the same trusted network for meaningful validation

```sh
brew install xcodegen
cd ios
make parity
make verify
open HueBoard.xcodeproj
```

Select a signing team, install on a physical device, grant Local Network permission, press the Hue Bridge button, and pair.

## Verified here

- Swift 6.2 package compiles on Linux.
- 512 JavaScript engine vectors match Swift to `1e-9`.
- Contract, Hue resource decoding, scene JSON, host allowlisting and playback state tests pass.
- Every app Swift file passes the Swift parser.
- JavaScript behavior tests pass independently of the unpublished v5.3 installer manifest.
- GitHub includes a macOS 26 / Xcode 26.6 simulator build workflow for the generated project; current Actions execution remains externally blocked by the repository owner billing lock.

## Not verified here

- Xcode/iOS target compilation, code signing or installation, because this environment does not include Xcode.
- Hue Bridge TLS behavior and firmware compatibility.
- Local Network permission UX, iOS suspension, `BGContinuedProcessingTask` scheduling/expiration, or app-switcher termination.
- Physical light output, VoiceOver, energy use, thermal behavior, interruption recovery, or concurrent Hue controllers.

Do not publish or claim App Store readiness until those device checks pass.

## Current parity boundary

| Capability | Scriptable 5.3 | Native app |
| --- | --- | --- |
| Room/zone discovery and selection | Yes | Yes |
| Everyday power and area brightness | Yes | Yes |
| 32 curated looks and Bridge-native Play | Yes | Yes |
| Automatic phone-free Bridge playback | Yes | Yes |
| Deterministic 24-pattern engine | Yes | Yes, 512-vector parity gate |
| Exact Live choreography | Foreground REST controller | Foreground or bounded iOS 26 continued REST controller |
| Restore baseline | Yes | Yes |
| Hue layout editor, gradients, cue sequencer, saved-scene static copy | Yes | Planned native parity work |
| Hue Entertainment high-rate streaming | No | Planned native transport |

The native app is the primary product direction. Scriptable remains a compatibility implementation and parity oracle until the shared contract and native feature set cover the remaining advanced surfaces.
