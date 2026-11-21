# Hue Board native iOS app

The native SwiftUI app is the primary product direction for Hue Board. Scriptable remains a compatibility implementation and source-of-truth parity oracle while the native feature set converges.

## Playback contract

- **Play** validates a saved scene identity, captures every light the next operation may touch, creates or updates a compatible Hue Bridge dynamic scene, recalls it, and then lets the Bridge continue independently of the phone.
- **Native Live** samples the same deterministic JavaScript engine bundled with Scriptable through JavaScriptCore. The current transport uses conservative, long REST transitions; sessions are explicitly user-started and duration-bounded.
- **Live input** in Studio can use the animation alone, a microphone, or a local audio or video file. The microphone contributes a level. Local media contributes a level and, for video, a frame color. Physical playback samples the input at the existing Live transition rate within the configured brightness limits.
- On iOS 18–25, Native Live is foreground-only. On iOS 26+, animation-only sessions request `BGContinuedProcessingTask` after the user taps Start. The system displays progress and can cancel or expire the task.
- Choosing **Microphone** or a file leaves the input idle. **Preview input** opens it on this iPhone without a Bridge connection, light writes or changes to recovery. Leaving Studio, opening Settings or the connection sheet, or moving Hue Board to the background stops the preview.
- **Start Studio Live** or **Start cue sequence** ends any preview before using the selected input for physical playback. Microphone and local media sessions stop when Hue Board enters the background, and their saved baseline remains available for restoration. Microphone metering retains only a sound level. Screen and cross-app audio capture belong to the separate [iOS 27 probe](ScreenInputProbe/README.md).
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
- **Stop & restore** requires a ready connection to the original Bridge. It reads current inventory before issuing commands and checks fresh Bridge readback against saved power, brightness, and the captured active XY color or color temperature. Missing or incompatible fixtures and unconfirmed settings keep the baseline available for retry.
- Partial restore failures retain all unresolved snapshots for another attempt.
- Normal credential removal remains restore-first. If the original Bridge is permanently unreachable or replaced, a separately confirmed **Discard recovery & forget Bridge** action removes the application key, certificate pin, scene registry, and unrecoverable baseline.

## Browse and compose

Scenes and Studio work offline. Search looks or edit a draft locally. Play and Start require a ready Bridge and the usual playback checks. Use **Jump to section** in Studio to reach the palette, cues or library, and use **Position X** and **Position Y** in Room for precise placement or as an alternative to dragging.

Room reads room membership from the Hue Bridge. While the Bridge is ready and idle, the room picker shows matching Hue Entertainment areas that supply saved fixture coordinates. Hue Board has no Apple Home reader and does not infer positions from room membership.

Select an area suggestion to preview its positions. **Save positions** updates the matched fixtures on the local map and preserves their animation phases. To change animation order, choose **Use positions for sweep**, review the eligible moving fixtures, then tap **Save phases**. Both edits preserve fixture selection, roles, trims and ceilings.

Studio previews the selected room or a labeled sample room when offline. Scrub the timeline or step between cues to see modeled fixture targets. Under **Playback**, choose **Microphone** or **Local media**, then use **Preview input** to see the level or video tint before an explicit physical Start. Audio uses the phone's input or the selected file, and video files supply a tint from the current frame. With Reduce Light Motion or iOS Dim Flashing Lights enabled, choose **Engine** for physical Live. Settings applies updated limits to a new playback session.

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

## Transfer local data

Use **Settings → Import and export → Export setup** to move several sections in one file. Import previews the changes and checks the destination again before saving. [Setup files and compatibility](../docs/native-setup-format.md)

Open **Settings → Import and export** to save or open JSON files in Files. Export the Studio draft, custom colors, cue sequence, saved mixes, scene favorites, selected room layout, or physical-light safety preferences. To export one mix as a canonical Hue Board scene document, choose **Export mix** from its Studio library menu.

Import previews the changes and asks for confirmation during idle playback. Mix imports add new items and skip identical copies. A different mix with the same document ID blocks the import and preserves the library. Canonical scene schema 2 and legacy Scriptable mix schema 3 files can be added to the Studio library. Importing a draft loads it into Studio. Save it as a mix to keep a local copy.

A layout file contains the original room or zone and fixture resource IDs so only matching placements can be updated. Keep layout files private when they describe your home. Layout import previews any brightness-ceiling changes. Safety preferences preserve the warning consent already recorded on the receiving device. Transfer files contain local configuration and exclude Bridge credentials, connection profiles, and recovery and playback state. Files never issue lighting commands.

## Parity gate

The generated contract covers **32 looks, 24 patterns and 19 palettes**. `scripts/export-ios-contract.cjs` also evaluates 512 deterministic frames across every preset, four times and four positions. It writes a compact canonical SHA-256 manifest rather than a large opaque fixture dump.

On Apple test hosts, `HueBoardAppleEngineTests` executes those 512 cases through JavaScriptCore and must reproduce the same digest. Eight named anchor cases remain in the manifest for readable diagnostics. The bundled engine runtime has its own independent SHA-256 integrity check before execution.

## Candidate build evidence

These checks were recorded during development of the named revisions. The build 6 qualification below applies to **0.2.2 (6)**. The current internal project is **0.3.0 (7)**. Installation and device evidence is recorded separately below.

- Xcode 27.2 signed generic iPhoneOS Debug build: passed, code signature verified. The spatial/cue candidate was subsequently installed as **0.2.1 (build 5)**.
- Swift package tests: nine spatial/cue model and persistence tests passed, plus two synthetic Native Live frame tests with no Bridge writes.
- JavaScript controller and native structural regression suite: 201/201 passed.
- The earlier native candidate had six passing iOS simulator tests. After the spatial/cue changes, build-for-testing passed, but simulator app-level execution stalled during Apple test launch. That simulator runtime check remains unverified.

### Reconciliation checkpoint checks

- Current JavaScript native-parity tests: **8/8 passed**.
- Current TypeScript check: **passed**.
- On November 21, 2026, the published `a9a5d905` checkpoint passed eight focused Apple package tests on Xcode 27.2, including the schema-2, eleven-decimal 512-frame JavaScriptCore digest and six transport tests.
- The existing-installation device runner's XcodeGen project generated successfully. Its physical-device assertions are qualified separately below.

### November 21 candidate source checks

On candidate `1c25352`, the full Apple package run passed **80 tests** with Xcode 27.2. It reproduced the 512-frame JavaScriptCore digest and covered restore readback, portable JSON, saved-mix palettes, spatial limits, cue ordering, and interruption and restart using synthetic clients.

On Node 22.23.1 and pnpm 10.17.1, all **201 JavaScript tests**, the **8 focused parity tests**, TypeScript, and the timing suite passed. Regenerating the contract left the tracked parity resources unchanged. XcodeGen 2.46.0 generated the app and the standalone DeviceSmoke project.

The signed generic iPhoneOS Debug build of `1c25352` passed. Signature verification succeeded, and the app bundle identified itself as **0.2.2 (build 6)**. Generic iPhoneOS `build-for-testing` compiled both app test targets. The standalone DeviceSmoke target also built for testing, and its runner signature verified after automatic development provisioning. CoreSimulator discovery stalled in both the default and an isolated device set, leaving simulator execution and rendered review unverified. Build receipts are stored under ignored `ios/DerivedData/qualification/` on the Mac.

### Saved layout and Live input candidate

Candidate `41bc092` passed **94 Apple package tests** on Xcode 27.2, including the unchanged 512-frame JavaScriptCore digest, saved Hue layout mapping, writer handoff, synthetic microphone-level modulation, and synthetic quiet/loud WAV and red MP4 sampling. All **201 JavaScript tests**, TypeScript, timing checks, and contract regeneration passed on Node 22.23.1 and pnpm 10.17.1. Xcode verified the signed build 6 app and DeviceSmoke runner, and generic iPhoneOS builds compiled both app test targets.

## Installed candidate evidence

Earlier physical-iPhone queries reported **0.2.1 (build 5)**. Two fresh copies independently verified the state and recovery checksums and reported a recovery journal, idle playback, and no live descriptor. The journal blocked the earlier browse-only test and the in-place candidate installation. The reusable [existing-installation device runner](DeviceSmoke/README.md) is versioned separately from the app.

The earlier device session reached **Bridge connected** and recorded the following results before that journal appeared.

- The explicit Stop & restore retry completed. The copied on-device state has a valid payload checksum, no recovery journal, no live descriptor, and idle playback. A later independent copy confirmed that the cleared state persisted.
- The original pre-installation baseline backup remains preserved. Recovery was cleared through the app's restore path, not by deleting its preferences.
- A partial paired-device UI check reached Lights, an individual-light sheet, and Scenes before its Scenes search-field lookup failed. The active debug write audit recorded zero Hue write attempts, and the post-check preferences remained checksum-valid, idle, and free of recovery/live-session records. This is not a passing full navigation or visual qualification.
- The standalone UI runner was revised to reveal search before querying it, rebuilt, and its signature verified. The next run was blocked before UI execution because iOS reported that the phone was locked. Studio, Room, search behavior, and screenshot review remain unverified in this device pass.
- The installed build 5 restore comparator confirmed power and brightness only. Verifying the active color settings on actual fixtures remains a hardware gate. Bridge readback does not establish emitted optical output.

### Build 6 in-place update

Later November 21 preflight copies independently reported a valid state checksum, idle playback, and the absence of a recovery journal and live descriptor. The change was detected before an authorized restore attempt, so Hue Board received no restore command from the runner. After confirming the matching app identity, development team, Keychain access and phone provisioning, the signed `41bc092` candidate was installed over build 5. The original recovery backup and a fresh pre-install copy remain private on the Mac. An independent post-install query identified **0.2.2 (build 6)**, and the copied state remained checksum-valid and idle without recovery or Live records.

The fresh browse preflight subsequently stalled in CoreDevice during the lock-state query and the app preferences copy. Restarting the user connection service did not restore device discovery. The browse runner never reached app activation, leaving the current write audit, navigation, and rendered review unverified. The app installation and post-install state receipts are separate from those runtime checks.

## Remaining release gates

- Repeat current UI/app tests to completion on a working simulator, or verify their equivalent on a connected physical device; inspect screenshots of the actual new screens.
- Validate tap/drag interactions, scene filtering, saved mixes, and VoiceOver/Dynamic Type/Reduce Motion with rendered evidence.
- With explicit user-started sessions, test spatial selection, output trims/ceilings, ordered/shuffled cues, custom palette editing, stop/restore, interruptions, and Bridge readback on the real iPhone/Bridge. No automatic light writes on opening or browsing.
- Validate reconnect and restored baseline behavior after termination and certificate rotation. Do not assume a successful Hue API acknowledgment measures physical emitted light.
- Confirm Hue Entertainment positions against a known-direction saved area on actual hardware. High-rate Entertainment streaming, gradient-strip editing and saved Hue scene copying remain unsupported.

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
| Static restore baseline | Yes | Expands for newly touched lights and checks active color during readback; incomplete restores retain the baseline |
| Individual per-light power, brightness, color, white controls | Yes | New native editing sheet with capability and temperature-range gating |
| Local spatial editor (fixture selection, positions, phase, roles, trim, ceilings) | Yes | Room-scoped editor, saved-area discovery, position import and optional left-to-right phase assignment |
| Saved Studio mixes | Yes | Validated, scope-free local scene documents with JSON import and export |
| Custom four-color palettes and engine-sampled thumbnails | Yes | New editable Studio palette and sampled visual previews; no optical-output claims |
| Cue sequencing | Yes | New ordered/seeded-shuffle cues within one bounded Native Live lease; still requires device verification |
| Settings and design portability | Scene documents and local preferences | Selective setup bundles and individual JSON files for Studio drafts, palettes, cues, saved mixes, favorites, room layouts and lighting safety preferences |
| Microphone and audio/video inputs | Microphone response | Opt-in offline preview and foreground Native Live using microphone level, local-audio level and local-video tint. Physical validation pending |
| Apple Home spatial geometry, cross-app screen or audio capture | No | Unavailable in the internal app. The isolated iOS 27 screen-input probe has its own evidence gates |
| Gradient-strip editing and saved Hue scene copying | Yes | Not yet implemented |
| Hue Entertainment high-rate streaming | No | Required future transport for exact temporal choreography |
